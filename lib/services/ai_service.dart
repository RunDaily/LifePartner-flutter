import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'ai_debug_log_service.dart';

class ChatMessage {
  final String role;
  final String content;
  final DateTime createdAt;
  const ChatMessage({required this.role, required this.content, required this.createdAt});
}

class AiDebugTokenInfo {
  final DateTime startTime;
  final int systemPromptTokens;
  final int historyTokens;
  final int userQuestionTokens;
  final int totalInputTokens;
  final int maxOutputTokens;
  final String diaryContextMode;
  final int injectedMomentCount;
  final int totalMomentCount;
  final int maxHistoryMessages;
  int outputTokens;
  double tokensPerSecond;
  bool isCompleted;
  DateTime? endTime;
  int? apiPromptTokens;
  int? apiCompletionTokens;
  int? apiTotalTokens;
  String responseContent;
  final String systemPromptContent;
  final String userQuestion;

  AiDebugTokenInfo({required this.startTime, required this.systemPromptTokens, required this.historyTokens, required this.userQuestionTokens, required this.totalInputTokens, required this.maxOutputTokens, this.diaryContextMode = 'general', this.injectedMomentCount = 0, this.totalMomentCount = 0, required this.maxHistoryMessages, this.outputTokens = 0, this.tokensPerSecond = 0, this.isCompleted = false, this.endTime, this.apiPromptTokens, this.apiCompletionTokens, this.apiTotalTokens, this.responseContent = '', this.systemPromptContent = '', this.userQuestion = ''});

  int get elapsedMs => isCompleted ? (endTime ?? DateTime.now()).difference(startTime).inMilliseconds : DateTime.now().difference(startTime).inMilliseconds;
  double get inputUsageRatio => (totalInputTokens / 64000).clamp(0.0, 1.0);
  double get outputUsageRatio => maxOutputTokens > 0 ? (outputTokens / maxOutputTokens).clamp(0.0, 1.0) : 0;
}

class BgTaskStatus {
  final String label;
  final int estimatedInputTokens;
  bool isCompleted;
  int? actualTotalTokens;
  final DateTime startTime;
  DateTime? endTime;
  BgTaskStatus({required this.label, required this.estimatedInputTokens, this.isCompleted = false, this.actualTotalTokens, required this.startTime, this.endTime});
  int get elapsedMs => isCompleted ? (endTime ?? DateTime.now()).difference(startTime).inMilliseconds : DateTime.now().difference(startTime).inMilliseconds;
}

class AiDebugNotifier extends ChangeNotifier {
  static final AiDebugNotifier instance = AiDebugNotifier._();
  AiDebugNotifier._();
  AiDebugTokenInfo? _current;
  final List<AiDebugTokenInfo> _history = [];
  BgTaskStatus? _bgTask;
  BgTaskStatus? get bgTask => _bgTask;
  AiDebugTokenInfo? get current => _current;
  List<AiDebugTokenInfo> get history => List.unmodifiable(_history);

  void startSession(AiDebugTokenInfo info) { if (!kDebugMode) return; _current = info; notifyListeners(); }
  void updateOutput(int newOutputTokens, double tps) { if (!kDebugMode || _current == null) return; _current!.outputTokens = newOutputTokens; _current!.tokensPerSecond = tps; notifyListeners(); }
  void completeSession({int? apiPrompt, int? apiCompletion, int? apiTotal, String? responseContent}) {
    if (!kDebugMode || _current == null) return;
    _current!.isCompleted = true; _current!.endTime = DateTime.now();
    if (apiPrompt != null) _current!.apiPromptTokens = apiPrompt;
    if (apiCompletion != null) _current!.apiCompletionTokens = apiCompletion;
    if (apiTotal != null) _current!.apiTotalTokens = apiTotal;
    if (responseContent != null) _current!.responseContent = responseContent;
    _history.insert(0, _current!); if (_history.length > 20) _history.removeLast();
    AiDebugLogService.instance.appendLog(_current!); notifyListeners();
  }
  void startBgTask({required String label, required int estimatedInputTokens}) {
    if (!kDebugMode) return;
    _bgTask = BgTaskStatus(label: label, estimatedInputTokens: estimatedInputTokens, startTime: DateTime.now()); notifyListeners();
  }
  void completeBgTask({int? actualTotalTokens}) {
    if (!kDebugMode || _bgTask == null) return;
    _bgTask!.isCompleted = true; _bgTask!.endTime = DateTime.now(); _bgTask!.actualTotalTokens = actualTotalTokens; notifyListeners();
    Future.delayed(const Duration(seconds: 3), () { if (_bgTask?.isCompleted == true) { _bgTask = null; notifyListeners(); } });
  }
  void clearHistory() { _history.clear(); _current = null; notifyListeners(); }
}

