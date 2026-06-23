import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/checklist.dart';
import '../providers/checklist_provider.dart';
import '../theme/app_theme.dart';
import 'checklist_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────
//  ScheduleChecklistScreen —— 日程类清单二级页面
//
//  【定位】
//  时间维度视角：展示所有有日期锚点的时态型清单。
//  区别于清单 Tab 主页（清单对象管理）和今日 Tab（今天执行视角）。
//  这里是"规划者视角"：看到横跨多天/多周的日程全貌。
//
//  【布局结构】
//  ┌───────────────────────────────┐
//  │  ← 日程清单      [+ 新建]    │  AppBar
//  ├───────────────────────────────┤
//  │  📅 周视图导航条（← 本周 →）  │
//  ├───────────────────────────────┤
//  │  周内日历行（Mon-Sun 格）      │  点击切换当前日
//  ├───────────────────────────────┤
//  │  逾期清单折叠区（红）          │  可折叠
//  ├───────────────────────────────┤
//  │  按日分组的清单列表            │  仅展示本周内有数据的天
//  │    2025-06-10（周一）         │
//  │      ▸ 清单卡片               │
//  │    2025-06-11（今天）         │
//  │      ▸ 清单卡片               │
//  ├───────────────────────────────┤
//  │  📥 收件箱（无日期待办）      │
//  └───────────────────────────────┘
//
//  交互：
//  - 点击日历格 → 跳到对应日期组
//  - 点击清单卡片 → 进入详情页
//  - 长按清单卡片 → 右键菜单（修改日期 / 归档 / 删除）
// ─────────────────────────────────────────────────────────────────

class ScheduleChecklistScreen extends StatefulWidget {
  const ScheduleChecklistScreen({super.key});

  @override
  State<ScheduleChecklistScreen> createState() =>
      _ScheduleChecklistScreenState();
}

class _ScheduleChecklistScreenState extends State<ScheduleChecklistScreen> {
  // 当前周的周一（ISO 8601 周开始日）
  late DateTime _weekStart;
  // 当前高亮日（null = 不筛选，显示全部）
  DateTime? _selectedDay;

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // 找到本周周一
    _weekStart = _getWeekStart(now);
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  static DateTime _getWeekStart(DateTime date) {
    final diff = date.weekday - 1; // Monday = 1
    return DateTime(date.year, date.month, date.day - diff);
  }

  void _prevWeek() {
    setState(() {
      _weekStart = _weekStart.subtract(const Duration(days: 7));
      _selectedDay = null;
    });
  }

  void _nextWeek() {
    setState(() {
      _weekStart = _weekStart.add(const Duration(days: 7));
      _selectedDay = null;
    });
  }

