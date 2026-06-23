// ─────────────────────────────────────────────────────────────────
//  Habit —— 习惯定义模型（时间层容器）
//
//  【设计思路】
//  Habit 是习惯的"元定义"，描述用户想要养成的重复行为。
//  每次实际打卡对应一条 Record（type=habitLog，habitId=本习惯ID）。
//
//  例如：
//    习惯："每天跑步30分钟"（频率=每天，目标=30分钟）
//      ├── 打卡记录 2024-01-01（完成，耗时32分钟）
//      ├── 打卡记录 2024-01-02（完成）
//      └── 打卡记录 2024-01-04（完成，跳过了01-03）
// ─────────────────────────────────────────────────────────────────

const _sentinel = Object();

/// 习惯频率
enum HabitFrequency {
  daily('daily', '每天'),
  weekdays('weekdays', '工作日'),
  weekends('weekends', '周末'),
  weekly('weekly', '每周'),
  custom('custom', '自定义');

  const HabitFrequency(this.value, this.label);
  final String value;
  final String label;

  static HabitFrequency fromValue(String v) =>
      HabitFrequency.values.firstWhere(
        (e) => e.value == v,
        orElse: () => HabitFrequency.daily,
      );
}

/// 习惯打卡目标类型
enum HabitGoalType {
  /// 简单完成（是/否）
  boolean('boolean', '完成即可'),

  /// 数量目标（如跑步3公里、喝水8杯）
  count('count', '次数/数量'),

  /// 时长目标（如冥想20分钟）
  duration('duration', '时长(分钟)');

  const HabitGoalType(this.value, this.label);
  final String value;
  final String label;

  static HabitGoalType fromValue(String v) =>
      HabitGoalType.values.firstWhere(
        (e) => e.value == v,
        orElse: () => HabitGoalType.boolean,
      );
}

/// 习惯模型
class Habit {
  final String id;

  /// 习惯名称
  final String title;

  /// 描述/备注
  final String description;

  /// emoji 图标
  final String emoji;

  /// 主题色（hex）
  final String colorHex;

  /// 频率
  final HabitFrequency frequency;

  /// 自定义频率（每周几，1=周一...7=周日，frequency=custom 时有效）
  final List<int> customDays;

  /// 目标类型
  final HabitGoalType goalType;

  /// 目标值（count/duration 类型时有效）
  final double goalValue;

  /// 目标单位（如 "杯"、"公里"、"分钟"）
  final String goalUnit;

  /// 提醒时间（HH:mm 格式，如 "07:30"，null 表示不提醒）
  final String? reminderTime;

  /// 是否激活（暂停的习惯不在今天视图出现）
  final bool isActive;

  /// 关联的目标 ID（可选，习惯可以服务于某个目标）
  final String? goalId;

  /// 排序权重
  final int sortOrder;

  /// 连续打卡天数（缓存，由 Provider 计算更新）
  final int currentStreak;

  /// 历史最长连续天数（缓存）
  final int longestStreak;

  /// 总打卡次数（缓存）
  final int totalCheckIns;

  /// 创建时间
  final DateTime createdAt;

  /// 最后更新时间
  final DateTime updatedAt;

  /// 最近一次打卡时间（缓存）
  final DateTime? lastCheckInAt;

  const Habit({
    required this.id,
    required this.title,
    this.description = '',
    this.emoji = '🔁',
    this.colorHex = '#27AE60',
    this.frequency = HabitFrequency.daily,
    this.customDays = const [],
    this.goalType = HabitGoalType.boolean,
    this.goalValue = 1,
    this.goalUnit = '',
    this.reminderTime,
    this.isActive = true,
    this.goalId,
    this.sortOrder = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.totalCheckIns = 0,
    required this.createdAt,
    required this.updatedAt,
    this.lastCheckInAt,
  });

