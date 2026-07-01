import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../models/record.dart';
import '../../providers/auth_provider.dart';
import '../../providers/record_provider.dart';
import '../../repositories/sync_service.dart';

const Color brandBlue = Color(0xFF007BFF);

/// ==========================================
/// 🚀 1. 日期标题组件
/// ==========================================
class ClickableDateTitle extends StatelessWidget {
  final DateTime date;
  final VoidCallback onTap;

  const ClickableDateTitle({
    super.key,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('M月d日 E', 'zh_CN').format(date);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              dateStr,
              style: const TextStyle(
                color: brandBlue,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, color: brandBlue, size: 20),
          ],
        ),
      ),
    );
  }
}

/// ==========================================
/// 🚀 2. 呼吸吸入动画引擎
/// ==========================================
class BreathAnimationOverlay {
  static void run({
    required BuildContext context,
    required GlobalKey targetKey,
    required Offset startOffset,
    required String kcal,
    required String mins,
  }) {
    final overlayState = Overlay.of(context);
    final RenderBox? targetBox =
        targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (targetBox == null) return;

    final Offset targetOffset = targetBox.localToGlobal(
      Offset(targetBox.size.width * 0.8, targetBox.size.height / 2),
    );

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _BreathAnimationWidget(
        startOffset: startOffset,
        targetOffset: targetOffset,
        kcal: kcal,
        mins: mins,
        onEnd: () => entry.remove(),
      ),
    );
    overlayState.insert(entry);
  }
}

class _BreathAnimationWidget extends StatefulWidget {
  final Offset startOffset, targetOffset;
  final String kcal, mins;
  final VoidCallback onEnd;

  const _BreathAnimationWidget({
    required this.startOffset,
    required this.targetOffset,
    required this.kcal,
    required this.mins,
    required this.onEnd,
  });

  @override
  State<_BreathAnimationWidget> createState() => _BreathAnimationWidgetState();
}

class _BreathAnimationWidgetState extends State<_BreathAnimationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale, _opacity;
  late Animation<Offset> _position;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.8,
          end: 1.5,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.5,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeInBack)),
        weight: 60,
      ),
    ]).animate(_ctrl);

    _position =
        Tween<Offset>(
          begin: widget.startOffset,
          end: widget.targetOffset,
        ).animate(
          CurvedAnimation(
            parent: _ctrl,
            curve: const Interval(0.2, 1.0, curve: Curves.easeInOutQuart),
          ),
        );

    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 70),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_ctrl);

    _ctrl.forward().then((_) => widget.onEnd());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Positioned(
          left: _position.value.dx - 80,
          top: _position.value.dy - 25,
          child: Opacity(
            opacity: _opacity.value,
            child: Transform.scale(
              scale: _scale.value,
              child: IntrinsicWidth(
                child: Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: brandBlue,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: brandBlue.withValues(alpha: 0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '${widget.kcal}千卡 | ${widget.mins}分',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        decoration: TextDecoration.none,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// ==========================================
/// 🚀 3. 打卡输入弹窗
/// ==========================================
class ExerciseInputBottomSheet extends StatefulWidget {
  final Map<String, dynamic> exercise;
  final DateTime recordDate;
  final GlobalKey targetKey; // 接收来自动画终点的坐标

  const ExerciseInputBottomSheet({
    super.key,
    required this.exercise,
    required this.recordDate,
    required this.targetKey,
  });

  @override
  State<ExerciseInputBottomSheet> createState() =>
      _ExerciseInputBottomSheetState();
}

class _ExerciseInputBottomSheetState extends State<ExerciseInputBottomSheet> {
  final TextEditingController _wCtrl = TextEditingController(text: "60");
  final TextEditingController _dCtrl = TextEditingController();
  final GlobalKey _startKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _wCtrl.addListener(() => setState(() {}));
    _dCtrl.addListener(() => setState(() {}));
  }

  int get _kcal {
    final w = double.tryParse(_wCtrl.text) ?? 60;
    final d = double.tryParse(_dCtrl.text) ?? 0;
    return (widget.exercise['met'] * w * (d / 60)).round();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
                const Text(
                  '添加运动',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.check, color: brandBlue),
                  onPressed: () async {
                    final double? duration = double.tryParse(_dCtrl.text);
                    if (duration == null || duration <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('请输入有效的运动时长哦')),
                      );
                      return;
                    }

                    int kcal =
                        (widget.exercise['met'] *
                                (double.tryParse(_wCtrl.text) ?? 60) *
                                (duration / 60))
                            .round();
                    if (kcal == 0) kcal = 1;

                    final rb =
                        _startKey.currentContext?.findRenderObject()
                            as RenderBox?;
                    final start =
                        rb?.localToGlobal(
                          Offset(rb.size.width / 2, rb.size.height / 2),
                        ) ??
                        Offset.zero;

                    final record = HealthRecord(
                      userId: context.read<AuthProvider>().userId!,
                      recordType: 'EXERCISE',
                      recordValue: _kcal.toDouble(),
                      duration: duration,
                      unit: 'kcal',
                      recordDate: widget.recordDate.toLocal().toIso8601String(),
                      notes: '${widget.exercise['name']} ${duration.toInt()}分钟',
                    );

                    await context.read<RecordProvider>().addRecord(record);
                    if (!mounted) return;

                    Navigator.pop(context);

                    // 触发解耦的动画引擎
                    BreathAnimationOverlay.run(
                      context: context,
                      targetKey: widget.targetKey,
                      startOffset: start,
                      kcal: kcal.toString(),
                      mins: duration.toInt().toString(),
                    );
                    context.read<SyncService>().syncSingleRecord(record);
                  },
                ),
              ],
            ),
            const Divider(),
            Row(
              key: _startKey,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.exercise['name'],
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${widget.exercise['met']} METs',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
                Text(
                  '消耗：$_kcal 千卡',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: brandBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _buildInput(_wCtrl, '体重(kg)')),
                const SizedBox(width: 16),
                Expanded(child: _buildInput(_dCtrl, '时长(min)', auto: true)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(TextEditingController c, String l, {bool auto = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: c,
        autofocus: auto,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        decoration: InputDecoration(labelText: l, border: InputBorder.none),
      ),
    );
  }
}