  void _goToday() {
    final now = DateTime.now();
    setState(() {
      _weekStart = _getWeekStart(now);
      _selectedDay = DateTime(now.year, now.month, now.day);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = WeeklyTheme.getLightPalette();
    final primary = isDark ? AppColors.darkPrimary : palette.primary;
    final bg = isDark ? AppColors.backgroundDark : palette.background;

    return Scaffold(
      backgroundColor: bg,
      body: Consumer<ChecklistProvider>(
        builder: (ctx, provider, _) {
          final weekChecklists = provider.temporalForWeek(_weekStart);
          final overdue = provider.overdueChecklists;
          final inbox = provider.inboxTemporalChecklists;

          // 按日分组（仅本周）
          final groupedByDay = <DateTime, List<Checklist>>{};
          for (final c in weekChecklists) {
            final d = c.scheduledDate!;
            final key = DateTime(d.year, d.month, d.day);
            groupedByDay.putIfAbsent(key, () => []).add(c);
          }
          final sortedDays = groupedByDay.keys.toList()..sort();

          // 如果选中了某天，仅展示那天
          final displayDays = _selectedDay != null
              ? sortedDays.where((d) => d == _selectedDay).toList()
              : sortedDays;

          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              // ── AppBar ───────────────────────────────────────────
              _buildAppBar(context, isDark, primary, bg, provider),

              // ── 周导航条 ─────────────────────────────────────────
              SliverToBoxAdapter(
                child: _WeekNavBar(
                  weekStart: _weekStart,
                  primary: primary,
                  isDark: isDark,
                  onPrev: _prevWeek,
                  onNext: _nextWeek,
                  onToday: _goToday,
                ),
              ),

              // ── 周内日历格 ───────────────────────────────────────
              SliverToBoxAdapter(
                child: _WeekCalendarRow(
                  weekStart: _weekStart,
                  selectedDay: _selectedDay,
                  groupedByDay: groupedByDay,
                  primary: primary,
                  isDark: isDark,
                  onDayTap: (day) {
                    setState(() {
                      // 再次点击已选中的天 = 取消筛选
                      _selectedDay = _selectedDay == day ? null : day;
                    });
                  },
                ),
              ),

              // ── 逾期区（折叠） ────────────────────────────────────
              if (overdue.isNotEmpty && _selectedDay == null)
                SliverToBoxAdapter(
                  child: _OverdueSection(
                    checklists: overdue,
                    isDark: isDark,
                    onTap: (c) => _openDetail(context, c),
                  ),
                ),

              // ── 按日分组的清单 ────────────────────────────────────
              if (displayDays.isEmpty && inbox.isEmpty)
                SliverToBoxAdapter(
                  child: _EmptyWeek(
                    primary: primary,
                    isDark: isDark,
                    isFiltered: _selectedDay != null,
                    selectedDay: _selectedDay,
                    onClearFilter: () => setState(() => _selectedDay = null),
                    onCreateForDay: () => _openCreate(
                      context,
                      scheduledDate: _selectedDay,
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, idx) {
                      final day = displayDays[idx];
                      final items = groupedByDay[day] ?? [];
                      return _DayGroup(
                        day: day,
                        checklists: items,
                        primary: primary,
                        isDark: isDark,
                        onTap: (c) => _openDetail(context, c),
                        onLongPress: (c) =>
                            _showContextMenu(context, c, isDark, provider),
                        onAddForDay: () =>
                            _openCreate(context, scheduledDate: day),
                      );
                    },
                    childCount: displayDays.length,
                  ),
                ),

              // ── 收件箱（无日期时态清单）─────────────────────────
              if (inbox.isNotEmpty && _selectedDay == null)
                SliverToBoxAdapter(
                  child: _InboxSection(
                    checklists: inbox,
                    primary: primary,
                    isDark: isDark,
                    onTap: (c) => _openDetail(context, c),
                    onLongPress: (c) =>
                        _showContextMenu(context, c, isDark, provider),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          );
        },
      ),
      floatingActionButton: _buildFab(context, primary),
    );
  }

  Widget _buildAppBar(BuildContext context, bool isDark, Color primary,
      Color bg, ChecklistProvider provider) {
    final textColor = isDark ? Colors.white : const Color(0xFF1A1410);
    final totalScheduled = provider.scheduledTemporalChecklists.length;

    return SliverAppBar(
      floating: true,
      pinned: true,
      backgroundColor: bg,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: Icon(Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: isDark ? Colors.white70 : const Color(0xFF666666)),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '日程清单',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          if (totalScheduled > 0)
            Text(
              '$totalScheduled 个日程清单',
              style: TextStyle(
                fontSize: 11,
                color: isDark
                    ? AppColors.textTertiaryDark
                    : const Color(0xFFAAAAAA),
              ),
            ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: _goToday,
          tooltip: '回到今天',
          icon: Icon(Icons.today_rounded, color: primary, size: 22),
        ),
        IconButton(
          onPressed: () => _openCreate(context),
          tooltip: '新建日程清单',
          icon: Icon(Icons.add_rounded, color: primary, size: 26),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildFab(BuildContext context, Color primary) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        _openCreate(context, scheduledDate: _selectedDay);
      },
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [primary, primary.withValues(alpha: 0.8)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  void _openDetail(BuildContext context, Checklist checklist) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChecklistDetailScreen(checklistId: checklist.id),
      ),
    );
  }

  void _openCreate(BuildContext context, {DateTime? scheduledDate}) async {
    // 复用 checklist_screen 的创建 Sheet，但预填时态类型和日期
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ScheduleCreateSheet(
        initialDate: scheduledDate ?? _selectedDay ?? DateTime.now(),
      ),
    );
  }

  void _showContextMenu(BuildContext context, Checklist checklist, bool isDark,
      ChecklistProvider provider) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ScheduleContextMenu(
        checklist: checklist,
        isDark: isDark,
        onReschedule: () {
          Navigator.pop(context);
          _showReschedulePicker(context, checklist, provider);
        },
        onArchive: () {
          Navigator.pop(context);
          provider.archiveChecklist(checklist.id);
        },
        onDelete: () {
          Navigator.pop(context);
          _confirmDelete(context, checklist, provider);
        },
      ),
    );
  }

