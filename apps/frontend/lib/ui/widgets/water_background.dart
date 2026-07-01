import 'package:flutter/material.dart';

/// 💧 通用水波纹背景容器
class WaterBackground extends StatelessWidget {
  final Widget child;
  final bool showBackButton;
  final VoidCallback? onBackPressed;

  const WaterBackground({
    super.key,
    required this.child,
    this.showBackButton = false,
    this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF006BFF);

    return Scaffold(
      backgroundColor: primaryBlue,
      // 避免键盘弹起时背景波浪被严重挤压变形
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // 1. 底层：流体波浪背景
          Positioned.fill(
            child: CustomPaint(painter: _WaterBackgroundPainter()),
          ),

          // 2. 顶层：SafeArea 包裹的内容区
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 顶部导航栏区域（统一放 Logo 或返回键）
                Padding(
                  padding: const EdgeInsets.only(
                    left: 16.0,
                    top: 16.0,
                    right: 16.0,
                  ),
                  child: Row(
                    children: [
                      if (showBackButton)
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white,
                          ),
                          onPressed:
                              onBackPressed ?? () => Navigator.pop(context),
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.only(left: 8.0),
                          child: Text(
                            'wwater', // 这里可以替换成你的真实 Logo
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // 核心内容区：使用 Expanded 和 MediaQuery 解决键盘遮挡问题
                Expanded(
                  child: Padding(
                    // 动态获取键盘高度，确保内容可以被滚动上来
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom,
                    ),
                    child: child,
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
      ..color =
          const Color(0xFF005CE6) // 比底色深一点的蓝色
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
