import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/record_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/goal_provider.dart';
import '../../repositories/sync_service.dart';

import 'add_exercise_screen.dart';
import '../widgets/weight_data_card.dart';
import '../widgets/dashboard_cards.dart';
import '../widgets/add_record_form.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.userId;
      if (userId == null) return;

      final recordProvider = context.read<RecordProvider>();
      final syncService = context.read<SyncService>();

      // 🚀 核心战果 1：彻底斩杀 goalProvider.checkGoalStatus！
      // 门卫已经查过了，主页绝对不准再查！死循环被彻底掐断！

      // 🚀 核心战果 2：瞬间加载本地记录，不要 await！
      // 此时 UI 会在 0.01 秒内把 SQLite 里的历史数据渲染上屏
      recordProvider.loadRecords(userId);

      // 🚀 核心战果 3：异步脱手（Fire and Forget）！
      // 让 SyncService 在后台默默去云端拉取漫游数据，绝不阻塞主线程。
      // 拉取成功后，它会触发我们在 main.dart 里写好的 onSyncComplete 回调，
      // 那个回调会自动、静默地再调一次 loadRecords 刷新界面！
      syncService.pullRecordsFromCloud();
    });
  }

  void _showAddRecordBottomSheet(String recordType, {String? initialValue}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: AddRecordForm(
          initialType: recordType,
          initialValue: initialValue,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🎨 定义背景色
    const Color bgColor = Color(0xFFF5F6F9);

    // 🚀 核心修改：使用引导页面的招牌亮蓝色
    const Color brandBlue = Color(0xFF006BFF);
    const Color brandBlueLight = Color(0xFF338AFF); // 稍微浅一点的蓝色用于渐变，增加通透感

    final double safeAreaTop = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // 顶部背景大渐变（已换成引导页蓝色）
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 280,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [brandBlue, brandBlueLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),

          Consumer2<RecordProvider, GoalProvider>(
            builder: (context, recordProvider, goalProvider, child) {
              if (recordProvider.isLoading || goalProvider.isLoading) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }

              final goal = goalProvider.goal;
              final targetKcal = goal?.targetKcal ?? 2000.0;
              final status = recordProvider.getTodayCompleteStatus(targetKcal);

              // 🚀 算力降维：删掉之前极其消耗性能的 DateTime.parse 手动循环！
              // 直接调用我们在 Provider 里写好的高性能、纯字符串匹配的方法！
              final double todaySleep = recordProvider.todaySleepDuration;

              return CustomScrollView(
                physics: const ClampingScrollPhysics(),
                slivers: [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _DashboardHeaderDelegate(safeAreaTop, brandBlue),
                  ),
                  SliverToBoxAdapter(
                    child: goal != null
                        ? NutritionHeroCard(goal: goal, status: status)
                        : const EmptyGoalCard(),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          ActionModuleCard(
                            title: '运动消耗',
                            icon: Icons.local_fire_department,
                            iconColor: Colors.redAccent,
                            value: status['burn']!.round().toString(),
                            unit: '千卡',
                            subIcon: Icons.access_time_filled_rounded,
                            subValue: status['duration']!.round().toString(),
                            subUnit: '分钟',
                            onAdd: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AddExerciseScreen(),
                              ),
                            ),
                          ),
                          ActionModuleCard(
                            title: '睡眠记录',
                            icon: Icons.bedtime,
                            iconColor: Colors.indigo,
                            value: todaySleep.toStringAsFixed(1),
                            unit: '小时',
                            onAdd: () => _showAddRecordBottomSheet('SLEEP'),
                          ),
                          const SizedBox(height: 24),
                          WeightDataCard(
                            records: recordProvider.records,
                            onAdd: () {
                              double currentWeight = goal?.weight ?? 0.0;
                              if (recordProvider.weightRecords.isNotEmpty) {
                                currentWeight = recordProvider
                                    .weightRecords
                                    .last
                                    .recordValue;
                              }
                              _showAddRecordBottomSheet(
                                'WEIGHT',
                                initialValue: currentWeight.toString(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// 🚀 吸顶头部代理：颜色已同步为引导页蓝色
class _DashboardHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double safeAreaTop;
  final Color brandBlue; // 传入招牌蓝

  _DashboardHeaderDelegate(this.safeAreaTop, this.brandBlue);

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final double progress = (shrinkOffset / maxExtent).clamp(0.0, 1.0);

    final Color appBarColor = Color.lerp(
      Colors.transparent,
      Colors.white,
      progress,
    )!;

    final Color textColor = Color.lerp(
      Colors.white,
      brandBlue, // 👈 吸顶后的文字颜色现在与背景色完美统一
      progress,
    )!;

    final double elevation = progress == 1.0 ? 2.0 : 0.0;

    return Material(
      color: appBarColor,
      elevation: elevation,
      shadowColor: Colors.black12,
      child: Container(
        height: maxExtent,
        padding: EdgeInsets.only(top: safeAreaTop, left: 24, right: 24),
        alignment: Alignment.centerLeft,
        child: Text(
          'SecondNature',
          style: TextStyle(
            color: textColor,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  @override
  double get maxExtent => 60.0 + safeAreaTop;

  @override
  double get minExtent => 60.0 + safeAreaTop;

  @override
  bool shouldRebuild(covariant _DashboardHeaderDelegate oldDelegate) {
    return oldDelegate.safeAreaTop != safeAreaTop ||
        oldDelegate.brandBlue != brandBlue;
  }
}
