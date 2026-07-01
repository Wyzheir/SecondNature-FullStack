import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../models/record.dart';

class WeightDataCard extends StatelessWidget {
  final List<HealthRecord> records;
  final VoidCallback onAdd;

  const WeightDataCard({super.key, required this.records, required this.onAdd});

  DateTime _forceParseLocal(String dateStr) {
    try {
      if (dateStr.length >= 10) {
        final year = int.parse(dateStr.substring(0, 4));
        final month = int.parse(dateStr.substring(5, 7));
        final day = int.parse(dateStr.substring(8, 10));
        return DateTime(year, month, day);
      }
      return DateTime.now();
    } catch (_) {
      return DateTime.now();
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawWeightRecords = records
        .where((r) => r.recordType == 'WEIGHT')
        .toList();

    rawWeightRecords.sort((a, b) {
      return a.recordDate.compareTo(b.recordDate);
    });

    Map<String, HealthRecord> dailyMap = {};
    for (var r in rawWeightRecords) {
      final localDate =
          DateTime.tryParse(r.recordDate)?.toLocal() ?? DateTime.now();
      final String dateKey =
          "${localDate.year}-${localDate.month.toString().padLeft(2, '0')}-${localDate.day.toString().padLeft(2, '0')}";
      dailyMap[dateKey] = r;
    }

    List<String> sortedDates = dailyMap.keys.toList()..sort();
    List<HealthRecord> processedRecords = sortedDates
        .map((date) => dailyMap[date]!)
        .toList();
    final bool hasData = processedRecords.isNotEmpty;

    return Container(
      height: 280,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '体重管理',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 28, color: Color(0xFF007BFF)),
                onPressed: onAdd,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(child: LineChart(_getChartData(hasData, processedRecords))),
        ],
      ),
    );
  }

  LineChartData _getChartData(bool hasData, List<HealthRecord> weightRecords) {
    if (!hasData) return _buildEmptyState();

    double minW = weightRecords
        .map((e) => e.recordValue)
        .reduce((a, b) => a < b ? a : b);
    double maxW = weightRecords
        .map((e) => e.recordValue)
        .reduce((a, b) => a > b ? a : b);

    double range = maxW - minW;
    if (range < 3) range = 3;
    int yInterval = (range / 3).ceil();
    if (yInterval < 1) yInterval = 1;

    int baseMin = minW.floor();
    List<double> targetLines = [
      baseMin.toDouble(),
      (baseMin + yInterval).toDouble(),
      (baseMin + yInterval * 2).toDouble(),
      (baseMin + yInterval * 3).toDouble(),
    ];

    double drawMinY = targetLines.first - 0.5;
    double drawMaxY = targetLines.last + 0.5;

    double xInterval = 1.0;
    int count = weightRecords.length;
    if (count > 7 && count <= 14) {
      xInterval = 2.0;
    } else if (count > 14) {
      xInterval = (count / 5).ceilToDouble();
    }

    List<FlSpot> spots = [];
    Map<int, String> titles = {};

    for (int i = 0; i < count; i++) {
      spots.add(FlSpot(i.toDouble(), weightRecords[i].recordValue));
      titles[i] = _formatDate(weightRecords[i].recordDate);
    }

    double safeMaxX = (count - 1).toDouble();
    if (safeMaxX <= 0) safeMaxX = 1.0;

    return _buildMainChart(
      spots,
      titles,
      0,
      safeMaxX,
      drawMinY,
      drawMaxY,
      targetLines,
      xInterval,
    );
  }

  LineChartData _buildEmptyState() {
    return LineChartData(
      minX: 0,
      maxX: 3,
      minY: 0,
      maxY: 100,
      gridData: const FlGridData(show: false),
      titlesData: const FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(spots: const [FlSpot(0, 0)], show: false),
      ],
    );
  }

  LineChartData _buildMainChart(
    List<FlSpot> spots,
    Map<int, String> titles,
    double minX,
    double maxX,
    double drawMinY,
    double drawMaxY,
    List<double> targetLines,
    double xInterval,
  ) {
    return LineChartData(
      minX: minX,
      maxX: maxX,
      minY: drawMinY,
      maxY: drawMaxY,
      borderData: FlBorderData(show: false),

      // 🚀 物理降维 1：彻底关闭默认的耗性能扫描网格！
      gridData: const FlGridData(show: false),

      // 🚀 物理降维 2：使用极低性能消耗的 ExtraLinesData，精准画出 4 条灰线
      extraLinesData: ExtraLinesData(
        horizontalLines: targetLines
            .map(
              (y) => HorizontalLine(
                y: y,
                color: Colors.grey.shade300,
                strokeWidth: 1.5,
              ),
            )
            .toList(),
      ),

      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 35,
            // 🚀 物理降维 3：抛弃 0.1 扫描。强行按 1.0 扫描，性能提升十倍，绝不死机！
            interval: 1.0,
            getTitlesWidget: (value, meta) {
              if (!targetLines.any((t) => (value - t).abs() < 0.1)) {
                return const SizedBox.shrink();
              }
              return SideTitleWidget(
                meta: meta,
                space: 8,
                child: Text(
                  '${value.toInt()}',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: xInterval,
            getTitlesWidget: (value, meta) {
              final int index = value.toInt();
              if ((value - index).abs() > 0.1) return const SizedBox.shrink();
              final text = titles[index];
              if (text == null) return const SizedBox.shrink();

              return SideTitleWidget(
                meta: meta,
                space: 8,
                child: Text(
                  text,
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                ),
              );
            },
          ),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: spots.length > 1,
          color: const Color(0xFF007BFF).withValues(alpha: 0.5),
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            checkToShowDot: (spot, barData) => spot.x == barData.spots.last.x,
            getDotPainter: (spot, percent, barData, index) =>
                FlDotCirclePainter(
                  radius: 5,
                  color: Colors.orange,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                ),
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                const Color(0xFF007BFF).withValues(alpha: 0.2),
                Colors.transparent,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(String dateStr) {
    try {
      DateTime dt = _forceParseLocal(dateStr);
      return DateFormat('MM/dd').format(dt);
    } catch (_) {
      return '';
    }
  }
}
