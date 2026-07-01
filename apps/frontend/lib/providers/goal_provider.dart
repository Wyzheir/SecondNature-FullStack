import 'package:flutter/foundation.dart';
import 'package:hel_app/models/goal.dart';
import '../repositories/goal_repository_impl.dart';
import '../core/database/goal_dao.dart';

class GoalProvider extends ChangeNotifier {
  final GoalRepositoryImpl _apiRepository;
  final GoalDao _goalDao;

  bool _isSaving = false;
  bool _hasGoal = false;
  bool _isChecking = true;

  Goal? _goal;
  bool _isLoading = false;

  bool get isSaving => _isSaving;
  bool get hasGoal => _hasGoal;
  bool get isChecking => _isChecking;

  Goal? get goal => _goal;
  bool get isLoading => _isLoading || _isChecking;

  GoalProvider({
    required GoalRepositoryImpl apiRepository,
    required GoalDao goalDao,
  }) : _apiRepository = apiRepository,
       _goalDao = goalDao;

  Future<void> checkGoalStatus(String? userId) async {
    if (userId == null || userId.isEmpty) {
      _hasGoal = false;
      _goal = null;
      _isChecking = false;
      notifyListeners();
      return;
    }

    // 🚀 核心修复：只有当内存里【确实有目标】且【数据恰好属于当前登录的userId】时，才允许跳过检查！
    if (_hasGoal && _goal != null && _goal!.userId == userId) {
      _isChecking = false;
      return;
    }

    // 🚀 核心清毒：如果换了新账号，或者彻底没数据，立刻把前任的幽灵数据全部擦洗干净！
    _goal = null;
    _hasGoal = false;
    _isChecking = true;
    _isLoading = true;
    notifyListeners();

    try {
      final goals = await _goalDao.getGoalsByUserId(userId);

      if (goals.isNotEmpty) {
        debugPrint('✅ [状态机] 本地数据命中，允许放行进入 Dashboard！');
        _goal = goals.first;
        _hasGoal = true;
      } else {
        debugPrint('☁️ [端云同步] 本地无数据，尝试从后端拉取画像...');
        final cloudGoalData = await _apiRepository.getCurrentGoal();

        if (cloudGoalData != null) {
          debugPrint('📥 [端云同步] 发现云端历史数据！正在静默回填至本地...');

          final localGoal = Goal.fromMap({
            'client_msg_id': DateTime.now().millisecondsSinceEpoch.toString(),
            'user_id': userId,
            'goal_type': cloudGoalData['goal_type'],
            'target_weight': cloudGoalData['target_weight'],
            'gender': cloudGoalData['gender'].toString(),
            'age': cloudGoalData['age'],
            'height': cloudGoalData['height'],
            'weight': cloudGoalData['weight'],
            'activity_level': cloudGoalData['activity_level'].toString(),
            'sync_status': 1,
            'target_kcal': cloudGoalData['target_kcal'] ?? 2000,
            'carbs_g': cloudGoalData['carbs_g'] ?? 200,
            'protein_g': cloudGoalData['protein_g'] ?? 100,
            'fat_g': cloudGoalData['fat_g'] ?? 50,
          });

          await _goalDao.insertGoal(localGoal);
          debugPrint('✅ [端云同步] 数据回填成功！放行！');
          _goal = localGoal;
          _hasGoal = true;
        } else {
          debugPrint('🤷 [端云同步] 云端亦无数据，确认为新用户，拦截至录入页。');
          _hasGoal = false;
          _goal = null;
        }
      }
    } catch (e) {
      debugPrint('❌ [状态机] 检查或同步画像时彻底崩溃: $e');
      _hasGoal = false;
      _goal = null;
    } finally {
      _isChecking = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearGoalStatus() {
    _hasGoal = false;
    _goal = null;
    _isChecking = false; // 🚀 确保同步清洗重置检查大门
    notifyListeners();
  }

  void markGoalAsCreated() {
    _hasGoal = true;
    notifyListeners();
  }

  Future<void> calculateAndSaveGoal({
    required String userId,
    required int gender,
    required double height,
    required double weight,
    required int age,
    required double activityLevel,
    required double targetWeight,
    required String goalType,
  }) async {
    _isSaving = true;
    notifyListeners();

    try {
      final payload = {
        "gender": gender,
        "height": height,
        "weight": weight,
        "age": age,
        "activity_level": activityLevel,
        "target_weight": targetWeight,
        "goal_type": goalType,
      };

      final responseData = await _apiRepository.calculateAndSave(payload);
      debugPrint('🌐 [网络层] 成功拿到仓储层解析的数据: $responseData');

      try {
        final localGoal = Goal.fromMap({
          'client_msg_id': DateTime.now().millisecondsSinceEpoch.toString(),
          'user_id': userId,
          'goal_type': goalType,
          'target_weight': targetWeight,
          'gender': gender.toString(),
          'age': age,
          'height': height,
          'weight': weight,
          'activity_level': activityLevel.toString(),
          'sync_status': 1,
          'target_kcal': (responseData['target_kcal'] as num).toDouble(),
          'carbs_g': (responseData['carbs_g'] as num).toDouble(),
          'protein_g': (responseData['protein_g'] as num).toDouble(),
          'fat_g': (responseData['fat_g'] as num).toDouble(),
        });

        await _goalDao.insertGoal(localGoal);
        debugPrint('✅ [SQLite] 真实目标数据落盘成功！');

        _goal = localGoal;
      } catch (dbError) {
        debugPrint('🚨 [关键错误] 数据写入本地彻底失败！原因: $dbError');
        throw '本地缓存写入失败';
      }

      markGoalAsCreated();
    } catch (e) {
      debugPrint('🚨 画像录入崩溃: $e');
      throw '提交失败：您可能已经设置过计划，或网络异常';
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
