import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/goal_provider.dart';

class HealthGoalScreen extends StatefulWidget {
  const HealthGoalScreen({super.key});

  @override
  State<HealthGoalScreen> createState() => _HealthGoalScreenState();
}

class _HealthGoalScreenState extends State<HealthGoalScreen> {
  // --- 核心架构：页面控制器 ---
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 8; // 扩充至 8 步

  // --- 👉 【核心修复 1/2】：状态提拉：将性别设置为 nullable，默认无选择 ---
  int? _gender; // 1:男, 2:女，默认 null

  // 其他数据保持契约
  int _birthYear = 2001;
  int _height = 170;
  int _weightInt = 70;
  int _weightDec = 0;
  String _goalType = 'LOSE';
  int _targetWeightInt = 65;
  int _targetWeightDec = 0;
  double _activityLevel = 1.2;

  // --- 计算属性 ---
  double get _currentWeight => _weightInt + (_weightDec / 10.0);
  double get _targetWeight => _targetWeightInt + (_targetWeightDec / 10.0);
  int get _age => DateTime.now().year - _birthYear;
  double get _calculatedBMI =>
      _currentWeight / ((_height / 100) * (_height / 100));

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // --- 核心逻辑：下一步 ---
  void _handleNext() {
    // 步骤 6 (目标设定)：如果选择保持，自动同步目标体重
    if (_currentPage == 5 && _goalType == 'MAINTAIN') {
      setState(() {
        _targetWeightInt = _weightInt;
        _targetWeightDec = _weightDec;
      });
    }

    if (_currentPage == _totalPages - 1) {
      _submit();
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // --- 核心逻辑：提交网络请求 ---
  Future<void> _submit() async {
    // 🛡️ 架构师安全检查：确保性别已选
    if (_gender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择性别'), backgroundColor: Colors.orange),
      );
      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );
      return;
    }
    try {
      final authProvider = context
          .read<AuthProvider>(); // await 之前使用 context 是安全的
      final userId = authProvider.userId;
      if (userId == null) throw '用户信息丢失';

      // 1. 发起异步操作
      await context.read<GoalProvider>().calculateAndSaveGoal(
        userId: userId,
        gender: _gender!,
        height: _height.toDouble(),
        weight: _currentWeight,
        age: _age,
        activityLevel: _activityLevel,
        targetWeight: _targetWeight,
        goalType: _goalType,
      );

      // 👉 【核心修复 1】：检查组件是否还在树上
      // 因为执行完上面那行，AuthWrapper 可能已经把本页面销毁了
      if (!mounted) return;

      // 如果程序能走到这里，说明组件还没被销毁，可以安全地操作 context
      // 但在我们的逻辑里，这里其实已经不需要写任何代码了
    } catch (e) {
      // 👉 【核心修复 2】：错误处理块也必须检查 mounted
      // 否则如果请求还没回来页面就关了，这里调用 SnackBar 也会崩
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // 拦截系统物理返回键
  // 🚀 核心修改：拦截系统物理返回键逻辑
  Future<bool> _onWillPop() async {
    if (_currentPage > 0) {
      // 如果不是第一页，返回上一页进度
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      return false; // 拦截，不退出页面
    }

    // 🚀 关键点：如果 _currentPage == 0，返回 false
    // 这样用户在第一页点击手机自带的返回键时，App 不会有任何反应，强制用户完成定制
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = context.watch<GoalProvider>().isSaving;
    const Color primaryColor = Color(0xFF007BFF);

    // 🚀 【核心修复】：用 PopScope 替换已废弃的 WillPopScope
    return PopScope(
      // 1. canPop 为 false 表示拦截系统返回键，交给下面的回调处理
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        // 如果页面已经因为某种原因 pop 了（比如代码里手动调了 Navigator.pop），直接返回
        if (didPop) return;

        // 2. 🚀 执行你原本的 _onWillPop 确认逻辑
        // 注意：这里建议将 _onWillPop() 的返回值设为 Future<bool>
        final bool shouldPop = await _onWillPop();

        // 3. 如果用户确认退出且当前页面还在树上，手动执行返回
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white, // 建议改为纯白或 grey[50]
        body: SafeArea(
          child: Column(
            children: [
              // 【1. 顶部导航栏 + 进度条组合】
              // 使用 Stack 确保进度条永远处于正中心，不受返回按钮占位的影响
              Stack(
                alignment: Alignment.center,
                children: [
                  // 放置进度条
                  _buildProgressBar(),
                ],
              ),

              // 【2. 核心 PageView】
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (idx) => setState(() => _currentPage = idx),
                  children: [
                    _buildStep1Gender(primaryColor),
                    _buildStep2BirthYear(primaryColor),
                    _buildStep3Height(primaryColor),
                    _buildStep4Weight(primaryColor),
                    _buildStep5BMI(primaryColor),
                    _buildStep6Goal(primaryColor),
                    _buildStep7TargetWeight(primaryColor),
                    _buildStep8Activity(primaryColor),
                  ],
                ),
              ),

              // 【3. 底部统一的蓝色操作按钮】
              // 只有在非第一页显示（第一页性别点击后会自动跳转）
              if (_currentPage > 0)
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: isSaving ? null : _handleNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: isSaving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : Text(
                              _currentPage == _totalPages - 1 ? '完成定制' : '下一步',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        // 🚀 核心修正：使用 _totalPages (即 8) 来生成进度条
        children: List.generate(_totalPages, (index) {
          return Expanded(
            child: Container(
              height: 6,
              // 保持 2 像素的间距，让 8 个小块在屏幕上排布得更精致
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: index <= _currentPage
                    ? const Color(0xFF006BFF) // 招牌蓝
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }),
      ),
    );
  }
  // ==================== 单页 UI 重构 ====================

  // Step 1: 性别 (👉 【核心修复 2/2】：不再有默认高亮)
  Widget _buildStep1Gender(Color primary) {
    return _WizardPageWrapper(
      title: '您的性别是？',
      child: Column(
        children: [
          const SizedBox(height: 40),
          _GenderButton(
            label: '男',
            icon: Icons.male,
            // 👉 `_gender == 1` 在初始态为 null 时结果为 false，故不大亮
            isSelected: _gender == 1,
            primaryColor: primary,
            onTap: () {
              setState(() => _gender = 1);
              _handleNext(); // 选择后自动进入下一步，体验更丝滑
            },
          ),
          const SizedBox(height: 20),
          _GenderButton(
            label: '女',
            icon: Icons.female,
            // 👉 同理不大亮
            isSelected: _gender == 2,
            primaryColor: primary,
            onTap: () {
              setState(() => _gender = 2);
              _handleNext();
            },
          ),
        ],
      ),
    );
  }

  // ------------------------- 其他页面 UI 保持不变 -------------------------

  // Step 2: 出生年份
  // Step 2: 出生年份 (修改范围)
  Widget _buildStep2BirthYear(Color primary) {
    const int minYear = 1966; // 60岁
    const int maxYear = 2014; // 12岁
    const int totalYears = maxYear - minYear + 1;

    return _WizardPageWrapper(
      title: '记录您的出生年份\n让预测更准确',
      child: _buildSinglePicker(
        primaryColor: primary,
        unit: '年',
        itemCount: totalYears,
        initialIndex: 2001 - minYear, // 默认选中 2001 年
        onSelectedItemChanged: (idx) =>
            setState(() => _birthYear = minYear + idx),
        itemBuilder: (idx) => (minYear + idx).toString(),
      ),
    );
  }

  // Step 3: 身高
  Widget _buildStep3Height(Color primary) {
    return _WizardPageWrapper(
      title: '您的身高是多少？',
      child: _buildSinglePicker(
        primaryColor: primary,
        unit: 'cm',
        itemCount: 151, // 100 - 250
        initialIndex: _height - 100,
        onSelectedItemChanged: (idx) => setState(() => _height = 100 + idx),
        itemBuilder: (idx) => (100 + idx).toString(),
      ),
    );
  }

  // Step 4: 当前体重
  Widget _buildStep4Weight(Color primary) {
    return _WizardPageWrapper(
      title: '您的体重是多少？',
      child: _buildDoublePicker(
        primaryColor: primary,
        unit: '公斤',
        intInitial: _weightInt - 30, // 30kg - 150kg
        decInitial: _weightDec,
        onIntChanged: (idx) => setState(() => _weightInt = 30 + idx),
        onDecChanged: (idx) => setState(() => _weightDec = idx),
      ),
    );
  }

  // Step 5】：独立的 BMI 计算结果页
  Widget _buildStep5BMI(Color primary) {
    return _WizardPageWrapper(
      title: '您的身体质量指数\n(BMI)',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primary.withValues(alpha: 0.05),
              border: Border.all(
                color: primary.withValues(alpha: 0.2),
                width: 8,
              ),
            ),
            child: Text(
              _calculatedBMI.toStringAsFixed(1),
              style: TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.w900,
                color: primary,
              ),
            ),
          ),
          const SizedBox(height: 40),
          Text(
            _getBMIDescription(_calculatedBMI),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '根据您的身高 ${_height}cm 与体重 ${_currentWeight}kg 计算得出',
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  String _getBMIDescription(double bmi) {
    if (bmi < 18.5) return '体重过轻，需要增加营养哦';
    if (bmi < 24) return '非常标准，请继续保持！';
    if (bmi < 28) return '体重超标，该开始运动啦';
    return '肥胖预警，请注意健康饮食';
  }

  // Step 6: 核心目标
  Widget _buildStep6Goal(Color primary) {
    return _WizardPageWrapper(
      title: '您的健康目标是？',
      child: Column(
        children: [
          const SizedBox(height: 20),
          _SelectionCard(
            title: '减脂 (Lose)',
            desc: '制造热量缺口，降低体脂',
            isSelected: _goalType == 'LOSE',
            primary: primary,
            onTap: () => setState(() => _goalType = 'LOSE'),
          ),
          const SizedBox(height: 16),
          _SelectionCard(
            title: '保持 (Maintain)',
            desc: '热量收支平衡，维持体型',
            isSelected: _goalType == 'MAINTAIN',
            primary: primary,
            onTap: () => setState(() => _goalType = 'MAINTAIN'),
          ),
          const SizedBox(height: 16),
          _SelectionCard(
            title: '增肌 (Gain)',
            desc: '创造热量盈余，增加肌肉',
            isSelected: _goalType == 'GAIN',
            primary: primary,
            onTap: () => setState(() => _goalType = 'GAIN'),
          ),
        ],
      ),
    );
  }

  // Step 7: 目标体重
  Widget _buildStep7TargetWeight(Color primary) {
    if (_goalType == 'MAINTAIN') {
      return _WizardPageWrapper(
        title: '设定目标体重',
        child: Column(
          children: [
            const SizedBox(height: 60),
            const Icon(Icons.check_circle, size: 80, color: Colors.green),
            const SizedBox(height: 20),
            Text(
              '系统已自动将目标体重锁定为 ${_currentWeight}kg',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }
    return _WizardPageWrapper(
      title: '设定目标体重',
      child: _buildDoublePicker(
        primaryColor: primary,
        unit: '公斤',
        intInitial: _targetWeightInt - 30,
        decInitial: _targetWeightDec,
        onIntChanged: (idx) => setState(() => _targetWeightInt = 30 + idx),
        onDecChanged: (idx) => setState(() => _targetWeightDec = idx),
      ),
    );
  }

  // Step 8: 活动强度
  Widget _buildStep8Activity(Color primary) {
    return _WizardPageWrapper(
      title: '日常活动强度',
      child: Column(
        children: [
          _SelectionCard(
            title: '久坐不动',
            desc: '办公室工作，几乎不运动',
            isSelected: _activityLevel == 1.2,
            primary: primary,
            onTap: () => setState(() => _activityLevel = 1.2),
          ),
          const SizedBox(height: 12),
          _SelectionCard(
            title: '轻度活动',
            desc: '偶尔散步，少量家务',
            isSelected: _activityLevel == 1.375,
            primary: primary,
            onTap: () => setState(() => _activityLevel = 1.375),
          ),
          const SizedBox(height: 12),
          _SelectionCard(
            title: '中度活动',
            desc: '规律运动 (每周3-5天)',
            isSelected: _activityLevel == 1.55,
            primary: primary,
            onTap: () => setState(() => _activityLevel = 1.55),
          ),
          const SizedBox(height: 12),
          _SelectionCard(
            title: '高度/极度活跃',
            desc: '高强度运动或重体力劳动',
            isSelected: _activityLevel >= 1.725,
            primary: primary,
            onTap: () => setState(() => _activityLevel = 1.725),
          ),
        ],
      ),
    );
  }

  // ==================== UI 核心组件封装 (不变) ====================

  // 构建单列滚轮 (用于年份、身高)
  Widget _buildSinglePicker({
    required Color primaryColor,
    required String unit,
    required int itemCount,
    required int initialIndex,
    required ValueChanged<int> onSelectedItemChanged,
    required String Function(int) itemBuilder,
  }) {
    return SizedBox(
      height: 300,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CupertinoPicker(
            scrollController: FixedExtentScrollController(
              initialItem: initialIndex,
            ),
            itemExtent: 64,
            selectionOverlay: Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onSelectedItemChanged: onSelectedItemChanged,
            children: List.generate(itemCount, (idx) {
              return Center(
                child: Text(
                  itemBuilder(idx),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey, // 简化实现，这里不再根据选中态变色
                  ),
                ),
              );
            }),
          ),
          Positioned(
            right: 60,
            child: Text(
              unit,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 构建双列联动滚轮 (用于体重)
  Widget _buildDoublePicker({
    required Color primaryColor,
    required String unit,
    required int intInitial,
    required int decInitial,
    required ValueChanged<int> onIntChanged,
    required ValueChanged<int> onDecChanged,
  }) {
    return SizedBox(
      height: 300,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 统一的背景高亮框
          Container(
            height: 64,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 整数部分
              SizedBox(
                width: 100,
                child: CupertinoPicker(
                  scrollController: FixedExtentScrollController(
                    initialItem: intInitial,
                  ),
                  itemExtent: 64,
                  selectionOverlay: const SizedBox.shrink(),
                  onSelectedItemChanged: onIntChanged,
                  children: List.generate(
                    121,
                    (idx) => Center(
                      child: Text(
                        '${30 + idx}',
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Roboto',
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const Text(
                '.',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              // 小数部分
              SizedBox(
                width: 80,
                child: CupertinoPicker(
                  scrollController: FixedExtentScrollController(
                    initialItem: decInitial,
                  ),
                  itemExtent: 64,
                  selectionOverlay: const SizedBox.shrink(),
                  onSelectedItemChanged: onDecChanged,
                  children: List.generate(
                    10,
                    (idx) => Center(
                      child: Text(
                        '$idx',
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Roboto',
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                unit,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// 统一标题包装器 (已修复溢出问题)
class _WizardPageWrapper extends StatelessWidget {
  final String title;
  final Widget child;
  const _WizardPageWrapper({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    // 👉 核心修复：加入 SingleChildScrollView 允许内容超长时垂直滚动
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(), // 加上苹果风格的越界回弹效果，手感更好
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24), // 底部加一点 padding 避免贴底
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 60),
          child,
        ],
      ),
    );
  }
}

// 提取的性别选择按钮组件
class _GenderButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color primaryColor;
  final VoidCallback onTap;

  const _GenderButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 80,
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(40), // 胶囊形状
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey.shade600,
              size: 28,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 通用选择卡片
class _SelectionCard extends StatelessWidget {
  final String title;
  final String desc;
  final bool isSelected;
  final Color primary;
  final VoidCallback onTap;

  const _SelectionCard({
    required this.title,
    required this.desc,
    required this.isSelected,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? primary : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
          color: isSelected ? primary.withValues(alpha: 0.05) : Colors.white,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? primary : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: primary),
          ],
        ),
      ),
    );
  }
}
