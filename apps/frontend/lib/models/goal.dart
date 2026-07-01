class Goal {
  final int? localId;
  final String clientMsgId;
  final String userId;

  // 目标数据
  final String? goalType;
  final double? targetWeight;

  // 生理指标快照
  final String gender;
  final int age;
  final double height;
  final double weight;
  final String activityLevel;

  // 👉 【核心新增】：四大营养素基准指标 (Dashboard 渲染核心)
  final double targetKcal;
  final double carbsG;
  final double proteinG;
  final double fatG;

  final int syncStatus; // 0: 未同步, 1: 已同步

  Goal({
    this.localId,
    required this.clientMsgId,
    required this.userId,
    this.goalType,
    this.targetWeight,
    required this.gender,
    required this.age,
    required this.height,
    required this.weight,
    required this.activityLevel,
    this.syncStatus = 0,
    // 👉 默认值兜底，确保老代码逻辑不崩
    this.targetKcal = 2000.0,
    this.carbsG = 200.0,
    this.proteinG = 100.0,
    this.fatG = 50.0,
  });

  // 用于写入 SQLite 本地缓存
  Map<String, dynamic> toMap() {
    return {
      if (localId != null) 'local_id': localId,
      'client_msg_id': clientMsgId,
      'user_id': userId,
      'goal_type': goalType,
      'target_weight': targetWeight,
      'gender': gender,
      'age': age,
      'height': height,
      'weight': weight,
      'activity_level': activityLevel,
      'sync_status': syncStatus,
      // 👉 【新增】持久化营养数据
      'target_kcal': targetKcal,
      'carbs_g': carbsG,
      'protein_g': proteinG,
      'fat_g': fatG,
    };
  }

  // 从 SQLite 读取
  factory Goal.fromMap(Map<String, dynamic> map) {
    return Goal(
      localId: map['local_id'] as int?,
      clientMsgId: map['client_msg_id'] as String,
      userId: map['user_id'] as String,
      goalType: map['goal_type'] as String?,
      targetWeight: (map['target_weight'] as num?)?.toDouble(),
      gender: map['gender'] as String,
      age: map['age'] as int,
      height: (map['height'] as num).toDouble(),
      weight: (map['weight'] as num).toDouble(),
      activityLevel: map['activity_level'] as String,
      syncStatus: map['sync_status'] as int,
      // 👉 【新增】安全读取，使用 num 兼容 int 和 double
      targetKcal: ((map['target_kcal'] ?? 2000) as num).toDouble(),
      carbsG: ((map['carbs_g'] ?? 200) as num).toDouble(),
      proteinG: ((map['protein_g'] ?? 100) as num).toDouble(),
      fatG: ((map['fat_g'] ?? 50) as num).toDouble(),
    );
  }

  // 用于发送给后端
  Map<String, dynamic> toJson() {
    return {
      'client_msg_id': clientMsgId,
      'user_id': userId,
      'goal_type': goalType,
      'target_weight': targetWeight,
      'gender': gender,
      'age': age,
      'height': height,
      'weight': weight,
      'activity_level': activityLevel,
      // 如果后端也需要这些计算结果，可以一并传过去
      'target_kcal': targetKcal,
      'carbs_g': carbsG,
      'protein_g': proteinG,
      'fat_g': fatG,
    };
  }

  // 辅助方法：Immutable 模式
  Goal copyWith({
    int? syncStatus,
    int? localId,
    double? targetKcal,
    double? carbsG,
    double? proteinG,
    double? fatG,
  }) {
    return Goal(
      localId: localId ?? this.localId,
      clientMsgId: clientMsgId,
      userId: userId,
      goalType: goalType,
      targetWeight: targetWeight,
      gender: gender,
      age: age,
      height: height,
      weight: weight,
      activityLevel: activityLevel,
      syncStatus: syncStatus ?? this.syncStatus,
      targetKcal: targetKcal ?? this.targetKcal,
      carbsG: carbsG ?? this.carbsG,
      proteinG: proteinG ?? this.proteinG,
      fatG: fatG ?? this.fatG,
    );
  }
}

// 供 Provider 或 UI 层调用的入参契约
class GoalParams {
  final String userId;
  final String goalType;
  final double targetWeight;
  final String gender;
  final int age;
  final double height;
  final double weight;
  final String activityLevel;

  GoalParams({
    required this.userId,
    required this.goalType,
    required this.targetWeight,
    required this.gender,
    required this.age,
    required this.height,
    required this.weight,
    required this.activityLevel,
  });
}
