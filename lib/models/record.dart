import 'dart:convert';

// 用于 copyWith 中区分"未传入"和"传入 null"
const _sentinel = Object();

// ─────────────────────────────────────────────────────────────────
//  Record —— 统一内容条目模型（新版核心数据单元）
//
//  【设计原则】
//  一切皆 Record。所有用户记录的内容，无论是笔记、待办、日程、
//  收藏、灵感、打卡……底层都是一条 Record。
//  类型（RecordType）决定展示形态和可用字段。
//
//  【五层关联】
//  - 意图层：goalId / projectId（归属于某个目标/项目）
//  - 时间层：scheduledAt / deadline / habitId（时间维度）
//  - 记录层：content / title / imagePaths（内容本身）
//  - 关系层：contactIds（关联的人）
//  - 环境层：mood / energy / location / weather / tags（背景上下文）
// ─────────────────────────────────────────────────────────────────

/// 记录类型
///
/// ─────────────────────────────────────────────────────────────────
///  【域归属】空间 Tab 6 个模块对应的记录域：
///
///  📔 日记域  (JournalScreen)
///    → note / idea / mood
///
///  💎 知识域  (NotesScreen)
///    → collect / reading
///
///  ☑️ 执行域  (ChecklistScreen)
///    → 由 Checklist 模型统一管理（ChecklistItem）
///    → task / checkItem / schedule 已迁移至 Checklist，保留枚举值仅用于旧数据兼容
///
///  🎯 活动域  (ActivityCollectionScreen)
///    → event（extra.activityId 关联 ActivityDefinition）
///    → habitLog（extra.habitId 关联 Habit）
///
///  🚀 项目域  (PlanScreen)
///    → 由 Project / Goal / KeyResult 模型管理（不走 Record）
///    → review / transaction 属项目域附属记录（保留 Record 形式）
///
///  ✨ 关于我  (MeScreen)
///    → 由 UserProfile 模型管理（不走 Record）
/// ─────────────────────────────────────────────────────────────────
enum RecordType {
  // ══ 日记域 ══════════════════════════════════════════════════════
  /// 笔记 —— 自由文本，整理后的想法
  note('note', '笔记', '📝'),

  /// 灵感 —— 随手捕获，原始想法，未加工
  idea('idea', '灵感', '💡'),

  /// 心情 —— 纯情绪记录，可无文字
  mood('mood', '心情', '😊'),

  // ══ 知识域 ══════════════════════════════════════════════════════
  /// 收藏 —— 外部链接/图片/内容存档
  collect('collect', '收藏', '💎'),

  /// 阅读 —— 书/文章/课程，有进度追踪
  reading('reading', '阅读', '📚'),

  // ══ 活动域 ══════════════════════════════════════════════════════
  /// 活动记录 —— 一次具体的活动参与（extra.activityId 关联 ActivityDefinition）
  event('event', '活动', '🎉'),

  /// 习惯打卡 —— 某条习惯的单次打卡（extra.habitId 关联 Habit）
  habitLog('habit_log', '打卡', '🔁'),

  // ══ 项目域附属 ════════════════════════════════════════════════
  /// 复盘 —— 周/月/年复盘，结构化总结（归属某个 Project/Goal）
  review('review', '复盘', '🔍'),

  /// 收支记录 —— 财务流水（可关联项目）
  transaction('transaction', '收支', '💰'),

  // ══ 执行域（已迁移，保留用于旧数据兼容）══════════════════════
  /// @deprecated 已迁移至 Checklist 模型统一管理
  /// 旧数据迁移兼容：任务型记录
  task('task', '任务', '✅'),

  /// @deprecated 已迁移至 Checklist 模型统一管理
  /// 旧数据迁移兼容：清单项
  checkItem('check_item', '清单', '☑️'),

  /// @deprecated 已迁移至 Checklist 模型统一管理
  /// 旧数据迁移兼容：日程（时态型清单）
  schedule('schedule', '日程', '📅');

