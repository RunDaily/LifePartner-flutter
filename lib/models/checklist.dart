import 'dart:convert';

// ─────────────────────────────────────────────────────────────────
//  Checklist —— 清单模型
//
//  【设计思路 v3】
//  清单是「行动执行层」的工具性模块，区别于日记（记录过去）和目标（规划未来）。
//  清单强调「当下做什么」，多场景多风格，AI 深度参与内容生成和语义感知。
//
//  【核心分型】
//  清单本质上分为两种完全不同的事物：
//
//  ① 时态型（temporal）—— "今天/本周要做的事"
//     • 本质是时间轴上的任务流，有明确的"属于哪天"语义
//     • 生命周期：随时间消亡，完成后归入历史；可按 repeatType 自动重置
//     • 展示重点：日期醒目，快速勾选，进度次要
//     • 典型：今日待办、本周计划、晨间清单、睡前回顾
//
//  ② 结构型（structural）—— "这件事的标准做法"
//     • 本质是一份完整的知识结构或流程规范
//     • 生命周期：长期有效，可重置复用，可分享成模板
//     • 展示重点：进度条、场景标签、分组展示
//     • 典型：婚礼物资采购、手术前检查、旅行打包、SWOT分析
//
//  【三层语义标注体系】
//
//  ┌────────────────────────────────────────────────────────────────┐
//  │  类型层（TYPE）                                                 │
//  │    temporal / structural  —— 时间属性，驱动 UI 分叉             │
//  ├────────────────────────────────────────────────────────────────┤
//  │  场景层（SCENE TAG）  ← 本版本升级为双轨多标签体系              │
//  │                                                                │
//  │  userTags  : 用户手动打的自由文本标签（优先展示，最高权重）      │
//  │  aiTags    : AI 根据标题+事项内容推断的语义标签（补充/兜底）     │
//  │  两者合并展示，去重；用户标签有锁图标，AI 标签有 ✦ 图标         │
//  │                                                                │
//  │  兼容字段 scene 保留用于旧版过滤和 DB 兼容                      │
//  ├────────────────────────────────────────────────────────────────┤
//  │  功能层（FUNCTION）                                             │
//  │    描述「这张清单是用来干什么的」，与场景正交                    │
//  │    checklist / sop / purchase / plan / review                  │
//  │    影响 AI 生成条目的策略 + 空状态文案                          │
//  └────────────────────────────────────────────────────────────────┘
//
//  AI 重感知触发：清单事项数量达到阈值（aiTaggedItemCount + 5）时，
//  自动在后台重新推断标签，仅在与现有标签不同时更新。
// ─────────────────────────────────────────────────────────────────

// ── 清单类型 ──────────────────────────────────────────────────────
enum ChecklistType {
  /// 时态型：有日期语义，随时间消亡，可重复
  temporal('temporal'),

  /// 结构型：长期有效，可复用，场景化
  structural('structural');

  const ChecklistType(this.value);
  final String value;

  static ChecklistType fromValue(String v) =>
      ChecklistType.values.firstWhere(
        (e) => e.value == v,
        orElse: () => ChecklistType.structural,
      );
}

// ── 时态型重复周期 ────────────────────────────────────────────────
enum RepeatType {
  /// 不重复（一次性）
  none('none', '不重复'),

  /// 每日重置
  daily('daily', '每日'),

  /// 每周重置
  weekly('weekly', '每周');

  const RepeatType(this.value, this.label);
  final String value;
  final String label;

  static RepeatType fromValue(String v) =>
      RepeatType.values.firstWhere(
        (e) => e.value == v,
        orElse: () => RepeatType.none,
      );
}

