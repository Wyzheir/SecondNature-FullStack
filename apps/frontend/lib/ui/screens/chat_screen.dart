import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';

import '../../providers/assistant_provider.dart';
import '../../providers/goal_provider.dart';
import '../../providers/record_provider.dart';
import '../widgets/interactive_card.dart';

final GlobalKey<ScaffoldState> chatScaffoldKey = GlobalKey<ScaffoldState>();
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // 缓存抽屉 Widget，避免每次 build 都重建分组
  Widget? _cachedDrawerWidget;
  List<ChatSession>? _lastSessions;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final assistant = context.read<AssistantProvider>();
      await assistant.loadSessions();
      if (assistant.currentSessionId == null && assistant.sessions.isNotEmpty) {
        assistant.switchSession(assistant.sessions.first.sessionId);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ==========================================
  //  🚀 核心优化：使用 context.select 细粒度监听
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final currentTitle = context.select<AssistantProvider, String>((p) {
      if (p.currentSessionId != null && p.sessions.isNotEmpty) {
        final session = p.sessions.firstWhere(
          (s) => s.sessionId == p.currentSessionId,
          orElse: () => ChatSession(sessionId: '', title: '新话题'),
        );
        return session.title;
      }
      return '新话题';
    });

    final sessions = context.select<AssistantProvider, List<ChatSession>>(
      (p) => p.sessions,
    );
    final currentSessionId = context.select<AssistantProvider, String?>(
      (p) => p.currentSessionId,
    );

    final messages = context.select<AssistantProvider, List<ChatMessage>>(
      (p) => p.messages,
    );
    final isAwaitingFirstToken = context.select<AssistantProvider, bool>(
      (p) => p.isAwaitingFirstToken,
    );
    final isTyping = context.select<AssistantProvider, bool>((p) => p.isTyping);
    final isLoadingHistory = context.select<AssistantProvider, bool>(
      (p) => p.isLoadingHistory,
    );

    // 惰性重建抽屉：仅当 sessions 列表引用变化时才重新计算
    if (_cachedDrawerWidget == null || _lastSessions != sessions) {
      _lastSessions = sessions;
      // 传入 assistant 实例供内部回调使用（通过 context.read 获取，不触发重建）
      _cachedDrawerWidget = _buildDrawer(
        sessions,
        currentSessionId,
        context.read<AssistantProvider>(),
      );
    }

    final goalP = context.read<GoalProvider>();
    final recordP = context.read<RecordProvider>();
    final assistant = context.read<AssistantProvider>();

    return Scaffold(
      // 🚀 UI 规范 4: 统一使用品牌背景色，顶部主体完全一致
      backgroundColor: const Color(0xFFF5F6F9),
      // 🚀 核心修复 2：滑动拉出抽屉时，同样执行全局强杀焦点
      onDrawerChanged: (isOpened) {
        if (isOpened) {
          FocusManager.instance.primaryFocus?.unfocus();
        }
      },
      appBar: AppBar(
        // 🚀 核心修复 1：接管默认的抽屉按钮，手动阻断焦点与动画的冲突
        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                // 🔪 物理级斩断全局焦点，强制键盘立刻收回
                FocusManager.instance.primaryFocus?.unfocus();


                // 稍微给一小会的时间让键盘开始下降，再弹出抽屉，保证系统焦点树不乱
                Future.delayed(const Duration(milliseconds: 50), () {
                  // 🚀 核心修改 2：安全调用，直接用钥匙开门，避免 context 查找失败
                  chatScaffoldKey.currentState?.openDrawer();
                  if (context.mounted) {
                    Scaffold.of(context).openDrawer();
                  }
                });
              },
            );
          },
        ),
        title: Text(
          currentTitle,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0, // 突破 M3 限制：防止滚动时 AppBar 变色
        // 🚀 顶部背景与主体完全一致
        backgroundColor: const Color(0xFFF5F6F9),
        foregroundColor: Colors.black87,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: InkWell(
                onTap: () => assistant.prepareNewSession(),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F6F9), // 按钮底色融为一体
                    // 🚀 移除黑色边框轮廓：确保彩色图标美观
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SvgPicture.asset(
                      // 下游盲视必须定位并加载用户上传的 image_0.png 路径
                      'assets/icons/logo.svg',
                      // 🚀 严格控制大小
                      width: 35, // 强可读性尺寸
                      height: 35,
                      fit: BoxFit.contain, // 确保完全显示
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      drawer: _cachedDrawerWidget,
      body: _buildBody(
        isLoadingHistory: isLoadingHistory,
        isAwaitingFirstToken: isAwaitingFirstToken,
        isTyping: isTyping,
        messages: messages,
        currentSessionId: currentSessionId,
        goalP: goalP,
        recordP: recordP,
        assistant: assistant,
      ),
    );
  }

  // ==========================================
  //  📂 抽屉构建（解耦为纯函数，仅依赖传入数据）
  // ==========================================
  Widget _buildDrawer(
    List<ChatSession> sessions,
    String? currentSessionId,
    AssistantProvider assistant,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final Map<String, List<ChatSession>> groups = {
      '今天': [],
      '昨天': [],
      '7天内': [],
      '30天内': [],
      '更早': [],
    };

    for (var s in sessions) {
      if (s.updatedAt == null) {
        groups['更早']!.add(s);
        continue;
      }
      final date = DateTime(
        s.updatedAt!.year,
        s.updatedAt!.month,
        s.updatedAt!.day,
      );
      final diff = today.difference(date).inDays;

      if (diff == 0) {
        groups['今天']!.add(s);
      } else if (diff == 1) {
        groups['昨天']!.add(s);
      } else if (diff <= 7) {
        groups['7天内']!.add(s);
      } else if (diff <= 30) {
        groups['30天内']!.add(s);
      } else {
        groups['更早']!.add(s);
      }
    }

    List<Widget> listItems = [
      const Padding(
        padding: EdgeInsets.fromLTRB(24, 60, 24, 16),
        child: Text(
          '历史记录',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Colors.black87,
          ),
        ),
      ),
    ];

    groups.forEach((key, list) {
      if (list.isNotEmpty) {
        listItems.add(
          Padding(
            padding: const EdgeInsets.only(left: 24, top: 20, bottom: 8),
            child: Text(
              key,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade400,
              ),
            ),
          ),
        );
        for (var session in list) {
          final isSelected = session.sessionId == currentSessionId;
          listItems.add(
            Padding(
              // 依然保留外层间距，不破坏 UI 布局
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              
              // 🚀 核心战果 1：彻底抛弃 Container 和自定义 Card，回归原生大道！
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                
                // 🚀 核心战果 2：使用原生的 tileColor！底层会自动调度 Ink 绘制，绝不遮挡水波纹！
                tileColor: isSelected ? const Color(0xFFF0F4F9) : null,
                
                title: Text(
                  session.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? const Color(0xFF041E49) : Colors.black87,
                  ),
                ),
                
                onTap: () {
                  // 1. 核心修复：手动强行关闭抽屉
                    Navigator.of(context).pop(); 
  
                    // 2. 强杀全局焦点，防止键盘交互冲突
                    FocusManager.instance.primaryFocus?.unfocus();
  
                    // 3. 执行业务跳转或状态切换
                    assistant.switchSession(session.sessionId);
                },
                
                trailing: isSelected
                    ? IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                        onPressed: () => _showDeleteConfirm(
                          context,
                          assistant,
                          session.sessionId,
                        ),
                      )
                    : null,
              ),
            ),
          );
        }
      }
    });

    return Drawer(
      backgroundColor: Colors.white,
      elevation: 0,
      child: ListView(
        padding: EdgeInsets.zero,
        physics: const BouncingScrollPhysics(),
        children: listItems,
      ),
    );
  }

  // ==========================================
  //  💬 聊天主体
  // ==========================================
  Widget _buildBody({
    required bool isLoadingHistory,
    required bool isAwaitingFirstToken,
    required bool isTyping,
    required List<ChatMessage> messages,
    required String? currentSessionId,
    required GoalProvider goalP,
    required RecordProvider recordP,
    required AssistantProvider assistant,
  }) {
    return Column(
      children: [
        Expanded(
          child: (isLoadingHistory && messages.isEmpty)
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF007BFF)),
                )
              : (currentSessionId == null || messages.isEmpty)
              ? _buildWelcomeState()
              : ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[messages.length - 1 - index];
                    final isLast = index == 0;
                    // 首 token 等待指示器
                    if (isLast &&
                        isAwaitingFirstToken &&
                        !msg.isUser &&
                        msg.content.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12.0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.only(left: 16),
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Color(0xFF007BFF),
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                    return _buildChatBubble(msg);
                  },
                ),
        ),
        _buildInputArea(
          assistant: assistant,
          gP: goalP,
          rP: recordP,
          isTyping: isTyping,
          isAwaitingFirstToken: isAwaitingFirstToken,
        ),
      ],
    );
  }

  // ==========================================
  //  🎨 欢迎状态 & 聊天气泡
  // ==========================================
  Widget _buildWelcomeState() {
    return Center(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF007BFF).withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 56,
                color: Color(0xFF007BFF),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              "您好！我是 Sena,",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "今天想练点什么，或者有什么健康疑惑？",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatBubble(ChatMessage msg) {
    final isUser = msg.isUser;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              constraints: BoxConstraints(),
              padding: isUser
                  ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
                  : const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 8,
                    ), // 调整 AI 内边距
              decoration: isUser
                  ? const BoxDecoration(
                      color: Color(0xFFE8F3FF),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(4),
                      ),
                    )
                  : BoxDecoration(borderRadius: BorderRadius.circular(16)),
              child: isUser
                  ? Text(
                      msg.content,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                        height: 1.4,
                      ),
                    )
                  : MarkdownBody(
                      data: msg.content,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(
                          color: Colors.black87,
                          fontSize: 16,
                          height: 1.7,
                        ),
                        strong: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                        ),
                        listBullet: const TextStyle(
                          color: Color(0xFF007BFF),
                          fontSize: 16,
                        ),
                        blockquoteDecoration: BoxDecoration(
                          color: const Color(0xFF007BFF).withOpacity(0.05),
                          border: const Border(
                            left: BorderSide(
                              color: Color(0xFF007BFF),
                              width: 4,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  //  ⌨️ 输入区域（含动态暂停按钮）
  // ==========================================
  Widget _buildInputArea({
    required AssistantProvider assistant,
    required GoalProvider gP,
    required RecordProvider rP,
    required bool isTyping,
    required bool isAwaitingFirstToken,
  }) {
    final bool hasText = _controller.text.trim().isNotEmpty;
    final bool isGenerating = isTyping || isAwaitingFirstToken;

    return Container(
      color: const Color(0xFFF0F4F9), // 🚀 调换后：外部底座背景改为浅灰色
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white, // 🚀 调换后：聊天框输入区域改为纯白色
          borderRadius: BorderRadius.circular(28),
        ),
        padding: const EdgeInsets.only(left: 20, right: 8, top: 4, bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: 6,
                minLines: 1,
                style: const TextStyle(fontSize: 16),
                decoration: const InputDecoration(
                  hintText: "给Sena发送消息",
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 16),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
                onSubmitted: (_) =>
                    hasText ? _handleSend(assistant, gP, rP) : null,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 8),
              child: isGenerating
                  ? IconButton(
                      onPressed: () => assistant.stopGeneration(),
                      icon: const Icon(
                        Icons.stop,
                        color: Color(0xFF007BFF),
                        size: 24,
                      ),
                      tooltip: '暂停生成',
                    )
                  : IconButton(
                      onPressed: hasText
                          ? () => _handleSend(assistant, gP, rP)
                          : null,
                      icon: Icon(
                        Icons.send_rounded,
                        color: hasText
                            ? const Color(0xFF007BFF)
                            : Colors.grey.shade400,
                        size: 24,
                      ),
                      tooltip: '发送',
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSend(
    AssistantProvider assistant,
    GoalProvider gP,
    RecordProvider rP,
  ) {
    if (_controller.text.isEmpty) return;
    final text = _controller.text;
    _controller.clear();
    assistant.sendChatMessage(
      userText: text,
      goalProvider: gP,
      recordProvider: rP,
    );
    _scrollToBottom();
  }

  void _showDeleteConfirm(
    BuildContext context,
    AssistantProvider assistant,
    String sessionId,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "删除记录",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text("确定要永久删除这篇对话吗？"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("取消", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              assistant.deleteSession(sessionId);
              Navigator.pop(ctx);
            },
            child: const Text(
              "删除",
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
