import 'package:dio/dio.dart';

// 全局唯一的接口定义，供 Provider 和 SyncService 共同使用
abstract class GoalRepository {
  Future<Response> postGoal(Map<String, dynamic> data);
}
