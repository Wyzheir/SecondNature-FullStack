import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/record.dart';
import '../../providers/record_provider.dart';
import '../../repositories/sync_service.dart';

class FoodDetailScreen extends StatefulWidget {
  final HealthRecord record;
  const FoodDetailScreen({super.key, required this.record});

  @override
  State<FoodDetailScreen> createState() => _FoodDetailScreenState();
}

class _FoodDetailScreenState extends State<FoodDetailScreen> {
  late TextEditingController _amountController;
  late double _unitKcal, _unitCarbs, _unitProtein, _unitFat;

  @override
  void initState() {
    super.initState();
    // 解析重量
    final currentWeight =
        double.tryParse(
          widget.record.notes?.split(' ').last.replaceAll('g', '') ?? '100',
        ) ??
        100.0;

    _amountController = TextEditingController(
      text: currentWeight.toInt().toString(),
    );

    // 计算 1g 基准
    _unitKcal = widget.record.recordValue / currentWeight;
    _unitCarbs = (widget.record.carbsG ?? 0) / currentWeight;
    _unitProtein = (widget.record.proteinG ?? 0) / currentWeight;
    _unitFat = (widget.record.fatG ?? 0) / currentWeight;

    _amountController.addListener(() => setState(() {}));
  }

  double get _currentInputWeight =>
      double.tryParse(_amountController.text) ?? 0.0;

  @override
  Widget build(BuildContext context) {
    const Color brandBlue = Color(0xFF006BFF);
    const Color bgColor = Color(0xFFF5F6F9); // 统一背景色

    return Scaffold(
      backgroundColor: bgColor,
      // 🚀 修正 1：AppBar 颜色与背景一致，实现无缝衔接
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '食物详情',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🚀 修正 2：合理的标题字体大小
                  Row(
                    children: [
                      Text(
                        widget.record.foodName ?? '',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.check_circle,
                        color: Color(0xFF4CAF50),
                        size: 18,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 🚀 修正 3：紧凑的数据框，缩短竖向距离
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        // 数值行
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildInfoCol(
                              (_unitKcal * _currentInputWeight)
                                  .round()
                                  .toString(),
                              '千卡',
                              '热量',
                            ),
                            _buildInfoCol(
                              (_unitCarbs * _currentInputWeight)
                                  .toStringAsFixed(1),
                              'g',
                              '碳水',
                            ),
                            _buildInfoCol(
                              (_unitProtein * _currentInputWeight)
                                  .toStringAsFixed(1),
                              'g',
                              '蛋白质',
                            ),
                            _buildInfoCol(
                              (_unitFat * _currentInputWeight).toStringAsFixed(
                                1,
                              ),
                              'g',
                              '脂肪',
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Divider(height: 1, color: Color(0xFFF0F0F0)),
                        ),
                        // 单位行
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '单位',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Row(
                              children: [
                                const Text(
                                  'g',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_drop_down,
                                  color: Colors.grey.shade600,
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // 数量行
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '数量',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(
                              width: 80,
                              child: TextField(
                                controller: _amountController,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 🚀 修正 4：缩短了 Padding 的热量来源框
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 24,
                      horizontal: 20,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          '热量来源',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildMacroIcon(
                              Icons.rice_bowl,
                              '碳水',
                              _unitCarbs,
                              4,
                            ),
                            _buildMacroIcon(Icons.egg, '蛋白质', _unitProtein, 4),
                            _buildMacroIcon(
                              Icons.bakery_dining_rounded,
                              '脂肪',
                              _unitFat,
                              9,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 🚀 修正 5：按钮文案改为“保存”
          Container(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              MediaQuery.of(context).padding.bottom + 12,
            ),
            color: Colors.white,
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _handleSave,
                style: FilledButton.styleFrom(
                  backgroundColor: brandBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  '保存',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 内部小组件：数值列
  Widget _buildInfoCol(String value, String unit, String label) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(width: 1),
            Text(
              unit,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  // 内部小组件：热量比例图标
  Widget _buildMacroIcon(
    IconData icon,
    String label,
    double grams,
    int factor,
  ) {
    final double currentKcal = grams * _currentInputWeight * factor;
    final double totalKcal = _unitKcal * _currentInputWeight;
    final String percent = totalKcal > 0
        ? '${((currentKcal / totalKcal) * 100).round()}%'
        : '0%';

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.grey.shade400, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        Text(
          '($percent)',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Future<void> _handleSave() async {
    final weight = _currentInputWeight;
    if (weight <= 0) return;

    final updatedRecord = widget.record.copyWith(
      recordValue: _unitKcal * weight,
      carbsG: _unitCarbs * weight,
      proteinG: _unitProtein * weight,
      fatG: _unitFat * weight,
      notes: '${widget.record.foodName} ${weight.toInt()}g',
      syncStatus: 0,
    );

    final syncService = context.read<SyncService>();
    await context.read<RecordProvider>().updateRecord(
      updatedRecord,
      syncService: syncService,
    );

    if (mounted) Navigator.pop(context);
  }
}
