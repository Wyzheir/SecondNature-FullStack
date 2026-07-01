import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/record_provider.dart';
import '../../providers/food_dict_provider.dart';
import '../../models/record.dart';

class FoodSearchScreen extends StatefulWidget {
  final String mealType; // 必传：属于哪一顿饭 (如 BREAKFAST)
  final DateTime targetDate; // 🚀 新增：接收要打卡的真实日期

  const FoodSearchScreen({
    super.key,
    required this.mealType,
    required this.targetDate, // 👈 加入构造函数
  });

  @override
  State<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends State<FoodSearchScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 页面加载完毕后，自动执行空搜索获取“最近添加”列表
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FoodDictProvider>().search('');
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // 调起打卡弹窗
  void _openInputBottomSheet(Map<String, dynamic> foodInfo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FoodInputBottomSheet(
        mealType: widget.mealType,
        foodInfo: foodInfo,
        targetDate: widget.targetDate, // 👈 核心修复：把从 LogScreen 传过来的日期继续往下传！
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🚀 核心修复：在 build 方法的最顶层监听 Provider
    // 这样下面的所有 UI 组件（包括搜索框、排序按钮、列表）都能直接访问 'provider' 变量
    final provider = context.watch<FoodDictProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 1. 顶部搜索栏与返回区
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Container(
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        autofocus: false,
                        textInputAction: TextInputAction.search,
                        textAlignVertical: TextAlignVertical.center,
                        onChanged: (val) =>
                            provider.search(val), // 👈 直接使用 provider
                        decoration: const InputDecoration(
                          isCollapsed: true,
                          hintText: '请输入想要搜索的食物',
                          hintStyle: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: Colors.blueAccent,
                            size: 20,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    '搜索',
                    style: TextStyle(color: Colors.grey, fontSize: 15),
                  ),
                ],
              ),
            ),

            // 2. 分类 Tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _buildTab('全部食物', isActive: true),
                  const SizedBox(width: 24),
                  _buildTab('我的食物'),
                  const SizedBox(width: 24),
                  _buildTab('我的餐食/食谱'),
                ],
              ),
            ),

            Container(height: 8, color: const Color(0xFFF7F8FA)),

            // 3. 结果列表标题与排序控制
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _searchCtrl.text.isEmpty ? '最近添加' : '搜索结果',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_searchCtrl.text.isEmpty)
                    InkWell(
                      onTap: () =>
                          provider.toggleSortStrategy(), // 👈 不再报错，安全调用
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Row(
                          children: [
                            Text(
                              provider.sortByCount ? '次数 ' : '最新 ',
                              style: const TextStyle(
                                color: Colors.blue,
                                fontSize: 13,
                              ),
                            ),
                            const Icon(
                              Icons.swap_vert,
                              color: Colors.blue,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // 4. 瀑布流结果 (去掉了 Consumer 嵌套，直接读取 provider)
            Expanded(
              child: provider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : provider.searchResults.isEmpty
                  ? Center(
                      // 🚀 核心优化：根据搜索框是否为空，展示不同的文案
                      child: Text(
                        _searchCtrl.text.isEmpty
                            ? '暂无最近添加记录'
                            : '没有找到相关食物，试试换个关键词',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.separated(
                      itemCount: provider.searchResults.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, indent: 20),
                      itemBuilder: (context, index) {
                        final item = provider.searchResults[index];
                        final double kcal = (item['default_kcal'] as num)
                            .toDouble();
                        final String foodName = item['food_name'];

                        return InkWell(
                          onTap: () => _openInputBottomSheet(item),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          foodName,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Icon(
                                          Icons.verified,
                                          color: Colors.green,
                                          size: 14,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${kcal.toInt()}千卡/100克',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.add_circle,
                                    color: Colors.blueAccent,
                                    size: 28,
                                  ),
                                  onPressed: () => _openInputBottomSheet(item),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // 快捷构建 Tab
  Widget _buildTab(String title, {bool isActive = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? Colors.black87 : Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        if (isActive)
          Container(
            width: 24,
            height: 3,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(2),
            ),
          )
        else
          const SizedBox(height: 3),
      ],
    );
  }
}

/// ==========================================
/// 🚀 输入重量并结算入库的 BottomSheet
/// ==========================================
class _FoodInputBottomSheet extends StatefulWidget {
  final String mealType;
  final Map<String, dynamic> foodInfo;
  final DateTime targetDate; // 🚀 新增

  const _FoodInputBottomSheet({
    required this.mealType,
    required this.foodInfo,
    required this.targetDate, // 👈 记得接收
  });

  @override
  State<_FoodInputBottomSheet> createState() => _FoodInputBottomSheetState();
}

class _FoodInputBottomSheetState extends State<_FoodInputBottomSheet> {
  final TextEditingController _gCtrl = TextEditingController(text: "100");

  @override
  void initState() {
    super.initState();
    _gCtrl.addListener(() => setState(() {}));
  }

  // ⚖️ 核心计算属性：严格按 100g 比例缩放
  double get _userInputWeight => double.tryParse(_gCtrl.text) ?? 0.0;
  double get _scale => _userInputWeight / 100.0; // 缩放系数

  double get _totalKcal =>
      ((widget.foodInfo['default_kcal'] as num).toDouble()) * _scale;
  double get _totalCarbs =>
      ((widget.foodInfo['default_carbs'] ?? 0) as num).toDouble() * _scale;
  double get _totalProtein =>
      ((widget.foodInfo['default_protein'] ?? 0) as num).toDouble() * _scale;
  double get _totalFat =>
      ((widget.foodInfo['default_fat'] ?? 0) as num).toDouble() * _scale;

  Future<void> _submit() async {
    if (_userInputWeight <= 0) return;

    final userId = context.read<AuthProvider>().userId;
    if (userId == null) return;

    // 1. 组装 Record 实体，打入 SQLite
    final record = HealthRecord(
      userId: userId,
      recordType: 'DIET',
      mealType: widget.mealType,
      foodName: widget.foodInfo['food_name'],
      recordValue: _totalKcal,
      carbsG: _totalCarbs,
      proteinG: _totalProtein,
      fatG: _totalFat,
      unit: 'kcal',
      // 🚀 核心修复：使用透传过来的真实日期，而不是死板的 DateTime.now()
      recordDate: widget.targetDate.toLocal().toIso8601String(),
      notes: '${widget.foodInfo['food_name']} ${_userInputWeight.toInt()}g',
    );

    await context.read<RecordProvider>().addRecord(record);

    // 2. 记忆进化：让该食物在词库中频次 +1，排到最前
    if (mounted) {
      context.read<FoodDictProvider>().recordUsage(widget.foodInfo);
      Navigator.pop(context); // 关弹窗
      Navigator.pop(context); // 关搜索页，回到日志大屏
    }
  }

  @override
  Widget build(BuildContext context) {
    final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
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
                  '添加食物',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.check, color: Colors.blueAccent),
                  onPressed: _submit,
                ),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.foodInfo['food_name'],
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '碳水 ${_totalCarbs.toStringAsFixed(1)}g | 蛋白 ${_totalProtein.toStringAsFixed(1)}g | 脂肪 ${_totalFat.toStringAsFixed(1)}g',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${_totalKcal.toInt()}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.blueAccent,
                      ),
                    ),
                    const Text(
                      '千卡',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6F8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _gCtrl,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                decoration: const InputDecoration(
                  labelText: '重量 (克)',
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
