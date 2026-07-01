import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../providers/record_provider.dart';
import '../../core/constants/exercise_dict.dart';

import '../widgets/exercise_widgets.dart'; // 👉 确保这个文件已创建并保存！
import '../widgets/cupertino_date_picker_content.dart';
import 'daily_exercise_record_screen.dart';

const Color brandBlue = Color(0xFF007BFF); // 🚀 补齐：就地定义品牌色

class AddExerciseScreen extends StatefulWidget {
  const AddExerciseScreen({super.key});

  @override
  State<AddExerciseScreen> createState() => _AddExerciseScreenState();
}

class _AddExerciseScreenState extends State<AddExerciseScreen> {
  int _selectedCategoryIndex = 0;
  DateTime _selectedDate = DateTime.now();

  final GlobalKey _addedButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('zh_CN', null);
  }

  void _openInputBottomSheet(Map<String, dynamic> exercise) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width),
      builder: (context) => ExerciseInputBottomSheet(
        exercise: exercise,
        recordDate: _selectedDate,
        targetKey: _addedButtonKey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentCategoryExercises =
        ExerciseDict.categories[_selectedCategoryIndex]['exercises'] as List;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
        title: ClickableDateTitle(
          date: _selectedDate,
          onTap: () => showCustomCupertinoDatePicker(
            context: context,
            initialDate: _selectedDate,
            onDateSelected: (date) => setState(() => _selectedDate = date),
          ),
        ),
        actions: [
          Consumer<RecordProvider>(
            builder: (context, recordProvider, child) {
              final count = recordProvider.records.where((r) {
                if (r.recordType != 'EXERCISE') return false;
                try {
                  final d = DateTime.parse(r.recordDate).toLocal();
                  return d.year == _selectedDate.year &&
                      d.month == _selectedDate.month &&
                      d.day == _selectedDate.day;
                } catch (_) {
                  return false;
                }
              }).length;

              return Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Container(
                    key: _addedButtonKey,
                    margin: const EdgeInsets.only(right: 12),
                    child: TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DailyExerciseRecordScreen(
                            initialDate: _selectedDate,
                          ),
                        ),
                      ),
                      // 🚀 修复：移除了 Text 外部冲突的 const 修饰符
                      child: Text(
                        '已添加',
                        style: TextStyle(
                          color: brandBlue,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  if (count > 0)
                    Positioned(
                      top: 8,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        constraints: const BoxConstraints(
                          minWidth: 15,
                          minHeight: 15,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Center(
                          child: Text(
                            '$count',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: Row(
        children: [
          _buildCategoryList(),
          Expanded(child: _buildExerciseList(currentCategoryExercises)),
        ],
      ),
    );
  }

  Widget _buildCategoryList() {
    return Container(
      width: 120,
      color: const Color(0xFFF7F8FA),
      child: ListView.builder(
        itemCount: ExerciseDict.categories.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedCategoryIndex == index;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategoryIndex = index),
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.transparent,
                border: Border(
                  left: BorderSide(
                    color: isSelected ? brandBlue : Colors.transparent,
                    width: 4,
                  ),
                ),
              ),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 12),
              // 🚀 修复：安全使用 brandBlue
              child: Text(
                ExerciseDict.categories[index]['category'],
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? brandBlue : Colors.black87,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildExerciseList(List exercises) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: exercises.length,
      itemBuilder: (context, index) {
        final ex = exercises[index];
        return InkWell(
          onTap: () => _openInputBottomSheet(ex),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ex['name'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${ex['met']} METs',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.add_circle_outline,
                  color: Colors.grey,
                  size: 22,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