  void _showReschedulePicker(
      BuildContext context, Checklist checklist, ChecklistProvider provider) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: checklist.scheduledDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      helpText: '选择新日期',
    );
    if (picked != null) {
      final newDate = DateTime(picked.year, picked.month, picked.day);
      await provider.updateChecklist(
        checklist.copyWith(scheduledDate: newDate),
      );
      if (mounted) {
        setState(() {
          _weekStart = _getWeekStart(newDate);
          _selectedDay = newDate;
        });
      }
    }
  }

  void _confirmDelete(
      BuildContext context, Checklist checklist, ChecklistProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('删除清单',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('确定删除「${checklist.title}」？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              provider.deleteChecklist(checklist.id);
            },
            child:
                const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  周导航条
// ─────────────────────────────────────────────────────────────────

class _WeekNavBar extends StatelessWidget {
  final DateTime weekStart;
  final Color primary;
  final bool isDark;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;

  const _WeekNavBar({
    required this.weekStart,
    required this.primary,
    required this.isDark,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
  });

  String get _weekLabel {
    final now = DateTime.now();
    final thisWeekStart = _getThisWeekStart(now);
    final weekEnd = weekStart.add(const Duration(days: 6));

    if (weekStart == thisWeekStart) {
      return '本周  ${_fmt(weekStart)} – ${_fmt(weekEnd)}';
    }
    final diff = weekStart.difference(thisWeekStart).inDays;
    if (diff == 7) return '下周  ${_fmt(weekStart)} – ${_fmt(weekEnd)}';
    if (diff == -7) return '上周  ${_fmt(weekStart)} – ${_fmt(weekEnd)}';
    return '${_fmt(weekStart)} – ${_fmt(weekEnd)}';
  }

  static DateTime _getThisWeekStart(DateTime date) {
    final diff = date.weekday - 1;
    return DateTime(date.year, date.month, date.day - diff);
  }

  String _fmt(DateTime d) => '${d.month}/${d.day}';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: onPrev,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF2A2A2A)
                    : primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.chevron_left_rounded,
                  size: 20, color: primary),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: onToday,
              child: Text(
                _weekLabel,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1A1410),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onNext,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF2A2A2A)
                    : primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.chevron_right_rounded,
                  size: 20, color: primary),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  周内日历格（周一到周日横向排列）
// ─────────────────────────────────────────────────────────────────

class _WeekCalendarRow extends StatelessWidget {
  final DateTime weekStart;
  final DateTime? selectedDay;
  final Map<DateTime, List<Checklist>> groupedByDay;
  final Color primary;
  final bool isDark;
  final ValueChanged<DateTime> onDayTap;

  const _WeekCalendarRow({
    required this.weekStart,
    required this.selectedDay,
    required this.groupedByDay,
    required this.primary,
    required this.isDark,
    required this.onDayTap,
  });

