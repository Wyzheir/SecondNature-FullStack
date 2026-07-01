import 'package:flutter/foundation.dart';
import '../models/record.dart';
import '../core/database/record_dao.dart';
import '../repositories/sync_service.dart';

class RecordProvider extends ChangeNotifier {
  final RecordDao _recordDao;
  List<HealthRecord> _records = [];
  bool _isLoading = false;
  DateTime _logViewDate = DateTime.now();

  List<HealthRecord> get records => _records;

  List<HealthRecord> get weightRecords {
    final weights = _records.where((r) => r.recordType == 'WEIGHT').toList();
    weights.sort((a, b) => a.recordDate.compareTo(b.recordDate));
    return weights;
  }

  bool get isLoading => _isLoading;
  DateTime get logViewDate => _logViewDate;

  String get logViewDateTitle {
    final now = DateTime.now();
    if (_logViewDate.year == now.year &&
        _logViewDate.month == now.month &&
        _logViewDate.day == now.day) {
      return '今日';
    }
    return '${_logViewDate.month}月${_logViewDate.day}日';
  }

  RecordProvider(this._recordDao);

  void changeLogViewDate(int days) {
    _logViewDate = _logViewDate.add(Duration(days: days));
    notifyListeners();
  }

  void setLogViewDate(DateTime date) {
    _logViewDate = date;
    notifyListeners();
  }

