import 'dart:convert';

// ─────────────────────────────────────────────────────────────────
//  Goal —— 目标模型（意图层顶层容器）
//
//  【设计思路】
//  目标是最高层级的意图容器，代表用户想要达成的某个方向性结果。
//  目标可以拆解为多个 Project（项目），也可以直接关联 Record（任务）。
//
//  例如：
//    目标："今年跑完一个马拉松"
//      ├── 项目：备赛计划
//      ├── 项目：装备购置
//      └── 直接任务：报名参赛
// ─────────────────────────────────────────────────────────────────

/// 目标状态
enum GoalStatus {
  active('active', '进行中'),
  paused('paused', '已暂停'),
  completed('completed', '已完成'),
  abandoned('abandoned', '已放弃');

  const GoalStatus(this.value, this.label);
  final String value;
  final String label;

  static GoalStatus fromValue(String v) => GoalStatus.values.firstWhere(
        (e) => e.value == v,
        orElse: () => GoalStatus.active,
      );
}

/// 目标时间维度
enum GoalTimeframe {
  daily('daily', '每日'),
  weekly('weekly', '每周'),
  monthly('monthly', '每月'),
  quarterly('quarterly', '每季度'),
  yearly('yearly', '每年'),
  custom('custom', '自定义');

  const GoalTimeframe(this.value, this.label);
  final String value;
  final String label;

  static GoalTimeframe fromValue(String v) => GoalTimeframe.values.firstWhere(
        (e) => e.value == v,
        orElse: () => GoalTimeframe.custom,
      );
}

/// 里程碑
class Milestone {
  final String id;
  final String title;
  final bool isCompleted;
  final DateTime? dueDate;
  final DateTime? completedAt;

  const Milestone({
    required this.id,
    required this.title,
    this.isCompleted = false,
    this.dueDate,
    this.completedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'isCompleted': isCompleted,
        'dueDate': dueDate?.millisecondsSinceEpoch,
        'completedAt': completedAt?.millisecondsSinceEpoch,
      };

  factory Milestone.fromMap(Map<String, dynamic> map) => Milestone(
        id: map['id'] as String,
        title: map['title'] as String? ?? '',
        isCompleted: (map['isCompleted'] as int?) == 1 ||
            (map['isCompleted'] as bool?) == true,
        dueDate: map['dueDate'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['dueDate'] as int)
            : null,
        completedAt: map['completedAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['completedAt'] as int)
            : null,
      );

  Milestone copyWith({
    String? id,
    String? title,
    bool? isCompleted,
    Object? dueDate = _sentinel,
    Object? completedAt = _sentinel,
  }) {
    return Milestone(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      dueDate: dueDate == _sentinel ? this.dueDate : dueDate as DateTime?,
      completedAt:
          completedAt == _sentinel ? this.completedAt : completedAt as DateTime?,
    );
  }
}

const _sentinel = Object();

/// 目标模型
class Goal {
  final String id;

  /// 目标标题
  final String title;

  /// 目标描述
  final String description;

  /// emoji 图标
  final String emoji;

  /// 主题色（hex，如 #E07818）
  final String colorHex;

  /// 状态
  final GoalStatus status;

  /// 时间维度
  final GoalTimeframe timeframe;

  /// 截止日期（可选）
  final DateTime? deadline;

  /// 是否置顶
  final bool isPinned;

  /// 排序权重
  final int sortOrder;

  /// 里程碑列表（序列化为 JSON 存储）
  final List<Milestone> milestones;

  /// 进度（0~100，手动设置或自动计算）
  final int progress;

  /// 是否自动计算进度（根据关联的 Project/Task 完成比例）
  final bool autoProgress;

  /// AI 对目标的分析/建议
  final String? aiInsight;

  /// 创建时间
  final DateTime createdAt;

  /// 最后更新时间
  final DateTime updatedAt;

  const Goal({
    required this.id,
    required this.title,
    this.description = '',
    this.emoji = '🎯',
    this.colorHex = '#E07818',
    this.status = GoalStatus.active,
    this.timeframe = GoalTimeframe.custom,
    this.deadline,
    this.isPinned = false,
    this.sortOrder = 0,
    this.milestones = const [],
    this.progress = 0,
    this.autoProgress = true,
    this.aiInsight,
    required this.createdAt,
    required this.updatedAt,
  });

  Goal copyWith({
    String? id,
    String? title,
    String? description,
    String? emoji,
    String? colorHex,
    GoalStatus? status,
    GoalTimeframe? timeframe,
    Object? deadline = _sentinel,
    bool? isPinned,
    int? sortOrder,
    List<Milestone>? milestones,
    int? progress,
    bool? autoProgress,
    Object? aiInsight = _sentinel,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Goal(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      emoji: emoji ?? this.emoji,
      colorHex: colorHex ?? this.colorHex,
      status: status ?? this.status,
      timeframe: timeframe ?? this.timeframe,
      deadline: deadline == _sentinel ? this.deadline : deadline as DateTime?,
      isPinned: isPinned ?? this.isPinned,
      sortOrder: sortOrder ?? this.sortOrder,
      milestones: milestones ?? this.milestones,
      progress: progress ?? this.progress,
      autoProgress: autoProgress ?? this.autoProgress,
      aiInsight: aiInsight == _sentinel ? this.aiInsight : aiInsight as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'emoji': emoji,
        'colorHex': colorHex,
        'status': status.value,
        'timeframe': timeframe.value,
        'deadline': deadline?.millisecondsSinceEpoch,
        'isPinned': isPinned ? 1 : 0,
        'sortOrder': sortOrder,
        'milestones': jsonEncode(milestones.map((m) => m.toMap()).toList()),
        'progress': progress,
        'autoProgress': autoProgress ? 1 : 0,
        'aiInsight': aiInsight,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
      };

  factory Goal.fromMap(Map<String, dynamic> map) => Goal(
        id: map['id'] as String,
        title: map['title'] as String? ?? '',
        description: map['description'] as String? ?? '',
        emoji: map['emoji'] as String? ?? '🎯',
        colorHex: map['colorHex'] as String? ?? '#E07818',
        status: GoalStatus.fromValue(map['status'] as String? ?? 'active'),
        timeframe:
            GoalTimeframe.fromValue(map['timeframe'] as String? ?? 'custom'),
        deadline: map['deadline'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['deadline'] as int)
            : null,
        isPinned: (map['isPinned'] as int?) == 1,
        sortOrder: map['sortOrder'] as int? ?? 0,
        milestones: (() {
          final raw = map['milestones'];
          if (raw is String && raw.isNotEmpty) {
            try {
              final list = jsonDecode(raw) as List<dynamic>;
              return list
                  .map((e) => Milestone.fromMap(e as Map<String, dynamic>))
                  .toList();
            } catch (_) {}
          }
          return <Milestone>[];
        })(),
        progress: map['progress'] as int? ?? 0,
        autoProgress: (map['autoProgress'] as int?) != 0,
        aiInsight: map['aiInsight'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
      );

  /// 完成里程碑数 / 总里程碑数
  String get milestoneProgress =>
      '${milestones.where((m) => m.isCompleted).length}/${milestones.length}';

  /// 是否已过期（未完成且截止日在过去）
  bool get isOverdue {
    if (status == GoalStatus.completed) return false;
    if (deadline == null) return false;
    return deadline!.isBefore(DateTime.now());
  }
}
