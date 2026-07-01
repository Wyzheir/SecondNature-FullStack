import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'api_exception.dart';
import '../../providers/auth_provider.dart';

class AppInterceptor extends Interceptor {
  final AuthProvider _authProvider; // 接收外部注入的 AuthProvider

  AppInterceptor(this._authProvider);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // 1. 动态读取 Provider 中真实的 JWT Token
    final String? token = _authProvider.token;
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    options.headers['Content-Type'] = 'application/json';
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // 【核心修复】：智能兼容后端的多种返回格式

    // 1. 只要 HTTP 状态码是 200 或 201，在网络层面上就是成功的
    if (response.statusCode == 200 || response.statusCode == 201) {
      // 2. 检查返回体是否是 Map (JSON 对象)
      if (response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;

        // 3. 场景 A：后端使用了标准结构 {code: 200, data: {...}}
        if (data.containsKey('code')) {
          if (data['code'] == 200) {
            return handler.next(response); // 校验通过，放行！
          } else {
            // 业务级报错 (例如 code: 40001)
            return handler.reject(
              DioException(
                requestOptions: response.requestOptions,
                response: response,
                error: data['message'] ?? '请求失败，错误码：${data['code']}',
              ),
            );
          }
        }
      }

      // 4. 场景 B：后端直接返回了裸数据（比如 {"tdee": 2400} 或 直接返回了数组）
      // 既然 HTTP 已经是 200 了，就别难为它了，直接放行！
      return handler.next(response);
    } else {
      // 5. 其他非 200/201 的 HTTP 状态码
      return handler.next(response);
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // 3. HTTP 协议层面的 401 拦截：触发全局登出
    if (err.response?.statusCode == 401) {
      _handleTokenExpired();
    }

    // 4. 从后端的 Error Payload 中提取高价值业务阻断信息
    String errorMessage = err.message ?? '网络请求异常';
    int errorCode = err.response?.statusCode ?? -1;

    if (err.response?.data != null && err.response?.data is Map) {
      final Map<String, dynamic> responseData =
          err.response!.data as Map<String, dynamic>;

      if (responseData.containsKey('message') &&
          responseData['message'] != null) {
        errorMessage = responseData['message'].toString();
      } else {
        errorMessage = err.response?.statusMessage ?? errorMessage;
      }

      if (responseData.containsKey('code') && responseData['code'] != null) {
        errorCode = responseData['code'] as int;
      }
    } else {
      errorMessage = err.response?.statusMessage ?? errorMessage;
    }

    // 5. 将底层的 Dio 错误统一包装为干净的业务异常
    final customError = ApiException(errorCode, errorMessage);
    final cleanError = err.copyWith(error: customError);
    super.onError(cleanError, handler);
  }

  /// 触发全局登出与状态重置
  void _handleTokenExpired() {
    debugPrint("【安全拦截】Token 已过期或失效 (401)。已自动触发 AuthProvider.logout() 熔断！");
    // 移到微任务中执行，释放 Dio 回调线程
    Future.microtask(() => _authProvider.logout());
  }
}
