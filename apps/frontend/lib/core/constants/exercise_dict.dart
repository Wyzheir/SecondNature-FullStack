import 'package:flutter/material.dart';

class ExerciseDict {
  // 升级为二维结构：包含 category (分类名) 和 exercises (该分类下的运动)
  static final List<Map<String, dynamic>> categories = [
    {
      'category': '行走与跑步',
      'exercises': [
        {'name': '散步 (慢)', 'met': 2.5, 'icon': Icons.directions_walk},
        {'name': '快走', 'met': 4.3, 'icon': Icons.directions_walk},
        {'name': '慢跑', 'met': 7.0, 'icon': Icons.directions_run},
        {'name': '跑步 (快)', 'met': 11.0, 'icon': Icons.directions_run},
      ],
    },
    {
      'category': '自行车骑行',
      'exercises': [
        {'name': '休闲骑行', 'met': 4.0, 'icon': Icons.directions_bike},
        {'name': '动感单车', 'met': 7.0, 'icon': Icons.pedal_bike},
        {'name': '竞速骑行', 'met': 8.5, 'icon': Icons.directions_bike},
      ],
    },
    {
      'category': '有氧器材',
      'exercises': [
        {'name': '椭圆机 (轻松)', 'met': 4.5, 'icon': Icons.fitness_center},
        {'name': '划船机', 'met': 7.0, 'icon': Icons.rowing},
        {'name': '爬楼梯机', 'met': 8.0, 'icon': Icons.stairs},
      ],
    },
    {
      'category': '水上运动',
      'exercises': [
        {'name': '休闲游泳', 'met': 6.0, 'icon': Icons.pool},
        {'name': '蛙泳/自由泳', 'met': 9.8, 'icon': Icons.pool},
      ],
    },
    {
      'category': '球类运动',
      'exercises': [
        {'name': '乒乓球', 'met': 4.0, 'icon': Icons.sports_tennis},
        {'name': '羽毛球', 'met': 5.5, 'icon': Icons.sports_tennis},
        {'name': '足球', 'met': 7.0, 'icon': Icons.sports_soccer},
        {'name': '篮球', 'met': 8.0, 'icon': Icons.sports_basketball},
      ],
    },
    {
      'category': '力量与健身',
      'exercises': [
        {'name': '力量训练 (轻)', 'met': 3.0, 'icon': Icons.fitness_center},
        {'name': '力量训练 (重)', 'met': 6.0, 'icon': Icons.fitness_center},
        {'name': 'HIIT (高强度)', 'met': 8.0, 'icon': Icons.local_fire_department},
      ],
    },
    {
      'category': '瑜伽与普拉提',
      'exercises': [
        {'name': '瑜伽', 'met': 2.5, 'icon': Icons.self_improvement},
        {'name': '普拉提', 'met': 3.0, 'icon': Icons.accessibility_new},
      ],
    },
    {
      'category': '日常与休闲', // 替代原图的部分细分选项，保证有数据可展示
      'exercises': [
        {'name': '做家务', 'met': 3.0, 'icon': Icons.cleaning_services},
        {'name': '跳绳', 'met': 10.0, 'icon': Icons.sports_gymnastics},
      ],
    },
  ];
}
