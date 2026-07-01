import 'package:uuid/uuid.dart';

class HealthRecord {
  final int? localId;
  final String clientMsgId;
  final String userId;
  final String recordType;
  final double recordValue; // 热量(kcal) 或 体重(kg) 或 睡眠(hours)
  final double? duration; // 运动时长（分钟）
  final String unit;
  final String recordDate;
  final String? notes;
  final int syncStatus;
  final String? exerciseName; // 🚀 新增：运动名称

  // 🚀 【新增】：精细化饮食打卡 5 大字段
  final String? mealType;
  final String? foodName;
  final double? carbsG;
  final double? proteinG;
  final double? fatG;

  HealthRecord({
    this.localId,
    String? clientMsgId,
    required this.userId,
    required this.recordType,
    required this.recordValue,
    this.duration,
    required this.unit,
    required this.recordDate,
    this.notes,
    this.syncStatus = 0,
    // 👉 饮食专属字段
    this.mealType,
    this.foodName,
    this.carbsG,
    this.proteinG,
    this.fatG,
    this.exerciseName,
  }) : clientMsgId = clientMsgId ?? const Uuid().v4();

  factory HealthRecord.fromMap(Map<String, dynamic> map) {
    return HealthRecord(
      localId: map['local_id'] as int?,
      clientMsgId: map['client_msg_id'] as String,
      userId: map['user_id'] as String,
      recordType: map['record_type'] as String,
      recordValue: (map['record_value'] as num).toDouble(),
      duration: map['duration'] != null
          ? (map['duration'] as num).toDouble()
          : null,
      unit: map['unit'] as String,
      recordDate: map['record_date'] as String,
      notes: map['notes'] as String?,
      syncStatus: map['sync_status'] as int? ?? 0,
      exerciseName: map['exercise_name'] as String?,

      // 🚀 精细化饮食字段（严格驼峰映射与 num 安全强转）
      mealType: map['meal_type'] as String?,
      foodName: map['food_name'] as String?,
      carbsG: map['carbs_g'] != null
          ? (map['carbs_g'] as num).toDouble()
          : null,
      proteinG: map['protein_g'] != null
          ? (map['protein_g'] as num).toDouble()
          : null,
      fatG: map['fat_g'] != null ? (map['fat_g'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'local_id': localId,
      'client_msg_id': clientMsgId,
      'user_id': userId,
      'record_type': recordType,
      'record_value': recordValue,
      'duration': duration,
      'unit': unit,
      'record_date': recordDate,
      'notes': notes,
      'sync_status': syncStatus,

      // 🚀 写入 SQLite (严格下划线)
      'meal_type': mealType,
      'food_name': foodName,
      'carbs_g': carbsG,
      'protein_g': proteinG,
      'fat_g': fatG,
      'exercise_name': exerciseName,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'client_msg_id': clientMsgId,
      'user_id': userId,
      'record_type': recordType,
      'record_value': recordValue,
      'duration': duration,
      'unit': unit,
      'record_date': recordDate,
      'notes': notes,

      // 🚀 发送给云端 (严格 JSON 契约)
      'meal_type': mealType,
      'food_name': foodName,
      'carbs_g': carbsG,
      'protein_g': proteinG,
      'fat_g': fatG,
      'exercise_name': exerciseName,
    };
  }

  HealthRecord copyWith({
    int? localId,
    String? clientMsgId,
    String? userId,
    String? recordType,
    double? recordValue,
    double? duration,
    String? unit,
    String? recordDate,
    String? notes,
    int? syncStatus,
    String? mealType,
    String? foodName,
    double? carbsG,
    double? proteinG,
    double? fatG,
    String? exerciseName,
  }) {
    return HealthRecord(
      localId: localId ?? this.localId,
      clientMsgId: clientMsgId ?? this.clientMsgId,
      userId: userId ?? this.userId,
      recordType: recordType ?? this.recordType,
      recordValue: recordValue ?? this.recordValue,
      duration: duration ?? this.duration,
      unit: unit ?? this.unit,
      recordDate: recordDate ?? this.recordDate,
      notes: notes ?? this.notes,
      syncStatus: syncStatus ?? this.syncStatus,
      mealType: mealType ?? this.mealType,
      foodName: foodName ?? this.foodName,
      carbsG: carbsG ?? this.carbsG,
      proteinG: proteinG ?? this.proteinG,
      fatG: fatG ?? this.fatG,
      exerciseName: exerciseName ?? this.exerciseName,
    );
  }
}
