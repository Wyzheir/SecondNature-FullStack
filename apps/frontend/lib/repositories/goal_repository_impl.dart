import 'package:dio/dio.dart';
import '../core/network/dio_client.dart';

class GoalRepositoryImpl {
  final DioClient _dioClient;

  GoalRepositoryImpl(this._dioClient);

  Future<Map<String, dynamic>?> getCurrentGoal() async {
    try {
      final response = await _dioClient.dio.get('/goals');
      if (response.data != null) {
        if (response.data is Map<String, dynamic> &&
            response.data.containsKey('data')) {
          return response.data['data'];
        }
        return response.data as Map<String, dynamic>;
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  /// 把后端算好的真实数据提取出来，运回给 Provider
  Future<Map<String, dynamic>> calculateAndSave(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dioClient.dio.post(
        '/goals/calculate_and_save',
        data: data,
      );

      final responseBody = response.data;

      if (responseBody is Map<String, dynamic>) {
        // 如果后端返回了完整的 {code: 200, message: "success", data: {...}} 外壳
        if (responseBody.containsKey('data')) {
          return responseBody['data'] as Map<String, dynamic>;
        }
        // 如果你的拦截器已经自动剥离了外壳，直接返回
        return responseBody;
      }

      throw '后端返回的数据格式不正确';
    } catch (e) {
      rethrow; // 抛给 Provider 统一弹窗报错
    }
  }
}
