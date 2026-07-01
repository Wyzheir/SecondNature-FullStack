import 'package:flutter/material.dart';

// 🚀 剥离：顶部巨大的营养目标卡片
class NutritionHeroCard extends StatelessWidget {
  final dynamic goal;
  final Map<String, double> status;

  const NutritionHeroCard({
    super.key,
    required this.goal,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final double intake = status['intake']!;
    final double burn = status['burn']!;
    final double remaining = status['remaining']!;

    double dietRatio = goal.targetKcal > 0
        ? (intake / goal.targetKcal).clamp(0.0, 1.0)
        : 0.0;
    double exerciseRatio = goal.targetKcal > 0
        ? (burn / goal.targetKcal).clamp(0.0, 1.0)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 30),
            padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '今日营养目标',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 16),
                _buildDynamicTargetCard(goal.targetKcal, burn),
                const SizedBox(height: 40),
                Row(
                  children: [
                    Expanded(
                      child: _buildMacroBar(
                        '碳水',
                        status['carbs']!.round(),
                        goal.carbsG.round(),
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildMacroBar(
                        '蛋白质',
                        status['protein']!.round(),
                        goal.proteinG.round(),
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildMacroBar(
                        '脂肪',
                        status['fat']!.round(),
                        goal.fatG.round(),
                        Colors.orange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            right: 20,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      value: 1.0,
                      strokeWidth: 10,
                      valueColor: AlwaysStoppedAnimation(Colors.grey.shade100),
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      value: dietRatio * 0.5,
                      strokeWidth: 10,
                      strokeCap: StrokeCap.round,
                      valueColor: const AlwaysStoppedAnimation(
                        Color(0xFF007BFF),
                      ),
                    ),
                  ),
                  Transform.scale(
                    scaleX: -1,
                    child: SizedBox(
                      width: 120,
                      height: 120,
                      child: CircularProgressIndicator(
                        value: exerciseRatio * 0.5,
                        strokeWidth: 10,
                        strokeCap: StrokeCap.round,
                        valueColor: const AlwaysStoppedAnimation(Colors.orange),
                      ),
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${remaining.round()}',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF007BFF),
                        ),
                      ),
                      const Text(
                        '剩余摄入',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroBar(String title, int consumed, int target, Color color) {
    double progress = target == 0 ? 0 : consumed / target;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: progress.clamp(0.0, 1.0),
          backgroundColor: Colors.grey.shade100,
          color: color,
          minHeight: 6,
        ),
        const SizedBox(height: 4),
        Text(
          '$consumed/${target}g',
          style: const TextStyle(color: Colors.grey, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildDynamicTargetCard(double baseKcal, double exerciseKcal) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            baseKcal.toStringAsFixed(0),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.blueAccent,
            ),
          ),
          if (exerciseKcal > 0)
            Text(
              ' +${exerciseKcal.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.orange,
              ),
            ),
          const SizedBox(width: 6),
          const Text('千卡', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}

// 🚀 剥离：通用动作模块卡片
class ActionModuleCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final String value;
  final String unit;
  final IconData? subIcon;
  final String? subValue;
  final String? subUnit;
  final VoidCallback onAdd;

  const ActionModuleCard({
    super.key,
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.unit,
    this.subIcon,
    this.subValue,
    this.subUnit,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              IconButton(
                onPressed: onAdd,
                icon: const Icon(Icons.add, color: Color(0xFF007BFF), size: 28),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Icon(icon, color: iconColor, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      unit,
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ),
              ),
              if (subValue != null)
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      if (subIcon != null) ...[
                        Icon(
                          subIcon,
                          color: Colors.blueGrey.shade300,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        subValue!,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        subUnit ?? '',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// 🚀 剥离：目标同步状态卡片
class EmptyGoalCard extends StatelessWidget {
  const EmptyGoalCard({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Center(
        child: Text('正在同步健康计划...', style: TextStyle(color: Colors.blue)),
      ),
    );
  }
}
