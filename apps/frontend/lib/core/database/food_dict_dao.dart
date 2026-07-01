// lib/core/database/food_dict_dao.dart

import 'package:flutter/foundation.dart'; // 🔧 补充 debugPrint 依赖
import 'package:sqflite/sqflite.dart';

class FoodDictDao {
  final Database db;
  static const String tableName = 'local_food_dictionary';

  FoodDictDao(this.db);

  /// 🔍 核心算法：空关键词返回常吃/最近，有关键词走模糊搜索
  Future<List<Map<String, dynamic>>> searchFoods(String keyword) async {
    String whereClause = '';
    List<String> whereArgs = [];

    if (keyword.trim().isNotEmpty) {
      whereClause = 'WHERE food_name LIKE ?';
      whereArgs = ['%${keyword.trim()}%'];
    } else {
      whereClause = 'WHERE usage_count > 0';
    }

    return await db.rawQuery('''
      SELECT * FROM $tableName 
      $whereClause 
      ORDER BY usage_count DESC, last_used_at DESC 
      LIMIT 50
    ''', whereArgs.isEmpty ? null : whereArgs);
  }

  /// 🧠 记忆进化 (Upsert)：有则 +1 且刷新时间，无则插入
  Future<void> recordUsage(Map<String, dynamic> food) async {
    await db.rawInsert(
      '''
      INSERT INTO $tableName 
      (food_name, default_kcal, default_carbs, default_protein, default_fat, usage_count, last_used_at)
      VALUES (?, ?, ?, ?, ?, 1, ?)
      ON CONFLICT(food_name) DO UPDATE SET 
        usage_count = usage_count + 1,
        last_used_at = excluded.last_used_at
    ''',
      [
        food['food_name'],
        food['default_kcal'],
        food['default_carbs'],
        food['default_protein'],
        food['default_fat'],
        DateTime.now().toIso8601String(),
      ],
    );
  }

  /// 🚀 新增：云端搜索结果静默缓存
  Future<void> cacheCloudFoods(List<Map<String, dynamic>> cloudFoods) async {
    final batch = db.batch();
    for (var food in cloudFoods) {
      batch.rawInsert(
        '''
        INSERT INTO $tableName 
        (food_name, default_kcal, default_carbs, default_protein, default_fat, usage_count, last_used_at)
        VALUES (?, ?, ?, ?, ?, 0, ?)
        ON CONFLICT(food_name) DO UPDATE SET
          default_kcal = excluded.default_kcal,
          default_carbs = excluded.default_carbs,
          default_protein = excluded.default_protein,
          default_fat = excluded.default_fat,
          last_used_at = excluded.last_used_at
        ''',
        [
          food['food_name'],
          food['default_kcal'],
          food['default_carbs'],
          food['default_protein'],
          food['default_fat'],
          DateTime.now().toIso8601String(),
        ],
      );
    }
    try {
      await batch.commit(noResult: true);
      debugPrint('💾 [本地缓存] ${cloudFoods.length} 条云端食物已静默落盘');
    } catch (e) {
      debugPrint('⚠️ [本地缓存] 批量写入异常: $e');
    }
  }
}
