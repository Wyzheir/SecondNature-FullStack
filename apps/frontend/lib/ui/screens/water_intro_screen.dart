import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class WaterIntroScreen extends StatelessWidget {
  const WaterIntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF006BFF);

    return Scaffold(
      backgroundColor: primaryBlue,
      body: Stack(
        children: [
          // 1. 底层：自定义流体波浪背景
          Positioned.fill(
            child: CustomPaint(painter: _WaterBackgroundPainter()),
          ),

          // 2. 顶层：SafeArea 保证不被刘海屏遮挡
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🚀 修改点 1：左上角项目名 Logo
                const Padding(
                  padding: EdgeInsets.only(left: 24.0, top: 16.0),
                  child: Text(
                    'SecondNature',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),

                const Spacer(),

                // 底部内容区
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🚀 修改点 2：契合健康 App 的大标题
                      const Text(
                        '重塑健康本能',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 🚀 修改点 3：核心功能描述副标题
                      Text(
                        '科学量化饮食与运动，记录你的每一次蜕变。\n现在就开始专属于你的健康之旅。',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 16,
                          height: 1.6, // 稍微拉开一点行高，中文阅读更舒适
                        ),
                      ),
                      const SizedBox(height: 40),

                      // 🚀 修改点 4：登录按钮中文
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: primaryBlue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            '登 录',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2.0, // 中文加一点字间距更好看
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 🚀 修改点 5：注册按钮中文
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(
                              color: Colors.white,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RegisterScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            '注 册',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 🎨 核心魔法：使用 Canvas 纯代码绘制流体波浪背景
class _WaterBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintDarkBlue = Paint()
      ..color = const Color(0xFF005CE6)
      ..style = PaintingStyle.fill;

    // 1. 绘制右上角的大块流体
    final path1 = Path();
    path1.moveTo(size.width * 0.3, 0);
    path1.quadraticBezierTo(
      size.width * 0.5,
      size.height * 0.2,
      size.width,
      size.height * 0.25,
    );
    path1.lineTo(size.width, 0);
    path1.close();
    canvas.drawPath(path1, paintDarkBlue);

    // 2. 绘制中部的波浪流体
    final path2 = Path();
    path2.moveTo(0, size.height * 0.25);
    path2.cubicTo(
      size.width * 0.4,
      size.height * 0.25,
      size.width * 0.4,
      size.height * 0.5,
      size.width,
      size.height * 0.45,
    );
    path2.lineTo(size.width, size.height * 0.65);
    path2.cubicTo(
      size.width * 0.6,
      size.height * 0.7,
      size.width * 0.2,
      size.height * 0.55,
      0,
      size.height * 0.6,
    );
    path2.close();
    canvas.drawPath(path2, paintDarkBlue);

    // 3. 绘制散落的“气泡”圆圈
    canvas.drawCircle(
      Offset(size.width * 0.8, size.height * 0.08),
      35,
      paintDarkBlue,
    );
    canvas.drawCircle(
      Offset(size.width * 0.95, size.height * 0.22),
      15,
      paintDarkBlue,
    );
    canvas.drawCircle(
      Offset(size.width * 0.55, size.height * 0.32),
      25,
      paintDarkBlue,
    );
    canvas.drawCircle(
      Offset(size.width * 0.1, size.height * 0.45),
      18,
      paintDarkBlue,
    );
    canvas.drawCircle(
      Offset(size.width * 0.75, size.height * 0.55),
      22,
      paintDarkBlue,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
