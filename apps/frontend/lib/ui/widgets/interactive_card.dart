import 'package:flutter/material.dart';

class InteractiveCard extends StatelessWidget {
  final Widget child;
  final Color color;
  final double radius;

  // 🚀 核心修复：补齐 super.key，消除所有语法和 Lint 报错
  const InteractiveCard({
    super.key,
    required this.child,
    this.color = Colors.transparent, // 默认改为透明更安全
    this.radius = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias, // 🔪 强制裁剪水波纹边界
      // 这里的 child 里面必须直接放 ListTile，中间绝不能隔着带颜色的 Container！
      child: child, 
    );
  }
}