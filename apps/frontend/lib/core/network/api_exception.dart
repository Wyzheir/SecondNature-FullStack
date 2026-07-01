class ApiException implements Exception {
  final int code;
  final String message;

  ApiException(this.code, this.message);

  @override
  String toString() => message; // 直接重写 toString，方便 UI 层拦截后直接展示 Toast
}