  String _getDatePrefix(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  double get todaySleepDuration {
    final targetStr = _getDatePrefix(DateTime.now());
    return _records
        .where(
          (r) => r.recordType == 'SLEEP' && r.recordDate.startsWith(targetStr),
        )
        .fold(0.0, (sum, r) => sum + r.recordValue.roundToDouble());
  }

  Map<String, double> getTodayCompleteStatus(
    double targetKcal, [
    DateTime? date,
  ]) {
    double intakeKcal = 0.0, burnKcal = 0.0, totalDuration = 0.0;
    double carbs = 0.0, protein = 0.0, fat = 0.0;

    final targetStr = _getDatePrefix(date ?? DateTime.now());

    for (var r in _records) {
      if (r.recordDate.startsWith(targetStr)) {
        if (r.recordType == 'DIET') {
          intakeKcal += r.recordValue.roundToDouble();
          carbs += (r.carbsG ?? 0.0).roundToDouble();
          protein += (r.proteinG ?? 0.0).roundToDouble();
          fat += (r.fatG ?? 0.0).roundToDouble();
        } else if (r.recordType == 'EXERCISE') {
          burnKcal += r.recordValue.roundToDouble();
          totalDuration += (r.duration ?? 0.0).roundToDouble();
        }
      }
    }

    return {
      'intake': intakeKcal,
      'burn': burnKcal,
      'duration': totalDuration,
      'remaining': (targetKcal + burnKcal) - intakeKcal,
      'carbs': carbs,
      'protein': protein,
      'fat': fat,
    };
  }

  List<HealthRecord> getTodayRecordsByMeal(String mealType, [DateTime? date]) {
    final targetStr = _getDatePrefix(date ?? DateTime.now());
    return _records
        .where(
          (r) =>
              r.recordType == 'DIET' &&
              r.mealType == mealType &&
              r.recordDate.startsWith(targetStr),
        )
        .toList();
  }

  // 🚀 新增：获取今日饮食明细（最多15条，时间倒序，用于AI上下文）
  List<Map<String, dynamic>> getTodayDietItems() {
    final targetStr = _getDatePrefix(DateTime.now());

    // 🐛 调试日志：输出所有饮食记录总数
    final allDiet = _records.where((r) => r.recordType == 'DIET').toList();
    debugPrint('📊 [RecordProvider] 所有饮食记录总数: ${allDiet.length}');

    final dietRecords = _records
        .where(
          (r) => r.recordType == 'DIET' && r.recordDate.startsWith(targetStr),
        )
        .toList();

    // 🐛 调试日志：输出今日匹配到的饮食记录数量及日期前缀
    debugPrint(
      '📊 [RecordProvider] 今日饮食记录数: ${dietRecords.length} (前缀: $targetStr)',
    );
    if (dietRecords.isNotEmpty) {
      debugPrint(
        '🔍 [RecordProvider] 第一条记录日期示例: ${dietRecords.first.recordDate}',
      );
    }

    // 按时间倒序（假设 recordDate 为 ISO 字符串，越晚越大）
    dietRecords.sort((a, b) => b.recordDate.compareTo(a.recordDate));

    // 最多携带15条，避免 token 膨胀
    final limited = dietRecords.take(15);

    final result = limited.map((r) {
      return {
        'food_name': r.foodName ?? '',
        'meal_type': r.mealType ?? '',
        'record_value': r.recordValue,
        'carbs_g': r.carbsG ?? 0.0,
        'protein_g': r.proteinG ?? 0.0,
        'fat_g': r.fatG ?? 0.0,
      };
    }).toList();

    // 🐛 调试日志：输出最终发送的条目数
    debugPrint('🍽️ [RecordProvider] 最终发送饮食明细: ${result.length} 条');
    return result;
  }

  Future<void> loadRecords(String? userId, {bool isSilent = false}) async {
    if (userId == null || userId.isEmpty) {
      _records = [];
      notifyListeners();
      return;
    }
    if (!isSilent) {
      _isLoading = true;
      notifyListeners();
    }
    try {
      final List<Map<String, dynamic>> maps = await _recordDao
          .getRecordsByUserId(userId);
      _records = maps.map((map) => HealthRecord.fromMap(map)).toList();
    } catch (e) {
      _records = [];
    } finally {
      if (!isSilent) _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addRecord(HealthRecord record) async {
    try {
      final int newLocalId = await _recordDao.insertRecord(record.toMap());
      final recordWithId = record.copyWith(localId: newLocalId);
      _records.insert(0, recordWithId);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateRecord(
    HealthRecord updatedRecord, {
    required SyncService syncService,
  }) async {
    try {
      await _recordDao.updateRecord(updatedRecord.toMap());
      final index = _records.indexWhere(
        (r) => r.clientMsgId == updatedRecord.clientMsgId,
      );
      if (index != -1) {
        _records[index] = updatedRecord;
        notifyListeners();
      }

      syncService
          .syncSingleRecord(updatedRecord)
          .then((_) {
            updateRecordSyncStatusInMemory(updatedRecord.clientMsgId, 1);
          })
          .catchError((_) {});
    } catch (e) {}
  }

  void updateRecordSyncStatusInMemory(String clientMsgId, int newStatus) {
    final index = _records.indexWhere((r) => r.clientMsgId == clientMsgId);
    if (index != -1) {
      _records[index] = _records[index].copyWith(syncStatus: newStatus);
      notifyListeners();
    }
  }

  // 🚀 新增：获取今日运动明细（最多10条）
  List<Map<String, dynamic>> getTodayExerciseItems() {
    final targetStr = _getDatePrefix(DateTime.now());
    final exerciseRecords = _records
        .where(
          (r) =>
              r.recordType == 'EXERCISE' && r.recordDate.startsWith(targetStr),
        )
        .toList();

    // 按时间倒序
    exerciseRecords.sort((a, b) => b.recordDate.compareTo(a.recordDate));

    final limited = exerciseRecords.take(10);

    return limited.map((r) {
      // 运动名称优先取专门字段，若无则用 notes 兜底
      final name = (r.exerciseName != null && r.exerciseName!.isNotEmpty)
          ? r.exerciseName!
          : (r.notes ?? '运动');
      return {
        'exercise_name': name,
        'duration': r.duration ?? 0.0, // 分钟
        'burn_kcal': r.recordValue,
      };
    }).toList();
  }

  void clearRecords() {
    _records = [];
    notifyListeners();
  }
}