// ── 场景（兼容旧版，用于 DB 存储和基础过滤）────────────────────────
/// 保留 5 大基础场景枚举，仅用于数据库 schema 兼容和基础筛选。
/// v3 开始，UI 优先使用 userTags / aiTags（自由文本多标签）。
/// 历史数据中 travel/health/home/event/finance/recipe 均兜底到 life。
enum ChecklistScene {
  general('general', '通用', '📋'),
  work('work', '工作', '💼'),
  study('study', '学习', '📚'),
  life('life', '生活', '🏠'),
  shopping('shopping', '购物', '🛒');

  const ChecklistScene(this.value, this.label, this.emoji);
  final String value;
  final String label;
  final String emoji;

  static ChecklistScene fromValue(String v) {
    // 兼容旧数据：将已废弃的细分场景迁移到 life
    const legacyToLife = {
      'travel', 'health', 'home', 'event', 'finance', 'recipe'
    };
    if (legacyToLife.contains(v)) return ChecklistScene.life;
    return ChecklistScene.values.firstWhere(
      (e) => e.value == v,
      orElse: () => ChecklistScene.general,
    );
  }
}

// ── 功能层 ────────────────────────────────────────────────────────
/// 描述「这张清单是用来干什么的」，与场景（Where）正交，回答 What。
///
///  场景（Where） × 功能（What） = 清单的完整语义
///  例："旅行" × "采购" = 旅行打包清单
///      "工作" × "SOP"  = 工作流程规范
///      "健康" × "核对" = 手术前检查清单
///
///  功能层影响：
///   · AI 生成条目时的默认策略（SOP→有序步骤；purchase→分组数量）
///   · 展示风格的智能默认（sop→numbered；purchase→grouped）
///   · 空状态文案（plan: "还没有规划事项，添加第一条"）
enum ChecklistFunction {
  /// 通用核对/打勾清单（最常见，如打包清单、待办清单）
  checklist('checklist', '清单', '✅'),

  /// 标准操作流程（有序步骤，如菜谱、手术流程、上线 SOP）
  sop('sop', '流程 SOP', '🔢'),

  /// 采购/购物清单（有数量，分组按类）
  purchase('purchase', '采购清单', '🛍️'),

  /// 规划/计划（目标导向，如周计划、旅行计划）
  plan('plan', '规划', '🗓️'),

  /// 回顾/复盘（完成后review，如晨间回顾、周复盘）
  review('review', '回顾', '🔍');

  const ChecklistFunction(this.value, this.label, this.emoji);
  final String value;
  final String label;
  final String emoji;

  /// 功能→推荐风格的映射（AI 推断功能后自动设置展示风格）
  ChecklistStyle get recommendedStyle => switch (this) {
        ChecklistFunction.sop => ChecklistStyle.numbered,
        ChecklistFunction.purchase => ChecklistStyle.grouped,
        _ => ChecklistStyle.simple,
      };

  static ChecklistFunction fromValue(String v) =>
      ChecklistFunction.values.firstWhere(
        (e) => e.value == v,
        orElse: () => ChecklistFunction.checklist,
      );
}

// ── 交互范式（清单级别）──────────────────────────────────────────
/// 描述「这张清单里的条目，主要以什么方式被操作」。
///
/// 与 ChecklistFunction（目的层）正交：
///   function 回答「这张清单是用来干什么的」
///   interactionMode 回答「用户在使用这张清单时主要做什么动作」
///
/// 影响：
///   • 详情页的整体 UI 范式（进度条是否显示、条目控件类型、底部操作区）
///   • AI 生成条目的默认策略
///   • 空状态文案
///
/// 映射关系（AI 推断 function 后自动建议 mode）：
///   checklist / sop / purchase → execution
///   plan                       → execution（有时也可以是 reference）
///   review                     → review
///
/// 用户可在清单设置中手动覆盖 AI 建议的 mode。
enum ChecklistInteractionMode {
  /// 执行范式（默认）：条目可勾选，代表「做完了」；有进度条；勾完=完成
  /// 适用：打包清单、购物单、待办、SOP、手术核查
  execution('execution', '执行清单', '✅'),

