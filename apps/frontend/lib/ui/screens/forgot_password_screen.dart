import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'package:hel_app/main.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;

  // 倒计时状态
  Timer? _timer;
  int _countdown = 0;
  bool get _isCountingDown => _countdown > 0;

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    setState(() => _countdown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown == 0) {
        timer.cancel();
      } else {
        setState(() => _countdown--);
      }
    });
  }

  // 发送验证码
  Future<void> _handleSendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showError('请输入有效的邮箱地址');
      return;
    }

    FocusScope.of(context).unfocus();
    try {
      await context.read<AuthProvider>().sendResetCode(email);
      _startCountdown();
      _showSuccess('验证码已发送至您的邮箱');
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // 提交重置密码
  Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    try {
      await context.read<AuthProvider>().resetPassword(
        _emailController.text.trim(),
        _codeController.text.trim(),
        _passwordController.text.trim(),
      );

      if (!mounted) return;
      _showSuccess('密码重置成功，请重新登录');
      Navigator.pop(context); // 返回登录页
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _showError(String message) {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger != null) {
      messenger.removeCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showSuccess(String message) {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger != null) {
      messenger.removeCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // 统一输入框样式
  InputDecoration _buildInputDecoration({
    required String hintText,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 15),
      prefixIcon: Icon(icon, color: Colors.grey.shade500, size: 22),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF5F7FA),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF006BFF), width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;
    const Color primaryBlue = Color(0xFF006BFF);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black87,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                const Text(
                  '重置密码',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '输入您的注册邮箱，我们将向您发送验证码。',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 48),

                // 邮箱输入框
                TextFormField(
                  controller: _emailController,
                  enabled: !isLoading,
                  decoration: _buildInputDecoration(
                    hintText: '注册邮箱',
                    icon: Icons.email_outlined,
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty ? '请输入邮箱' : null,
                ),
                const SizedBox(height: 20),

                // 验证码与获取按钮组合
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _codeController,
                        enabled: !isLoading,
                        keyboardType: TextInputType.number,
                        decoration: _buildInputDecoration(
                          hintText: '6位验证码',
                          icon: Icons.security_outlined,
                        ),
                        validator: (value) => value == null || value.length != 6
                            ? '请输入6位验证码'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 56, // 与输入框高度对齐
                      child: FilledButton(
                        onPressed: (_isCountingDown || isLoading)
                            ? null
                            : _handleSendCode,
                        style: FilledButton.styleFrom(
                          backgroundColor: primaryBlue.withValues(alpha: 0.1),
                          foregroundColor: primaryBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          _isCountingDown ? '重新获取($_countdown)' : '获取验证码',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 新密码输入框
                TextFormField(
                  controller: _passwordController,
                  enabled: !isLoading,
                  obscureText: _obscurePassword,
                  decoration: _buildInputDecoration(
                    hintText: '设置新密码',
                    icon: Icons.lock_outline,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (value) =>
                      (value == null || value.length < 6) ? '密码不能少于6位' : null,
                ),
                const SizedBox(height: 48),

                // 确认重置按钮
                SizedBox(
                  height: 56,
                  child: FilledButton(
                    onPressed: isLoading ? null : _handleResetPassword,
                    style: FilledButton.styleFrom(
                      backgroundColor: primaryBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            '确 认 重 置',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
