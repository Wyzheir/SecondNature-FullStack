import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hel_app/providers/goal_provider.dart';
import 'package:hel_app/providers/record_provider.dart';
import '../core/network/dio_client.dart';

// --- 数据模型 ---
class ChatMessage {
  final String content;
  final bool isUser;
  ChatMessage({required this.content, required this.isUser});

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      content: json['content'] ?? '',
      isUser: json['is_user'] == true || json['is_user'] == 1,
    );
  }
}

class ChatSession {
  final String sessionId;
  final String title;
  final DateTime? updatedAt;

  ChatSession({required this.sessionId, required this.title, this.updatedAt});

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      sessionId: json['session_id'] ?? '',
      title: json['title'] ?? '新对话',
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'])?.toLocal()
          : null,
    );
  }
}

// --- 状态机 ---
class AssistantProvider extends ChangeNotifier {
  final DioClient _dioClient;
  bool _isAwaitingFirstToken = false;
  bool get isAwaitingFirstToken => _isAwaitingFirstToken;

  List<ChatMessage> _messages = [];
  bool _isTyping = false;
  bool _isLoadingHistory = false;
  CancelToken? _chatCancelToken;

  List<ChatSession> _sessions = [];
  String? _currentSessionId;
  bool _isLoadingSessions = false;

  List<ChatMessage> get messages => _messages;
  bool get isTyping => _isTyping;
  bool get isLoadingHistory => _isLoadingHistory;

  List<ChatSession> get sessions => _sessions;
  String? get currentSessionId => _currentSessionId;
  bool get isLoadingSessions => _isLoadingSessions;

  AssistantProvider(this._dioClient);

  void forceKillConnection({String reason = 'manual'}) {
    if (_chatCancelToken != null && !_chatCancelToken!.isCancelled) {
      _chatCancelToken!.cancel(reason);
      _chatCancelToken = null;
    }
    _isTyping = false;
    _isAwaitingFirstToken = false;
    notifyListeners();
  }

  void clearAllData() {
    forceKillConnection();
    _messages = [];
    _currentSessionId = null;
    _sessions = [];
    _isLoadingHistory = false;
    _isLoadingSessions = false;
    _isTyping = false;
    _isAwaitingFirstToken = false;
    notifyListeners();
  }

