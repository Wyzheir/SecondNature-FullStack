import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/record_provider.dart';
import '../../repositories/sync_service.dart';
import '../../models/record.dart';

// 🚀 剥离出来的独立打卡表单组件
class AddRecordForm extends StatefulWidget {
  final String initialType;
  final String? initialValue;
  const AddRecordForm({
    super.key,
    required this.initialType,
    this.initialValue,
  });

  @override
  State<AddRecordForm> createState() => _AddRecordFormState();
}

class _AddRecordFormState extends State<AddRecordForm> {
  final _formKey = GlobalKey<FormState>();
  final _valueController = TextEditingController();
  final _notesController = TextEditingController();
  late String _recordType;

  @override
  void initState() {
    super.initState();
    _recordType = widget.initialType;
    if (widget.initialValue != null) {
      _valueController.text = widget.initialValue!;
    }
  }

  @override
  void dispose() {
    _valueController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String get _typeLabel {
    switch (_recordType) {
      case 'DIET':
        return '摄入热量';
      case 'EXERCISE':
        return '运动消耗';
      case 'SLEEP':
        return '睡眠时长';
      case 'WEIGHT':
        return '当前体重';
      default:
        return '数值';
    }
  }

  String get _unitSuffix {
    switch (_recordType) {
      case 'DIET':
      case 'EXERCISE':
        return 'kcal';
      case 'SLEEP':
        return '小时';
      case 'WEIGHT':
        return 'kg';
      default:
        return '';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final recordProvider = context.read<RecordProvider>();
    final syncService = context.read<SyncService>();
    final messenger = ScaffoldMessenger.of(context);

    final userId = authProvider.userId;
    if (userId == null) return;

    final unit = (_recordType == 'DIET' || _recordType == 'EXERCISE')
        ? 'kcal'
        : (_recordType == 'WEIGHT' ? 'kg' : 'hours');

    final newRecord = HealthRecord(
      userId: userId,
      recordType: _recordType,
      recordValue: double.parse(_valueController.text),
      unit: unit,
      recordDate: DateTime.now().toLocal().toIso8601String(),
      notes: _notesController.text,
    );

    try {
      await recordProvider.addRecord(newRecord);
      if (!mounted) return;
      Navigator.pop(context);
      syncService
          .syncSingleRecord(newRecord)
          .then((_) {
            recordProvider.updateRecordSyncStatusInMemory(
              newRecord.clientMsgId,
              1,
            );
          })
          .catchError((_) {});
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('保存失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _recordType == 'WEIGHT'
                      ? '记录体重'
                      : (_recordType == 'SLEEP' ? '记录睡眠' : '添加记录'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _valueController,
              autofocus: true,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: _typeLabel,
                hintStyle: TextStyle(fontSize: 16, color: Colors.grey.shade400),
                suffixText: _unitSuffix,
                suffixStyle: const TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (v) => (v == null || v.isEmpty) ? '不能为空' : null,
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 56,
              child: FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF007BFF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  '保存记录',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
