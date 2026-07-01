import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../../providers/record_provider.dart';
import '../../providers/goal_provider.dart';
import 'food_search_screen.dart';
import 'food_detail_screen.dart';

class LogScreen extends StatelessWidget {
  const LogScreen({super.key});

  // 抽取出来的底部日期选择器调起方法
  void _showDatePicker(BuildContext context, RecordProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _CupertinoDatePickerForm(
        initialDate: provider.logViewDate,
        // 🚀 直接调用 provider 的状态修改方法
        onDateSelected: (date) => provider.setLogViewDate(date),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color brandBlue = Color(0xFF007BFF);
    // 🚀 在最顶层监听全局数据
    final recordProvider = context.watch<RecordProvider>();
    final goalProvider = context.watch<GoalProvider>();

    final goal = goalProvider.goal;
    final targetKcal = goal?.targetKcal ?? 2000.0;

    // 🚀 算力中枢直接读取 Provider 内部的 logViewDate
    final status = recordProvider.getTodayCompleteStatus(
      targetKcal,
      recordProvider.logViewDate,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new,
                size: 20,
                color: Colors.black87,
              ),
              onPressed: () => recordProvider.changeLogViewDate(-1), // 👈 发送动作
            ),
            InkWell(
              onTap: () => _showDatePicker(context, recordProvider),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      recordProvider.logViewDateTitle, // 👈 直接读取计算好的标题
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down, color: Colors.black87),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.arrow_forward_ios,
                size: 20,
                color: Colors.black87,
              ),
              onPressed: () => recordProvider.changeLogViewDate(1), // 👈 发送动作
            ),
          ],
        ),
      ),
      body: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          // --- 顶部：营养目标进度 ---
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${recordProvider.logViewDateTitle}摄入进度',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMacroRing(
                        '热量(kcal)',
                        status['intake']!,
                        targetKcal,
                        brandBlue,
                        radius: 36,
                      ),
                      _buildMacroRing(
                        '碳水(g)',
                        status['carbs']!,
                        goal?.carbsG ?? 200.0,
                        Colors.green,
                      ),
                      _buildMacroRing(
                        '蛋白质(g)',
                        status['protein']!,
                        goal?.proteinG ?? 100.0,
                        Colors.blue,
                      ),
                      _buildMacroRing(
                        '脂肪(g)',
                        status['fat']!,
                        goal?.fatG ?? 50.0,
                        Colors.orange,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // --- 底部：四餐瀑布流 ---
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildMealCard(context, '早餐', 'BREAKFAST', recordProvider),
                _buildMealCard(context, '午餐', 'LUNCH', recordProvider),
                _buildMealCard(context, '晚餐', 'DINNER', recordProvider),
                _buildMealCard(context, '加餐/零食', 'SNACK', recordProvider),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 内部组件保持逻辑一致 ====================

  Widget _buildMacroRing(
    String title,
    double current,
    double target,
    Color color, {
    double radius = 30,
  }) {
    double progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    return Column(
      children: [
        SizedBox(
          width: radius * 2,
          height: radius * 2,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: 1.0,
                strokeWidth: radius == 36 ? 8 : 6,
                valueColor: AlwaysStoppedAnimation(Colors.grey.shade100),
              ),
              CircularProgressIndicator(
                value: progress,
                strokeWidth: radius == 36 ? 8 : 6,
                strokeCap: StrokeCap.round,
                valueColor: AlwaysStoppedAnimation(color),
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      current.toInt().toString(),
                      style: TextStyle(
                        fontSize: radius == 36 ? 16 : 14,
                        fontWeight: FontWeight.bold,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '/${target.toInt()}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildMealCard(
    BuildContext context,
    String title,
    String mealType,
    RecordProvider provider,
  ) {
    // 🚀 取数据时，依赖 provider 的 logViewDate
    final records = provider.getTodayRecordsByMeal(
      mealType,
      provider.logViewDate,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, color: Color(0xFF007BFF), size: 28),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          FoodSearchScreen(
                            mealType: mealType,
                            targetDate: provider.logViewDate,
                          ),
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
                            return SlideTransition(
                              position: animation.drive(
                                Tween(
                                  begin: const Offset(1.0, 0.0),
                                  end: Offset.zero,
                                ).chain(
                                  CurveTween(curve: Curves.easeInOutQuart),
                                ),
                              ),
                              child: child,
                            );
                          },
                      transitionDuration: const Duration(milliseconds: 350),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (records.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                '请添加食物',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 15),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: records.length,
              separatorBuilder: (context, index) => const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1),
              ),
              itemBuilder: (context, index) {
                final r = records[index];

                // 🚀 核心修改 1：从 notes 中提取重量（假设格式为 "食物名 100g"）
                // 如果 notes 为空或格式不符，则兜底显示 "100g"
                final String portionText = r.notes?.split(' ').last ?? '100g';

                return InkWell(
                  // 🚀 核心修改 2：点击进入详情页，实现数据查看与修改
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FoodDetailScreen(record: r),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 4,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.foodName ?? '未知食物',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              // 🚀 核心修改 3：只显示重量/份数，保持界面清爽
                              Text(
                                portionText,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F6F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${r.recordValue.round()} kcal',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// ===========================================================================
/// 🚀 从 add_exercise_screen 移植过来的底层 Cupertino 日期选择器
/// ===========================================================================
class _CupertinoDatePickerForm extends StatefulWidget {
  final DateTime initialDate;
  final ValueChanged<DateTime> onDateSelected;

  const _CupertinoDatePickerForm({
    required this.initialDate,
    required this.onDateSelected,
  });

  @override
  State<_CupertinoDatePickerForm> createState() =>
      _CupertinoDatePickerFormState();
}

class _CupertinoDatePickerFormState extends State<_CupertinoDatePickerForm> {
  int _selectedYearIndex = 0;
  int _selectedMonthIndex = 0;
  int _selectedDayIndex = 0;
  late FixedExtentScrollController _yearCtrl, _monthCtrl, _dayCtrl;
  late List<int> _years;
  late DateTime _currentTempDate;
  final int _startYear = 1970;

  @override
  void initState() {
    super.initState();
    _currentTempDate = widget.initialDate;
    final currentYear = DateTime.now().year;
    _years = List.generate(
      (currentYear + 10) - _startYear + 1,
      (idx) => _startYear + idx,
    );
    _selectedYearIndex = _currentTempDate.year - _startYear;
    _selectedMonthIndex = _currentTempDate.month - 1;
    _selectedDayIndex = _currentTempDate.day - 1;

    _yearCtrl = FixedExtentScrollController(initialItem: _selectedYearIndex);
    _monthCtrl = FixedExtentScrollController(initialItem: _selectedMonthIndex);
    _dayCtrl = FixedExtentScrollController(initialItem: _selectedDayIndex);
  }

  @override
  void dispose() {
    _yearCtrl.dispose();
    _monthCtrl.dispose();
    _dayCtrl.dispose();
    super.dispose();
  }

  List<int> get _days => List.generate(
    DateTime(_currentTempDate.year, _currentTempDate.month + 1, 0).day,
    (idx) => idx + 1,
  );

  void _setToday() {
    final now = DateTime.now();
    _yearCtrl.animateToItem(
      now.year - _startYear,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    _monthCtrl.animateToItem(
      now.month - 1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    _dayCtrl.animateToItem(
      now.day - 1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() {
      _currentTempDate = now;
      _selectedYearIndex = now.year - _startYear;
      _selectedMonthIndex = now.month - 1;
      _selectedDayIndex = now.day - 1;
    });
  }

  void _onYearMonthChanged() {
    setState(() {
      final daysInMonth = _days.length;
      if (_currentTempDate.day > daysInMonth) {
        _dayCtrl.jumpToItem(daysInMonth - 1);
        _currentTempDate = DateTime(
          _currentTempDate.year,
          _currentTempDate.month,
          daysInMonth,
        );
        _selectedDayIndex = daysInMonth - 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color brandBlue = Color(0xFF007BFF);
    return Material(
      type: MaterialType.transparency,
      child: Container(
        height: 380,
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    size: 28,
                    color: Colors.black54,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                const Text(
                  '更改日期',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.check, size: 28, color: brandBlue),
                  onPressed: () {
                    widget.onDateSelected(_currentTempDate);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _setToday,
              style: TextButton.styleFrom(
                foregroundColor: brandBlue,
                textStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              child: const Text('今天'),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    height: 64,
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: brandBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildCupertinoPicker(
                          controller: _yearCtrl,
                          items: _years,
                          unit: '年',
                          selectedIndex: _selectedYearIndex,
                          onChanged: (idx) {
                            _currentTempDate = DateTime(
                              _years[idx],
                              _currentTempDate.month,
                              _currentTempDate.day,
                            );
                            _selectedYearIndex = idx;
                            _onYearMonthChanged();
                          },
                        ),
                      ),
                      Expanded(
                        child: _buildCupertinoPicker(
                          controller: _monthCtrl,
                          items: List.generate(12, (idx) => idx + 1),
                          unit: '月',
                          selectedIndex: _selectedMonthIndex,
                          onChanged: (idx) {
                            _currentTempDate = DateTime(
                              _currentTempDate.year,
                              idx + 1,
                              _currentTempDate.day,
                            );
                            _selectedMonthIndex = idx;
                            _onYearMonthChanged();
                          },
                        ),
                      ),
                      Expanded(
                        child: _buildCupertinoPicker(
                          controller: _dayCtrl,
                          items: _days,
                          unit: '日',
                          selectedIndex: _selectedDayIndex,
                          onChanged: (idx) {
                            setState(() {
                              _currentTempDate = DateTime(
                                _currentTempDate.year,
                                _currentTempDate.month,
                                _days[idx],
                              );
                              _selectedDayIndex = idx;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCupertinoPicker({
    required FixedExtentScrollController controller,
    required List<int> items,
    required String unit,
    required int selectedIndex,
    required ValueChanged<int> onChanged,
  }) {
    const Color brandBlue = Color(0xFF007BFF);
    return CupertinoPicker(
      scrollController: controller,
      itemExtent: 64,
      selectionOverlay: const SizedBox.shrink(),
      onSelectedItemChanged: onChanged,
      children: List.generate(items.length, (idx) {
        final bool isSelected = idx == selectedIndex;
        return Center(
          child: RichText(
            text: TextSpan(
              text: '${items[idx]}',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: isSelected ? brandBlue : Colors.grey,
              ),
              children: [
                TextSpan(
                  text: unit,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
