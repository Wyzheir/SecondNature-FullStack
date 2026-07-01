import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/goal_provider.dart';

import 'main_tab_screen.dart';
import 'health_goal_screen.dart';
import 'water_intro_screen.dart';
import '../../providers/assistant_provider.dart'; // 🚀 就是漏了这一行，加上它，封印解除！

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  // 记录上一次被检查过画像的账号
  String? _lastCheckedUserId;

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final goalProvider = context.watch<GoalProvider>();

    // 1. 如果 Auth 还在加载本地 Token，显示菊花
    if (authProvider.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // 2. 如果未登录，直接去登录页，并重置记录
    if (!authProvider.isAuthenticated) {
      _lastCheckedUserId = null;
      // 🚀 核心防线：退登的瞬间，利用后帧回调连带把全局的 Goal 缓存也清除干净，形成两道绝对防火墙！
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<GoalProvider>().clearGoalStatus();
        context
            .read<AssistantProvider>()
            .clearAllData(); // 👈 加上这行，彻底斩断上一个账号的残留！
      });
      return const WaterIntroScreen();
    }

    // ==========================================
    // 3. 【智能拦截核心】：发现账号变更，立即触发新账号的专属查询
    // ==========================================
    if (_lastCheckedUserId != authProvider.userId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        goalProvider.checkGoalStatus(authProvider.userId);
        setState(() {
          _lastCheckedUserId = authProvider.userId;
        });
      });
      // 正在准备查询，暂时显示加载页
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // 4. 等待查询数据库的结果
    if (goalProvider.isChecking) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在检测您的云端健康画像状态...', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    // 5. 精准分发：如果没有属于该新账号的画像，强制去录入；否则进主页
    if (!goalProvider.hasGoal) {
      return const HealthGoalScreen();
    } else {
      return const MainTabScreen();
    }
  }
}