  Habit copyWith({
    String? id,
    String? title,
    String? description,
    String? emoji,
    String? colorHex,
    HabitFrequency? frequency,
    List<int>? customDays,
    HabitGoalType? goalType,
    double? goalValue,
    String? goalUnit,
    Object? reminderTime = _sentinel,
    bool? isActive,
    Object? goalId = _sentinel,
    int? sortOrder,
    int? currentStreak,
    int? longestStreak,
    int? totalCheckIns,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? lastCheckInAt = _sentinel,
  }) {
    return Habit(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      emoji: emoji ?? this.emoji,
      colorHex: colorHex ?? this.colorHex,
      frequency: frequency ?? this.frequency,
      customDays: customDays ?? this.customDays,
      goalType: goalType ?? this.goalType,
      goalValue: goalValue ?? this.goalValue,
      goalUnit: goalUnit ?? this.goalUnit,
      reminderTime:
          reminderTime == _sentinel ? this.reminderTime : reminderTime as String?,
      isActive: isActive ?? this.isActive,
      goalId: goalId == _sentinel ? this.goalId : goalId as String?,
      sortOrder: sortOrder ?? this.sortOrder,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      totalCheckIns: totalCheckIns ?? this.totalCheckIns,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastCheckInAt: lastCheckInAt == _sentinel
          ? this.lastCheckInAt
          : lastCheckInAt as DateTime?,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'emoji': emoji,
        'colorHex': colorHex,
        'frequency': frequency.value,
        'customDays': customDays.join(','),
        'goalType': goalType.value,
        'goalValue': goalValue,
        'goalUnit': goalUnit,
        'reminderTime': reminderTime,
        'isActive': isActive ? 1 : 0,
        'goalId': goalId,
        'sortOrder': sortOrder,
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'totalCheckIns': totalCheckIns,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'lastCheckInAt': lastCheckInAt?.millisecondsSinceEpoch,
      };

  factory Habit.fromMap(Map<String, dynamic> map) => Habit(
        id: map['id'] as String,
        title: map['title'] as String? ?? '',
        description: map['description'] as String? ?? '',
        emoji: map['emoji'] as String? ?? '🔁',
        colorHex: map['colorHex'] as String? ?? '#27AE60',
        frequency:
            HabitFrequency.fromValue(map['frequency'] as String? ?? 'daily'),
        customDays: (map['customDays'] as String?)?.isNotEmpty == true
            ? (map['customDays'] as String)
                .split(',')
                .map(int.parse)
                .toList()
            : [],
        goalType:
            HabitGoalType.fromValue(map['goalType'] as String? ?? 'boolean'),
        goalValue: (map['goalValue'] as num?)?.toDouble() ?? 1,
        goalUnit: map['goalUnit'] as String? ?? '',
        reminderTime: map['reminderTime'] as String?,
        isActive: (map['isActive'] as int?) != 0,
        goalId: map['goalId'] as String?,
        sortOrder: map['sortOrder'] as int? ?? 0,
        currentStreak: map['currentStreak'] as int? ?? 0,
        longestStreak: map['longestStreak'] as int? ?? 0,
        totalCheckIns: map['totalCheckIns'] as int? ?? 0,
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
        lastCheckInAt: map['lastCheckInAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['lastCheckInAt'] as int)
            : null,
      );

  /// 今天是否需要打卡
  bool get isScheduledToday {
    if (!isActive) return false;
    final weekday = DateTime.now().weekday; // 1=周一...7=周日
    switch (frequency) {
      case HabitFrequency.daily:
        return true;
      case HabitFrequency.weekdays:
        return weekday <= 5;
      case HabitFrequency.weekends:
        return weekday >= 6;
      case HabitFrequency.weekly:
        // 默认周一
        return weekday == 1;
      case HabitFrequency.custom:
        return customDays.contains(weekday);
    }
  }

  /// 今天是否已打卡（需要传入今天的打卡记录判断）
  bool isTodayCheckedIn(DateTime? lastCheckIn) {
    if (lastCheckIn == null) return false;
    final now = DateTime.now();
    return lastCheckIn.year == now.year &&
        lastCheckIn.month == now.month &&
        lastCheckIn.day == now.day;
  }

  /// 目标显示文本
  String get goalDescription {
    switch (goalType) {
      case HabitGoalType.boolean:
        return '完成即可';
      case HabitGoalType.count:
        return '目标 ${goalValue.toInt()} ${goalUnit.isNotEmpty ? goalUnit : "次"}';
      case HabitGoalType.duration:
        return '目标 ${goalValue.toInt()} 分钟';
    }
  }
}