  static const _weekLabels = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: List.generate(7, (idx) {
          final day = weekStart.add(Duration(days: idx));
          final dayKey = DateTime(day.year, day.month, day.day);
          final isToday = dayKey == today;
          final isSelected = dayKey == selectedDay;
          final hasItems = groupedByDay.containsKey(dayKey) &&
              groupedByDay[dayKey]!.isNotEmpty;
          final allDone = hasItems &&
              groupedByDay[dayKey]!.every((c) => c.isAllDone);

          Color? dotColor;
          if (hasItems) {
            dotColor = allDone ? Colors.green : primary;
          }

          return Expanded(
            child: GestureDetector(
              onTap: () => onDayTap(dayKey),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? primary
                      : (isToday
                          ? primary.withValues(alpha: 0.1)
                          : Colors.transparent),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _weekLabels[idx],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: isSelected
                            ? Colors.white70
                            : (isDark
                                ? AppColors.textTertiaryDark
                                : const Color(0xFFAAAAAA)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${day.day}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: (isToday || isSelected)
                            ? FontWeight.w800
                            : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : (isToday
                                ? primary
                                : (isDark
                                    ? Colors.white
                                    : const Color(0xFF333333))),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // 有数据时显示小圆点
                    if (dotColor != null)
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : dotColor,
                          shape: BoxShape.circle,
                        ),
                      )
                    else
                      const SizedBox(height: 5),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  逾期区
// ─────────────────────────────────────────────────────────────────

class _OverdueSection extends StatefulWidget {
  final List<Checklist> checklists;
  final bool isDark;
  final ValueChanged<Checklist> onTap;

  const _OverdueSection({
    required this.checklists,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_OverdueSection> createState() => _OverdueSectionState();
}

class _OverdueSectionState extends State<_OverdueSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFF6B6B).withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFFF6B6B).withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          children: [
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    const Text('⚠️', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Text(
                      '${widget.checklists.length} 个清单已逾期',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFE05555),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _expanded ? '收起' : '展开',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFFE05555)),
                    ),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: const Color(0xFFE05555),
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded) ...[
              const Divider(height: 1, color: Color(0x22FF6B6B)),
              ...widget.checklists.map((c) => GestureDetector(
                    onTap: () => widget.onTap(c),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          Text(c.emoji,
                              style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c.title,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF444444),
                                  ),
                                ),
                                if (c.scheduledDate != null)
                                  Text(
                                    _overdueLabel(c.scheduledDate!),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFFE05555),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // 进度
                          if (c.totalCount > 0)
                            Text(
                              '${c.checkedCount}/${c.totalCount}',
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFFE05555)),
                            ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right_rounded,
                              size: 14, color: Color(0xFFE05555)),
                        ],
                      ),
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  String _overdueLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    final diff = today.difference(d).inDays;
    if (diff == 1) return '昨天逾期';
    if (diff <= 7) return '$diff 天前逾期';
    return '${date.month}/${date.day} 逾期';
  }
}

// ─────────────────────────────────────────────────────────────────
//  按天分组区块
// ─────────────────────────────────────────────────────────────────

class _DayGroup extends StatelessWidget {
  final DateTime day;
  final List<Checklist> checklists;
  final Color primary;
  final bool isDark;
  final ValueChanged<Checklist> onTap;
  final ValueChanged<Checklist> onLongPress;
  final VoidCallback onAddForDay;