  Future<void> loadSessions() async {
    _isLoadingSessions = true;
    notifyListeners();
    try {
      final response = await _dioClient.dio.get('/assistant/sessions');
      if (response.data['code'] == 200) {
        final List<dynamic> dataList = response.data['data'] ?? [];
        _sessions = dataList.map((e) => ChatSession.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint("拉取话题列表失败: $e");
    } finally {
      _isLoadingSessions = false;
      notifyListeners();
    }
  }

  void prepareNewSession() {
    forceKillConnection(reason: 'new_session');
    _currentSessionId = null;
    _messages = [];
    _isAwaitingFirstToken = false;
    notifyListeners();
  }

  Future<void> switchSession(String sessionId) async {
    forceKillConnection(reason: 'switch_session');
    _currentSessionId = sessionId;
    _messages = [];
    _isAwaitingFirstToken = false;
    notifyListeners();
    await _loadCloudHistory(sessionId);
  }

  Future<void> deleteSession(String sessionId) async {
    final bool isCurrentSession = (_currentSessionId == sessionId);
    final List<ChatMessage>? snapshotMessages = isCurrentSession
        ? List.from(_messages)
        : null;

    if (isCurrentSession) {
      forceKillConnection(reason: 'delete_session');
      _currentSessionId = null;
      _messages = [];
      notifyListeners();
    }

    try {
      await _dioClient.dio.delete('/assistant/sessions/$sessionId');
      await loadSessions();
    } catch (e) {
      debugPrint("❌ 删除话题失败: $e");
      if (isCurrentSession && snapshotMessages != null) {
        _currentSessionId = sessionId;
        _messages = snapshotMessages;
        notifyListeners();
      }
      await loadSessions();
    }
  }

  Future<void> _loadCloudHistory(String sessionId) async {
    _isLoadingHistory = true;
    notifyListeners();
    try {
      final response = await _dioClient.dio.get(
        '/assistant/history',
        queryParameters: {'session_id': sessionId},
      );
      if (response.data['code'] == 200) {
        final List<dynamic> dataList = response.data['data'] ?? [];
        _messages = dataList.map((e) => ChatMessage.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint("拉取云端聊天记录失败: $e");
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
    }
  }

  Future<void> sendChatMessage({
    required String userText,
    required GoalProvider goalProvider,
    required RecordProvider recordProvider,
  }) async {
    if (userText.trim().isEmpty) return;

    forceKillConnection(reason: 'new_message');
    // ==========================================
    // 懒加载建群逻辑
    // ==========================================
    if (_currentSessionId == null) {
      _isTyping = true;
      notifyListeners();
      try {
        final response = await _dioClient.dio.post('/assistant/sessions');
        if (response.data['code'] == 200) {
          _currentSessionId = response.data['session_id'];
        } else {
          _isTyping = false;
          notifyListeners();
          return;
        }
      } catch (e) {
        debugPrint("静默创建话题失败: $e");
        _isTyping = false;
        notifyListeners();
        return;
      }
    }

    _messages.add(ChatMessage(content: userText, isUser: true));
    _messages.add(ChatMessage(content: "", isUser: false));
    _isTyping = true;
    _isAwaitingFirstToken = true;
    notifyListeners();

    final bool isFirstMessage = _messages.length == 2;
    final String? shotSessionId = _currentSessionId;

    if (isFirstMessage && shotSessionId != null) {
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (_currentSessionId == shotSessionId) {
          loadSessions();
        }
      });
    }

    final aiDio = Dio(
      BaseOptions(
        baseUrl: _dioClient.dio.options.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 120),
        // 明确指定响应类型为流，避免被覆盖
        responseType: ResponseType.stream,
      ),
    );
    aiDio.interceptors.addAll(_dioClient.dio.interceptors);
    _chatCancelToken = CancelToken();

    try {
      final goal = goalProvider.goal;
      final today = recordProvider.getTodayCompleteStatus(
        goal?.targetKcal ?? 2000.0,
      );
      final todayDietItems = recordProvider.getTodayDietItems();
      debugPrint('🍽️ 发送饮食明细: ${todayDietItems.length} 条');

      final response = await aiDio.post(
        '/assistant/chat',
        data: {
          "session_id": _currentSessionId,
          "message": userText,
          "context": {
            "target_kcal": goal?.targetKcal ?? 2000.0,
            "current_weight": goal?.weight ?? 60.0,
            "recent_diet_kcal": today['intake'],
            "recent_burn_kcal": today['burn'],
            "today_diet_items": todayDietItems,
            "today_exercise_items": recordProvider
                .getTodayExerciseItems(), // 新增
            "today_sleep_hours": recordProvider.todaySleepDuration, // 新增
          },
        },
        cancelToken: _chatCancelToken,
        options: Options(
          responseType: ResponseType.stream,
          headers: {'Accept': 'text/event-stream'},
        ),
      );

      debugPrint('📡 响应状态: ${response.statusCode}');
      debugPrint('📡 Content-Type: ${response.headers.value('content-type')}');

      String fullReply = "";
      final stream = response.data.stream
          .cast<List<int>>()
          .transform(utf8.decoder)
          .timeout(const Duration(seconds: 30));

      bool firstTokenReceived = false;
      int chunkCount = 0;

      await for (final chunk in stream) {
        chunkCount++;
        debugPrint('📦 第 $chunkCount 次收到原始流数据 (长度: ${chunk.length})');
        final lines = chunk.split('\n');
        for (var line in lines) {
          if (line.startsWith('data: ') && !line.contains('[DONE]')) {
            final jsonStr = line.substring(6);
            try {
              final Map<String, dynamic> data = jsonDecode(jsonStr);
              final newChunk = data['chunk'] ?? "";
              if (newChunk.isNotEmpty) {
                debugPrint(
                  '📨 解析出 chunk: ${newChunk.substring(0, newChunk.length.clamp(0, 30))}',
                );
                fullReply += newChunk;

                if (!firstTokenReceived) {
                  firstTokenReceived = true;
                  _isAwaitingFirstToken = false;
                  debugPrint('✅ 首 token 到达，切换 UI 状态');
                }

                _messages = List<ChatMessage>.from(_messages)
                  ..removeLast()
                  ..add(ChatMessage(content: fullReply, isUser: false));
                notifyListeners();
              }
            } catch (e) {
              debugPrint('⚠️ JSON 解析失败: $e');
            }
          }
        }
      }
      debugPrint('🏁 流式传输结束，共收到 $chunkCount 个流块');
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        final reason = e.message ?? 'unknown';
        debugPrint("🛑 [AI 流] 请求已被用户取消，原因: $reason");
      } else {
        debugPrint("❌ AI 连接断开: $e");
        if (_currentSessionId == shotSessionId && _messages.isNotEmpty) {
          _messages[_messages.length - 1] = ChatMessage(
            content: "网络连接已断开，请检查后重试。",
            isUser: false,
          );
          notifyListeners();
        }
      }
    } finally {
      _isAwaitingFirstToken = false;
      aiDio.close(force: true);
      _isTyping = false;
      notifyListeners();
    }
  }

  Future<void> stopGeneration() async {
    forceKillConnection(reason: 'user_stop');
    await Future.delayed(Duration.zero);
    _isAwaitingFirstToken = false;
    notifyListeners();
  }

  bool get isGenerating => _isTyping || _isAwaitingFirstToken;
}
