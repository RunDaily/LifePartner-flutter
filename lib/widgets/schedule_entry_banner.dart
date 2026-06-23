import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/checklist_provider.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────
//  ScheduleEntryBanner —— 日程入口横条（公共 Widget）
//
//  两种模式：
//
//  1. showStats = true（清单模块）
//     展示今日数量、逾期数量等实时数据，通过 Consumer 读取 provider。
//     适合 ChecklistScreen，让用户一眼看到今天有多少事情要做。
//
//  2. showStats = false（规划模块）
//     简洁的"日程"入口，不依赖 provider，仅作为跳转触发器。
//     适合 PlanScreen，以紧凑的横条形式嵌入到 TabBar 之上。
//
//  两种模式的视觉语言保持统一（渐变背景、边框、圆角、图标、箭头）。
// ─────────────────────────────────────────────────────────────────

class ScheduleEntryBanner extends StatelessWidget {
  /// 主色调（来自当前主题 / DayPalette）
  final Color primary;

  /// 是否深色模式
  final bool isDark;

  /// 点击回调（通常是 Navigator.push 到 ScheduleScreen）
  final VoidCallback onTap;

  /// true = 读取 ChecklistProvider 展示今日/逾期数量
  /// false = 仅展示简洁文字（不依赖 provider）
  final bool showStats;

  /// showStats = false 时展示的副标题文字
  final String? subtitle;

  const ScheduleEntryBanner({
    super.key,
    required this.primary,
    required this.isDark,
    required this.onTap,
    this.showStats = true,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    if (showStats) {
      return Consumer<ChecklistProvider>(
        builder: (_, provider, __) => _buildBanner(
          context,
          todayCount: provider.todayChecklists.length,
          overdueCount: provider.overdueChecklists.length,
          scheduledCount: provider.scheduledTemporalChecklists.length,
          pendingItems: provider.todayPendingItemCount,
        ),
      );
    }
    return _buildBanner(context);
  }

  Widget _buildBanner(
    BuildContext context, {
    int todayCount = 0,
    int overdueCount = 0,
    int scheduledCount = 0,
    int pendingItems = 0,
  }) {
    // ── 副标题文字 ─────────────────────────────────────────────
    String subtitleText;
    if (!showStats) {
      subtitleText = subtitle ?? '查看并安排执行日程';
    } else if (scheduledCount == 0) {
      subtitleText = '点击规划今日与本周的任务';
    } else {
      final parts = <String>[];
      if (todayCount > 0) parts.add('今天 $todayCount 个');
      if (overdueCount > 0) parts.add('逾期 $overdueCount 个');
      if (parts.isEmpty) parts.add('共 $scheduledCount 个日程');
      subtitleText = parts.join(' · ');
    }

    // ── 外层容器尺寸适配（showStats 时略高） ──────────────────
    final verticalPadding = showStats ? 14.0 : 10.0;
    final margin = showStats
        ? const EdgeInsets.fromLTRB(16, 4, 16, 0)
        : const EdgeInsets.fromLTRB(16, 4, 16, 4);

    return Padding(
      padding: margin,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: verticalPadding),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primary.withValues(alpha: isDark ? 0.18 : 0.1),
                primary.withValues(alpha: isDark ? 0.08 : 0.04),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: primary.withValues(alpha: isDark ? 0.25 : 0.15),
            ),
          ),
          child: Row(
            children: [
              // ── 左侧图标 ──────────────────────────────────────
              Container(
                width: showStats ? 44 : 36,
                height: showStats ? 44 : 36,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(showStats ? 12 : 10),
                ),
                child: Center(
                  child: Text(
                    '📅',
                    style: TextStyle(fontSize: showStats ? 22 : 18),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // ── 中间文字 ──────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '日程',
                          style: TextStyle(
                            fontSize: showStats ? 16 : 15,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1A1410),
                          ),
                        ),
                        // 未完成条目 badge（仅 showStats 模式）
                        if (showStats && pendingItems > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$pendingItems 项待做',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                        // 逾期警告 badge（仅 showStats 模式）
                        if (showStats && overdueCount > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6B6B)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '逾期 $overdueCount',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFE05555),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitleText,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textTertiaryDark
                            : const Color(0xFF888888),
                      ),
                    ),
                  ],
                ),
              ),

              // ── 右侧箭头 ──────────────────────────────────────
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
                color: primary.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