  const _DayGroup({
    required this.day,
    required this.checklists,
    required this.primary,
    required this.isDark,
    required this.onTap,
    required this.onLongPress,
    required this.onAddForDay,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isToday = day == today;
    final tomorrow = today.add(const Duration(days: 1));
    final isYesterday = day == today.subtract(const Duration(days: 1));

    String dayLabel;
    if (isToday) {
      dayLabel = '今天';
    } else if (day == tomorrow) {
      dayLabel = '明天';
    } else if (isYesterday) {
      dayLabel = '昨天';
    } else {
      const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      dayLabel = weekdays[day.weekday - 1];
    }

    final dateStr = '${day.month}月${day.day}日 · $dayLabel';

    // 完成度
    final totalItems =
        checklists.fold<int>(0, (s, c) => s + c.totalCount);
    final doneItems =
        checklists.fold<int>(0, (s, c) => s + c.checkedCount);
    final allDone = totalItems > 0 && doneItems == totalItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 日期分组标题 ───────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 16, 10),
          child: Row(
            children: [
              // 颜色点
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: allDone
                      ? Colors.green
                      : (isToday ? primary : primary.withValues(alpha: 0.4)),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                dateStr,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isToday
                      ? primary
                      : (isDark
                          ? Colors.white
                          : const Color(0xFF1A1410)),
                ),
              ),
              const SizedBox(width: 8),
              // 完成进度小标
              if (totalItems > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: allDone
                        ? Colors.green.withValues(alpha: 0.1)
                        : primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    allDone ? '✅ 全部完成' : '$doneItems/$totalItems',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: allDone ? Colors.green : primary,
                    ),
                  ),
                ),
              const Spacer(),
              // + 当天新建按钮
              GestureDetector(
                onTap: onAddForDay,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, size: 13, color: primary),
                      const SizedBox(width: 2),
                      Text(
                        '添加',
                        style: TextStyle(
                          fontSize: 11,
                          color: primary,
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
        // ── 清单卡片 ───────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: checklists
                .map((c) => _ScheduleCard(
                      checklist: c,
                      primary: primary,
                      isDark: isDark,
                      onTap: () => onTap(c),
                      onLongPress: () => onLongPress(c),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  日程清单卡片（横向紧凑，进度环 + 标题 + 条目数）
// ─────────────────────────────────────────────────────────────────

class _ScheduleCard extends StatelessWidget {
  final Checklist checklist;
  final Color primary;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ScheduleCard({
    required this.checklist,
    required this.primary,
    required this.isDark,
    required this.onTap,
    required this.onLongPress,
  });

  Color get _accentColor {
    try {
      final hex = checklist.colorHex.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final allDone = checklist.isAllDone;
    final progress = checklist.progress;
    final ringColor = allDone ? Colors.green : _accentColor;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color:
                  Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // 进度环
            _ProgressRing(
              progress: progress,
              color: ringColor,
              isDone: allDone,
              size: 40,
            ),
            const SizedBox(width: 12),
            // 主信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${checklist.emoji}  ${checklist.title}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: allDone
                          ? (isDark
                              ? Colors.white38
                              : const Color(0xFFAAAAAA))
                          : (isDark
                              ? Colors.white
                              : const Color(0xFF1A1410)),
                      decoration:
                          allDone ? TextDecoration.lineThrough : null,
                      decorationColor:
                          isDark ? Colors.white38 : const Color(0xFFCCCCCC),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (checklist.totalCount > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        // 未完成条目预览
                        Expanded(
                          child: Text(
                            _previewItems(checklist),
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AppColors.textTertiaryDark
                                  : const Color(0xFFAAAAAA),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // 重复标签
                        if (checklist.repeatType != RepeatType.none)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF20C997)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.refresh_rounded,
                                    size: 9,
                                    color: Color(0xFF20C997)),
                                const SizedBox(width: 2),
                                Text(
                                  checklist.repeatType.label,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF20C997),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 进度文字
            Text(
              allDone
                  ? '完成'
                  : '${checklist.checkedCount}/${checklist.totalCount}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: allDone
                    ? Colors.green
                    : (isDark
                        ? AppColors.textSecondaryDark
                        : const Color(0xFF888888)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _previewItems(Checklist c) {
    final unchecked = c.items.where((i) => !i.isChecked).take(3);
    if (unchecked.isEmpty) return '所有条目已完成 ✓';
    return unchecked.map((i) => i.title).join(' · ');
  }
}

// ─────────────────────────────────────────────────────────────────
//  收件箱区（无日期的时态清单）
// ─────────────────────────────────────────────────────────────────

class _InboxSection extends StatefulWidget {
  final List<Checklist> checklists;
  final Color primary;
  final bool isDark;
  final ValueChanged<Checklist> onTap;
  final ValueChanged<Checklist> onLongPress;

  const _InboxSection({
    required this.checklists,
    required this.primary,
    required this.isDark,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_InboxSection> createState() => _InboxSectionState();
}

class _InboxSectionState extends State<_InboxSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 16, 10),
            child: Row(
              children: [
                const Text('📥', style: TextStyle(fontSize: 15)),
                const SizedBox(width: 8),
                Text(
                  '收件箱',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color:
                        widget.isDark ? Colors.white : const Color(0xFF1A1410),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: widget.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${widget.checklists.length} 个无日期',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: widget.primary,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: widget.isDark
                      ? AppColors.textTertiaryDark
                      : const Color(0xFFAAAAAA),
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: widget.checklists
                  .map((c) => _ScheduleCard(
                        checklist: c,
                        primary: widget.primary,
                        isDark: widget.isDark,
                        onTap: () => widget.onTap(c),
                        onLongPress: () => widget.onLongPress(c),
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  空状态
// ─────────────────────────────────────────────────────────────────

class _EmptyWeek extends StatelessWidget {
  final Color primary;
  final bool isDark;
  final bool isFiltered;
  final DateTime? selectedDay;
  final VoidCallback onClearFilter;
  final VoidCallback onCreateForDay;

  const _EmptyWeek({
    required this.primary,
    required this.isDark,
    required this.isFiltered,
    required this.selectedDay,
    required this.onClearFilter,
    required this.onCreateForDay,
  });

  @override
  Widget build(BuildContext context) {
    final msg = isFiltered && selectedDay != null
        ? '${selectedDay!.month}月${selectedDay!.day}日\n没有日程清单'
        : '本周没有日程清单';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isFiltered ? '📭' : '📅',
            style: const TextStyle(fontSize: 48),
          ),
          const SizedBox(height: 16),
          Text(
            msg,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.6,
              color: isDark ? Colors.white : const Color(0xFF1A1410),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isFiltered
                ? '点击下方按钮为这天新建一个日程清单'
                : '创建日程清单来规划今日、本周或未来的任务',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color:
                  isDark ? AppColors.textSecondaryDark : const Color(0xFF888888),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isFiltered) ...[
                GestureDetector(
                  onTap: onClearFilter,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2A2A2A)
                          : const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '查看全周',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : const Color(0xFF666666),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              GestureDetector(
                onTap: onCreateForDay,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_rounded,
                          size: 16, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        isFiltered ? '为这天新建' : '新建日程清单',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  右键菜单（日程专属：可修改日期）
// ─────────────────────────────────────────────────────────────────

class _ScheduleContextMenu extends StatelessWidget {
  final Checklist checklist;
  final bool isDark;
  final VoidCallback onReschedule;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  const _ScheduleContextMenu({
    required this.checklist,
    required this.isDark,
    required this.onReschedule,
    required this.onArchive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? AppColors.surfaceDark : Colors.white;
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 清单标题
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Text(checklist.emoji,
                      style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      checklist.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? Colors.white
                            : const Color(0xFF1A1410),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            _MenuItem(
              icon: Icons.event_rounded,
              label: '修改日期',
              isDark: isDark,
              onTap: onReschedule,
            ),
            _MenuItem(
              icon: Icons.archive_outlined,
              label: '归档',
              isDark: isDark,
              onTap: onArchive,
            ),
            _MenuItem(
              icon: Icons.delete_outline_rounded,
              label: '删除',
              isDark: isDark,
              color: Colors.red,
              onTap: onDelete,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback onTap;
  final Color? color;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textColor =
        color ?? (isDark ? AppColors.textPrimaryDark : const Color(0xFF1A1410));
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: textColor),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: textColor),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  进度环（复用自 checklist_screen）
// ─────────────────────────────────────────────────────────────────

class _ProgressRing extends StatelessWidget {
  final double progress;
  final Color color;
  final bool isDone;
  final double size;

  const _ProgressRing({
    required this.progress,
    required this.color,
    required this.isDone,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: 1.0,
            strokeWidth: 2.5,
            color: color.withValues(alpha: 0.12),
          ),
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 2.5,
            color: color,
            backgroundColor: Colors.transparent,
          ),
          if (isDone)
            Icon(Icons.check_rounded, color: color, size: size * 0.45)
          else if (progress == 0)
            Icon(Icons.radio_button_unchecked_rounded,
                color: color.withValues(alpha: 0.4), size: size * 0.45)
          else
            Text(
              '${(progress * 100).round()}%',
              style: TextStyle(
                fontSize: size * 0.22,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  快速创建 Sheet（日程专属，预填时态类型 + 日期）
//
//  注意：此 Sheet 是为日程页设计的轻量版本。
//  仅包含标题、日期、重复周期三个核心字段，
//  减少认知负担，让用户聚焦在「规划这天要做什么」上。
// ─────────────────────────────────────────────────────────────────

class _ScheduleCreateSheet extends StatefulWidget {
  final DateTime initialDate;

  const _ScheduleCreateSheet({required this.initialDate});

  @override
  State<_ScheduleCreateSheet> createState() => _ScheduleCreateSheetState();
}

class _ScheduleCreateSheetState extends State<_ScheduleCreateSheet> {
  final _titleCtrl = TextEditingController();
  late DateTime _scheduledDate;
  RepeatType _repeatType = RepeatType.none;

  @override
  void initState() {
    super.initState();
    _scheduledDate = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入清单名称')),
      );
      return;
    }
    final provider = context.read<ChecklistProvider>();
    await provider.addChecklist(
      title: title,
      emoji: '📅',
      colorHex: '#339AF0',
      checklistType: ChecklistType.temporal,
      scheduledDate: _scheduledDate,
      repeatType: _repeatType,
    );
    if (mounted) Navigator.pop(context);
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    if (d == today) return '今天 (${d.month}/${d.day})';
    if (d == tomorrow) return '明天 (${d.month}/${d.day})';
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return '${d.month}/${d.day} · ${weekdays[d.weekday - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = const Color(0xFF339AF0);
    final bgColor = isDark ? AppColors.surfaceDark : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1410);
    final hintColor =
        isDark ? AppColors.textTertiaryDark : const Color(0xFFBBBBBB);
    final inputFill =
        isDark ? AppColors.inputFillDark : const Color(0xFFF5F5F5);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 拖拽手柄
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white24
                        : Colors.black.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // 标题
              Text(
                '新建日程清单',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '为特定日期创建一个任务清单',
                style: TextStyle(
                  fontSize: 12,
                  color:
                      isDark ? AppColors.textTertiaryDark : const Color(0xFFAAAAAA),
                ),
              ),
              const SizedBox(height: 16),

              // 清单名称
              TextField(
                controller: _titleCtrl,
                autofocus: true,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColor),
                decoration: InputDecoration(
                  hintText: '清单名称（如：今日工作安排）',
                  hintStyle: TextStyle(
                      color: hintColor, fontWeight: FontWeight.w400),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(left: 12, right: 8),
                    child: Text('📅', style: TextStyle(fontSize: 20)),
                  ),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 0, minHeight: 0),
                  filled: true,
                  fillColor: inputFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 16),
                ),
              ),
              const SizedBox(height: 14),

              // 日期选择
              GestureDetector(
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _scheduledDate,
                    firstDate: now.subtract(const Duration(days: 365)),
                    lastDate: now.add(const Duration(days: 365 * 2)),
                    helpText: '选择日期',
                  );
                  if (picked != null) {
                    setState(() {
                      _scheduledDate =
                          DateTime(picked.year, picked.month, picked.day);
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 18, color: primary),
                      const SizedBox(width: 10),
                      Text(
                        _formatDate(_scheduledDate),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: primary,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.chevron_right_rounded,
                          size: 16, color: primary.withValues(alpha: 0.5)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 重复周期
              Row(
                children: RepeatType.values.map((r) {
                  final isActive = _repeatType == r;
                  final labels = {
                    RepeatType.none: '不重复',
                    RepeatType.daily: '🔁 每日',
                    RepeatType.weekly: '📅 每周',
                  };
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _repeatType = r),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isActive
                              ? primary
                              : (isDark
                                  ? const Color(0xFF2A2A2A)
                                  : const Color(0xFFF0F0F0)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          labels[r] ?? r.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isActive
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isActive
                                ? Colors.white
                                : (isDark
                                    ? AppColors.textSecondaryDark
                                    : const Color(0xFF666666)),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // 确认按钮
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: _save,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: primary,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: primary.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Text(
                      '创建日程清单',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
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