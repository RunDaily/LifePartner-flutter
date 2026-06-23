// ─────────────────────────────────────────────────────────────────
//  AI 能量豆系统
//
//  产品设计：
//  · 用户拥有虚拟资产「AI 能量豆」，用于手动触发 AI 评论
//  · 每次手动触发 AI 评论消耗 1 颗能量豆
//  · 新用户初始赠送 10 颗，作为体验额度
//  · 每日自动补充（签到/自然恢复）+ 特殊行为奖励
//  · 能量豆耗尽时，展示充值/获取途径的引导
// ─────────────────────────────────────────────────────────────────

/// AI 能量豆状态数据模型（不可变值对象）
class EnergyBeansState {
  /// 当前剩余能量豆数量
  final int current;

  /// 今日已领取的每日奖励（防重复领取）
  final bool dailyRewardClaimed;

  /// 今日每日奖励领取日期（格式：yyyy-MM-dd）
  final String? dailyRewardDate;

  /// 累计消耗总数（用于统计）
  final int totalConsumed;

  /// 累计获得总数（用于统计）
  final int totalEarned;

  /// 最后一次消耗时间（ISO 8601）
  final String? lastConsumedAt;

  const EnergyBeansState({
    this.current = kInitialBeans,
    this.dailyRewardClaimed = false,
    this.dailyRewardDate,
    this.totalConsumed = 0,
    this.totalEarned = kInitialBeans,
    this.lastConsumedAt,
  });

  EnergyBeansState copyWith({
    int? current,
    bool? dailyRewardClaimed,
    String? dailyRewardDate,
    int? totalConsumed,
    int? totalEarned,
    String? lastConsumedAt,
  }) =>
      EnergyBeansState(
        current: current ?? this.current,
        dailyRewardClaimed: dailyRewardClaimed ?? this.dailyRewardClaimed,
        dailyRewardDate: dailyRewardDate ?? this.dailyRewardDate,
        totalConsumed: totalConsumed ?? this.totalConsumed,
        totalEarned: totalEarned ?? this.totalEarned,
        lastConsumedAt: lastConsumedAt ?? this.lastConsumedAt,
      );

  Map<String, dynamic> toMap() => {
        'current': current,
        'dailyRewardClaimed': dailyRewardClaimed,
        'dailyRewardDate': dailyRewardDate,
        'totalConsumed': totalConsumed,
        'totalEarned': totalEarned,
        'lastConsumedAt': lastConsumedAt,
      };

  factory EnergyBeansState.fromMap(Map<String, dynamic> map) =>
      EnergyBeansState(
        current: (map['current'] as int?) ?? kInitialBeans,
        dailyRewardClaimed: (map['dailyRewardClaimed'] as bool?) ?? false,
        dailyRewardDate: map['dailyRewardDate'] as String?,
        totalConsumed: (map['totalConsumed'] as int?) ?? 0,
        totalEarned: (map['totalEarned'] as int?) ?? kInitialBeans,
        lastConsumedAt: map['lastConsumedAt'] as String?,
      );
}

// ─────────────────────────────────────────────────────────────────
//  能量豆规则常量
// ─────────────────────────────────────────────────────────────────

/// 新用户初始赠送能量豆数量
const int kInitialBeans = 10;

/// 每次触发 AI 评论消耗的能量豆数量
const int kCommentCostBeans = 1;

/// 每日签到/自然恢复补充量
const int kDailyRewardBeans = 3;

/// 能量豆存储上限（防止无限囤积）
const int kMaxBeans = 99;

// ─────────────────────────────────────────────────────────────────
//  能量豆变动事件类型（用于 UI 反馈动画）
// ─────────────────────────────────────────────────────────────────

/// 能量豆变动来源
enum EnergyBeansEvent {
  /// 触发 AI 评论（-1 豆）
  aiComment('ai_comment', '生成AI评论', -kCommentCostBeans, '🤖'),

  /// 每日自然恢复（+3 豆）
  dailyRestore('daily_restore', '每日补充', kDailyRewardBeans, '🌟'),

  /// 新用户初始赠送（+10 豆）
  welcome('welcome', '新手礼包', kInitialBeans, '🎁'),

  /// 写日记奖励 - 累计满足条件时赠送
  writeReward('write_reward', '写作奖励', 2, '✍️'),

  /// 分享/其他奖励（预留扩展）
  bonusReward('bonus_reward', '活动奖励', 5, '🎉');

  const EnergyBeansEvent(
    this.value,
    this.label,
    this.delta,
    this.emoji,
  );

  final String value;
  final String label;
  final int delta; // 正数=获得，负数=消耗
  final String emoji;
}
