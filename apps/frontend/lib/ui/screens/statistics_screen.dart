import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/statistics_provider.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  int _selectedDays = 7;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StatisticsProvider>().fetchStatistics(days: _selectedDays);
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color bgColor = Color(0xFFF7F8FA);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '统计',
          style: TextStyle(
            color: Color(0xFF007BFF),
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        actions: [
          // 🚀 顶部极简时间跨度切换
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _selectedDays,
              icon: const Icon(Icons.arrow_drop_down, color: Colors.black87),
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              items: const [
                DropdownMenuItem(value: 7, child: Text('近一周')),
                DropdownMenuItem(value: 30, child: Text('近一月')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedDays = val);
                  context.read<StatisticsProvider>().fetchStatistics(days: val);
                }
              },
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Consumer<StatisticsProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.redAccent,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    provider.errorMessage!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                  TextButton(
                    onPressed: () =>
                        provider.fetchStatistics(days: _selectedDays),
                    child: const Text('重试'),
                  ),
                ],
              ),
            );
          }

          if (provider.chartData.isEmpty) {
            return const Center(
              child: Text(
                '暂无统计数据，快去打卡吧！',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            physics: const BouncingScrollPhysics(),
            children: [
              // 1. 均值汇总卡片
              _buildSummaryCard(provider),
              const SizedBox(height: 16),

              // 2. 卡路里单柱图卡片
              _buildCalorieCard(provider),
              const SizedBox(height: 16),

              // 3. 营养素分组柱图卡片
              _buildMacroCard(provider),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }

  /// ==========================================
  /// 📊 模块 1：均值汇总卡片
  /// ==========================================
  Widget _buildSummaryCard(StatisticsProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text(
                '均值',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                '(每日)',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryItem(provider.averageKcal.toString(), '热量(千卡)'),
              _buildSummaryItem(provider.averageCarbs.toString(), '碳水(g)'),
              _buildSummaryItem(provider.averageProtein.toString(), '蛋白(g)'),
              _buildSummaryItem(provider.averageFat.toString(), '脂肪(g)'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  /// ==========================================
  /// 📊 模块 2：卡路里柱状图
  /// ==========================================
  Widget _buildCalorieCard(StatisticsProvider provider) {
    final data = provider.chartData;
    double maxKcal = 0;
    for (var d in data) {
      if (d.dietKcal > maxKcal) maxKcal = d.dietKcal;
    }
    // 让 Y 轴的顶端稍微比最高值高一点，留出呼吸空间
    final maxY = maxKcal < 2000 ? 2500.0 : maxKcal * 1.2;

    return Container(
      height: 320,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '卡路里',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: BarChart(
              BarChartData(
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.shade200,
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: maxY / 4,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= data.length)
                          return const SizedBox.shrink();
                        // 如果是近30天，隔天显示标签防拥挤
                        if (_selectedDays == 30 && idx % 4 != 0)
                          return const SizedBox.shrink();

                        final dateStr = data[idx].date
                            .split('-')
                            .last; // 只取 "日"
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            '${dateStr}日',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 11,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: data.asMap().entries.map((e) {
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value.dietKcal,
                        color: const Color(0xFF007BFF),
                        width: _selectedDays == 7 ? 20 : 8, // 天数多柱子就细一点
                        borderRadius: BorderRadius.zero, // 方角柱子还原图片风格
                      ),
                    ],
                  );
                }).toList(),
              ),
              swapAnimationDuration: const Duration(milliseconds: 350),
            ),
          ),
        ],
      ),
    );
  }

  /// ==========================================
  /// 📊 模块 3：营养素分组柱状图
  /// ==========================================
  Widget _buildMacroCard(StatisticsProvider provider) {
    final data = provider.chartData;
    double maxMacro = 0;
    for (var d in data) {
      if (d.carbsG > maxMacro) maxMacro = d.carbsG;
      if (d.proteinG > maxMacro) maxMacro = d.proteinG;
      if (d.fatG > maxMacro) maxMacro = d.fatG;
    }
    final maxY = maxMacro < 50 ? 100.0 : maxMacro * 1.2;

    const Color carbsColor = Color(0xFF8A2BE2); // 紫色
    const Color proteinColor = Color(0xFFFFD700); // 黄色
    const Color fatColor = Color(0xFFFF8C00); // 橘色

    return Container(
      height: 350,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '营养素',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                '单位: 克',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 图例
          Row(
            children: [
              _buildLegend(carbsColor, '碳水'),
              const SizedBox(width: 16),
              _buildLegend(proteinColor, '蛋白质'),
              const SizedBox(width: 16),
              _buildLegend(fatColor, '脂肪'),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: BarChart(
              BarChartData(
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (value) =>
                      FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: maxY / 4,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= data.length)
                          return const SizedBox.shrink();
                        if (_selectedDays == 30 && idx % 4 != 0)
                          return const SizedBox.shrink();

                        final dateStr = data[idx].date.split('-').last;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            '${dateStr}日',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 11,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                // 🚀 核心魔法：使用多个 BarChartRodData 拼装成分组柱状图
                barGroups: data.asMap().entries.map((e) {
                  final barWidth = _selectedDays == 7 ? 8.0 : 4.0;
                  return BarChartGroupData(
                    x: e.key,
                    barsSpace: 2, // 柱子之间的缝隙
                    barRods: [
                      BarChartRodData(
                        toY: e.value.carbsG,
                        color: carbsColor,
                        width: barWidth,
                        borderRadius: BorderRadius.zero,
                      ),
                      BarChartRodData(
                        toY: e.value.proteinG,
                        color: proteinColor,
                        width: barWidth,
                        borderRadius: BorderRadius.zero,
                      ),
                      BarChartRodData(
                        toY: e.value.fatG,
                        color: fatColor,
                        width: barWidth,
                        borderRadius: BorderRadius.zero,
                      ),
                    ],
                  );
                }).toList(),
              ),
              swapAnimationDuration: const Duration(milliseconds: 350),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