  const RecordType(this.value, this.label, this.emoji);
  final String value;
  final String label;
  final String emoji;

  static RecordType fromValue(String v) => RecordType.values.firstWhere(
        (e) => e.value == v,
        orElse: () => RecordType.note,
      );

  // ── 域判断 ────────────────────────────────────────────────────

  /// 是否属于日记域（JournalScreen 展示范围）
  bool get isJournalDomain => this == note || this == idea || this == mood;

  /// 是否属于知识域（NotesScreen 展示范围）
  bool get isKnowledgeDomain => this == collect || this == reading;

  /// 是否属于活动域（ActivityCollectionScreen 展示范围）
  bool get isActivityDomain => this == event || this == habitLog;

  /// 是否属于项目域附属记录
  bool get isProjectDomain => this == review || this == transaction;

  /// 是否为已迁移的执行域类型（仅旧数据兼容使用）
  bool get isLegacyExecutionType =>
      this == task || this == checkItem || this == schedule;

  // ── 向后兼容属性（保留供旧代码引用，避免编译失败）─────────────

  /// 是否有完成状态（兼容旧代码）
  bool get hasCompletionState =>
      this == task || this == checkItem || this == schedule;
}

/// AI 对单条 Record 的分析结果
class RecordAiMeta {
  /// AI 的即时评论
  final String comment;

  /// 价值密度（high/medium/low）
  final String valueDensity;

  /// AI 提炼的核心关键词（1-3个）
  final List<String> keywords;

  /// AI 推荐关联的 Goal ID 列表
  final List<String> suggestedGoalIds;

  /// AI 推荐关联的 Project ID 列表
  final List<String> suggestedProjectIds;

  /// AI 发现的相关 Record ID 列表
  final List<String> linkedRecordIds;

  /// 生成时间
  final DateTime generatedAt;

  const RecordAiMeta({
    required this.comment,
    this.valueDensity = 'medium',
    this.keywords = const [],
    this.suggestedGoalIds = const [],
    this.suggestedProjectIds = const [],
    this.linkedRecordIds = const [],
    required this.generatedAt,
  });

  Map<String, dynamic> toMap() => {
        'comment': comment,
        'valueDensity': valueDensity,
        'keywords': keywords,
        'suggestedGoalIds': suggestedGoalIds,
        'suggestedProjectIds': suggestedProjectIds,
        'linkedRecordIds': linkedRecordIds,
        'generatedAt': generatedAt.toIso8601String(),
      };

