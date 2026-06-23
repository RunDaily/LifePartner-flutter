// ─────────────────────────────────────────────────────────────────
//  ProjectSection —— 版块模型（项目内的独立容器）
//
//  【设计思路】
//  版块是项目内部的组织单元，独立于任务存在。
//  层级结构：
//    项目（Project）
//      └── 版块（ProjectSection）
//            ├── 子版块（ProjectSection，parentSectionId 指向父版块）
//            │     └── 任务（Record，sectionId 指向所属版块）
//            └── 任务（Record，sectionId 指向所属版块）
//
//  版块支持无限层级嵌套（通过 parentSectionId 引用父版块）。
//  顶级版块的 parentSectionId 为 null。
// ─────────────────────────────────────────────────────────────────

const _sectionSentinel = Object();

/// 版块颜色主题（预设）
enum SectionColor {
  blue('blue', '#4A90D9'),
  green('green', '#27AE60'),
  orange('orange', '#E67E22'),
  purple('purple', '#9B59B6'),
  red('red', '#E74C3C'),
  teal('teal', '#1ABC9C'),
  pink('pink', '#E91E8C'),
  gray('gray', '#95A5A6');

  const SectionColor(this.value, this.hex);
  final String value;
  final String hex;

  static SectionColor fromValue(String? v) => SectionColor.values.firstWhere(
        (e) => e.value == v,
        orElse: () => SectionColor.blue,
      );
}

/// 版块模型
class ProjectSection {
  /// 版块唯一 ID
  final String id;

  /// 所属项目 ID
  final String projectId;

  /// 父版块 ID（顶级版块为 null）
  final String? parentSectionId;

  /// 版块名称
  final String title;

  /// 版块描述（可选）
  final String description;

  /// emoji 图标（可选）
  final String emoji;

  /// 颜色主题值（hex 格式，如 '#4A90D9'）
  final String colorHex;

  /// 是否折叠（UI 状态，默认展开）
  final bool isCollapsed;

  /// 是否完成（版块下所有任务完成时可设置）
  final bool isCompleted;

  /// 排序权重（越大越靠前）
  final int sortOrder;

  /// 任务数缓存
  final int taskCount;

  /// 已完成任务数缓存
  final int completedTaskCount;

  /// 创建时间
  final DateTime createdAt;

  /// 最后更新时间
  final DateTime updatedAt;

  const ProjectSection({
    required this.id,
    required this.projectId,
    this.parentSectionId,
    required this.title,
    this.description = '',
    this.emoji = '📂',
    this.colorHex = '#4A90D9',
    this.isCollapsed = false,
    this.isCompleted = false,
    this.sortOrder = 0,
    this.taskCount = 0,
    this.completedTaskCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 是否为顶级版块
  bool get isTopLevel => parentSectionId == null;

  /// 完成率（0.0 ~ 1.0）
  double get completionRate =>
      taskCount > 0 ? completedTaskCount / taskCount : 0.0;

  ProjectSection copyWith({
    String? id,
    String? projectId,
    Object? parentSectionId = _sectionSentinel,
    String? title,
    String? description,
    String? emoji,
    String? colorHex,
    bool? isCollapsed,
    bool? isCompleted,
    int? sortOrder,
    int? taskCount,
    int? completedTaskCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProjectSection(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      parentSectionId: parentSectionId == _sectionSentinel
          ? this.parentSectionId
          : parentSectionId as String?,
      title: title ?? this.title,
      description: description ?? this.description,
      emoji: emoji ?? this.emoji,
      colorHex: colorHex ?? this.colorHex,
      isCollapsed: isCollapsed ?? this.isCollapsed,
      isCompleted: isCompleted ?? this.isCompleted,
      sortOrder: sortOrder ?? this.sortOrder,
      taskCount: taskCount ?? this.taskCount,
      completedTaskCount: completedTaskCount ?? this.completedTaskCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'projectId': projectId,
        'parentSectionId': parentSectionId,
        'title': title,
        'description': description,
        'emoji': emoji,
        'colorHex': colorHex,
        'isCollapsed': isCollapsed ? 1 : 0,
        'isCompleted': isCompleted ? 1 : 0,
        'sortOrder': sortOrder,
        'taskCount': taskCount,
        'completedTaskCount': completedTaskCount,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
      };

  factory ProjectSection.fromMap(Map<String, dynamic> map) => ProjectSection(
        id: map['id'] as String,
        projectId: map['projectId'] as String,
        parentSectionId: map['parentSectionId'] as String?,
        title: map['title'] as String? ?? '',
        description: map['description'] as String? ?? '',
        emoji: map['emoji'] as String? ?? '📂',
        colorHex: map['colorHex'] as String? ?? '#4A90D9',
        isCollapsed: (map['isCollapsed'] as int?) == 1,
        isCompleted: (map['isCompleted'] as int?) == 1,
        sortOrder: map['sortOrder'] as int? ?? 0,
        taskCount: map['taskCount'] as int? ?? 0,
        completedTaskCount: map['completedTaskCount'] as int? ?? 0,
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
      );

  @override
  String toString() =>
      'ProjectSection(id: $id, title: $title, projectId: $projectId, parent: $parentSectionId)';
}
