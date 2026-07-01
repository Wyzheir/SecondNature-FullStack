import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import 'app_interceptor.dart';
import '../../providers/auth_provider.dart';
import '../config/app_config.dart';

class DioClient {
  late final Dio _dio;

  DioClient(AuthProvider authProvider) {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: const Duration(
          seconds: AppConfig.connectTimeoutSeconds,
        ),
        receiveTimeout: const Duration(
          seconds: AppConfig.receiveTimeoutSeconds,
        ),
      ),
    );

    // 🚀 使用 IOHttpClientAdapter，解决 Android 设备上 DNS 解析失败的问题
    _dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        // 测试阶段信任所有证书（避免 ngrok 等临时证书问题）
        // 正式上线请删除此行或配置正确的证书
        client.badCertificateCallback = (_, __, ___) => true;
        return client;
      },
    );

    _dio.interceptors.add(AppInterceptor(authProvider));
  }

  Dio get dio => _dio;
}
