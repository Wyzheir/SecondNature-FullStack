import 'dart:convert'; // 🔧 必须：引入 jsonEncode 序列化工具
import 'dart:io'; 
import 'package:dio/io.dart'; 
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../core/database/database_helper.dart';
import '../core/storage/local_storage.dart';
import '../core/config/app_config.dart';

class AuthProvider extends ChangeNotifier {
  String? _token;
  String? _userId;
  String? _username;
  bool _isLoading = false;

  bool get isAuthenticated => _token != null && _token!.isNotEmpty;
  String? get token => _token;
  String? get userId => _userId;
  String? get username => _username;
  bool get isLoading => _isLoading;

  AuthProvider() {
    _loadStoredAuth();
  }

  // 🚀 统一的 Dio 构建器
  Dio _createAuthDio() {
    final dio = Dio(
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

    // 挂载 IOHttpClientAdapter，解决 Android DNS 和 HTTPS 证书拦截问题
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.badCertificateCallback = (_, __, ___) => true;
        return client;
      },
    );

    return dio;
  }

  Future<void> _loadStoredAuth() async {
    _isLoading = true;
    notifyListeners();

    _token = await LocalStorage.getStoredToken();
    _userId = await LocalStorage.getStoredUserId();
    _username = await LocalStorage.getStoredUsername();

    if (_token != null) {
      debugPrint('🔑 发现持久化凭证，已自动登录: ${_token?.substring(0, 10)}...');
    }

    _isLoading = false;
    notifyListeners();
  }

  // 🚀 1. 登录逻辑修复
  Future<void> login(String username, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final authDio = _createAuthDio();

      final response = await authDio.post(
        '/auth/login',
        // 🔧 关键修改 1：强行转成干净的 JSON 字符串文本
        data: jsonEncode({
          'username': username.trim(), 
          'password': password.trim()
        }),
        // 🔧 关键修改 2：显式锁定 Content-Type 头
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        _token = data['access_token'];
        _userId = data['user_id'] ?? username;
        _username = username;

        await LocalStorage.saveAuthData(_token!, _userId!, _username!);
        debugPrint('✅ 登录并持久化成功');
      } else {
        throw Exception(response.data['message'] ?? '登录失败');
      }
    } on DioException catch (e) {
      debugPrint('❌ 登录 DioException: ${e.response?.statusCode} - ${e.response?.data}');
      if (e.response != null) {
        final data = e.response?.data;
        String errorMsg = '服务器拒绝了请求';
        if (data is Map) {
          errorMsg = data['message'] ?? data['detail'] ?? errorMsg;
        }
        throw Exception(errorMsg);
      }
      throw Exception('网络连接失败');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 🚀 2. 注册逻辑修复
  Future<void> register(String username, String password, String email) async {
    _isLoading = true;
    notifyListeners();

    try {
      final authDio = _createAuthDio();

      final response = await authDio.post(
        '/auth/register',
        // 🔧 关键修改：强行转 JSON
        data: jsonEncode({
          'username': username.trim(), 
          'password': password.trim(), 
          'email': email.trim()
        }),
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          response.data['code'] == 200) {
        final data = response.data['data'];
        _token = data['access_token'];
        _userId = data['user_id'] ?? username;
        _username = username;

        await LocalStorage.saveAuthData(_token!, _userId!, _username!);
        debugPrint('✅ 注册并持久化成功');
      } else {
        throw Exception(response.data['message'] ?? '注册失败');
      }
    } on DioException catch (e) {
      debugPrint('❌ 注册 DioException: ${e.response?.statusCode}');
      if (e.response != null) {
        final data = e.response?.data;
        String errorMsg = '注册失败';
        if (data is Map) {
          errorMsg = data['message'] ?? data['detail'] ?? errorMsg;
        }
        throw Exception(errorMsg);
      }
      throw Exception('网络连接失败');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      debugPrint('🔒 启动安全核销程序...');
      await DatabaseHelper.instance.clearAllData();
      await LocalStorage.clearAuthData();

      _token = null;
      _userId = null;
      _username = null;
      debugPrint('✅ 全链路数据核销完毕，已安全退出');
    } catch (e) {
      debugPrint('❌ 登出异常: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 🚀 3. 发送验证码修复
  Future<void> sendResetCode(String email) async {
    _isLoading = true;
    notifyListeners();

    try {
      final authDio = _createAuthDio();

      final response = await authDio.post(
        '/auth/send-reset-code',
        // 🔧 关键修改：强行转 JSON
        data: jsonEncode({'email': email.trim()}),
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (response.statusCode != 200 || response.data['code'] != 200) {
        throw Exception(response.data['message'] ?? '验证码发送失败');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        final data = e.response?.data;
        throw Exception(data is Map ? (data['message'] ?? '发送失败') : '请求被拒绝');
      }
      throw Exception('网络连接失败');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 🚀 4. 重置密码修复
  Future<void> resetPassword(String email, String code, String newPassword) async {
    _isLoading = true;
    notifyListeners();

    try {
      final authDio = _createAuthDio();

      final response = await authDio.post(
        '/auth/reset-password',
        // 🔧 关键修改：强行转 JSON
        data: jsonEncode({
          'email': email.trim(), 
          'code': code.trim(), 
          'new_password': newPassword.trim()
        }),
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (response.statusCode != 200 || response.data['code'] != 200) {
        throw Exception(response.data['message'] ?? '密码重置失败');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        final data = e.response?.data;
        throw Exception(data is Map ? (data['message'] ?? '重置失败') : '请求被拒绝');
      }
      throw Exception('网络连接失败');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}