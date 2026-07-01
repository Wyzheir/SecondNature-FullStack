import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  static const String tableGoals = 'local_health_goals';
  static const String tableRecords = 'local_health_records';
  static const String tableFoodDict = 'local_food_dictionary';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('health_app_v6.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 7, // 升级版本号至 7
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    debugPrint('🏗️ 正在创建全新的数据库 (v7)...');

    await db.execute('''
      CREATE TABLE $tableGoals (
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
    ''');

    await db.execute('''
      CREATE TABLE $tableRecords (
        local_id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_msg_id TEXT NOT NULL UNIQUE,
        user_id TEXT NOT NULL,
        record_type TEXT NOT NULL,
        record_value REAL NOT NULL,
        unit TEXT NOT NULL,
        record_date TEXT NOT NULL,
        notes TEXT,
        sync_status INTEGER DEFAULT 0,
        duration REAL,
        meal_type TEXT,
        food_name TEXT,
        carbs_g REAL,
        protein_g REAL,
        fat_g REAL,
        exercise_name TEXT
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_records_user ON $tableRecords (user_id)',
    );
    await db.execute(
      'CREATE INDEX idx_records_date ON $tableRecords (record_date)',
    );

    // 创建高频食物词库表
    await _createFoodDictTable(db);
    // 🚀 植入权威种子数据
    await _seedAuthoritativeFoods(db);
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    debugPrint('🔄 数据库升级中: v$oldVersion -> v$newVersion');

    if (oldVersion < 6) {
      debugPrint('🔧 执行 v6 迁移：构建本地食物自进化词库...');

      await _createFoodDictTable(db);
      // 🚀 植入权威种子数据
      await _seedAuthoritativeFoods(db);

      try {
        await db.execute(
          'ALTER TABLE $tableRecords ADD COLUMN meal_type TEXT;',
        );
        await db.execute(
          'ALTER TABLE $tableRecords ADD COLUMN food_name TEXT;',
        );
        await db.execute('ALTER TABLE $tableRecords ADD COLUMN carbs_g REAL;');
        await db.execute(
          'ALTER TABLE $tableRecords ADD COLUMN protein_g REAL;',
        );
        await db.execute('ALTER TABLE $tableRecords ADD COLUMN fat_g REAL;');
      } catch (e) {
        debugPrint('字段可能已存在，跳过追加: $e');
      }
    }

    if (oldVersion < 7) {
      debugPrint('🔧 执行 v7 迁移：增加运动名称字段');
      try {
        await db.execute(
          'ALTER TABLE $tableRecords ADD COLUMN exercise_name TEXT;',
        );
      } catch (e) {
        debugPrint('字段可能已存在，跳过追加: $e');
      }
    }
  }

  Future<void> clearAllData() async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete(tableGoals);
      await txn.delete(tableRecords);
    });
    debugPrint('🧹 本地数据库已清空');
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }

  Future<void> _createFoodDictTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tableFoodDict (
        food_name TEXT PRIMARY KEY,
        default_kcal REAL NOT NULL,
        default_carbs REAL,
        default_protein REAL,
        default_fat REAL,
        usage_count INTEGER DEFAULT 1,
        last_used_at TEXT NOT NULL
      )
    ''');
  }

  /// 💎 批量植入权威种子词库 (数据来源: 中国食物成分表 / USDA)
  Future<void> _seedAuthoritativeFoods(Database db) async {
    final now = DateTime.now().toIso8601String();

    // 权威高频食物矩阵
    final List<Map<String, dynamic>> seedFoods = [
      // --- 🍚 优质主食 ---
      {
        'food_name': '米饭 (白大米饭, 蒸)',
        'kcal': 116.0,
        'carbs': 25.9,
        'protein': 2.6,
        'fat': 0.3,
      },
      {
        'food_name': '燕麦片 (生)',
        'kcal': 377.0,
        'carbs': 66.9,
        'protein': 15.0,
        'fat': 6.7,
      },
      {
        'food_name': '红薯 (生)',
        'kcal': 86.0,
        'carbs': 20.1,
        'protein': 1.6,
        'fat': 0.1,
      },
      {
        'food_name': '土豆 (生)',
        'kcal': 77.0,
        'carbs': 17.5,
        'protein': 2.0,
        'fat': 0.1,
      },
      {
        'food_name': '玉米 (鲜)',
        'kcal': 112.0,
        'carbs': 22.8,
        'protein': 4.0,
        'fat': 1.2,
      },
      {
        'food_name': '全麦面包',
        'kcal': 246.0,
        'carbs': 42.8,
        'protein': 9.8,
        'fat': 3.9,
      },

      // --- 🥩 优质蛋白 (肉蛋奶) ---
      {
        'food_name': '水煮鸡蛋',
        'kcal': 144.0,
        'carbs': 1.5,
        'protein': 13.3,
        'fat': 8.8,
      },
      {
        'food_name': '鸡胸肉 (生)',
        'kcal': 118.0,
        'carbs': 0.0,
        'protein': 24.6,
        'fat': 1.9,
      },
      {
        'food_name': '瘦猪肉 (生)',
        'kcal': 143.0,
        'carbs': 1.5,
        'protein': 20.3,
        'fat': 6.2,
      },
      {
        'food_name': '瘦牛肉 (生)',
        'kcal': 106.0,
        'carbs': 1.2,
        'protein': 20.2,
        'fat': 2.3,
      },
      {
        'food_name': '三文鱼 (生)',
        'kcal': 139.0,
        'carbs': 0.0,
        'protein': 17.2,
        'fat': 7.8,
      },
      {
        'food_name': '纯牛奶 (全脂)',
        'kcal': 54.0,
        'carbs': 4.8,
        'protein': 3.0,
        'fat': 3.2,
      },
      {
        'food_name': '老豆腐',
        'kcal': 81.0,
        'carbs': 4.2,
        'protein': 8.1,
        'fat': 3.7,
      },

      // --- 🥦 蔬果纤维 ---
      {
        'food_name': '西蓝花 (生)',
        'kcal': 34.0,
        'carbs': 6.6,
        'protein': 2.8,
        'fat': 0.4,
      },
      {
        'food_name': '西红柿 (生)',
        'kcal': 15.0,
        'carbs': 3.3,
        'protein': 0.9,
        'fat': 0.2,
      },
      {
        'food_name': '黄瓜 (生)',
        'kcal': 16.0,
        'carbs': 3.6,
        'protein': 0.7,
        'fat': 0.2,
      },
      {
        'food_name': '生菜',
        'kcal': 15.0,
        'carbs': 2.9,
        'protein': 1.4,
        'fat': 0.2,
      },
      {
        'food_name': '苹果',
        'kcal': 52.0,
        'carbs': 13.8,
        'protein': 0.3,
        'fat': 0.2,
      },
      {
        'food_name': '香蕉',
        'kcal': 89.0,
        'carbs': 22.8,
        'protein': 1.1,
        'fat': 0.3,
      },
    ];

    final batch = db.batch();
    for (var food in seedFoods) {
      batch.insert('local_food_dictionary', {
        'food_name': food['food_name'],
        'default_kcal': food['kcal'],
        'default_carbs': food['carbs'],
        'default_protein': food['protein'],
        'default_fat': food['fat'],
        'usage_count': 0,
        'last_used_at': now,
      });
    }
    await batch.commit(noResult: true);
    debugPrint('🧬 权威种子词库注入完成 (${seedFoods.length} 条)');
  }
}