  /// 参考范式：条目不勾选，作为候选池/知识库浏览；无进度条
  /// 适用：书单、想去的地方、Bucket List、技术清单、待学课程
  reference('reference', '参考列表', '📖'),

  /// 回顾范式：每条是一道思考问题；点击后展开文字输入区记录回应
  /// 勾选 = 「已回答过这道题」；进度 = 已回答/共N题
  /// 适用：周复盘、反思提示、面试复盘、SWOT分析
  review('review', '回顾复盘', '🔍'),

  /// 流程范式：条目有顺序依赖，前一步未完成则后续步骤锁定
  /// 适用：上线发布流程、手术前准备、严格操作手册
  process('process', '流程 SOP', '🔢');

  const ChecklistInteractionMode(this.value, this.label, this.emoji);
  final String value;
  final String label;
  final String emoji;

  static ChecklistInteractionMode fromValue(String v) =>
      ChecklistInteractionMode.values.firstWhere(
        (e) => e.value == v,
        orElse: () => ChecklistInteractionMode.execution,
      );

  /// 根据 function 推断默认 interactionMode（AI 使用此映射作为兜底）
  static ChecklistInteractionMode fromFunction(ChecklistFunction fn) =>
      switch (fn) {
        ChecklistFunction.review => ChecklistInteractionMode.review,
        ChecklistFunction.sop => ChecklistInteractionMode.process,
        _ => ChecklistInteractionMode.execution,
      };
}

// ── 条目交互控件类型（条目级别）─────────────────────────────────
/// 描述「单个条目的主要交互控件」。
///
/// 通常由清单的 interactionMode 统一决定（默认继承），
/// 但允许每条条目单独覆盖（如在 execution 清单里添加一条 note_entry 题目）。
///
/// 若为 null / inherit，则继承清单级别的 interactionMode 对应的默认控件：
///   execution → checkbox
///   reference → info_only
///   review    → note_entry
///   process   → checkbox（带顺序锁）
enum ChecklistItemMode {
  /// 继承清单级别的默认控件（null 语义）
  inherit('inherit'),

  /// 传统勾选框（☑）
  checkbox('checkbox'),

  /// 仅展示，无交互（ℹ️）—— 参考范式默认
  infoOnly('info_only'),

  /// 展开文字输入区（📝）—— 回顾范式默认；点击后显示多行文本框记录思考
  noteEntry('note_entry'),

  /// 多状态循环切换（🔄）—— 如「未读→在读→已读」或「待处理→进行中→完成」
  statusCycle('status_cycle'),

  /// 数字计数器（🔢 +/-）—— 如「今天喝了几杯水」
  counter('counter'),

  /// 1-5 星评分（⭐）—— 如「这本书值几分」
  rating('rating');

  const ChecklistItemMode(this.value);
  final String value;

  static ChecklistItemMode fromValue(String v) =>
      ChecklistItemMode.values.firstWhere(
        (e) => e.value == v,
        orElse: () => ChecklistItemMode.inherit,
      );
}

// ── 风格 ──────────────────────────────────────────────────────────
enum ChecklistStyle {
  simple('simple', '简洁清单'),
  numbered('numbered', '编号步骤'),
  grouped('grouped', '分组清单');

  const ChecklistStyle(this.value, this.label);
  final String value;
  final String label;

  static ChecklistStyle fromValue(String v) =>
      ChecklistStyle.values.firstWhere(
        (e) => e.value == v,
        orElse: () => ChecklistStyle.simple,
      );
}

// ── 清单状态 ──────────────────────────────────────────────────────
enum ChecklistStatus {
  active('active', '进行中'),
  completed('completed', '已完成'),
  archived('archived', '已归档');

  const ChecklistStatus(this.value, this.label);
  final String value;
  final String label;

  static ChecklistStatus fromValue(String v) =>
      ChecklistStatus.values.firstWhere(
        (e) => e.value == v,
        orElse: () => ChecklistStatus.active,
      );
}

