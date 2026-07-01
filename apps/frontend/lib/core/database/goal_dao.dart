import 'package:sqflite/sqflite.dart';
import '../../models/goal.dart';

class GoalDao {
  final Database db;
  static const String tableName = 'local_health_goals';

  GoalDao(this.db);

  static const String createTableQuery =
      '''
    CREATE TABLE $tableName (
      local_id INTEGER PRIMARY KEY AUTOINCREMENT,
      client_msg_id TEXT NOT NULL UNIQUE, 
      user_id TEXT NOT NULL,
      goal_type TEXT,
      target_weight REAL,
      gender TEXT NOT NULL,
      age INTEGER NOT NULL,
      height REAL NOT NULL,
      weight REAL NOT NULL,
      activity_level TEXT NOT NULL,
      sync_status INTEGER DEFAULT 0,
      target_kcal REAL,
      carbs_g REAL,
      protein_g REAL,
      fat_g REAL
    )
  ''';

  /// ✅ 获取特定用户的健康目标记录 (已有的，保持不变)
  Future<List<Goal>> getGoalsByUserId(String userId) async {
    final List<Map<String, dynamic>> maps = await db.query(
      tableName,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'local_id DESC',
    );
    return maps.map((map) => Goal.fromMap(map)).toList();
  }

  /// ✅ 插入或替换记录
  Future<int> insertGoal(Goal goal) async {
    return await db.insert(
      tableName,
      goal.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// ✅ 更新同步状态
  Future<void> updateSyncStatus(String clientMsgId, int status) async {
    await db.update(
      tableName,
      {'sync_status': status},
      where: 'client_msg_id = ?',
      whereArgs: [clientMsgId],
    );
  }

  /// 🚀 【精准改造 1】：获取“当前用户”未同步的数据量
  /// 避免把其他用户的待同步数据计入当前用户的 UI 显示
  Future<int> getUnsyncedCountByUserId(String userId) async {
    final result = await db.rawQuery(
      'SELECT COUNT(*) FROM $tableName WHERE user_id = ? AND sync_status = 0',
      [userId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// 🚀 【精准改造 2】：获取“当前用户”待同步的队列
  /// 这样 SyncService 在后台同步时，才不会拿用户 A 的 Token 去传用户 B 的数据
  Future<List<Goal>> getPendingGoalsByUserId(String userId) async {
    final List<Map<String, dynamic>> maps = await db.query(
      tableName,
      where: 'user_id = ? AND sync_status = 0',
      whereArgs: [userId],
    );
    return maps.map((map) => Goal.fromMap(map)).toList();
  }

  /// 🚀 【精准改造 3】：获取“当前用户”的所有记录
  /// 原来的 getAllGoals 会暴露其他用户隐私，现在只给看自己的
  Future<List<Goal>> getUserAllGoals(String userId) async {
    final List<Map<String, dynamic>> maps = await db.query(
      tableName,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'local_id DESC',
    );
    return maps.map((map) => Goal.fromMap(map)).toList();
  }
}