  factory RecordAiMeta.fromMap(Map<String, dynamic> map) => RecordAiMeta(
        comment: map['comment'] as String? ?? '',
        valueDensity: map['valueDensity'] as String? ?? 'medium',
        keywords: (map['keywords'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
        suggestedGoalIds: (map['suggestedGoalIds'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
        suggestedProjectIds:
            (map['suggestedProjectIds'] as List<dynamic>? ?? [])
                .map((e) => e.toString())
                .toList(),
        linkedRecordIds: (map['linkedRecordIds'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
        generatedAt:
            DateTime.tryParse(map['generatedAt'] as String? ?? '') ??
                DateTime.now(),
      );

  String toJson() => jsonEncode(toMap());

  static RecordAiMeta? fromJson(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      return RecordAiMeta.fromMap(jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}

// ─────────────────────────────────────────────────────────────────
//  Record —— 统一内容条目
// ─────────────────────────────────────────────────────────────────
class Record {
  final String id;

  /// 内容类型
  final RecordType type;

  /// 可选标题
  final String title;

  /// 正文内容
  final String content;

  /// 创建时间
  final DateTime createdAt;

  /// 最后更新时间
  final DateTime updatedAt;

  // ── 意图层关联 ────────────────────────────────────────────────
  /// 归属的目标 ID（可选）
  final String? goalId;

  /// 归属的项目 ID（可选）
  final String? projectId;

  /// 归属的版块 ID（可选，ProjectSection.id）
  final String? sectionId;

  // ── 时间层字段 ────────────────────────────────────────────────
  /// 计划/日程时间
  final DateTime? scheduledAt;

  /// 截止时间
  final DateTime? deadline;

  /// 是否全天事件
  final bool isAllDay;

  /// 提醒（提前分钟数，-1 表示不提醒）
  final int reminderMinutes;

  /// 关联的习惯 ID（habitLog 类型使用）
  final String? habitId;

  // ── 行为状态 ─────────────────────────────────────────────────
  /// 是否已完成（task/checkItem/schedule 类型使用）
  final bool isCompleted;

  /// 完成时间
  final DateTime? completedAt;

  // ── 内容扩展字段 ──────────────────────────────────────────────
  /// 附图路径列表
  final List<String> imagePaths;

  /// 外部链接（collect 类型使用）
  final String? url;

  /// 是否收藏
  final bool isFavorite;

  /// 阅读进度（0~100，reading 类型使用）
  final int readingProgress;

  // ── 关系层关联 ────────────────────────────────────────────────
  /// 关联的联系人 ID 列表
  final List<String> contactIds;

  /// 收支金额（transaction 类型使用，正=收入，负=支出）
  final double? amount;

  /// 收支分类（transaction 类型使用）
  final String? transactionCategory;

  // ── 环境层（背景上下文）─────────────────────────────────────
  /// 心情
  final String? mood;

  /// 能量状态（high/medium/low）
  final String? energy;

  /// 地点
  final String? location;

  /// 天气
  final String? weather;

  /// 标签（用户自定义分类）
  final List<String> tags;

  // ── AI 元数据 ─────────────────────────────────────────────────
  /// AI 对本条记录的分析
  final RecordAiMeta? aiMeta;

  // ── 扩展字段 ─────────────────────────────────────────────────
  /// 类型专属扩展数据（JSON）
  final Map<String, dynamic> extra;

  const Record({
    required this.id,
    required this.type,
    this.title = '',
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.goalId,
    this.projectId,
    this.sectionId,
    this.scheduledAt,
    this.deadline,
    this.isAllDay = false,
    this.reminderMinutes = -1,
    this.habitId,
    this.isCompleted = false,
    this.completedAt,
    this.imagePaths = const [],
    this.url,
    this.isFavorite = false,
    this.readingProgress = 0,
    this.contactIds = const [],
    this.amount,
    this.transactionCategory,
    this.mood,
    this.energy,
    this.location,
    this.weather,
    this.tags = const [],
    this.aiMeta,
    this.extra = const {},
  });

  Record copyWith({
    String? id,
    RecordType? type,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? goalId = _sentinel,
    Object? projectId = _sentinel,
    Object? sectionId = _sentinel,
    Object? scheduledAt = _sentinel,
    Object? deadline = _sentinel,
    bool? isAllDay,
    int? reminderMinutes,
    Object? habitId = _sentinel,
    bool? isCompleted,
    Object? completedAt = _sentinel,
    List<String>? imagePaths,
    Object? url = _sentinel,
    bool? isFavorite,
    int? readingProgress,
    List<String>? contactIds,
    Object? amount = _sentinel,
    Object? transactionCategory = _sentinel,
    Object? mood = _sentinel,
    Object? energy = _sentinel,
    Object? location = _sentinel,
    Object? weather = _sentinel,
    List<String>? tags,
    Object? aiMeta = _sentinel,
    Map<String, dynamic>? extra,
  }) {
    return Record(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      goalId: goalId == _sentinel ? this.goalId : goalId as String?,
      projectId: projectId == _sentinel ? this.projectId : projectId as String?,
      sectionId: sectionId == _sentinel ? this.sectionId : sectionId as String?,
      scheduledAt: scheduledAt == _sentinel ? this.scheduledAt : scheduledAt as DateTime?,
      deadline: deadline == _sentinel ? this.deadline : deadline as DateTime?,
      isAllDay: isAllDay ?? this.isAllDay,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      habitId: habitId == _sentinel ? this.habitId : habitId as String?,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt == _sentinel ? this.completedAt : completedAt as DateTime?,
      imagePaths: imagePaths ?? this.imagePaths,
      url: url == _sentinel ? this.url : url as String?,
      isFavorite: isFavorite ?? this.isFavorite,
      readingProgress: readingProgress ?? this.readingProgress,
      contactIds: contactIds ?? this.contactIds,
      amount: amount == _sentinel ? this.amount : amount as double?,
      transactionCategory: transactionCategory == _sentinel
          ? this.transactionCategory
          : transactionCategory as String?,
      mood: mood == _sentinel ? this.mood : mood as String?,
      energy: energy == _sentinel ? this.energy : energy as String?,
      location: location == _sentinel ? this.location : location as String?,
      weather: weather == _sentinel ? this.weather : weather as String?,
      tags: tags ?? this.tags,
      aiMeta: aiMeta == _sentinel ? this.aiMeta : aiMeta as RecordAiMeta?,
      extra: extra ?? this.extra,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.value,
        'title': title,
        'content': content,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'goalId': goalId,
        'projectId': projectId,
        'sectionId': sectionId,
        'scheduledAt': scheduledAt?.millisecondsSinceEpoch,
        'deadline': deadline?.millisecondsSinceEpoch,
        'isAllDay': isAllDay ? 1 : 0,
        'reminderMinutes': reminderMinutes,
        'habitId': habitId,
        'isCompleted': isCompleted ? 1 : 0,
        'completedAt': completedAt?.millisecondsSinceEpoch,
        'imagePaths': imagePaths.join('|'),
        'url': url,
        'isFavorite': isFavorite ? 1 : 0,
        'readingProgress': readingProgress,
        'contactIds': contactIds.join(','),
        'amount': amount,
        'transactionCategory': transactionCategory,
        'mood': mood,
        'energy': energy,
        'location': location,
        'weather': weather,
        'tags': tags.join(','),
        'aiMeta': aiMeta?.toJson(),
        'extra': extra.isEmpty ? '{}' : jsonEncode(extra),
      };

  factory Record.fromMap(Map<String, dynamic> map) => Record(
        id: map['id'] as String,
        type: RecordType.fromValue(map['type'] as String? ?? 'note'),
        title: map['title'] as String? ?? '',
        content: map['content'] as String? ?? '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
        goalId: map['goalId'] as String?,
        projectId: map['projectId'] as String?,
        sectionId: map['sectionId'] as String?,
        scheduledAt: map['scheduledAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['scheduledAt'] as int)
            : null,
        deadline: map['deadline'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['deadline'] as int)
            : null,
        isAllDay: (map['isAllDay'] as int?) == 1,
        reminderMinutes: map['reminderMinutes'] as int? ?? -1,
        habitId: map['habitId'] as String?,
        isCompleted: (map['isCompleted'] as int?) == 1,
        completedAt: map['completedAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['completedAt'] as int)
            : null,
        imagePaths: (map['imagePaths'] as String?)?.isNotEmpty == true
            ? (map['imagePaths'] as String).split('|')
            : [],
        url: map['url'] as String?,
        isFavorite: (map['isFavorite'] as int?) == 1,
        readingProgress: map['readingProgress'] as int? ?? 0,
        contactIds: (map['contactIds'] as String?)?.isNotEmpty == true
            ? (map['contactIds'] as String).split(',')
            : [],
        amount: (map['amount'] as num?)?.toDouble(),
        transactionCategory: map['transactionCategory'] as String?,
        mood: map['mood'] as String?,
        energy: map['energy'] as String?,
        location: map['location'] as String?,
        weather: map['weather'] as String?,
        tags: (map['tags'] as String?)?.isNotEmpty == true
            ? (map['tags'] as String).split(',')
            : [],
        aiMeta: RecordAiMeta.fromJson(map['aiMeta'] as String?),
        extra: (() {
          final raw = map['extra'];
          if (raw is Map<String, dynamic>) return raw;
          if (raw is String && raw.isNotEmpty) {
            try {
              final decoded = jsonDecode(raw);
              if (decoded is Map<String, dynamic>) return decoded;
            } catch (_) {}
          }
          return <String, dynamic>{};
        })(),
      );

  // ── 便捷属性 ────────────────────────────────────────────────

  /// 内容预览（优先标题，无标题取正文首 60 字）
  String get preview {
    if (title.isNotEmpty) return title;
    final text = content.trim().replaceAll('\n', ' ');
    return text.length > 60 ? '${text.substring(0, 60)}…' : text;
  }

  /// 用于日期分组的 key（yyyy-MM-dd）
  String get dateKey {
    return '${createdAt.year.toString().padLeft(4, '0')}'
        '-${createdAt.month.toString().padLeft(2, '0')}'
        '-${createdAt.day.toString().padLeft(2, '0')}';
  }

  /// 是否已过期（task/schedule 类型，未完成且时间已过）
  bool get isOverdue {
    if (isCompleted) return false;
    final target = scheduledAt ?? deadline;
    if (target == null) return false;
    return target.isBefore(DateTime.now());
  }

  /// 是否是今天的日程/任务
  bool get isToday {
    final target = scheduledAt ?? deadline;
    if (target == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(target.year, target.month, target.day);
    return d == today;
  }

  @override
  String toString() =>
      'Record(id: $id, type: ${type.value}, createdAt: $createdAt)';
}

// ─────────────────────────────────────────────────────────────────
//  心情枚举
// ─────────────────────────────────────────────────────────────────
enum MoodType {
  happy('happy', '开心', '😊'),
  excited('excited', '兴奋', '🤩'),
  neutral('neutral', '平静', '😐'),
  touched('touched', '感动', '🥹'),
  sad('sad', '难过', '😢'),
  angry('angry', '生气', '😠'),
  anxious('anxious', '焦虑', '😰'),
  tired('tired', '疲惫', '😪');

  const MoodType(this.value, this.label, this.emoji);
  final String value;
  final String label;
  final String emoji;

  static MoodType fromValue(String value) => MoodType.values.firstWhere(
        (e) => e.value == value,
        orElse: () => MoodType.neutral,
      );
}

/// 能量状态
enum EnergyLevel {
  high('high', '充沛', '⚡'),
  medium('medium', '正常', '🔋'),
  low('low', '疲惫', '🪫');

  const EnergyLevel(this.value, this.label, this.emoji);
  final String value;
  final String label;
  final String emoji;

  static EnergyLevel? fromValue(String? v) {
    if (v == null) return null;
    return EnergyLevel.values.firstWhere(
      (e) => e.value == v,
      orElse: () => EnergyLevel.medium,
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  天气枚举
// ─────────────────────────────────────────────────────────────────
enum WeatherType {
  sunny('sunny', '晴天', '☀️'),
  cloudy('cloudy', '多云', '⛅'),
  rainy('rainy', '雨天', '🌧️'),
  snowy('snowy', '下雪', '❄️'),
  windy('windy', '刮风', '💨'),
  thunderstorm('thunderstorm', '雷雨', '⛈️');

  const WeatherType(this.value, this.label, this.emoji);
  final String value;
  final String label;
  final String emoji;

  static WeatherType? fromValue(String? value) {
    if (value == null) return null;
    return WeatherType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => WeatherType.sunny,
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  日期分组 —— 用于记录流按日期聚合展示
// ─────────────────────────────────────────────────────────────────
class RecordDayGroup {
  final DateTime date;
  final List<Record> records;

  const RecordDayGroup({required this.date, required this.records});

  /// 当天主心情
  String? get dominantMood {
    final withMood = records.where((r) => r.mood != null).toList();
    if (withMood.isEmpty) return null;
    final freq = <String, int>{};
    for (final r in withMood) {
      freq[r.mood!] = (freq[r.mood!] ?? 0) + 1;
    }
    final sorted = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }
}
