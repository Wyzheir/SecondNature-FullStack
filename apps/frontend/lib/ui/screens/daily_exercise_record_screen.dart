import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/record_provider.dart';
import '../widgets/exercise_widgets.dart'; // 👉 确保这个文件已创建并保存！
import '../widgets/cupertino_date_picker_content.dart';

const Color brandBlue = Color(0xFF007BFF); // 🚀 补齐：就地定义品牌色，彻底解决 const 报错

class DailyExerciseRecordScreen extends StatefulWidget {
  final DateTime initialDate;
  const DailyExerciseRecordScreen({super.key, required this.initialDate});

  @override
  State<DailyExerciseRecordScreen> createState() =>
      _DailyExerciseRecordScreenState();
}

class _DailyExerciseRecordScreenState extends State<DailyExerciseRecordScreen> {
  late DateTime _currentDate;

  @override
  void initState() {
    super.initState();
    _currentDate = widget.initialDate;
  }

  @override
  Widget build(BuildContext context) {
    final records = context.watch<RecordProvider>().records.where((r) {
      if (r.recordType != 'EXERCISE') return false;
      final d = DateTime.parse(r.recordDate).toLocal();
      return d.year == _currentDate.year &&
          d.month == _currentDate.month &&
          d.day == _currentDate.day;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: ClickableDateTitle(
          date: _currentDate,
          onTap: () => showCustomCupertinoDatePicker(
            context: context,
            initialDate: _currentDate,
            onDateSelected: (d) => setState(() => _currentDate = d),
          ),
        ),
      ),
      body: records.isEmpty
          ? const Center(child: Text('没有运动记录'))
          : ListView.builder(
              itemCount: records.length,
              itemBuilder: (context, index) {
                final r = records[index];
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade100),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // 🚀 修复：移除了 TextStyle 前面的 const
                          Text(
                            '${r.recordValue.round()}千卡',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: brandBlue,
                            ),
                          ),
                          const SizedBox(width: 32),
                          const Icon(
                            Icons.access_time_filled,
                            color: Colors.orange,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${r.duration?.toInt()} 分钟',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        r.notes?.split(' ').first ?? '',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
