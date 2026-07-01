import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../core/network/dio_client.dart';

/// 严格对齐后端统计契约的数据模型
class DailyStatisticItem {
  final String date;
  final double dietKcal;
  final double exerciseMins;
  // 🚀 新增：承接后端的宏量营养素数据
  final double carbsG;
  final double proteinG;
  final double fatG;

  DailyStatisticItem({
    required this.date,
    required this.dietKcal,
    required this.exerciseMins,
    required this.carbsG,
    required this.proteinG,
    required this.fatG,
  });

  factory DailyStatisticItem.fromJson(Map<String, dynamic> json) {
    return DailyStatisticItem(
      date: json['date'] ?? '',
      dietKcal: double.tryParse(json['diet_kcal'].toString()) ?? 0.0,
      exerciseMins: double.tryParse(json['exercise_mins'].toString()) ?? 0.0,
      // 🚀 新增：安全解析三大营养素，统一转字符串再强转 double，防止动态类型崩溃
      carbsG: double.tryParse(json['carbs_g'].toString()) ?? 0.0,
      proteinG: double.tryParse(json['protein_g'].toString()) ?? 0.0,
      fatG: double.tryParse(json['fat_g'].toString()) ?? 0.0,
    );
  }
}

class StatisticsProvider extends ChangeNotifier {
  final DioClient _dioClient;

  List<DailyStatisticItem> _chartData = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<DailyStatisticItem> get chartData => _chartData;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // ==========================================
  // 🚀 新增：数据算力引擎 - 自动计算 UI 顶部的“每日均值”
  // ==========================================

  int get averageKcal {
    if (_chartData.isEmpty) return 0;
    // 使用 fold 对当前列表内的全部热量求和，再除以天数，最后四舍五入为整数
    final sum = _chartData.fold(0.0, (prev, item) => prev + item.dietKcal);
    return (sum / _chartData.length).round();
  }

  int get averageCarbs {
    if (_chartData.isEmpty) return 0;
    final sum = _chartData.fold(0.0, (prev, item) => prev + item.carbsG);
    return (sum / _chartData.length).round();
  }

  int get averageProtein {
    if (_chartData.isEmpty) return 0;
    final sum = _chartData.fold(0.0, (prev, item) => prev + item.proteinG);
    return (sum / _chartData.length).round();
  }

  int get averageFat {
    if (_chartData.isEmpty) return 0;
    final sum = _chartData.fold(0.0, (prev, item) => prev + item.fatG);
    return (sum / _chartData.length).round();
  }

  // ==========================================

  StatisticsProvider(this._dioClient);

  /// 核心网络对接：拉取指定天数的统计数据
  Future<void> fetchStatistics({int days = 7}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: days - 1));

      String formatDate(DateTime dt) =>
          "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";

      debugPrint('📊 正在拉取图表数据: ${formatDate(startDate)} -> ${formatDate(now)}');

      final response = await _dioClient.dio.get(
        '/records/statistics',
        queryParameters: {
          'start_date': formatDate(startDate),
          'end_date': formatDate(now),
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final Map<String, dynamic> responseBody = response.data;

        // 🚀 核心修复：先扒开后端的标准统一外壳，拿到真正的业务数据 'data' 字典
        if (responseBody['code'] == 200 && responseBody.containsKey('data')) {
          final Map<String, dynamic> realData = responseBody['data'];

          // 然后再从 'data' 字典里提取 'statistics' 数组
          final List<dynamic> rawList = realData['statistics'] ?? [];

          _chartData = rawList
              .map((item) => DailyStatisticItem.fromJson(item))
              .toList();
        }
      }
    } on DioException catch (e) {
      _errorMessage = '网络请求失败: ${e.message}';
      debugPrint('❌ 统计数据拉取异常: ${e.message}');
    } catch (e) {
      _errorMessage = '数据解析失败';
      debugPrint('❌ 统计数据解析异常: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