class EntryInsightResult {
  final String comment;
  final String valueDensity;
  final List<String> keywords;
  const EntryInsightResult({required this.comment, this.valueDensity = 'medium', this.keywords = const []});
}

class AiService {
  // ── 单例 ──────────────────────────────────────────────────
  AiService._internal();
  static final AiService instance = AiService._internal();
  factory AiService() => instance;
  // ──────────────────────────────────────────────────────────

  static const _apiKey = 'sk-763aa438905246479f3e9d590b7b6bdc';
  static const _baseUrl = 'https://api.deepseek.com/chat/completions';
  static const _model = 'deepseek-chat';

  Future<String> chatCompletion({required List<Map<String, String>> messages, int maxTokens = 2048, double temperature = 0.7, bool silent = false}) async {
    final debugNotifier = (kDebugMode && !silent) ? AiDebugNotifier.instance : null;
    final systemMsg = messages.firstWhere((m) => m['role'] == 'system', orElse: () => {'role': 'system', 'content': ''});
    final userMsg = messages.lastWhere((m) => m['role'] == 'user', orElse: () => {'role': 'user', 'content': ''});
    if (kDebugMode && debugNotifier != null) {
      final systemTokens = _estimateTokens(systemMsg['content'] ?? '');
      final userTokens = _estimateTokens(userMsg['content'] ?? '');
      debugNotifier.startSession(AiDebugTokenInfo(startTime: DateTime.now(), systemPromptTokens: systemTokens, historyTokens: 0, userQuestionTokens: userTokens, totalInputTokens: systemTokens + userTokens, maxOutputTokens: maxTokens, diaryContextMode: 'general', maxHistoryMessages: 0, systemPromptContent: systemMsg['content'] ?? '', userQuestion: userMsg['content'] ?? ''));
    }
    if (kDebugMode && silent) {
      AiDebugNotifier.instance.startBgTask(label: '后台 AI 任务', estimatedInputTokens: messages.fold(0, (sum, m) => sum + _estimateTokens(m['content'] ?? '')));
    }
    final request = http.Request('POST', Uri.parse(_baseUrl));
    request.headers.addAll({'Content-Type': 'application/json', 'Authorization': 'Bearer $_apiKey'});
    request.body = jsonEncode({'model': _model, 'messages': messages, 'stream': false, 'temperature': temperature, 'max_tokens': maxTokens});
    try {
      final client = http.Client();
      try {
        final streamedResponse = await client.send(request);
        final body = await streamedResponse.stream.bytesToString();
        if (streamedResponse.statusCode != 200) throw Exception('DeepSeek API 错误 ${streamedResponse.statusCode}: $body');
        final json = jsonDecode(body) as Map<String, dynamic>;
        final content = json['choices']?[0]?['message']?['content'] as String? ?? '';
        if (kDebugMode && debugNotifier != null) {
          final usage = json['usage'] as Map<String, dynamic>?;
          debugNotifier.completeSession(apiPrompt: usage?['prompt_tokens'] as int?, apiCompletion: usage?['completion_tokens'] as int?, apiTotal: usage?['total_tokens'] as int?, responseContent: content);
        }
        if (kDebugMode && silent) { final usage = json['usage'] as Map<String, dynamic>?; AiDebugNotifier.instance.completeBgTask(actualTotalTokens: usage?['total_tokens'] as int?); }
        return content;
      } finally { client.close(); }
    } catch (e) {
      if (kDebugMode && debugNotifier != null) debugNotifier.completeSession();
      if (kDebugMode && silent) AiDebugNotifier.instance.completeBgTask();
      rethrow;
    }
  }

