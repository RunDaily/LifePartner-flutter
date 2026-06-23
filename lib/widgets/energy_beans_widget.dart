import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/energy_beans.dart';
import '../providers/energy_provider.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────
//  AI 能量豆 UI 组件集合
//
//  包含：
//  · EnergyBeansBar      - 顶部横条（用于个人中心页展示）
//  · EnergyBeansChip     - 紧凑徽章（用于 AppBar 或列表项）
//  · EnergyBeansPanel    - 详情面板（展示余量/补充/规则）
// ─────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────
//  EnergyBeansChip  —  紧凑徽章（AppBar / 顶部展示）
// ─────────────────────────────────────────────────────────────────

class EnergyBeansChip extends StatelessWidget {
  /// 点击回调（弹出详情面板）
  final VoidCallback? onTap;

  const EnergyBeansChip({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Consumer<EnergyProvider>(
      builder: (context, ep, _) {
        final count = ep.current;
        final isEmpty = count <= 0;
        return GestureDetector(
          onTap: onTap ??
              () => _showEnergyBeansPanel(context),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isEmpty
                  ? (isDark
                      ? const Color(0xFF2A2A2A)
                      : const Color(0xFFF5F5F5))
                  : AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isEmpty
                    ? (isDark
                        ? const Color(0xFF444444)
                        : const Color(0xFFE0E0E0))
                    : AppColors.primary
                        .withValues(alpha: isDark ? 0.3 : 0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '⚡',
                  style: TextStyle(fontSize: isEmpty ? 12 : 13),
                ),
                const SizedBox(width: 4),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isEmpty
                        ? (isDark
                            ? const Color(0xFF555555)
                            : const Color(0xFFBBBBBB))
                        : AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  EnergyBeansBar  —  条形展示（个人中心/我的页面使用）
// ─────────────────────────────────────────────────────────────────

class EnergyBeansBar extends StatelessWidget {
  const EnergyBeansBar({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Consumer<EnergyProvider>(
      builder: (context, ep, _) {
        final count = ep.current;
        final canClaim = ep.canClaimDailyReward;

        return GestureDetector(
          onTap: () => _showEnergyBeansPanel(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E1A2E)
                  : const Color(0xFFF8F5FF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.1),
              ),
            ),
            child: Row(
              children: [
                // 图标
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text('⚡', style: TextStyle(fontSize: 20)),
                  ),
                ),
                const SizedBox(width: 14),
                // 文字信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI 能量豆',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '剩余 $count 颗 · 每次AI评论消耗 $kCommentCostBeans 颗',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? const Color(0xFF888888)
                              : const Color(0xFF999999),
                        ),
                      ),
                    ],
                  ),
                ),
                // 每日领取徽章
                if (canClaim)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryLight],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '领取 +3',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  )
                else
                  Text(
                    '查看详情',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primary.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  EnergyBeansPanel  —  底部详情面板（点击入口后弹出）
// ─────────────────────────────────────────────────────────────────

/// 显示能量豆详情面板（底部弹出）
void _showEnergyBeansPanel(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _EnergyBeansPanelSheet(),
  );
}

/// 从外部可调用的入口函数
void showEnergyBeansPanel(BuildContext context) =>
    _showEnergyBeansPanel(context);

class _EnergyBeansPanelSheet extends StatelessWidget {
  const _EnergyBeansPanelSheet();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1628) : Colors.white,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 顶部拖拽指示条
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF333333)
                    : const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Consumer<EnergyProvider>(
                builder: (context, ep, _) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── 标题 & 余量大数字 ────────────────────────
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primary,
                                  AppColors.primaryLight,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Center(
                              child: Text('⚡',
                                  style: TextStyle(fontSize: 22)),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'AI 能量豆',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '用于手动触发 AI 评论',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? const Color(0xFF888888)
                                      : const Color(0xFF999999),
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          // 当前余量大数字
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${ep.current}',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  color: ep.current > 0
                                      ? AppColors.primary
                                      : (isDark
                                          ? const Color(0xFF555555)
                                          : const Color(0xFFCCCCCC)),
                                ),
                              ),
                              Text(
                                '/ $kMaxBeans',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? const Color(0xFF555555)
                                      : const Color(0xFFCCCCCC),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // ── 进度条 ────────────────────────────────────
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (ep.current / kMaxBeans).clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: isDark
                              ? const Color(0xFF2A2A2A)
                              : const Color(0xFFF0EDFF),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            ep.current > 0
                                ? AppColors.primary
                                : const Color(0xFFCCCCCC),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── 每日领取区 ────────────────────────────────
                      _DailyRewardCard(ep: ep, isDark: isDark),

                      const SizedBox(height: 16),

                      // ── 规则说明 ──────────────────────────────────
                      _RulesCard(isDark: isDark),

                      const SizedBox(height: 16),

                      // ── 统计信息 ──────────────────────────────────
                      _StatsRow(ep: ep, isDark: isDark),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 每日领取卡片 ─────────────────────────────────────────────────

class _DailyRewardCard extends StatelessWidget {
  final EnergyProvider ep;
  final bool isDark;

  const _DailyRewardCard({required this.ep, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final canClaim = ep.canClaimDailyReward;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: canClaim
            ? AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.07)
            : (isDark ? const Color(0xFF222222) : const Color(0xFFF8F8F8)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: canClaim
              ? AppColors.primary.withValues(alpha: isDark ? 0.3 : 0.2)
              : (isDark
                  ? const Color(0xFF333333)
                  : const Color(0xFFEEEEEE)),
        ),
      ),
      child: Row(
        children: [
          Text(
            canClaim ? '🌟' : '✅',
            style: const TextStyle(fontSize: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  canClaim ? '今日能量豆可领取' : '今日已领取',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: canClaim
                        ? AppColors.primary
                        : (isDark
                            ? const Color(0xFF777777)
                            : const Color(0xFF999999)),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  canClaim
                      ? '每天补充 +$kDailyRewardBeans 颗，坚持使用每天都有'
                      : '明天再来领取，保持记录习惯 💪',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? const Color(0xFF666666)
                        : const Color(0xFFAAAAAA),
                  ),
                ),
              ],
            ),
          ),
          if (canClaim)
            GestureDetector(
              onTap: () async {
                final success = await ep.claimDailyReward();
                if (success && context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Text('🌟 '),
                          Text('已领取今日 +$kDailyRewardBeans 颗能量豆！'),
                        ],
                      ),
                      duration: const Duration(seconds: 2),
                      backgroundColor: AppColors.primary,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryLight],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '+$kDailyRewardBeans 领取',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── 规则说明卡片 ─────────────────────────────────────────────────

class _RulesCard extends StatelessWidget {
  final bool isDark;

  const _RulesCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final rules = [
      ('🤖', '触发 AI 评论', '消耗 $kCommentCostBeans 颗'),
      ('🌟', '每日自动补充', '每天 +$kDailyRewardBeans 颗'),
      ('🎁', '新手礼包', '首次赠送 $kInitialBeans 颗'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFAF9FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? const Color(0xFF2A2A2A)
              : const Color(0xFFF0EDFF),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '能量豆规则',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? const Color(0xFF888888)
                  : const Color(0xFF999999),
            ),
          ),
          const SizedBox(height: 10),
          ...rules.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Text(r.$1, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      r.$2,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? const Color(0xFFCCCCCC)
                            : const Color(0xFF444444),
                      ),
                    ),
                  ),
                  Text(
                    r.$3,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 底部统计行 ────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final EnergyProvider ep;
  final bool isDark;

  const _StatsRow({required this.ep, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatItem(
          emoji: '📊',
          label: '累计获得',
          value: '${ep.state.totalEarned}',
          isDark: isDark,
        ),
        const SizedBox(width: 12),
        _StatItem(
          emoji: '✨',
          label: '累计消耗',
          value: '${ep.state.totalConsumed}',
          isDark: isDark,
        ),
        const SizedBox(width: 12),
        _StatItem(
          emoji: '🔢',
          label: '生成次数',
          value: '${ep.state.totalConsumed ~/ kCommentCostBeans}',
          isDark: isDark,
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;
  final bool isDark;

  const _StatItem({
    required this.emoji,
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFAF9FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? const Color(0xFF2A2A2A)
                : const Color(0xFFF0EDFF),
          ),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isDark
                    ? const Color(0xFF666666)
                    : const Color(0xFFBBBBBB),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
