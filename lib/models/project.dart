// ─────────────────────────────────────────────────────────────────
//  Project —— 项目模型（意图层中层容器）
//
//  【设计思路】
//  项目是目标的具体执行结构。一个目标可以有多个项目，
//  一个项目也可以独立存在（不关联任何目标）。
//  项目内包含多条 Record（type=task）作为子任务。
//
//  例如：
//    项目："备赛计划"（关联目标：跑马拉松）
//      ├── 任务：制定12周训练计划
//      ├── 任务：购买跑鞋
//      └── 任务：报名比赛
// ─────────────────────────────────────────────────────────────────

const _sentinel = Object();

/// 项目状态
enum ProjectStatus {
  todo('todo', '待开始'),
  inProgress('in_progress', '进行中'),
  paused('paused', '已暂停'),
  completed('completed', '已完成'),
  cancelled('cancelled', '已取消');

  const ProjectStatus(this.value, this.label);
  final String value;
  final String label;

  static ProjectStatus fromValue(String v) => ProjectStatus.values.firstWhere(
        (e) => e.value == v,
        orElse: () => ProjectStatus.todo,
      );
}

/// 项目优先级
enum ProjectPriority {
  urgent('urgent', '紧急', '🔴'),
  high('high', '高', '🟠'),
  medium('medium', '中', '🟡'),
  low('low', '低', '🟢');

  const ProjectPriority(this.value, this.label, this.emoji);
  final String value;
  final String label;
  final String emoji;

  static ProjectPriority fromValue(String v) =>
      ProjectPriority.values.firstWhere(
        (e) => e.value == v,
        orElse: () => ProjectPriority.medium,
      );
}

/// 项目模型
class Project {
  final String id;

  /// 项目名称
  final String title;

  /// 项目描述
  final String description;

  /// emoji 图标
  final String emoji;

  /// 主题色（hex）
  final String colorHex;

  /// 状态
  final ProjectStatus status;

  /// 优先级
  final ProjectPriority priority;

  /// 关联的目标 ID（可选）
  final String? goalId;

  /// 开始日期（可选）
  final DateTime? startDate;

  /// 截止日期（可选）
  final DateTime? deadline;

  /// 是否置顶
  final bool isPinned;

  /// 排序权重
  final int sortOrder;

  /// 任务总数（缓存，由 Provider 更新）
  final int taskCount;

  /// 已完成任务数（缓存，由 Provider 更新）
  final int completedTaskCount;

  /// AI 对项目的分析/建议
  final String? aiInsight;

  /// 创建时间
  final DateTime createdAt;

  /// 最后更新时间
  final DateTime updatedAt;

  const Project({
    required this.id,
    required this.title,
    this.description = '',
    this.emoji = '📁',
    this.colorHex = '#4A90D9',
    this.status = ProjectStatus.todo,
    this.priority = ProjectPriority.medium,
    this.goalId,
    this.startDate,
    this.deadline,
    this.isPinned = false,
    this.sortOrder = 0,
    this.taskCount = 0,
    this.completedTaskCount = 0,
    this.aiInsight,
    required this.createdAt,
    required this.updatedAt,
  });

  Project copyWith({
    String? id,
    String? title,
    String? description,
    String? emoji,
    String? colorHex,
    ProjectStatus? status,
    ProjectPriority? priority,
    Object? goalId = _sentinel,
    Object? startDate = _sentinel,
    Object? deadline = _sentinel,
    bool? isPinned,
    int? sortOrder,
    int? taskCount,
    int? completedTaskCount,
    Object? aiInsight = _sentinel,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Project(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      emoji: emoji ?? this.emoji,
      colorHex: colorHex ?? this.colorHex,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      goalId: goalId == _sentinel ? this.goalId : goalId as String?,
      startDate: startDate == _sentinel ? this.startDate : startDate as DateTime?,
      deadline: deadline == _sentinel ? this.deadline : deadline as DateTime?,
      isPinned: isPinned ?? this.isPinned,
      sortOrder: sortOrder ?? this.sortOrder,
      taskCount: taskCount ?? this.taskCount,
      completedTaskCount: completedTaskCount ?? this.completedTaskCount,
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
        'priority': priority.value,
        'goalId': goalId,
        'startDate': startDate?.millisecondsSinceEpoch,
        'deadline': deadline?.millisecondsSinceEpoch,
        'isPinned': isPinned ? 1 : 0,
        'sortOrder': sortOrder,
        'taskCount': taskCount,
        'completedTaskCount': completedTaskCount,
        'aiInsight': aiInsight,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
      };

  factory Project.fromMap(Map<String, dynamic> map) => Project(
        id: map['id'] as String,
        title: map['title'] as String? ?? '',
        description: map['description'] as String? ?? '',
        emoji: map['emoji'] as String? ?? '📁',
        colorHex: map['colorHex'] as String? ?? '#4A90D9',
        status: ProjectStatus.fromValue(map['status'] as String? ?? 'todo'),
        priority: ProjectPriority.fromValue(
            map['priority'] as String? ?? 'medium'),
        goalId: map['goalId'] as String?,
        startDate: map['startDate'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['startDate'] as int)
            : null,
        deadline: map['deadline'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['deadline'] as int)
            : null,
        isPinned: (map['isPinned'] as int?) == 1,
        sortOrder: map['sortOrder'] as int? ?? 0,
        taskCount: map['taskCount'] as int? ?? 0,
        completedTaskCount: map['completedTaskCount'] as int? ?? 0,
        aiInsight: map['aiInsight'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
      );

  /// 完成率（0.0 ~ 1.0）
  double get completionRate =>
      taskCount > 0 ? completedTaskCount / taskCount : 0.0;

  /// 是否已过期
  bool get isOverdue {
    if (status == ProjectStatus.completed ||
        status == ProjectStatus.cancelled) {
      return false;
    }
    if (deadline == null) return false;
    return deadline!.isBefore(DateTime.now());
  }
}