  /// 通用流式聊天（逐 token 输出）
  Stream<String> chatStream({
    required String systemPrompt,
    required String userMessage,
    List<ChatMessage> history = const [],
    int maxTokens = 2048,
    double temperature = 0.7,
  }) async* {
    final debugNotifier = kDebugMode ? AiDebugNotifier.instance : null;
    const maxHistoryMessages = 20;
    final trimmedHistory = history.length > maxHistoryMessages
        ? history.sublist(history.length - maxHistoryMessages)
        : history;
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
      ...trimmedHistory.map((m) => {'role': m.role, 'content': m.content}),
      {'role': 'user', 'content': userMessage},
    ];

    if (kDebugMode && debugNotifier != null) {
      final systemTokens = _estimateTokens(systemPrompt);
      final histTokens = trimmedHistory.fold(0, (sum, m) => sum + _estimateTokens(m.content));
      final userTokens = _estimateTokens(userMessage);
      debugNotifier.startSession(AiDebugTokenInfo(
        startTime: DateTime.now(),
        systemPromptTokens: systemTokens,
        historyTokens: histTokens,
        userQuestionTokens: userTokens,
        totalInputTokens: systemTokens + histTokens + userTokens,
        maxOutputTokens: maxTokens,
        diaryContextMode: 'stream',
        injectedMomentCount: 0,
        totalMomentCount: 0,
        maxHistoryMessages: maxHistoryMessages,
        systemPromptContent: systemPrompt,
        userQuestion: userMessage,
      ));
    }

    final request = http.Request('POST', Uri.parse(_baseUrl));
    request.headers.addAll({'Content-Type': 'application/json', 'Authorization': 'Bearer $_apiKey'});
    request.body = jsonEncode({
      'model': _model,
      'messages': messages,
      'stream': true,
      'temperature': temperature,
      'max_tokens': maxTokens,
      if (kDebugMode) 'stream_options': {'include_usage': true},
    });

    final client = http.Client();
    int outputTokenCount = 0;
    final streamStart = DateTime.now();
    DateTime? lastTpsUpdate;
    int tokensSinceLastUpdate = 0;
    double currentTps = 0;
    final outputContentBuffer = kDebugMode ? StringBuffer() : null;