// ── 标签来源 ──────────────────────────────────────────────────────
/// 用于区分标签是用户手动打的还是 AI 推断的。
enum TagSource {
  /// 用户手动添加（最高权重，UI 优先展示，有锁图标）
  user,

  /// AI 推断（补充/兜底，有 ✦ 图标）
  ai,
}

// ── 标签模型 ──────────────────────────────────────────────────────
/// 一个语义标签，携带来源和创建时间。
///
/// 标签是自由文本（如「旅行」「健康」「季度」），不限于枚举值。
/// UI 展示时用 source 区分样式：user 标签有锁，ai 标签有 ✦。
class ChecklistTag {
  final String label;
  final TagSource source;
  final DateTime createdAt;

  const ChecklistTag({
    required this.label,
    required this.source,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'label': label,
        'source': source == TagSource.user ? 'user' : 'ai',
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory ChecklistTag.fromMap(Map<String, dynamic> map) => ChecklistTag(
        label: map['label'] as String? ?? '',
        source: (map['source'] as String?) == 'user' ? TagSource.user : TagSource.ai,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            map['createdAt'] as int? ?? 0),
      );

  @override
  bool operator ==(Object other) =>
      other is ChecklistTag && other.label == label && other.source == source;

  @override
  int get hashCode => Object.hash(label, source);
}

// ── 清单条目 ──────────────────────────────────────────────────────
class ChecklistItem {
  final String id;
  final String title;
  final String? note;
  final bool isChecked;

  /// 分组标签（grouped 风格下使用）
  final String? groupLabel;

  /// 数量（购物场景下：数量/单位）
  final String? quantity;

  /// 排序权重
  final int sortOrder;

  /// 条目创建时间
  final DateTime createdAt;

  /// 勾选时间
  final DateTime? checkedAt;

  /// 【v4 新增】条目级别的交互控件类型
  /// ChecklistItemMode.inherit（默认）= 继承清单的 interactionMode 对应的默认控件
  final ChecklistItemMode itemMode;

  /// 【v4 新增】回顾范式下，用户对这条问题写下的文字回应
  /// 仅在 itemMode == noteEntry 时有意义；空字符串 = 未回答
  final String noteResponse;

  /// 【v4 新增】计数器范式下的当前计数值（counter 控件）
  final int counterValue;

  /// 【v4 新增】评分范式下的当前评分（1-5 星，0 = 未评分）
  final int ratingValue;

  const ChecklistItem({
    required this.id,
    required this.title,
    this.note,
    this.isChecked = false,
    this.groupLabel,
    this.quantity,
    this.sortOrder = 0,
    required this.createdAt,
    this.checkedAt,
    this.itemMode = ChecklistItemMode.inherit,
    this.noteResponse = '',
    this.counterValue = 0,
    this.ratingValue = 0,
  });

