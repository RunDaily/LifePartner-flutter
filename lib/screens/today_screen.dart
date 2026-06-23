import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/record.dart';
import '../models/habit.dart';
import '../models/checklist.dart';
import '../providers/record_provider.dart';
import '../providers/habit_provider.dart';
import '../providers/checklist_provider.dart';
import '../providers/user_profile_provider.dart';
import '../theme/app_theme.dart';
import 'checklist_detail_screen.dart';
import 'quick_capture_sheet.dart';
import 'me_screen.dart';

// ─────────────────────────────────────────────────────────────────
//  TodayScreen —— 今天视图（混合时间线）
//
//  展示今天所有发生的一切：
//  1. 习惯打卡区（横向卡片，快速打卡）
//  2. 混合时间线（日程 / 任务 / 活动 / 心情 —— 统一时间流）
//
//  设计哲学：
//  "今天"不只是待办清单，而是生活的全景快照。
//  用户打开今天页，应该能回答："我今天计划了什么？做了什么？感受如何？"
// ─────────────────────────────────────────────────────────────────

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final recordProvider = context.read<RecordProvider>();
    final habitProvider = context.read<HabitProvider>();
    final checklistProvider = context.read<ChecklistProvider>();
    await Future.wait([
      recordProvider.loadTodayData(),
      habitProvider.loadHabits(),
      checklistProvider.loadChecklists(),
    ]);
    final checkedIds = recordProvider.todayHabitLogs
        .map((r) => r.habitId)
        .whereType<String>()
        .toSet();
    if (mounted) {
      context.read<HabitProvider>().syncTodayCheckIns(checkedIds);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final palette = WeeklyTheme.getLightPalette(now);

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : palette.background,
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: isDark ? AppColors.darkPrimary : palette.primary,
        child: CustomScrollView(
          slivers: [
            _buildAppBar(context, isDark, palette, now),
            _buildHabitSection(context, isDark, palette),
            _buildTodayChecklistSection(context, isDark, palette),
            _buildTimelineSectionHeader(isDark, palette),
            _buildTimeline(context, isDark, palette),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────
  Widget _buildAppBar(
      BuildContext context, bool isDark, DayPalette palette, DateTime now) {
    final weekdayNames = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final weekday = weekdayNames[now.weekday - 1];
    final dateStr = '${now.month}月${now.day}日 $weekday';

    return SliverAppBar(
      floating: true,
      backgroundColor: isDark ? AppColors.backgroundDark : palette.background,
      elevation: 0,
      expandedHeight: 100,
      // 左上角：圆形头像（点击进入「我的」）
      leading: Padding(
        padding: const EdgeInsets.only(left: 14, top: 8, bottom: 8),
        child: _AvatarButton(
          isDark: isDark,
          palette: palette,
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MeScreen()),
            );
          },
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(60, 0, 20, 16),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '今天',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF1A1410),
              ),
            ),
            Text(
              dateStr,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: isDark
                    ? const Color(0xFF888888)
                    : palette.primary.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
      actions: [
        // 今日小结按钮
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Consumer<RecordProvider>(
            builder: (ctx, rp, _) {
              return _DaySummaryBadge(
                scheduleCount: rp.todaySchedules.length,
                taskDoneCount: rp.todayTasks.where((t) => t.isCompleted).length,
                taskTotal: rp.todayTasks.length,
                eventCount: rp.todayEvents.length,
                isDark: isDark,
                palette: palette,
              );
            },
          ),
        ),
      ],
    );
  }

  // ── 习惯打卡区域 ──────────────────────────────────────────────
  Widget _buildHabitSection(
      BuildContext context, bool isDark, DayPalette palette) {
    return Consumer2<HabitProvider, RecordProvider>(
      builder: (ctx, habitProvider, recordProvider, _) {
        final todayHabits = habitProvider.todayHabits;

        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section 标题行
                Row(
                  children: [
                    _SectionIcon(
                      icon: Icons.loop_rounded,
                      color: isDark ? AppColors.darkPrimary : palette.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '习惯',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1A1410),
                      ),
                    ),
                    const Spacer(),
                    if (todayHabits.isNotEmpty)
                      _CompletionChip(
                        done: habitProvider.todayCheckedCount,
                        total: habitProvider.todayTotalCount,
                        color: isDark ? AppColors.darkPrimary : palette.primary,
                      ),
                    const SizedBox(width: 8),
                    // 快速添加习惯按钮
                    GestureDetector(
                      onTap: () => _showAddHabitSheet(context, isDark, palette),
                      child: Icon(
                        Icons.add_circle_outline_rounded,
                        size: 18,
                        color: isDark
                            ? const Color(0xFF666666)
                            : const Color(0xFFCCCCCC),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // 习惯卡片横向滚动
                if (todayHabits.isEmpty)
                  _EmptyHabitPrompt(isDark: isDark, palette: palette)
                else
                  SizedBox(
                    height: 90,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: todayHabits.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (ctx, i) => _HabitCard(
                        habit: todayHabits[i],
                        isChecked:
                            habitProvider.isTodayCheckedIn(todayHabits[i].id),
                        isDark: isDark,
                        palette: palette,
                        onTap: () => _onHabitTap(
                          context,
                          todayHabits[i],
                          habitProvider.isTodayCheckedIn(todayHabits[i].id),
                          habitProvider,
                          recordProvider,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _onHabitTap(
    BuildContext context,
    Habit habit,
    bool isChecked,
    HabitProvider habitProvider,
    RecordProvider recordProvider,
  ) async {
    HapticFeedback.lightImpact();
    if (isChecked) {
      await recordProvider.undoTodayCheckIn(habit.id);
      await habitProvider.onUndoCheckIn(habit.id);
    } else {
      await recordProvider.checkInHabit(habitId: habit.id);
      await habitProvider.onCheckIn(habit.id);
    }
  }

  // ── 今日清单区域 ──────────────────────────────────────────────
  Widget _buildTodayChecklistSection(
      BuildContext context, bool isDark, DayPalette palette) {
    return Consumer<ChecklistProvider>(
      builder: (ctx, checklistProvider, _) {
        final todayLists = checklistProvider.todayChecklists;
        if (todayLists.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

        final accentColor = isDark ? AppColors.darkPrimary : palette.primary;

        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section 标题行
                Row(
                  children: [
                    _SectionIcon(
                      icon: Icons.checklist_rounded,
                      color: accentColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '今日清单',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1A1410),
                      ),
                    ),
                    const Spacer(),
                    // 总体完成进度
                    _TodayChecklistProgress(
                        lists: todayLists, color: accentColor),
                  ],
                ),
                const SizedBox(height: 10),
                // 清单列表（纵向展开）
                ...todayLists.map(
                  (cl) => _TodayChecklistCard(
                    checklist: cl,
                    isDark: isDark,
                    accentColor: accentColor,
                    onToggleItem: (itemId) {
                      checklistProvider.toggleItem(cl.id, itemId);
                    },
                    onOpenDetail: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ChecklistDetailScreen(checklistId: cl.id),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── 时间线标题 ───────────────────────────────────────────────
  Widget _buildTimelineSectionHeader(bool isDark, DayPalette palette) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Row(
          children: [
            _SectionIcon(
              icon: Icons.timeline_rounded,
              color: isDark ? AppColors.darkPrimary : palette.primary,
            ),
            const SizedBox(width: 8),
            Text(
              '今日动态',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1A1410),
              ),
            ),
            const Spacer(),
            // 快速添加按钮
            GestureDetector(
              onTap: () => QuickCaptureSheet.show(context),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.darkPrimary : palette.primary)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_rounded,
                      size: 13,
                      color: isDark ? AppColors.darkPrimary : palette.primary,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '记录',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            isDark ? AppColors.darkPrimary : palette.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 混合时间线 ────────────────────────────────────────────────
  Widget _buildTimeline(
      BuildContext context, bool isDark, DayPalette palette) {
    return Consumer<RecordProvider>(
      builder: (ctx, recordProvider, _) {
        // 合并：日程 + 任务 + 活动 + 今日心情 + 今日打卡
        final allItems = _buildTimelineItems(recordProvider);

        if (allItems.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: _EmptyTimeline(isDark: isDark, palette: palette),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => _TimelineItem(
                item: allItems[i],
                isDark: isDark,
                palette: palette,
                isFirst: i == 0,
                isLast: i == allItems.length - 1,
                onToggle: allItems[i].record != null
                    ? () => recordProvider
                        .toggleComplete(allItems[i].record!.id)
                    : null,
              ),
              childCount: allItems.length,
            ),
          ),
        );
      },
    );
  }

  List<_TodayTimelineEntry> _buildTimelineItems(RecordProvider rp) {
    final items = <_TodayTimelineEntry>[];

    // 日程（有具体时间）
    for (final r in rp.todaySchedules) {
      items.add(_TodayTimelineEntry(
        record: r,
        category: _TimelineCategory.schedule,
        time: r.scheduledAt,
      ));
    }

    // 任务（today 相关，按 deadline/scheduledAt 排序）
    for (final r in rp.todayTasks) {
      items.add(_TodayTimelineEntry(
        record: r,
        category: _TimelineCategory.task,
        time: r.scheduledAt ?? r.deadline,
      ));
    }

    // 活动（今日事件）
    for (final r in rp.todayEvents) {
      items.add(_TodayTimelineEntry(
        record: r,
        category: _TimelineCategory.event,
        time: r.scheduledAt ?? r.createdAt,
      ));
    }

    // 今日打卡记录
    for (final r in rp.todayHabitLogs) {
      items.add(_TodayTimelineEntry(
        record: r,
        category: _TimelineCategory.habitLog,
        time: r.createdAt,
      ));
    }

    // 今日心情记录
    for (final r in rp.todayMoods) {
      items.add(_TodayTimelineEntry(
        record: r,
        category: _TimelineCategory.mood,
        time: r.createdAt,
      ));
    }

    // 按时间排序（有时间的在前，按时间升序；无时间的按创建时间）
    items.sort((a, b) {
      final ta = a.time;
      final tb = b.time;
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return ta.compareTo(tb);
    });

    return items;
  }

  // ── 添加习惯提示弹窗 ─────────────────────────────────────────
  void _showAddHabitSheet(
      BuildContext context, bool isDark, DayPalette palette) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _AddHabitSheet(isDark: isDark, palette: palette),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  今日时间线数据结构
// ─────────────────────────────────────────────────────────────────

enum _TimelineCategory { schedule, task, event, habitLog, mood }

class _TodayTimelineEntry {
  final Record? record;
  final _TimelineCategory category;
  final DateTime? time;

  const _TodayTimelineEntry({
    this.record,
    required this.category,
    this.time,
  });
}

// ─────────────────────────────────────────────────────────────────
//  时间线条目组件
// ─────────────────────────────────────────────────────────────────

class _TimelineItem extends StatelessWidget {
  final _TodayTimelineEntry item;
  final bool isDark;
  final DayPalette palette;
  final bool isFirst;
  final bool isLast;
  final VoidCallback? onToggle;

  const _TimelineItem({
    required this.item,
    required this.isDark,
    required this.palette,
    required this.isFirst,
    required this.isLast,
    this.onToggle,
  });

  Color get _categoryColor {
    switch (item.category) {
      case _TimelineCategory.schedule:
        return const Color(0xFF4A90D9);
      case _TimelineCategory.task:
        return const Color(0xFF27AE60);
      case _TimelineCategory.event:
        return const Color(0xFFE07818);
      case _TimelineCategory.habitLog:
        return const Color(0xFF9B59B6);
      case _TimelineCategory.mood:
        return const Color(0xFFE74C3C);
    }
  }

  IconData get _categoryIcon {
    switch (item.category) {
      case _TimelineCategory.schedule:
        return Icons.calendar_today_rounded;
      case _TimelineCategory.task:
        return Icons.check_circle_outline_rounded;
      case _TimelineCategory.event:
        return Icons.bolt_rounded;
      case _TimelineCategory.habitLog:
        return Icons.loop_rounded;
      case _TimelineCategory.mood:
        return Icons.favorite_border_rounded;
    }
  }

  String get _categoryLabel {
    switch (item.category) {
      case _TimelineCategory.schedule:
        return '日程';
      case _TimelineCategory.task:
        return '任务';
      case _TimelineCategory.event:
        return '活动';
      case _TimelineCategory.habitLog:
        return '打卡';
      case _TimelineCategory.mood:
        return '心情';
    }
  }

  @override
  Widget build(BuildContext context) {
    final record = item.record;
    if (record == null) return const SizedBox.shrink();

    final timeStr = item.time != null
        ? '${item.time!.hour.toString().padLeft(2, '0')}:${item.time!.minute.toString().padLeft(2, '0')}'
        : '';

    final isCompleted = record.isCompleted;
    final canToggle = record.type.hasCompletionState;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 时间轴左侧
          SizedBox(
            width: 52,
            child: Column(
              children: [
                // 时间文字
                if (timeStr.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      timeStr,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? const Color(0xFF888888)
                            : const Color(0xFFAAAAAA),
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 12),
                // 时间轴线
                Expanded(
                  child: Center(
                    child: Column(
                      children: [
                        if (!isFirst)
                          Container(
                            width: 1.5,
                            height: 8,
                            color: isDark
                                ? const Color(0xFF333333)
                                : const Color(0xFFE0E0E0),
                          ),
                        // 节点圆点
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isCompleted
                                ? _categoryColor
                                : _categoryColor.withValues(alpha: 0.3),
                            border: Border.all(
                              color: _categoryColor,
                              width: 1.5,
                            ),
                          ),
                        ),
                        if (!isLast)
                          Expanded(
                            child: Container(
                              width: 1.5,
                              color: isDark
                                  ? const Color(0xFF333333)
                                  : const Color(0xFFE0E0E0),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // 卡片内容
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                top: 8,
                bottom: isLast ? 8 : 6,
              ),
              child: _TimelineCard(
                record: record,
                categoryColor: _categoryColor,
                categoryIcon: _categoryIcon,
                categoryLabel: _categoryLabel,
                isDark: isDark,
                isCompleted: isCompleted,
                canToggle: canToggle,
                onToggle: onToggle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  时间线卡片
// ─────────────────────────────────────────────────────────────────

class _TimelineCard extends StatelessWidget {
  final Record record;
  final Color categoryColor;
  final IconData categoryIcon;
  final String categoryLabel;
  final bool isDark;
  final bool isCompleted;
  final bool canToggle;
  final VoidCallback? onToggle;

  const _TimelineCard({
    required this.record,
    required this.categoryColor,
    required this.categoryIcon,
    required this.categoryLabel,
    required this.isDark,
    required this.isCompleted,
    required this.canToggle,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted
              ? categoryColor.withValues(alpha: 0.15)
              : categoryColor.withValues(alpha: 0.12),
          width: 1,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: Row(
        children: [
          // 类型图标
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: categoryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(categoryIcon, size: 14, color: categoryColor),
          ),
          const SizedBox(width: 10),
          // 内容
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // 类型标签
                    Text(
                      categoryLabel,
                      style: TextStyle(
                        fontSize: 10,
                        color: categoryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (record.type == RecordType.habitLog &&
                        record.habitId != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        '· 已打卡',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark
                              ? Colors.white38
                              : const Color(0xFFBBBBBB),
                        ),
                      ),
                    ],
                    if (record.isOverdue) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE74C3C).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text(
                          '逾期',
                          style: TextStyle(
                            fontSize: 9,
                            color: Color(0xFFE74C3C),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _displayText,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isCompleted
                        ? (isDark ? Colors.white38 : Colors.black26)
                        : (isDark ? Colors.white : const Color(0xFF1A1410)),
                    decoration:
                        isCompleted ? TextDecoration.lineThrough : null,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                // 心情 / 标签
                if (record.mood != null || record.tags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        if (record.mood != null)
                          Text(
                            _moodEmoji(record.mood!),
                            style: const TextStyle(fontSize: 12),
                          ),
                        if (record.tags.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          ...record.tags.take(2).map((tag) => Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Text(
                                  '#$tag',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? Colors.white38
                                        : const Color(0xFFBBBBBB),
                                  ),
                                ),
                              )),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // 完成状态按钮
          if (canToggle)
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onToggle?.call();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted ? categoryColor : Colors.transparent,
                  border: Border.all(color: categoryColor, width: 2),
                ),
                child: isCompleted
                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                    : null,
              ),
            ),
        ],
      ),
    );
  }

  String get _displayText {
    if (record.type == RecordType.habitLog) {
      return record.content.isNotEmpty ? record.content : '完成习惯打卡';
    }
    if (record.type == RecordType.mood) {
      return record.content.isNotEmpty
          ? record.content
          : '记录了心情 ${_moodEmoji(record.mood ?? '')}';
    }
    return record.preview;
  }

  String _moodEmoji(String mood) {
    const map = {
      'happy': '😊',
      'excited': '🤩',
      'neutral': '😐',
      'touched': '🥹',
      'sad': '😢',
      'angry': '😠',
      'anxious': '😰',
      'tired': '😪',
    };
    return map[mood] ?? '😊';
  }
}

// ─────────────────────────────────────────────────────────────────
//  空状态
// ─────────────────────────────────────────────────────────────────

class _EmptyTimeline extends StatelessWidget {
  final bool isDark;
  final DayPalette palette;

  const _EmptyTimeline({required this.isDark, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            '✨',
            style: const TextStyle(fontSize: 36),
          ),
          const SizedBox(height: 12),
          Text(
            '今天还什么都没有',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : const Color(0xFF999999),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '点击右上角「记录」，开始记录今天的第一件事',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white30 : const Color(0xFFBBBBBB),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _EmptyHabitPrompt extends StatelessWidget {
  final bool isDark;
  final DayPalette palette;

  const _EmptyHabitPrompt({required this.isDark, required this.palette});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => _AddHabitSheet(isDark: isDark, palette: palette),
        );
      },
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? const Color(0xFF333333)
                : const Color(0xFFEEEEEE),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_circle_outline_rounded,
              size: 16,
              color: isDark ? AppColors.darkPrimary : palette.primary,
            ),
            const SizedBox(width: 6),
            Text(
              '添加今日习惯计划',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkPrimary : palette.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  今日小结徽章
// ─────────────────────────────────────────────────────────────────

class _DaySummaryBadge extends StatelessWidget {
  final int scheduleCount;
  final int taskDoneCount;
  final int taskTotal;
  final int eventCount;
  final bool isDark;
  final DayPalette palette;

  const _DaySummaryBadge({
    required this.scheduleCount,
    required this.taskDoneCount,
    required this.taskTotal,
    required this.eventCount,
    required this.isDark,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    // 只在有内容时展示
    if (scheduleCount == 0 && taskTotal == 0 && eventCount == 0) {
      return const SizedBox.shrink();
    }

    final parts = <String>[];
    if (scheduleCount > 0) parts.add('$scheduleCount 日程');
    if (taskTotal > 0) parts.add('$taskDoneCount/$taskTotal 任务');
    if (eventCount > 0) parts.add('$eventCount 活动');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (isDark ? AppColors.darkPrimary : palette.primary)
            .withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        parts.join(' · '),
        style: TextStyle(
          fontSize: 11,
          color: isDark ? AppColors.darkPrimary : palette.primary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  习惯卡片
// ─────────────────────────────────────────────────────────────────

class _HabitCard extends StatelessWidget {
  final Habit habit;
  final bool isChecked;
  final bool isDark;
  final DayPalette palette;
  final VoidCallback onTap;

  const _HabitCard({
    required this.habit,
    required this.isChecked,
    required this.isDark,
    required this.palette,
    required this.onTap,
  });

  Color get _color {
    try {
      final hex = habit.colorHex.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF27AE60);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 80,
        decoration: BoxDecoration(
          color: isChecked
              ? _color
              : (isDark ? AppColors.surfaceDark : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isChecked ? _color : _color.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: isChecked
              ? [
                  BoxShadow(
                    color: _color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              habit.emoji,
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                habit.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isChecked
                      ? Colors.white
                      : (isDark ? Colors.white70 : const Color(0xFF333333)),
                ),
              ),
            ),
            if (habit.currentStreak > 0) ...[
              const SizedBox(height: 2),
              Text(
                '🔥${habit.currentStreak}',
                style: TextStyle(
                  fontSize: 10,
                  color: isChecked ? Colors.white70 : const Color(0xFFFF6B35),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  辅助组件
// ─────────────────────────────────────────────────────────────────

class _SectionIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _SectionIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Icon(icon, size: 14, color: color),
    );
  }
}

class _CompletionChip extends StatelessWidget {
  final int done;
  final int total;
  final Color color;

  const _CompletionChip(
      {required this.done, required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$done/$total',
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  添加习惯底部弹窗（简化版，快速创建）
// ─────────────────────────────────────────────────────────────────

class _AddHabitSheet extends StatefulWidget {
  final bool isDark;
  final DayPalette palette;

  const _AddHabitSheet({required this.isDark, required this.palette});

  @override
  State<_AddHabitSheet> createState() => _AddHabitSheetState();
}

class _AddHabitSheetState extends State<_AddHabitSheet> {
  final _titleController = TextEditingController();
  final _titleFocus = FocusNode();
  String _selectedEmoji = '🔁';
  HabitFrequency _selectedFrequency = HabitFrequency.daily;
  bool _isSaving = false;

  static const _emojiOptions = [
    '🔁', '🏃', '📚', '💪', '🧘', '💧', '🥗', '😴', '✍️', '🎸', '🎨', '🧹',
    '💊', '🌿', '🎯', '⏰',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _titleFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      await context.read<HabitProvider>().addHabit(
            title: title,
            emoji: _selectedEmoji,
            frequency: _selectedFrequency,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isDark = widget.isDark;
    final palette = widget.palette;
    final primaryColor = isDark ? AppColors.darkPrimary : palette.primary;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 拖拽把手
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                '添加习惯',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1A1410),
                ),
              ),
              const SizedBox(height: 16),
              // Emoji 选择
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _emojiOptions.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (ctx, i) {
                    final emoji = _emojiOptions[i];
                    final isSelected = _selectedEmoji == emoji;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedEmoji = emoji),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? primaryColor.withValues(alpha: 0.15)
                              : (isDark
                                  ? const Color(0xFF2A2A2A)
                                  : const Color(0xFFF5F5F5)),
                          borderRadius: BorderRadius.circular(10),
                          border: isSelected
                              ? Border.all(color: primaryColor, width: 1.5)
                              : null,
                        ),
                        child: Center(
                          child: Text(emoji,
                              style: const TextStyle(fontSize: 20)),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              // 习惯名称输入
              TextField(
                controller: _titleController,
                focusNode: _titleFocus,
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white : const Color(0xFF1A1410),
                ),
                decoration: InputDecoration(
                  hintText: '习惯名称，如：每天跑步 30 分钟',
                  hintStyle: TextStyle(
                    color: isDark
                        ? const Color(0xFF555555)
                        : const Color(0xFFCCCCCC),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor:
                      isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              // 频率选择
              Row(
                children: HabitFrequency.values.map((freq) {
                  final isSelected = _selectedFrequency == freq;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _selectedFrequency = freq),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? primaryColor.withValues(alpha: 0.12)
                              : (isDark
                                  ? const Color(0xFF2A2A2A)
                                  : const Color(0xFFF5F5F5)),
                          borderRadius: BorderRadius.circular(20),
                          border: isSelected
                              ? Border.all(color: primaryColor, width: 1.5)
                              : null,
                        ),
                        child: Text(
                          freq.label,
                          style: TextStyle(
                            fontSize: 13,
                            color: isSelected
                                ? primaryColor
                                : (isDark
                                    ? Colors.white60
                                    : const Color(0xFF666666)),
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              // 保存按钮
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          '添加习惯',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  今日清单整体完成进度徽章
// ─────────────────────────────────────────────────────────────────

class _TodayChecklistProgress extends StatelessWidget {
  final List<Checklist> lists;
  final Color color;

  const _TodayChecklistProgress(
      {required this.lists, required this.color});

  @override
  Widget build(BuildContext context) {
    final total = lists.fold<int>(0, (sum, c) => sum + c.totalCount);
    final done = lists.fold<int>(0, (sum, c) => sum + c.checkedCount);
    if (total == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$done/$total',
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  今日清单卡片（在今日 Tab 内直接勾选）
// ─────────────────────────────────────────────────────────────────

class _TodayChecklistCard extends StatefulWidget {
  final Checklist checklist;
  final bool isDark;
  final Color accentColor;
  final ValueChanged<String> onToggleItem;
  final VoidCallback onOpenDetail;

  const _TodayChecklistCard({
    required this.checklist,
    required this.isDark,
    required this.accentColor,
    required this.onToggleItem,
    required this.onOpenDetail,
  });

  @override
  State<_TodayChecklistCard> createState() => _TodayChecklistCardState();
}

class _TodayChecklistCardState extends State<_TodayChecklistCard> {
  // 默认展开未完成的条目，最多显示5条，超出时折叠
  static const _previewLimit = 5;
  bool _expanded = false;

  Color get _color {
    try {
      final hex = widget.checklist.colorHex.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return widget.accentColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cl = widget.checklist;
    final isDark = widget.isDark;
    final items = cl.items;
    // 未完成的条目优先展示
    final unchecked = items.where((i) => !i.isChecked).toList();
    final checked = items.where((i) => i.isChecked).toList();
    final ordered = [...unchecked, ...checked];

    final showItems = _expanded
        ? ordered
        : ordered.take(_previewLimit).toList();
    final hasMore = ordered.length > _previewLimit && !_expanded;

    return GestureDetector(
      onTap: widget.onOpenDetail,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _color.withValues(alpha: 0.18),
            width: 1,
          ),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 清单标题行 ──────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Row(
                children: [
                  Text(
                    cl.emoji,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      cl.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? Colors.white
                            : const Color(0xFF1A1410),
                      ),
                    ),
                  ),
                  // 进度标签
                  if (cl.totalCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: cl.isAllDone
                            ? _color.withValues(alpha: 0.15)
                            : _color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        cl.isAllDone
                            ? '✅ 完成'
                            : '${cl.checkedCount}/${cl.totalCount}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _color,
                        ),
                      ),
                    ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: isDark
                        ? Colors.white24
                        : const Color(0xFFCCCCCC),
                  ),
                ],
              ),
            ),
            // 分割线
            if (items.isNotEmpty)
              Divider(
                height: 1,
                indent: 14,
                endIndent: 14,
                color: isDark
                    ? Colors.white10
                    : Colors.black.withValues(alpha: 0.06),
              ),
            // ── 条目列表 ──────────────────────────────────────
            if (items.isEmpty)
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Text(
                  '暂无条目，点击进入添加',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? Colors.white38
                        : const Color(0xFFBBBBBB),
                  ),
                ),
              )
            else ...[
              ...showItems.map(
                (item) => _ChecklistItemRow(
                  item: item,
                  color: _color,
                  isDark: isDark,
                  onToggle: () {
                    HapticFeedback.lightImpact();
                    widget.onToggleItem(item.id);
                  },
                ),
              ),
              if (hasMore)
                InkWell(
                  onTap: () => setState(() => _expanded = true),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        14, 6, 14, 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.expand_more_rounded,
                          size: 16,
                          color: isDark
                              ? Colors.white38
                              : const Color(0xFFBBBBBB),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '还有 ${ordered.length - _previewLimit} 项',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.white38
                                : const Color(0xFFBBBBBB),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  清单条目行（今日 Tab 内轻量勾选）
// ─────────────────────────────────────────────────────────────────

class _ChecklistItemRow extends StatelessWidget {
  final ChecklistItem item;
  final Color color;
  final bool isDark;
  final VoidCallback onToggle;

  const _ChecklistItemRow({
    required this.item,
    required this.color,
    required this.isDark,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isChecked = item.isChecked;
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            // 勾选圆圈
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isChecked ? color : Colors.transparent,
                border: Border.all(
                  color: isChecked
                      ? color
                      : (isDark
                          ? const Color(0xFF555555)
                          : const Color(0xFFCCCCCC)),
                  width: 1.5,
                ),
              ),
              child: isChecked
                  ? const Icon(Icons.check, size: 11, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.title,
                style: TextStyle(
                  fontSize: 13,
                  color: isChecked
                      ? (isDark
                          ? Colors.white30
                          : const Color(0xFFBBBBBB))
                      : (isDark
                          ? Colors.white70
                          : const Color(0xFF333333)),
                  decoration:
                      isChecked ? TextDecoration.lineThrough : null,
                  decorationColor: isDark
                      ? Colors.white30
                      : const Color(0xFFBBBBBB),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 数量标签（购物场景）
            if (item.quantity != null && item.quantity!.isNotEmpty)
              Text(
                item.quantity!,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? Colors.white38
                      : const Color(0xFFBBBBBB),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  圆形头像按钮（左上角「我的」入口）
// ─────────────────────────────────────────────────────────────────

class _AvatarButton extends StatelessWidget {
  final bool isDark;
  final DayPalette palette;
  final VoidCallback onTap;

  const _AvatarButton({
    required this.isDark,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProfileProvider>(
      builder: (ctx, profileProvider, _) {
        final profile = profileProvider.profile;
        final name = profile.nickname;
        final initial = name.isNotEmpty ? name[0].toUpperCase() : '我';
        final accentColor = isDark ? AppColors.darkPrimary : palette.primary;

        return GestureDetector(
          onTap: onTap,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accentColor,
                  accentColor.withValues(alpha: 0.75),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
