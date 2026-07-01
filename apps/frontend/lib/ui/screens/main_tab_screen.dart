import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'dashboard_screen.dart';
import 'profile_screen.dart';
import 'log_screen.dart';
import 'chat_screen.dart'; // 🚀 新增：引入 AI 助理大屏页面
import 'chat_screen.dart'; // 💡 必须引入这个文件，才能拿到里面的 chatScaffoldKey

class MainTabScreen extends StatefulWidget {
  const MainTabScreen({super.key});

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  int _currentIndex = 0;

  // 核心架构：更新子页面列表，将 ChatScreen 嵌入日志与我的之间
  final List<Widget> _screens = [
    const DashboardScreen(),
    const LogScreen(),
    const ChatScreen(), // 🚀 新增：AI 助理嵌入为第三个 Tab 页面
    const ProfileScreen(),
  ];

  void _onTabTapped(int index) {
    // 🚀 核心核武：无视任何层级，直接查验 ChatScreen 的状态。如果侧边栏开着，强行关闭！
    if (chatScaffoldKey.currentState?.isDrawerOpen ?? false) {
      chatScaffoldKey.currentState?.closeDrawer();
    }

    if (_currentIndex == index) return;

    setState(() {
      _currentIndex = index;
    });
  }

  Widget _buildSvgIcon(
    String assetPath, {
    bool isSelected = false,
    double scale = 1.0,
  }) {
    const double iconSize = 32.0;

    Widget svgWidget = SvgPicture.asset(
      assetPath,
      key: ValueKey('${assetPath}_$isSelected'),
      width: iconSize,
      height: iconSize,
      fit: BoxFit.contain,
      colorFilter: isSelected
          ? const ColorFilter.mode(Color(0xFF007BFF), BlendMode.srcIn)
          : null,
    );

    // 🚀 如果传入了缩放比例，就在 GPU 渲染层强行放大，抵消 SVG 内部的留白
    if (scale != 1.0) {
      svgWidget = Transform.scale(scale: scale, child: svgWidget);
    }

    return SizedBox(
      width: iconSize,
      height: iconSize,
      child: Center(child: svgWidget),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),

      // 禁用点击时的 splash/highlight 效果
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _onTabTapped,
          backgroundColor: Theme.of(context).colorScheme.surface,
          indicatorColor: Colors.transparent, // 彻底移除选中指示器背景
          destinations: [
            // 1. 概览
            NavigationDestination(
              icon: _buildSvgIcon('assets/icons/home.svg', isSelected: false),
              selectedIcon: _buildSvgIcon(
                'assets/icons/home_filled.svg',
                isSelected: true,
              ),
              label: '概览',
            ),

            // 2. 日志
            NavigationDestination(
              icon: _buildSvgIcon('assets/icons/log.svg', isSelected: false),
              selectedIcon: _buildSvgIcon(
                'assets/icons/log_filled.svg',
                isSelected: true,
              ),
              label: '日志',
            ),

            NavigationDestination(
              // 👉 普通态：用你原来的空心/线框彩色 SVG，不加滤镜保留原样
              icon: _buildSvgIcon('assets/icons/ai.svg', isSelected: false),

              selectedIcon: _buildSvgIcon(
                'assets/icons/ai_filled.svg',
                isSelected: true,
                scale: 1.25, // 🚀 核心补救：强行放大 1.25 倍，抵消视觉误差！
              ),

              label: 'Sena',
            ),

            // 4. 我的
            NavigationDestination(
              icon: _buildSvgIcon('assets/icons/me.svg', isSelected: false),
              selectedIcon: _buildSvgIcon(
                'assets/icons/me_filled.svg',
                isSelected: true,
              ),
              label: '我的',
            ),
          ],
        ),
      ),
    );
  }
}