    try {
      final response = await client.send(request);
      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        if (kDebugMode) debugNotifier?.completeSession();
        throw Exception('DeepSeek API 错误 ${response.statusCode}: $body');
      }
      final stream = response.stream.transform(utf8.decoder).transform(const LineSplitter());
      await for (final line in stream) {
        if (line.startsWith('data: ')) {
          final data = line.substring(6).trim();
          if (data == '[DONE]') break;
          try {
            final json = jsonDecode(data) as Map<String, dynamic>;
            if (kDebugMode) {
              final usage = json['usage'] as Map<String, dynamic>?;
              if (usage != null) {
                debugNotifier?.completeSession(
                  apiPrompt: usage['prompt_tokens'] as int?,
                  apiCompletion: usage['completion_tokens'] as int?,
                  apiTotal: usage['total_tokens'] as int?,
                  responseContent: outputContentBuffer?.toString(),
                );
              }
            }
            final choices = json['choices'] as List?;
            if (choices != null && choices.isNotEmpty) {
              final delta = choices[0]['delta'] as Map<String, dynamic>?;
              final content = delta?['content'] as String?;
              if (content != null && content.isNotEmpty) {
                yield content;
                outputContentBuffer?.write(content);
                if (kDebugMode && debugNotifier != null) {
                  outputTokenCount += _estimateTokens(content);
                  tokensSinceLastUpdate += _estimateTokens(content);
                  final now = DateTime.now();
                  final elapsed = now.difference(streamStart).inMilliseconds;
                  final prev = lastTpsUpdate;
                  if (prev == null || now.difference(prev).inMilliseconds >= 300) {
                    final interval = prev != null ? now.difference(prev).inMilliseconds / 1000.0 : elapsed / 1000.0;
                    if (interval > 0) { currentTps = tokensSinceLastUpdate / interval; }
                    lastTpsUpdate = now;
                    tokensSinceLastUpdate = 0;
                  }
                  debugNotifier.updateOutput(outputTokenCount, currentTps);
                }
              }
            }
          } catch (_) {}
        }
      }
      if (kDebugMode) {
        final current = debugNotifier?.current;
        if (current != null && !current.isCompleted) {
          debugNotifier?.completeSession(responseContent: outputContentBuffer?.toString());
        }
      }
    } finally {
      client.close();
    }
  }

  static int _estimateTokens(String text) {
    if (text.isEmpty) return 0;
    final chineseChars = RegExp(r'[\u4e00-\u9fa5]').allMatches(text).length;
    final otherChars = text.length - chineseChars;
    return (chineseChars * 0.67 + otherChars / 4).ceil();
  }

  Future<EntryInsightResult?> analyzeEntry({required String content, String title = '', String kind = 'note'}) async {
    final kindLabel = switch (kind) { 'note' => '笔记', 'todo' => '待办', 'schedule' => '日程', 'collect' => '收藏', _ => '记录' };
    final titlePart = title.isNotEmpty ? '标题：$title\n' : '';
    final entryText = '$titlePart内容：$content';
    final systemPrompt = '你是用户的私人记录伙伴，刚刚看完用户写下的一条「$kindLabel」类型的内容。\n\n输出 JSON：{"comment":"感想","valueDensity":"medium","keywords":["关键词"]}。只输出 JSON。';
    try {
      final raw = await chatCompletion(messages: [{'role': 'system', 'content': systemPrompt}, {'role': 'user', 'content': '请分析这条$kindLabel：\n\n$entryText'}], maxTokens: 200, temperature: 0.85, silent: true);
      final jsonStr = _extractJson(raw);
      if (jsonStr == null) return null;
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return EntryInsightResult(comment: map['comment'] as String? ?? '', valueDensity: map['valueDensity'] as String? ?? 'medium', keywords: (map['keywords'] as List<dynamic>? ?? []).map((e) => e.toString().trim()).where((k) => k.isNotEmpty).toList());
    } catch (e) { debugPrint('[AiService] analyzeEntry 失败: $e'); return null; }
  }

  // ──────────────────────────────────────────────────────────
  //  清单维度智能识别（v3 升级版）
  //
  //  根据清单标题，自动推断：
  //    checklistType : temporal（日程/待办）or structural（结构/知识/工具）
  //    scene         : work / study / life / shopping / general（DB 兼容字段）
  //    style         : simple / numbered / grouped（展示风格）
  //    function      : checklist / sop / purchase / plan / review（功能层）
  //    aiTags        : 自由文本语义标签数组（最多 3 个，如 ["旅行","打包"]）
  //    emoji         : 最合适的 Emoji
  //    colorHex      : 推荐主题色
  //
  //  设计原则：快速、低 token、高准确率；失败时返回 null，由调用方保持默认值。
  // ──────────────────────────────────────────────────────────

  Future<ChecklistInferResult?> inferChecklistDimensions(String title) async {
    if (title.trim().length < 2) return null;

    const systemPrompt = '''你是一个清单分类助手。根据清单标题，输出 JSON 格式的分类结果。

清单类型说明：
- temporal: 有时间属性的待办清单（今天/本周/明天要做的事、日程安排、任务计划）
- structural: 长期有效的知识/工具清单（打包清单、SOP、采购清单、学习计划、检查清单）

场景说明（scene字段，兼容用）：
- work: 工作相关  - study: 学习相关  - life: 生活相关  - shopping: 购物采购  - general: 通用

功能层说明（function字段）：
- checklist: 通用核对清单（默认，打包/待办/检查）
- sop: 标准操作流程（有序步骤，如操作指南、菜谱、上线流程）
- purchase: 采购/购物清单（有数量，按类分组）
- plan: 规划/计划（目标导向，如旅行计划、周计划）
- review: 回顾/复盘（如晨间回顾、周复盘）

交互范式说明（interactionMode字段）——这是新增的最重要维度：
- execution: 执行范式（默认）——用户的核心动作是「勾选完成」，有进度条。适用：打包清单、购物单、待办、SOP步骤、手术核查
- reference: 参考范式——条目是「候选池/知识库」，浏览为主，无需打勾，无进度条。适用：书单、想去的地方、技术清单、电影清单
- review: 回顾范式——每条是一道「思考题」，用户需要在每题下写文字回应。适用：周复盘问卷、反思提示清单、面试复盘、SWOT分析
- process: 流程范式——步骤有严格顺序依赖，前一步完成后才能进行下一步。适用：上线发布流程、手术前严格操作手册（比SOP更严格）

判断逻辑：
- 含「书单/电影/想去/待学/清单库」等→ reference
- 含「复盘/回顾/反思/总结/review/SWOT」→ review
- 含「流程/上线/手术/严格步骤」→ process
- 其他默认 → execution

展示风格说明（style字段）：
- simple: 简单勾选式（默认）
- numbered: 有编号/顺序（步骤类）
- grouped: 分组式（内容多且有分类）

aiTags字段：最多3个简短的语义场景标签（自由文本，如 "旅行"、"健康"、"季度规划"、"家庭"），用于搜索和过滤。

只输出 JSON，格式：{"type":"temporal或structural","scene":"work/study/life/shopping/general","function":"checklist/sop/purchase/plan/review","interactionMode":"execution/reference/review/process","style":"simple/numbered/grouped","aiTags":["标签1","标签2"],"emoji":"一个emoji","colorHex":"#XXXXXX"}

Emoji 建议：工作→💼, 学习→📚, 购物→🛒, 旅行→✈️, 健康→💪, 日程→📅, 通用→📋, 计划→🎯, 采购→🛍️, 复盘→🔍, 书单→📚, 参考→📖, 流程→🔢''';

    try {
      final raw = await chatCompletion(
        messages: [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': '清单标题：$title'},
        ],
        maxTokens: 120,
        temperature: 0.3,
        silent: true,
      );
      final jsonStr = _extractJson(raw);
      if (jsonStr == null) return null;
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final typeStr = map['type'] as String? ?? 'structural';
      final sceneStr = map['scene'] as String? ?? 'general';
      final functionStr = map['function'] as String? ?? 'checklist';
      final styleStr = map['style'] as String? ?? 'simple';
      final interactionModeStr = map['interactionMode'] as String? ?? 'execution';
      final emoji = map['emoji'] as String? ?? '📋';
      final colorHex = map['colorHex'] as String? ?? '#5C7CFA';
      final rawTags = map['aiTags'];
      final aiTagLabels = rawTags is List
          ? rawTags
              .map((e) => e.toString().trim())
              .where((s) => s.isNotEmpty)
              .take(3)
              .toList()
          : <String>[];

      // 验证 emoji（必须包含非 ASCII 字符）
      final validEmoji = emoji.isNotEmpty && emoji.runes.any((r) => r > 127)
          ? emoji
          : '📋';
      // 验证 colorHex
      final validColor = RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(colorHex)
          ? colorHex
          : '#5C7CFA';
      // 验证 style
      const validStyles = {'simple', 'numbered', 'grouped'};
      final validStyle = validStyles.contains(styleStr) ? styleStr : 'simple';
      // 验证 function
      const validFunctions = {'checklist', 'sop', 'purchase', 'plan', 'review'};
      final validFunction =
          validFunctions.contains(functionStr) ? functionStr : 'checklist';
      // 验证 interactionMode
      const validModes = {'execution', 'reference', 'review', 'process'};
      final validMode = validModes.contains(interactionModeStr)
          ? interactionModeStr
          : 'execution';

      return ChecklistInferResult(
        checklistType: typeStr == 'temporal' ? 'temporal' : 'structural',
        scene: sceneStr,
        function: validFunction,
        interactionMode: validMode,
        style: validStyle,
        aiTagLabels: aiTagLabels,
        emoji: validEmoji,
        colorHex: validColor,
      );
    } catch (e) {
      debugPrint('[AiService] inferChecklistDimensions 失败: $e');
      return null;
    }
  }

  // ──────────────────────────────────────────────────────────
  //  清单事后重感知（AI ReTag）
  //
  //  在清单有了足够多的事项之后，根据「标题 + 当前事项列表」
  //  重新推断 function、aiTags，并按需更新 style。
  //
  //  设计原则：
  //  - 只更新 AI 标签（不动用户标签 userTags）
  //  - 仅在推断结果与现有 AI 标签有实质差异时才更新
  //  - 轻量请求，失败静默
  // ──────────────────────────────────────────────────────────

  Future<ChecklistReTagResult?> reInferChecklistTags({
    required String title,
    required List<String> itemTitles,
  }) async {
    if (title.trim().length < 2) return null;
    if (itemTitles.isEmpty) return null;

    const systemPrompt = '''你是一个清单语义分析助手。根据清单标题和事项列表，输出 JSON 格式的语义分析结果。

功能层说明（function字段）：
- checklist: 通用核对清单（打包/待办/检查）
- sop: 标准操作流程（有序步骤，如操作指南、菜谱）
- purchase: 采购/购物清单（有数量，按类分组）
- plan: 规划/计划（目标导向）
- review: 回顾/复盘

aiTags字段：最多4个简短语义场景标签（自由文本，如 "旅行"、"健康"、"季度规划"）。
结合标题和事项的真实内容来判断，不要泛泛而谈。

只输出 JSON，格式：{"function":"checklist/sop/purchase/plan/review","aiTags":["标签1","标签2"]}''';

    final itemSample = itemTitles.take(15).join('、');
    final userContent = '清单标题：$title\n事项（前${itemTitles.take(15).length}条）：$itemSample';

    try {
      final raw = await chatCompletion(
        messages: [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userContent},
        ],
        maxTokens: 80,
        temperature: 0.2,
        silent: true,
      );
      final jsonStr = _extractJson(raw);
      if (jsonStr == null) return null;
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final functionStr = map['function'] as String? ?? 'checklist';
      final rawTags = map['aiTags'];
      final aiTagLabels = rawTags is List
          ? rawTags
              .map((e) => e.toString().trim())
              .where((s) => s.isNotEmpty)
              .take(4)
              .toList()
          : <String>[];

      const validFunctions = {'checklist', 'sop', 'purchase', 'plan', 'review'};
      final validFunction =
          validFunctions.contains(functionStr) ? functionStr : 'checklist';

      return ChecklistReTagResult(
        function: validFunction,
        aiTagLabels: aiTagLabels,
      );
    } catch (e) {
      debugPrint('[AiService] reInferChecklistTags 失败: $e');
      return null;
    }
  }

  // ──────────────────────────────────────────────────────────
  //  活动专属一句话文案生成
  //
  //  为用户的某个具体活动生成一句有温度的个性化文案，
  //  用于打卡弹窗副标题、详情页空状态引导、Hero 区副文字。
  //
  //  设计原则：
  //  - 控制在 20~35 字，有诗意但不矫情
  //  - 紧扣活动名称，不使用通用模板
  //  - 失败（网络异常/超时）返回 null，调用方自行降级到本地插值
  // ──────────────────────────────────────────────────────────

  Future<String?> generateActivityMotto({
    required String activityName,
    required String activityEmoji,
    required String categoryLabel,
    String? activityDescription,
  }) async {
    final descPart = (activityDescription != null && activityDescription.isNotEmpty)
        ? '，这个活动的特点是「$activityDescription」'
        : '';
    const systemPrompt =
        '你是一个擅长写温暖文案的助手。用户让你为他的一项日常活动写一句专属的激励/记录文案。'
        '要求：\n'
        '1. 20~35个字，不超过35字\n'
        '2. 紧扣活动本身，有画面感或情感共鸣，不说废话\n'
        '3. 口吻真实自然，像是用户自己写给自己的\n'
        '4. 不使用感叹号，不重复活动名称作开头\n'
        '5. 只输出文案本身，不加引号，不加任何解释';

    final userContent =
        '活动名称：$activityEmoji $activityName\n'
        '所属维度：$categoryLabel$descPart\n\n'
        '请为这个活动写一句专属文案：';

    try {
      final result = await chatCompletion(
        messages: [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userContent},
        ],
        maxTokens: 80,
        temperature: 0.9,
        silent: true,
      );
      final cleaned = result.trim().replaceAll(RegExp(r'^[「『"\']+|[」』"\']+$'), '');
      if (cleaned.isEmpty || cleaned.length > 60) return null;
      return cleaned;
    } catch (e) {
      debugPrint('[AiService] generateActivityMotto 失败: $e');
      return null;
    }
  }

  String? _extractJson(String text) {
    try { jsonDecode(text); return text; } catch (_) {}
    final codeBlockMatch = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(text);
    if (codeBlockMatch != null) { final candidate = codeBlockMatch.group(1)?.trim(); if (candidate != null) { try { jsonDecode(candidate); return candidate; } catch (_) {} } }
    final startIdx = text.indexOf('{'); final endIdx = text.lastIndexOf('}');
    if (startIdx >= 0 && endIdx > startIdx) { final candidate = text.substring(startIdx, endIdx + 1); try { jsonDecode(candidate); return candidate; } catch (_) {} }
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────
//  ChecklistInferResult —— AI 推断清单维度结果
// ─────────────────────────────────────────────────────────────────

class ChecklistInferResult {
  /// 'temporal' 或 'structural'
  final String checklistType;

  /// 'work' / 'study' / 'life' / 'shopping' / 'general'（DB 兼容字段）
  final String scene;

  /// 'checklist' / 'sop' / 'purchase' / 'plan' / 'review'（功能层）
  final String function;

  /// 'execution' / 'reference' / 'review' / 'process'（交互范式）
  final String interactionMode;

  /// 'simple' / 'numbered' / 'grouped'
  final String style;

  /// AI 推断的语义标签文本列表（自由文本，最多 3 个）
  final List<String> aiTagLabels;

  /// 推荐的 Emoji
  final String emoji;

  /// 推荐的主题色（#RRGGBB 格式）
  final String colorHex;

  const ChecklistInferResult({
    required this.checklistType,
    required this.scene,
    this.function = 'checklist',
    this.interactionMode = 'execution',
    required this.style,
    this.aiTagLabels = const [],
    required this.emoji,
    required this.colorHex,
  });
}

// ─────────────────────────────────────────────────────────────────
//  ChecklistReTagResult —— AI 事后重感知结果
// ─────────────────────────────────────────────────────────────────

class ChecklistReTagResult {
  /// 'checklist' / 'sop' / 'purchase' / 'plan' / 'review'
  final String function;

  /// AI 重感知后的语义标签文本列表（最多 4 个）
  final List<String> aiTagLabels;

  const ChecklistReTagResult({
    required this.function,
    required this.aiTagLabels,
  });
}
