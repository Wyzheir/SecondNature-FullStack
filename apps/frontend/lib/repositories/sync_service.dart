// lib/repositories/sync_service.dart

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/database/record_dao.dart';
import '../models/record.dart';
import '../providers/auth_provider.dart';
import '../core/network/dio_client.dart';

class SyncService {
  final RecordDao _recordDao;
  final DioClient _dioClient;
  final AuthProvider _authProvider;
  final Connectivity _connectivity = Connectivity();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isSyncing = false;
  VoidCallback? onSyncComplete;
  Timer? _autoRetryTimer;
  Timer? _networkDebounceTimer;

  // 🚀 新增：内存待同步队列，用于合并短时间内多次单条同步请求
  final List<HealthRecord> _pendingSingleSyncQueue = [];

  SyncService({
    required RecordDao recordDao,
    required DioClient dioClient,
    required AuthProvider authProvider,
  }) : _recordDao = recordDao,
       _dioClient = dioClient,
       _authProvider = authProvider {
    _initNetworkListener();
    _startAutoRetryHeartbeat();
  }

  // --- 自动重试心跳 (改为触发同步循环) ---
  void _startAutoRetryHeartbeat() {
    _autoRetryTimer?.cancel();
    _autoRetryTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      final userId = _authProvider.userId;
      if (userId != null && !_isSyncing) {
        final unsyncedCount = await _recordDao.getUnsyncedCountByUserId(userId);
        if (unsyncedCount > 0 || _pendingSingleSyncQueue.isNotEmpty) {
          debugPrint('🔄 [心跳] 发现待同步数据，启动同步循环...');
          _runSyncLoop();
        }
      }
    });
  }

  // --- 网络恢复监听 (触发同步循环) ---
  void _initNetworkListener() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      results,
    ) {
      if (_networkDebounceTimer?.isActive ?? false) {
        _networkDebounceTimer!.cancel();
      }
      _networkDebounceTimer = Timer(const Duration(milliseconds: 1500), () {
        final hasNetwork = results.any(
          (result) => result != ConnectivityResult.none,
        );
        if (hasNetwork && _authProvider.isAuthenticated) {
          debugPrint('🌐 [网络恢复] 启动同步循环...');
          _runSyncLoop();
        }
      });
    });
  }

  // ==========================================
  //  🧩 重构核心：同步循环 (合并队列 + 数据库未同步记录)
  // ==========================================
  Future<void> _runSyncLoop() async {
    // 防止并发执行
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      while (true) {
        if (!_authProvider.isAuthenticated) {
          debugPrint('🔒 [同步循环] 未认证，终止同步。');
          break;
        }

        // 🚀 物理网络探针：确保底层 Socket 可用
        final connectivityResults = await _connectivity.checkConnectivity();
        final hasNetwork = connectivityResults.any(
          (r) => r != ConnectivityResult.none,
        );
        if (!hasNetwork) {
          debugPrint('📴 [底层拦截] 当前无网络，停止同步循环，队列保留。');
          break;
        }

        final userId = _authProvider.userId!; // 前面已保证不为 null

        // 1. 取出当前内存队列中的所有记录并清空
        List<HealthRecord> queueRecords = [];
        if (_pendingSingleSyncQueue.isNotEmpty) {
          queueRecords = List<HealthRecord>.from(_pendingSingleSyncQueue);
          _pendingSingleSyncQueue.clear();
          debugPrint('📤 [同步循环] 从内存队列取出 ${queueRecords.length} 条待同步记录');
        }

        // 2. 从数据库获取未同步记录 (包括刚才 syncSingleRecord 标记为 0 的记录)
        final List<Map<String, dynamic>> rawRecords = await _recordDao
            .getUnsyncedRecords(userId);
        List<HealthRecord> dbRecords = rawRecords
            .map((map) => HealthRecord.fromMap(map))
            .toList();

        // 3. 合并去重：使用 clientMsgId 为键，内存队列中的版本优先 (因为它可能更新鲜)
        final Map<String, HealthRecord> mergedMap = {};
        for (var r in dbRecords) {
          mergedMap[r.clientMsgId] = r;
        }
        for (var r in queueRecords) {
          mergedMap[r.clientMsgId] = r; // 后入覆盖
        }
        List<HealthRecord> allRecords = mergedMap.values.toList();

        // 4. 如果没有待同步数据，退出循环
        if (allRecords.isEmpty) {
          debugPrint('✅ [同步循环] 无待同步记录，退出。');
          break;
        }

        debugPrint('🔄 [同步循环] 准备批量同步 ${allRecords.length} 条记录...');

        // 5. 发送批量同步请求
        try {
          final payload = {
            "user_id": userId,
            "records": allRecords.map((r) => r.toJson()).toList(),
          };

          final response = await _dioClient.dio.post(
            '/records/batch_sync',
            data: payload,
          );

          if (response.data['code'] == 200) {
            List<String> syncedIds = allRecords
                .map((r) => r.clientMsgId)
                .toList();
            await _recordDao.updateSyncStatusBatch(syncedIds, 1);
            debugPrint('✅ [批量同步] ${syncedIds.length} 条记录成功上云');
            onSyncComplete?.call();
          } else {
            debugPrint('⚠️ [批量同步] 服务器返回非200: ${response.data['message']}');
            break; // 业务错误，退出循环，下次再试
          }
        } on DioException catch (e) {
          debugPrint('⏳ [批量同步] 网络错误: ${e.message}，等待下次触发。');
          // 网络错误时，队列已清空，但数据库记录仍为 sync_status = 0，
          // 下次网络恢复或定时器会重新拉取并同步。
          break;
        }
        // 成功后继续循环，检查是否有新的记录在本次发送期间被加入内存队列
      }
    } catch (e) {
      debugPrint('❌ [同步循环] 异常: $e');
    } finally {
      _isSyncing = false;
      // 如果同步循环结束后内存队列中又积压了新记录，则自动再次启动
      _isSyncing = false;
      if (_pendingSingleSyncQueue.isNotEmpty && _authProvider.isAuthenticated) {
        Future.microtask(() => _runSyncLoop());
      }
    }
  }

  // ==========================================
  //  🧩 重构后的单条记录同步入口 (加入队列，标记为未同步)
  // ==========================================
  Future<void> syncSingleRecord(HealthRecord record) async {
    final userId = _authProvider.userId;
    if (userId == null) return;

    try {
      await _recordDao.updateSyncStatus(record.clientMsgId, 0);
      _pendingSingleSyncQueue.add(record);
      debugPrint('📥 [单条同步] 加入同步队列，当前队列长度: ${_pendingSingleSyncQueue.length}');
      if (!_isSyncing) {
        _runSyncLoop();
      }
    } catch (e) {
      // 吞掉所有异常，不中断调用方
      debugPrint('❌ [单条同步] 内部异常: $e');
    }
  }

  // --- 原有云端拉取逻辑保持不变 ---
  Future<void> pullRecordsFromCloud() async {
    final userId = _authProvider.userId;
    if (userId == null) return;

    final results = await _connectivity.checkConnectivity();
    if (!results.any((r) => r != ConnectivityResult.none)) return;

    try {
      final response = await _dioClient.dio.get(
        '/records',
        queryParameters: {'user_id': userId},
      );
      final List<dynamic>? recordsData = response.data['data'];

      if (recordsData != null && recordsData.isNotEmpty) {
        List<Map<String, dynamic>> bulkInsertList = [];
        for (var recordMap in recordsData) {
          final map = Map<String, dynamic>.from(recordMap);
          map['user_id'] = userId;
          map['sync_status'] = 1;
          bulkInsertList.add(map);
        }
        await _recordDao.insertRecordsBatch(bulkInsertList);
        onSyncComplete?.call();
      }
    } catch (e) {
      debugPrint('❌ [漫游拉取] 异常: $e');
    }
  }

  // --- 手动触发全部同步 ---
  Future<void> triggerSyncManually() async {
    await _runSyncLoop();
    await pullRecordsFromCloud();
  }

  // --- 资源释放 ---
  void dispose() {
    _connectivitySubscription?.cancel();
    _networkDebounceTimer?.cancel();
    _autoRetryTimer?.cancel();
    _pendingSingleSyncQueue.clear();
  }
}
