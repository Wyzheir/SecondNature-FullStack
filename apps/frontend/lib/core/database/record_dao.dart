import 'package:sqflite/sqflite.dart';

class RecordDao {
  final Database db;
  static const String tableName = 'local_health_records';

  RecordDao(this.db);

  /// 1. 插入单条打卡记录 (防重写入)
  Future<int> insertRecord(Map<String, dynamic> recordMap) async {
    return await db.insert(
      tableName,
      recordMap,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 🚀 【核心补齐】：快速获取特定用户的未同步数量
  /// 专门用于修复 SyncService 的编译报错，心跳探测专用
  Future<int> getUnsyncedCountByUserId(String userId) async {
    final result = await db.rawQuery(
      'SELECT COUNT(*) FROM $tableName WHERE user_id = ? AND sync_status = 0',
      [userId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// 2. 获取指定用户的未同步记录 (推送 Push 专用)
  Future<List<Map<String, dynamic>>> getUnsyncedRecords(String userId) async {
    return await db.query(
      tableName,
      where: 'sync_status = ? AND user_id = ?',
      whereArgs: [0, userId],
    );
  }

  /// 3. 按时间倒序获取指定用户的所有记录 (UI 列表展示专用)
  Future<List<Map<String, dynamic>>> getRecordsByUserId(String userId) async {
    return await db.query(
      tableName,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'record_date DESC', // 确保最新记录在最前
    );
  }

  /// 4. 批量更新同步状态 (核销专用)
  Future<void> updateSyncStatusBatch(
    List<String> clientMsgIds,
    int status,
  ) async {
    if (clientMsgIds.isEmpty) return;

    final batch = db.batch();
    for (var id in clientMsgIds) {
      batch.update(
        tableName,
        {'sync_status': status},
        where: 'client_msg_id = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
  }

  /// 5. 单条更新同步状态
  Future<void> updateSyncStatus(String clientMsgId, int status) async {
    await db.update(
      tableName,
      {'sync_status': status},
      where: 'client_msg_id = ?',
      whereArgs: [clientMsgId],
    );
  }

  Future<int> updateRecord(Map<String, dynamic> recordMap) async {
    return await db.update(
      tableName,
      recordMap,
      where: 'client_msg_id = ?',
      whereArgs: [recordMap['client_msg_id']],
    );
  }

  /// 🚀 核心补齐：极速批量写库
  /// 已经安全放进类的内部，彻底解决变量找不到和方法未定义的问题！
  Future<void> insertRecordsBatch(List<Map<String, dynamic>> records) async {
    final batch = db.batch();
    for (var record in records) {
      batch.insert(
        tableName,
        record,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }
}
