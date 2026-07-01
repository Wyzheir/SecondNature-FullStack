import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

/// ==========================================
/// 🚀 自定义日期选择器弹窗 (真正的全宽、通铺、蓝字)
/// ==========================================
void showCustomCupertinoDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required ValueChanged<DateTime> onDateSelected,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    // 🚀 核心突破：打破 Material 3 的默认宽度限制，强制等同于屏幕物理宽度！
    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width),
    builder: (context) => _CupertinoDatePickerContent(
      initialDate: initialDate,
      onDateSelected: onDateSelected,
    ),
  );
}

class _CupertinoDatePickerContent extends StatefulWidget {
  final DateTime initialDate;
  final ValueChanged<DateTime> onDateSelected;

  const _CupertinoDatePickerContent({
    required this.initialDate,
    required this.onDateSelected,
  });

  @override
  State<_CupertinoDatePickerContent> createState() =>
      _CupertinoDatePickerContentState();
}

class _CupertinoDatePickerContentState
    extends State<_CupertinoDatePickerContent> {
  late FixedExtentScrollController _yearCtrl, _monthCtrl, _dayCtrl;
  late List<int> _years;
  late DateTime _currentTempDate;
  final int _startYear = 1970;

  // 🚀 核心状态：跟踪选中索引
  late int _selectedYearIndex;
  late int _selectedMonthIndex;
  late int _selectedDayIndex;

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

  List<int> get _days {
    return List.generate(
      DateTime(_currentTempDate.year, _currentTempDate.month + 1, 0).day,
      (idx) => idx + 1,
    );
  }

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
        width: double.infinity,
        // 🚀 修复 1：彻底删掉写死的 height: 380，把高度控制权交给内容
        decoration: const BoxDecoration(
          color: Colors.white,
          // 🚀 修复 2：圆角从 24 改为 20，完美对齐输入弹窗的 UI 规范
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          // 🚀 修复 3：核心魔法！让外层高度由内部内容“撑开”，实现完美自适应
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
                const Text(
                  '更改日期',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                    decoration: TextDecoration.none,
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
            const SizedBox(height: 16),
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

            // 🚀 修复 4：把 Expanded 换成固定高度的 SizedBox。
            // 因为滚轮需要一个明确的高度空间，我们将它设定为 250，这样整体弹窗高度刚好完美！
            SizedBox(
              height: 250,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 🎨 底层：贯通全宽的蓝色圆角背景
                  Container(
                    height: 64,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: brandBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),

                  // 🎡 顶层：三个彻底透明背景的滚轮
                  Row(
                    children: [
                      Expanded(
                        child: _buildCupertinoPicker(
                          controller: _yearCtrl,
                          items: _years,
                          unit: '年',
                          selectedIndex: _selectedYearIndex,
                          onChanged: (idx) {
                            setState(() {
                              _selectedYearIndex = idx;
                              _currentTempDate = DateTime(
                                _years[idx],
                                _currentTempDate.month,
                                _currentTempDate.day,
                              );
                              _onYearMonthChanged();
                            });
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
                            setState(() {
                              _selectedMonthIndex = idx;
                              _currentTempDate = DateTime(
                                _currentTempDate.year,
                                idx + 1,
                                _currentTempDate.day,
                              );
                              _onYearMonthChanged();
                            });
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
                              _selectedDayIndex = idx;
                              _currentTempDate = DateTime(
                                _currentTempDate.year,
                                _currentTempDate.month,
                                _days[idx],
                              );
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
      // 🚀 杀掉自带的隔离选中框，使用透明容器
      selectionOverlay: Container(color: Colors.transparent),
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
                // 🎨 选中变蓝，未选中变灰
                color: isSelected ? brandBlue : Colors.grey.shade400,
                decoration: TextDecoration.none,
              ),
              children: [
                TextSpan(
                  text: unit,
                  style: TextStyle(
                    fontSize: 14,
                    color: isSelected
                        ? brandBlue.withValues(alpha: 0.7)
                        : Colors.grey.shade400,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
