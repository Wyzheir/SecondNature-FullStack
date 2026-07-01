import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart'; // 引入 Dio 捕获网络异常
import '../core/database/food_dict_dao.dart';
import '../core/network/dio_client.dart'; // 引入网络客户端

class FoodDictProvider extends ChangeNotifier {
  final FoodDictDao _dao;
  final DioClient _dioClient; // 注入网络层

  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  Timer? _debounceTimer;

  // 🚀 新增：排序策略状态 (true: 频次优先, false: 最新优先)
  bool _sortByCount = true;

  List<Map<String, dynamic>> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  bool get sortByCount => _sortByCount; // 暴露给 UI

  FoodDictProvider(this._dao, this._dioClient);

  // 🚀 新增：切换排序策略的方法
  void toggleSortStrategy() {
    _sortByCount = !_sortByCount;
    _applySortLogic(); // 触发内存重排
    notifyListeners();
  }

  void search(String keyword) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();

    if (keyword.isEmpty) {
      _executeSearch('');
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _executeSearch(keyword);
    });
  }

  Future<void> _executeSearch(String keyword) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. 先查本地 SQLite (离线优先策略)
      List<Map<String, dynamic>> localResults = await _dao.searchFoods(keyword);

      // 2. 如果本地搜不到且有关键词，触发云端旁路补偿
      if (localResults.isEmpty && keyword.isNotEmpty) {
        debugPrint('🌐 [系统测试] 本地 SQLite 未命中 "$keyword"，启动云端旁路检索...');
        localResults = await _fetchFromCloud(keyword);
      }

      // 🚀 核心修复 1：sqflite 返回的是只读列表，必须深拷贝一份成可变列表，才能执行后续的 sort()！
      _searchResults = List<Map<String, dynamic>>.from(localResults);

      _applySortLogic(); // 统一执行排序策略
    } catch (e) {
      debugPrint('🚨 [系统异常] 检索食物词库彻底失败: $e');
      _searchResults = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 内部辅助：云端拉取逻辑
  Future<List<Map<String, dynamic>>> _fetchFromCloud(String keyword) async {
    try {
      final response = await _dioClient.dio.get(
        '/foods/search',
        queryParameters: {'keyword': keyword},
      );
      if (response.data['code'] == 200) {
        final List<dynamic> cloudData = response.data['data'];
        final List<Map<String, dynamic>> results = cloudData
            .map((e) => e as Map<String, dynamic>)
            .toList();

        // 🔧 核心修复：将云端结果静默写入本地词库，下次断网或重复搜索时可直接命中
        if (results.isNotEmpty) {
          await _dao.cacheCloudFoods(results);
        }

        return results;
      }
    } on DioException catch (e) {
      debugPrint('⚠️ [系统警告] 云端检索接口超时或报错: ${e.message}');
    }
    return [];
  }

  // 内部辅助：核心排序算法剥离出 UI 层
  void _applySortLogic() {
    _searchResults.sort((a, b) {
      if (_sortByCount) {
        final countA = a['usage_count'] as int? ?? 0;
        final countB = b['usage_count'] as int? ?? 0;
        return countB.compareTo(countA);
      } else {
        final timeA = a['last_used_at'] as String? ?? '';
        final timeB = b['last_used_at'] as String? ?? '';
        return timeB.compareTo(timeA);
      }
    });
  }

  Future<void> recordUsage(Map<String, dynamic> food) async {
    try {
      await _dao.recordUsage(food);
      debugPrint('✅ [本地写盘] 食物 ${food['food_name']} 频次已自增更新');

      // 🚀 核心修复 2：数据落盘后，立刻触发一次空搜索，强制刷新“最近添加”列表！
      search('');
    } catch (e) {
      debugPrint('❌ [本地写盘] 记录食物频次失败: $e');
    }
  }
}