  ChecklistItem copyWith({
    String? id,
    String? title,
    Object? note = _sentinel,
    bool? isChecked,
    Object? groupLabel = _sentinel,
    Object? quantity = _sentinel,
    int? sortOrder,
    DateTime? createdAt,
    Object? checkedAt = _sentinel,
    ChecklistItemMode? itemMode,
    String? noteResponse,
    int? counterValue,
    int? ratingValue,
  }) {
    return ChecklistItem(
      id: id ?? this.id,
      title: title ?? this.title,
      note: note == _sentinel ? this.note : note as String?,
      isChecked: isChecked ?? this.isChecked,
      groupLabel: groupLabel == _sentinel ? this.groupLabel : groupLabel as String?,
      quantity: quantity == _sentinel ? this.quantity : quantity as String?,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      checkedAt: checkedAt == _sentinel ? this.checkedAt : checkedAt as DateTime?,
      itemMode: itemMode ?? this.itemMode,
      noteResponse: noteResponse ?? this.noteResponse,
      counterValue: counterValue ?? this.counterValue,
      ratingValue: ratingValue ?? this.ratingValue,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'note': note,
        'isChecked': isChecked,
        'groupLabel': groupLabel,
        'quantity': quantity,
        'sortOrder': sortOrder,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'checkedAt': checkedAt?.millisecondsSinceEpoch,
        'itemMode': itemMode.value,
        'noteResponse': noteResponse,
        'counterValue': counterValue,
        'ratingValue': ratingValue,
      };

  factory ChecklistItem.fromMap(Map<String, dynamic> map) => ChecklistItem(
        id: map['id'] as String,
        title: map['title'] as String? ?? '',
        note: map['note'] as String?,
        isChecked: map['isChecked'] == true || map['isChecked'] == 1,
        groupLabel: map['groupLabel'] as String?,
        quantity: map['quantity'] as String?,
        sortOrder: map['sortOrder'] as int? ?? 0,
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
        checkedAt: map['checkedAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['checkedAt'] as int)
            : null,
        itemMode: ChecklistItemMode.fromValue(
            map['itemMode'] as String? ?? 'inherit'),
        noteResponse: map['noteResponse'] as String? ?? '',
        counterValue: map['counterValue'] as int? ?? 0,
        ratingValue: map['ratingValue'] as int? ?? 0,
      );
}

const _sentinel = Object();

// ── 清单头 ────────────────────────────────────────────────────────
class Checklist {
  final String id;
  final String title;
  final String description;
  final String emoji;
  final String colorHex;

  /// 清单类型：时态型 or 结构型
  final ChecklistType checklistType;

  /// 兼容字段：旧版单一场景（DB 存储用，v3 UI 优先使用 tags）
  final ChecklistScene scene;
  final ChecklistStyle style;
  final ChecklistStatus status;

  /// 【v3 新增】功能层：描述「这张清单是用来干什么的」
  /// 与场景（Where）正交，回答 What
  final ChecklistFunction function;

  /// 【v4 新增】交互范式：描述「这张清单里的条目主要以什么方式被操作」
  /// AI 根据标题+function 推断，用户可手动覆盖
  final ChecklistInteractionMode interactionMode;

  /// 【v3 新增】双轨多标签体系
  ///
  /// tags 是全部标签的合并列表，通过 source 字段区分来源：
  ///   TagSource.user → 用户手动打的自由文本标签（优先展示）
  ///   TagSource.ai   → AI 根据标题+事项内容推断的语义标签（兜底）
  ///
  /// 使用时：
  ///   userTags → tags.where(source == user)
  ///   aiTags   → tags.where(source == ai)
  ///   allTagLabels → 去重后的全部标签文本（用于过滤搜索）
  final List<ChecklistTag> tags;

  /// 【v3 新增】AI 上次感知时，清单共有多少事项
  /// 用于判断是否需要触发事后重感知（当 items.length >= aiTaggedItemCount + 5）
  final int aiTaggedItemCount;

  /// 是否置顶
  final bool isPinned;

  /// 排序权重
  final int sortOrder;

  /// 条目列表（序列化为 JSON 存入数据库）
  final List<ChecklistItem> items;

  /// AI 生成的描述/提示
  final String? aiSummary;

  /// 截止时间（可选）
  final DateTime? dueDate;

  /// 【时态型专属】该清单归属的日期（null = 不绑定特定日期）
  final DateTime? scheduledDate;

  /// 【时态型专属】重复类型
  final RepeatType repeatType;

  /// 【时态型专属】上次自动重置的时间
  final DateTime? lastResetAt;

  final DateTime createdAt;
  final DateTime updatedAt;

  const Checklist({
    required this.id,
    required this.title,
    this.description = '',
    this.emoji = '📋',
    this.colorHex = '#5C7CFA',
    this.checklistType = ChecklistType.structural,
    this.scene = ChecklistScene.general,
    this.style = ChecklistStyle.simple,
    this.status = ChecklistStatus.active,
    this.function = ChecklistFunction.checklist,
    this.interactionMode = ChecklistInteractionMode.execution,
    this.tags = const [],
    this.aiTaggedItemCount = 0,
    this.isPinned = false,
    this.sortOrder = 0,
    this.items = const [],
    this.aiSummary,
    this.dueDate,
    this.scheduledDate,
    this.repeatType = RepeatType.none,
    this.lastResetAt,
    required this.createdAt,
    required this.updatedAt,
  });

  // ── 计算属性 ─────────────────────────────────────────────────────

  int get totalCount => items.length;
  int get checkedCount => items.where((i) => i.isChecked).length;
  int get uncheckedCount => totalCount - checkedCount;
  double get progress => totalCount == 0 ? 0.0 : checkedCount / totalCount;
  bool get isAllDone => totalCount > 0 && checkedCount == totalCount;

  /// 用户手动打的标签（优先展示）
  List<ChecklistTag> get userTags =>
      tags.where((t) => t.source == TagSource.user).toList();

  /// AI 推断的标签（兜底补充）
  List<ChecklistTag> get aiTags =>
      tags.where((t) => t.source == TagSource.ai).toList();

  /// 所有标签文本（去重，用于搜索/过滤）
  List<String> get allTagLabels {
    final seen = <String>{};
    return tags
        .map((t) => t.label)
        .where((l) => l.isNotEmpty && seen.add(l))
        .toList();
  }

  /// 是否需要触发 AI 事后重感知
  /// 触发条件：事项数量比上次 AI 感知时多了 ≥ 5 条
  bool get needsAiReTag => items.length >= aiTaggedItemCount + 5;

  /// 是否是今天的时态清单
  bool get isToday {
    if (checklistType != ChecklistType.temporal) return false;
    if (scheduledDate == null) return false;
    final now = DateTime.now();
    return scheduledDate!.year == now.year &&
        scheduledDate!.month == now.month &&
        scheduledDate!.day == now.day;
  }

  /// 是否已逾期（时态型，scheduledDate 在今天之前且未完成）
  bool get isOverdue {
    if (checklistType != ChecklistType.temporal) return false;
    if (scheduledDate == null) return false;
    if (isAllDone) return false;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final scheduled = DateTime(
        scheduledDate!.year, scheduledDate!.month, scheduledDate!.day);
    return scheduled.isBefore(todayDate);
  }

  /// dueDate 距今天数（结构型，用于「即将到期」提示）
  int? get daysUntilDue {
    if (dueDate == null) return null;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final due = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    return due.difference(todayDate).inDays;
  }

  // ── copyWith ──────────────────────────────────────────────────────
  Checklist copyWith({
    String? id,
    String? title,
    String? description,
    String? emoji,
    String? colorHex,
    ChecklistType? checklistType,
    ChecklistScene? scene,
    ChecklistStyle? style,
    ChecklistStatus? status,
    ChecklistFunction? function,
    ChecklistInteractionMode? interactionMode,
    List<ChecklistTag>? tags,
    int? aiTaggedItemCount,
    bool? isPinned,
    int? sortOrder,
    List<ChecklistItem>? items,
    Object? aiSummary = _sentinel,
    Object? dueDate = _sentinel,
    Object? scheduledDate = _sentinel,
    RepeatType? repeatType,
    Object? lastResetAt = _sentinel,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Checklist(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      emoji: emoji ?? this.emoji,
      colorHex: colorHex ?? this.colorHex,
      checklistType: checklistType ?? this.checklistType,
      scene: scene ?? this.scene,
      style: style ?? this.style,
      status: status ?? this.status,
      function: function ?? this.function,
      interactionMode: interactionMode ?? this.interactionMode,
      tags: tags ?? this.tags,
      aiTaggedItemCount: aiTaggedItemCount ?? this.aiTaggedItemCount,
      isPinned: isPinned ?? this.isPinned,
      sortOrder: sortOrder ?? this.sortOrder,
      items: items ?? this.items,
      aiSummary: aiSummary == _sentinel ? this.aiSummary : aiSummary as String?,
      dueDate: dueDate == _sentinel ? this.dueDate : dueDate as DateTime?,
      scheduledDate: scheduledDate == _sentinel
          ? this.scheduledDate
          : scheduledDate as DateTime?,
      repeatType: repeatType ?? this.repeatType,
      lastResetAt: lastResetAt == _sentinel
          ? this.lastResetAt
          : lastResetAt as DateTime?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ── 序列化 ────────────────────────────────────────────────────────
  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'emoji': emoji,
        'colorHex': colorHex,
        'checklistType': checklistType.value,
        'scene': scene.value,
        'style': style.value,
        'status': status.value,
        'function': function.value,
        'interactionMode': interactionMode.value,
        'tags': jsonEncode(tags.map((t) => t.toMap()).toList()),
        'aiTaggedItemCount': aiTaggedItemCount,
        'isPinned': isPinned ? 1 : 0,
        'sortOrder': sortOrder,
        'items': jsonEncode(items.map((i) => i.toMap()).toList()),
        'aiSummary': aiSummary,
        'dueDate': dueDate?.millisecondsSinceEpoch,
        'scheduledDate': scheduledDate?.millisecondsSinceEpoch,
        'repeatType': repeatType.value,
        'lastResetAt': lastResetAt?.millisecondsSinceEpoch,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
      };

  factory Checklist.fromMap(Map<String, dynamic> map) => Checklist(
        id: map['id'] as String,
        title: map['title'] as String? ?? '',
        description: map['description'] as String? ?? '',
        emoji: map['emoji'] as String? ?? '📋',
        colorHex: map['colorHex'] as String? ?? '#5C7CFA',
        checklistType: ChecklistType.fromValue(
            map['checklistType'] as String? ?? 'structural'),
        scene: ChecklistScene.fromValue(map['scene'] as String? ?? 'general'),
        style: ChecklistStyle.fromValue(map['style'] as String? ?? 'simple'),
        status: ChecklistStatus.fromValue(map['status'] as String? ?? 'active'),
        function: ChecklistFunction.fromValue(
            map['function'] as String? ?? 'checklist'),
        interactionMode: ChecklistInteractionMode.fromValue(
            map['interactionMode'] as String? ?? 'execution'),
        tags: (() {
          final raw = map['tags'];
          if (raw is String && raw.isNotEmpty) {
            try {
              final list = jsonDecode(raw) as List<dynamic>;
              return list
                  .map((e) =>
                      ChecklistTag.fromMap(e as Map<String, dynamic>))
                  .toList();
            } catch (_) {}
          }
          return <ChecklistTag>[];
        })(),
        aiTaggedItemCount: map['aiTaggedItemCount'] as int? ?? 0,
        isPinned: (map['isPinned'] as int?) == 1,
        sortOrder: map['sortOrder'] as int? ?? 0,
        items: (() {
          final raw = map['items'];
          if (raw is String && raw.isNotEmpty) {
            try {
              final list = jsonDecode(raw) as List<dynamic>;
              return list
                  .map((e) =>
                      ChecklistItem.fromMap(e as Map<String, dynamic>))
                  .toList();
            } catch (_) {}
          }
          return <ChecklistItem>[];
        })(),
        aiSummary: map['aiSummary'] as String?,
        dueDate: map['dueDate'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['dueDate'] as int)
            : null,
        scheduledDate: map['scheduledDate'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['scheduledDate'] as int)
            : null,
        repeatType:
            RepeatType.fromValue(map['repeatType'] as String? ?? 'none'),
        lastResetAt: map['lastResetAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['lastResetAt'] as int)
            : null,
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
      );
}
