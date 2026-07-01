class AppConfig {
  //  默认走本地环境，通过来自环境的命令动态读取
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000/api/v1', // 本地测试兜底
  );
  static const int connectTimeoutSeconds = 15;
  static const int receiveTimeoutSeconds = 15;
}