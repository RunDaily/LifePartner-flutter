import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/checklist.dart';
import '../providers/checklist_provider.dart';
import '../theme/app_theme.dart';
import 'checklist_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────
//  ScheduleScreen —— 日程中枢（四视图）
//
//  参照滴答清单形态设计：
//  · 当日视图：全天区 + 时间段分区（早晨/上午/下午/晚上）
//  · 三日视图：紧凑三列日历 + 任务列表
//  · 周视图：可滑动周日历条 + 按天任务列表
//  · 月视图：完整月历 + 每格2-3条任务名（事件密度）
//
//  默认展示：周视图（与滴答清单默认一致）
// ─────────────────────────────────────────────────────────────────

enum _ScheduleView { day, threeDay, week, month }

extension _ScheduleViewLabel on _ScheduleView {
  String get label {
    switch (this) {
      case _ScheduleView.day:
        return '当日';
      case _ScheduleView.threeDay:
        return '三日';
      case _ScheduleView.week:
        return '周';
      case _ScheduleView.month:
        return '月';
    }
  }

}

/// 时间段枚举（用于当日/三日视图的时间分区）
enum _TimeSlot {
  allDay,    // 全天（无具体时间）
  morning,   // 早晨 (6:00–12:00)
  afternoon, // 下午 (12:00–18:00)
  evening,   // 晚上 (18:00–24:00)
}

extension _TimeSlotLabel on _TimeSlot {
  String get label {
    switch (this) {
      case _TimeSlot.allDay:
        return '全天';
      case _TimeSlot.morning:
        return '上午';
      case _TimeSlot.afternoon:
        return '下午';
      case _TimeSlot.evening:
        return '晚上';
    }
  }

  IconData get icon {
    switch (this) {
      case _TimeSlot.allDay:
        return Icons.wb_sunny_outlined;
      case _TimeSlot.morning:
        return Icons.wb_twilight_rounded;
      case _TimeSlot.afternoon:
        return Icons.light_mode_outlined;
      case _TimeSlot.evening:
        return Icons.nights_stay_outlined;
    }
  }
}

// ─────────────────────────────────────────────────────────────────
//  主屏幕
// ─────────────────────────────────────────────────────────────────

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen>
    with SingleTickerProviderStateMixin {
  _ScheduleView _currentView = _ScheduleView.week;

  // 当前焦点日期（所有视图共享，切换时保持日期上下文）
  late DateTime _focusDate;

  // 月视图：当前展示月份
  late DateTime _monthStart;

  // 周视图 PageView 控制器（从今天所在周开始）
  late PageController _weekPageCtrl;
  static const int _kWeekPageCenter = 500; // 虚拟中心页
  late DateTime _weekPageBase; // PageView page=0 对应的周一

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusDate = DateTime(now.year, now.month, now.day);
    _monthStart = DateTime(now.year, now.month, 1);

    // 计算今天所在周的周一
    final todayMonday = _getWeekStart(_focusDate);
    // base = center - 当前页 offset，使得 today 的页为 _kWeekPageCenter
    _weekPageBase = todayMonday.subtract(
      Duration(days: (_kWeekPageCenter) * 7),
    );
    _weekPageCtrl = PageController(initialPage: _kWeekPageCenter);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChecklistProvider>().loadChecklists();
    });
  }

  @override
  void dispose() {
    _weekPageCtrl.dispose();
    super.dispose();
  }

  // ── 导航辅助 ────────────────────────────────────────────────────

  void _goToday() {
    final now = DateTime.now();
    setState(() {
      _focusDate = DateTime(now.year, now.month, now.day);
      _monthStart = DateTime(now.year, now.month, 1);
    });
    // 周视图 PageView 跳回今天所在页
    if (_currentView == _ScheduleView.week) {
      final todayMonday = _getWeekStart(_focusDate);
      final diff = todayMonday.difference(_weekPageBase).inDays ~/ 7;
      _weekPageCtrl.animateToPage(
        diff,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _shiftFocus(int days) {
    setState(() {
      _focusDate = _focusDate.add(Duration(days: days));
      _monthStart = DateTime(_focusDate.year, _focusDate.month, 1);
    });
  }

  void _shiftMonth(int months) {
    setState(() {
      final m = _monthStart.month + months;
      final y = _monthStart.year + (m - 1) ~/ 12;
      _monthStart = DateTime(y, ((m - 1) % 12) + 1, 1);
      _focusDate = _monthStart;
    });
  }

  DateTime _getWeekStart(DateTime date) {
    final diff = date.weekday - 1;
    return DateTime(date.year, date.month, date.day - diff);
  }

  // ── build ───────────────────────────────────────────────────────

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
          return CustomScrollView(
            slivers: [
              // ── AppBar ──────────────────────────────────────────
              _buildAppBar(context, isDark, primary, bg),

              // ── 视图主体 ──────────────────────────────────────
              SliverToBoxAdapter(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: child,
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(_currentView),
                    child: _buildViewBody(
                        context, isDark, primary, bg, provider),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          );
        },
      ),
      // FAB 已移除：日程页不需要独立的「新建清单」入口。
      // 在每个日期格子右侧的小 + 已足够，语义更清晰（「为这天加一件事」）。
    );
  }

  // ── AppBar（标题区 = 日期标题 + 视图下拉 Picker）────────────────
  Widget _buildAppBar(
      BuildContext context, bool isDark, Color primary, Color bg) {
    final now = DateTime.now();
    final isToday = _focusDate == DateTime(now.year, now.month, now.day);

    return SliverAppBar(
      floating: false,
      pinned: true,
      backgroundColor: bg,
      elevation: 0,
      toolbarHeight: 56,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 18,
          color: isDark ? Colors.white70 : const Color(0xFF666666),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      // ── 标题区：左侧 = 日期/回今天，右侧 = 视图下拉 ────────────
      title: Row(
        children: [
          // 日期标题（点击回今天）
          GestureDetector(
            onTap: isToday ? null : _goToday,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getNavTitle(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1A1410),
                  ),
                ),
                if (!isToday && _currentView != _ScheduleView.month) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '回今天',
                      style: TextStyle(
                        fontSize: 11,
                        color: primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          // 视图下拉 Picker（点击弹出选择框）
          _ViewPickerButton(
            current: _currentView,
            primary: primary,
            isDark: isDark,
            onChanged: (v) => setState(() => _currentView = v),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () => _openCreate(context),
          icon: Icon(Icons.edit_note_rounded, color: primary, size: 24),
          tooltip: '快速添加',
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  String _getNavTitle() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_currentView) {
      case _ScheduleView.day:
        if (_focusDate == today) return '今天';
        if (_focusDate == today.add(const Duration(days: 1))) return '明天';
        if (_focusDate == today.subtract(const Duration(days: 1))) {
          return '昨天';
        }
        return '${_focusDate.month}月${_focusDate.day}日';
      case _ScheduleView.threeDay:
        final end = _focusDate.add(const Duration(days: 2));
        return '${_focusDate.month}/${_focusDate.day} – ${end.month}/${end.day}';
      case _ScheduleView.week:
        final ws = _getWeekStart(_focusDate);
        final thisWeek = _getWeekStart(today);
        if (ws == thisWeek) return '本周';
        if (ws == thisWeek.add(const Duration(days: 7))) return '下周';
        if (ws == thisWeek.subtract(const Duration(days: 7))) return '上周';
        return '${ws.month}/${ws.day}';
      case _ScheduleView.month:
        return '${_monthStart.year}年${_monthStart.month}月';
    }
  }

  // ── 视图主体路由 ───────────────────────────────────────────────
  Widget _buildViewBody(BuildContext context, bool isDark, Color primary,
      Color bg, ChecklistProvider provider) {
    switch (_currentView) {
      case _ScheduleView.day:
        return _DayView(
          focusDate: _focusDate,
          provider: provider,
          isDark: isDark,
          primary: primary,
          onPrev: () => _shiftFocus(-1),
          onNext: () => _shiftFocus(1),
          onTap: (c) => _openDetail(context, c),
          onLongPress: (c) => _showContextMenu(context, c, isDark, provider),
          onAddForDay: (d) => _openCreate(context, scheduledDate: d),
        );
      case _ScheduleView.threeDay:
        return _ThreeDayView(
          focusDate: _focusDate,
          provider: provider,
          isDark: isDark,
          primary: primary,
          onDayTap: (d) => setState(() => _focusDate = d),
          onPrev: () => _shiftFocus(-3),
          onNext: () => _shiftFocus(3),
          onTap: (c) => _openDetail(context, c),
          onLongPress: (c) => _showContextMenu(context, c, isDark, provider),
          onAddForDay: (d) => _openCreate(context, scheduledDate: d),
        );
      case _ScheduleView.week:
        return _WeekView(
          focusDate: _focusDate,
          provider: provider,
          isDark: isDark,
          primary: primary,
          pageController: _weekPageCtrl,
          weekPageBase: _weekPageBase,
          onDayTap: (d) => setState(() => _focusDate = d),
          onTap: (c) => _openDetail(context, c),
          onLongPress: (c) => _showContextMenu(context, c, isDark, provider),
          onAddForDay: (d) => _openCreate(context, scheduledDate: d),
          onFocusDateChange: (d) => setState(() => _focusDate = d),
        );
      case _ScheduleView.month:
        return _MonthView(
          monthStart: _monthStart,
          focusDate: _focusDate,
          provider: provider,
          isDark: isDark,
          primary: primary,
          onDayTap: (d) {
            setState(() {
              _focusDate = d;
              _currentView = _ScheduleView.day;
            });
          },
          onMonthChanged: _shiftMonth,
        );
    }
  }

  // ── 导航辅助方法 ───────────────────────────────────────────────
  void _openDetail(BuildContext context, Checklist checklist) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChecklistDetailScreen(checklistId: checklist.id),
      ),
    );
  }

  void _openCreate(BuildContext context, {DateTime? scheduledDate}) async {
    final date = scheduledDate ?? _focusDate;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ScheduleCreateSheet(initialDate: date),
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

  void _showReschedulePicker(BuildContext context, Checklist checklist,
      ChecklistProvider provider) async {
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
        setState(() => _focusDate = newDate);
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
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  视图下拉按钮（展示当前视图名 + 小三角）
//
//  点击后弹出轻量小浮窗，列出 4 个视图选项供用户选择。
//  交互设计参照博客/Notion 的「视图切换」风格。
// ─────────────────────────────────────────────────────────────────

class _ViewPickerButton extends StatelessWidget {
  final _ScheduleView current;
  final Color primary;
  final bool isDark;
  final ValueChanged<_ScheduleView> onChanged;

  const _ViewPickerButton({
    required this.current,
    required this.primary,
    required this.isDark,
    required this.onChanged,
  });

  // 每个视图对应的副标题（下方小字描述）
  String _subtitle(_ScheduleView v) {
    switch (v) {
      case _ScheduleView.day:
        return '单天全貌';
      case _ScheduleView.threeDay:
        return '连续三天';
      case _ScheduleView.week:
        return '本周七天';
      case _ScheduleView.month:
        return '月历鸟瞥';
    }
  }

  void _showPicker(BuildContext context) {
    HapticFeedback.lightImpact();
    showDialog<_ScheduleView>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (ctx) => _ViewPickerDialog(
        current: current,
        primary: primary,
        isDark: isDark,
        subtitle: _subtitle,
      ),
    ).then((picked) {
      if (picked != null) {
        HapticFeedback.selectionClick();
        onChanged(picked);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              current.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: primary,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.expand_more_rounded,
              size: 15,
              color: primary,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  视图选择对话框（由 _ViewPickerButton 弹出）
// ─────────────────────────────────────────────────────────────────

class _ViewPickerDialog extends StatelessWidget {
  final _ScheduleView current;
  final Color primary;
  final bool isDark;
  final String Function(_ScheduleView) subtitle;

  const _ViewPickerDialog({
    required this.current,
    required this.primary,
    required this.isDark,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark ? AppColors.cardDark : Colors.white;
    final screenWidth = MediaQuery.of(context).size.width;

    return Align(
      // 对齐到屏幕左上角（标题按钮正下方）
      alignment: const Alignment(-0.3, -0.7),
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: screenWidth * 0.62,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _ScheduleView.values.map((v) {
              final isActive = v == current;
              return InkWell(
                onTap: () => Navigator.of(context).pop(v),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 11),
                  child: Row(
                    children: [
                      // 选中状态小圆点
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive
                              ? primary
                              : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isActive
                                ? primary
                                : (isDark
                                    ? Colors.white24
                                    : const Color(0xFFCCCCCC)),
                            width: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 视图名称 + 副标题
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              v.label,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isActive
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isActive
                                    ? primary
                                    : (isDark
                                        ? Colors.white70
                                        : const Color(0xFF333333)),
                              ),
                            ),
                            Text(
                              subtitle(v),
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? Colors.white38
                                    : const Color(0xFFAAAAAA),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 选中打勾
                      if (isActive)
                        Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: primary,
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  共用：日导航条（当日/三日视图顶部）
// ─────────────────────────────────────────────────────────────────

class _DayNavBar extends StatelessWidget {
  final String label;
  final Color primary;
  final bool isDark;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _DayNavBar({
    required this.label,
    required this.primary,
    required this.isDark,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Row(
        children: [
          _NavBtn(
              icon: Icons.chevron_left_rounded,
              color: primary,
              isDark: isDark,
              onTap: onPrev),
          Expanded(
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? Colors.white70
                      : const Color(0xFF666666),
                ),
              ),
            ),
          ),
          _NavBtn(
              icon: Icons.chevron_right_rounded,
              color: primary,
              isDark: isDark,
              onTap: onNext),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  共用：导航按钮
// ─────────────────────────────────────────────────────────────────

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _NavBtn({
    required this.icon,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF2A2A2A)
              : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  共用：时间段分区标题（当日/三日视图，参照滴答清单）
// ─────────────────────────────────────────────────────────────────

class _TimeSlotHeader extends StatelessWidget {
  final _TimeSlot slot;
  final int count;
  final Color primary;
  final bool isDark;

  const _TimeSlotHeader({
    required this.slot,
    required this.count,
    required this.primary,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final slotColor = _slotColor(slot, primary);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 6),
      child: Row(
        children: [
          Icon(slot.icon, size: 13, color: slotColor.withValues(alpha: 0.8)),
          const SizedBox(width: 6),
          Text(
            slot.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: slotColor,
              letterSpacing: 0.5,
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: slotColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: slotColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _slotColor(_TimeSlot slot, Color primary) {
    switch (slot) {
      case _TimeSlot.allDay:
        return const Color(0xFF5C7CFA);
      case _TimeSlot.morning:
        return const Color(0xFFFF9B47);
      case _TimeSlot.afternoon:
        return const Color(0xFF20C997);
      case _TimeSlot.evening:
        return const Color(0xFF845EF7);
    }
  }
}

// ─────────────────────────────────────────────────────────────────
//  共用：日期组标题行（周/月视图使用）
// ─────────────────────────────────────────────────────────────────

class _DayHeader extends StatelessWidget {
  final DateTime day;
  final int itemCount;
  final int doneCount;
  final Color primary;
  final bool isDark;
  final bool isHighlighted;
  final VoidCallback? onAdd;

  const _DayHeader({
    required this.day,
    required this.itemCount,
    required this.doneCount,
    required this.primary,
    required this.isDark,
    this.isHighlighted = false,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isToday = day == today;
    final allDone = itemCount > 0 && doneCount == itemCount;

    String dayLabel;
    if (isToday) {
      dayLabel = '今天';
    } else if (day == today.add(const Duration(days: 1))) {
      dayLabel = '明天';
    } else if (day == today.subtract(const Duration(days: 1))) {
      dayLabel = '昨天';
    } else {
      const wd = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      dayLabel = wd[day.weekday - 1];
    }

    final dateStr = '${day.month}月${day.day}日 · $dayLabel';
    final labelColor = isHighlighted || isToday
        ? primary
        : (isDark ? Colors.white : const Color(0xFF1A1410));

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 8),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: allDone
                  ? Colors.green
                  : (isToday ? primary : primary.withValues(alpha: 0.35)),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            dateStr,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: labelColor,
            ),
          ),
          const SizedBox(width: 8),
          if (itemCount > 0)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: allDone
                    ? Colors.green.withValues(alpha: 0.1)
                    : primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                allDone ? '全部完成' : '$doneCount/$itemCount',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: allDone ? Colors.green : primary,
                ),
              ),
            ),
          const Spacer(),
          if (onAdd != null)
            GestureDetector(
              onTap: onAdd,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 13, color: primary),
                    const SizedBox(width: 2),
                    Text('添加',
                        style: TextStyle(
                            fontSize: 11,
                            color: primary,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  共用：清单卡片（精简版，用于日程视图）
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
                  Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            _ProgressRing(
              progress: progress,
              color: ringColor,
              isDone: allDone,
              size: 40,
            ),
            const SizedBox(width: 12),
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
                      decorationColor: isDark
                          ? Colors.white38
                          : const Color(0xFFCCCCCC),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (checklist.totalCount > 0) ...[
                    const SizedBox(height: 3),
                    Text(
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
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 重复标签
            if (checklist.repeatType != RepeatType.none)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 5, vertical: 2),
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color:
                      const Color(0xFF20C997).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.refresh_rounded,
                        size: 9, color: Color(0xFF20C997)),
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
//  进度环
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
//  内联空状态（某天无日程 - 滴答清单风格，无边框）
// ─────────────────────────────────────────────────────────────────

class _InlineAddPlaceholder extends StatelessWidget {
  final Color primary;
  final bool isDark;
  final VoidCallback onAdd;

  const _InlineAddPlaceholder({
    required this.primary,
    required this.isDark,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onAdd,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            Icon(
              Icons.add_rounded,
              size: 16,
              color: primary.withValues(alpha: 0.4),
            ),
            const SizedBox(width: 8),
            Text(
              '添加任务',
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? Colors.white24
                    : const Color(0xFFCCCCCC),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  逾期区（折叠）
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFF6B6B).withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: const Color(0xFFFF6B6B).withValues(alpha: 0.2)),
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
                    const Text('⚠️',
                        style: TextStyle(fontSize: 14)),
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
                          fontSize: 12,
                          color: Color(0xFFE05555)),
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
                              style:
                                  const TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
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
                          if (c.totalCount > 0)
                            Text(
                              '${c.checkedCount}/${c.totalCount}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFE05555)),
                            ),
                          const SizedBox(width: 4),
                          const Icon(
                              Icons.chevron_right_rounded,
                              size: 14,
                              color: Color(0xFFE05555)),
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
//  VIEW 1：当日视图（参照滴答清单：时间段分区）
// ─────────────────────────────────────────────────────────────────

class _DayView extends StatelessWidget {
  final DateTime focusDate;
  final ChecklistProvider provider;
  final bool isDark;
  final Color primary;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ValueChanged<Checklist> onTap;
  final ValueChanged<Checklist> onLongPress;
  final ValueChanged<DateTime> onAddForDay;

  const _DayView({
    required this.focusDate,
    required this.provider,
    required this.isDark,
    required this.primary,
    required this.onPrev,
    required this.onNext,
    required this.onTap,
    required this.onLongPress,
    required this.onAddForDay,
  });

  String _dayNavLabel() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (focusDate == today) return '今天 · ${focusDate.month}月${focusDate.day}日';
    if (focusDate == today.add(const Duration(days: 1))) {
      return '明天 · ${focusDate.month}月${focusDate.day}日';
    }
    if (focusDate == today.subtract(const Duration(days: 1))) {
      return '昨天 · ${focusDate.month}月${focusDate.day}日';
    }
    const wd = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return '${wd[focusDate.weekday - 1]} · ${focusDate.month}月${focusDate.day}日';
  }

  @override
  Widget build(BuildContext context) {
    final overdue = provider.overdueChecklists;
    final dayItems = provider.temporalForDay(focusDate);
    final inbox = provider.inboxTemporalChecklists;

    // 按时间段分类（当前版本清单无具体时间，全归"全天"；
    // 后期可按 scheduledTime 字段拆分）
    final allDayItems = dayItems; // 未来可按时间过滤

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 日导航条
        _DayNavBar(
          label: _dayNavLabel(),
          primary: primary,
          isDark: isDark,
          onPrev: onPrev,
          onNext: onNext,
        ),

        // 逾期区
        if (overdue.isNotEmpty)
          _OverdueSection(
            checklists: overdue,
            isDark: isDark,
            onTap: onTap,
          ),

        const SizedBox(height: 8),

        // 全天区（参照滴答清单的"全天"栏）
        _DayTimeSection(
          slot: _TimeSlot.allDay,
          items: allDayItems,
          primary: primary,
          isDark: isDark,
          onTap: onTap,
          onLongPress: onLongPress,
          onAdd: () => onAddForDay(focusDate),
        ),

        // 收件箱（无日期）
        if (inbox.isNotEmpty) ...[
          const SizedBox(height: 8),
          _InboxSection(
            inbox: inbox,
            primary: primary,
            isDark: isDark,
            onTap: onTap,
            onLongPress: onLongPress,
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  当日视图：单个时间段区域
// ─────────────────────────────────────────────────────────────────

class _DayTimeSection extends StatelessWidget {
  final _TimeSlot slot;
  final List<Checklist> items;
  final Color primary;
  final bool isDark;
  final ValueChanged<Checklist> onTap;
  final ValueChanged<Checklist> onLongPress;
  final VoidCallback onAdd;

  const _DayTimeSection({
    required this.slot,
    required this.items,
    required this.primary,
    required this.isDark,
    required this.onTap,
    required this.onLongPress,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TimeSlotHeader(
            slot: slot, count: items.length, primary: primary, isDark: isDark),
        if (items.isEmpty)
          _InlineAddPlaceholder(
              primary: primary, isDark: isDark, onAdd: onAdd)
        else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: items
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
          _InlineAddPlaceholder(
              primary: primary, isDark: isDark, onAdd: onAdd),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  收件箱区域（无日期时态清单）
// ─────────────────────────────────────────────────────────────────

class _InboxSection extends StatelessWidget {
  final List<Checklist> inbox;
  final Color primary;
  final bool isDark;
  final ValueChanged<Checklist> onTap;
  final ValueChanged<Checklist> onLongPress;

  const _InboxSection({
    required this.inbox,
    required this.primary,
    required this.isDark,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 16, 6),
          child: Row(
            children: [
              const Icon(Icons.inbox_rounded, size: 13,
                  color: Color(0xFF888888)),
              const SizedBox(width: 6),
              Text(
                '收件箱',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? Colors.white38
                      : const Color(0xFF888888),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFF888888).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  '${inbox.length}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF888888),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: inbox
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
//  VIEW 2：三日视图（参照滴答清单：三列日历 + 选中列高亮 + 任务列表）
// ─────────────────────────────────────────────────────────────────

class _ThreeDayView extends StatelessWidget {
  final DateTime focusDate;
  final ChecklistProvider provider;
  final bool isDark;
  final Color primary;
  final ValueChanged<DateTime> onDayTap;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ValueChanged<Checklist> onTap;
  final ValueChanged<Checklist> onLongPress;
  final ValueChanged<DateTime> onAddForDay;

  const _ThreeDayView({
    required this.focusDate,
    required this.provider,
    required this.isDark,
    required this.primary,
    required this.onDayTap,
    required this.onPrev,
    required this.onNext,
    required this.onTap,
    required this.onLongPress,
    required this.onAddForDay,
  });

  String _navLabel() {
    final days = List.generate(3, (i) => focusDate.add(Duration(days: i)));
    final start = days.first;
    final end = days.last;
    return '${start.month}/${start.day} – ${end.month}/${end.day}';
  }

  @override
  Widget build(BuildContext context) {
    final days = List.generate(3, (i) => focusDate.add(Duration(days: i)));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final overdue = provider.overdueChecklists;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 日导航条
        _DayNavBar(
          label: _navLabel(),
          primary: primary,
          isDark: isDark,
          onPrev: onPrev,
          onNext: onNext,
        ),

        // 三日日历格
        _ThreeDayCalendarRow(
          days: days,
          today: today,
          focusDate: focusDate,
          provider: provider,
          primary: primary,
          isDark: isDark,
          onDayTap: onDayTap,
        ),

        // 逾期区
        if (overdue.isNotEmpty)
          _OverdueSection(
            checklists: overdue,
            isDark: isDark,
            onTap: onTap,
          ),

        // 三天任务列表
        ...days.map((day) {
          final items = provider.temporalForDay(day);
          final total = items.fold<int>(0, (s, c) => s + c.totalCount);
          final done = items.fold<int>(0, (s, c) => s + c.checkedCount);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DayHeader(
                day: day,
                itemCount: total,
                doneCount: done,
                primary: primary,
                isDark: isDark,
                isHighlighted: day == today,
                onAdd: () => onAddForDay(day),
              ),
              if (items.isEmpty)
                _InlineAddPlaceholder(
                  primary: primary,
                  isDark: isDark,
                  onAdd: () => onAddForDay(day),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: items
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
                _InlineAddPlaceholder(
                  primary: primary,
                  isDark: isDark,
                  onAdd: () => onAddForDay(day),
                ),
              ],
            ],
          );
        }),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  三日日历格（带任务数量气泡）
// ─────────────────────────────────────────────────────────────────

class _ThreeDayCalendarRow extends StatelessWidget {
  final List<DateTime> days;
  final DateTime today;
  final DateTime focusDate;
  final ChecklistProvider provider;
  final Color primary;
  final bool isDark;
  final ValueChanged<DateTime> onDayTap;

  const _ThreeDayCalendarRow({
    required this.days,
    required this.today,
    required this.focusDate,
    required this.provider,
    required this.primary,
    required this.isDark,
    required this.onDayTap,
  });

  static const _wd = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                )
              ],
      ),
      child: Row(
        children: days.map((day) {
          final isToday = day == today;
          final isFocus = day == focusDate;
          final items = provider.temporalForDay(day);
          final count = items.length;
          final allDone = count > 0 && items.every((c) => c.isAllDone);
          final dotColor = count > 0 ? (allDone ? Colors.green : primary) : null;

          return Expanded(
            child: GestureDetector(
              onTap: () => onDayTap(day),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding:
                    const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isFocus
                      ? primary
                      : (isToday
                          ? primary.withValues(alpha: 0.08)
                          : Colors.transparent),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      _wd[day.weekday - 1],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isFocus
                            ? Colors.white70
                            : (isDark
                                ? Colors.white38
                                : const Color(0xFFAAAAAA)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${day.day}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: isFocus
                            ? Colors.white
                            : (isToday
                                ? primary
                                : (isDark
                                    ? Colors.white
                                    : const Color(0xFF333333))),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // 任务数气泡（参照滴答清单）
                    if (dotColor != null)
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: isFocus
                              ? Colors.white.withValues(alpha: 0.3)
                              : dotColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '$count',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isFocus ? Colors.white : dotColor,
                            ),
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 18),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  VIEW 3：周视图（参照滴答清单：PageView 横向滑动 + 任务列表）
// ─────────────────────────────────────────────────────────────────

class _WeekView extends StatelessWidget {
  final DateTime focusDate;
  final ChecklistProvider provider;
  final bool isDark;
  final Color primary;
  final PageController pageController;
  final DateTime weekPageBase;
  final ValueChanged<DateTime> onDayTap;
  final ValueChanged<Checklist> onTap;
  final ValueChanged<Checklist> onLongPress;
  final ValueChanged<DateTime> onAddForDay;
  final ValueChanged<DateTime> onFocusDateChange;

  const _WeekView({
    required this.focusDate,
    required this.provider,
    required this.isDark,
    required this.primary,
    required this.pageController,
    required this.weekPageBase,
    required this.onDayTap,
    required this.onTap,
    required this.onLongPress,
    required this.onAddForDay,
    required this.onFocusDateChange,
  });

  DateTime _getWeekStart(DateTime date) {
    final diff = date.weekday - 1;
    return DateTime(date.year, date.month, date.day - diff);
  }

  @override
  Widget build(BuildContext context) {
    final currentWeekStart = _getWeekStart(focusDate);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final overdue = provider.overdueChecklists;
    final inbox = provider.inboxTemporalChecklists;

    // 当前周的任务数据
    final weekChecklists = provider.temporalForWeek(currentWeekStart);
    final grouped = <DateTime, List<Checklist>>{};
    for (final c in weekChecklists) {
      final d = c.scheduledDate!;
      final key = DateTime(d.year, d.month, d.day);
      grouped.putIfAbsent(key, () => []).add(c);
    }
    final weekDays = List.generate(
        7, (i) => currentWeekStart.add(Duration(days: i)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 可横向滑动的周日历条（PageView）
        SizedBox(
          height: 90,
          child: PageView.builder(
            controller: pageController,
            onPageChanged: (page) {
              // 计算新周的周一
              final newWeekStart =
                  weekPageBase.add(Duration(days: page * 7));
              // 通知父组件更新 focusDate 到该周的周一（或今日）
              final now2 = DateTime.now();
              final today2 =
                  DateTime(now2.year, now2.month, now2.day);
              // 如果今天在新周内，聚焦今天；否则聚焦该周第一天
              final isCurrentWeek = !today2.isBefore(newWeekStart) &&
                  today2.isBefore(
                      newWeekStart.add(const Duration(days: 7)));
              onFocusDateChange(
                  isCurrentWeek ? today2 : newWeekStart);
            },
            itemBuilder: (context, page) {
              final pageWeekStart =
                  weekPageBase.add(Duration(days: page * 7));
              final pageWeekDays = List.generate(
                  7, (i) => pageWeekStart.add(Duration(days: i)));
              final pageGrouped = <DateTime, List<Checklist>>{};
              final pageChecklists =
                  provider.temporalForWeek(pageWeekStart);
              for (final c in pageChecklists) {
                final d = c.scheduledDate!;
                final key = DateTime(d.year, d.month, d.day);
                pageGrouped.putIfAbsent(key, () => []).add(c);
              }

              return _WeekCalendarStrip(
                weekDays: pageWeekDays,
                today: today,
                focusDate: focusDate,
                grouped: pageGrouped,
                primary: primary,
                isDark: isDark,
                onDayTap: onDayTap,
              );
            },
          ),
        ),

        // 逾期区
        if (overdue.isNotEmpty)
          _OverdueSection(
            checklists: overdue,
            isDark: isDark,
            onTap: onTap,
          ),

        // 按天展示任务
        ...weekDays.map((day) {
          final items = grouped[day] ?? [];
          final total = items.fold<int>(0, (s, c) => s + c.totalCount);
          final done = items.fold<int>(0, (s, c) => s + c.checkedCount);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DayHeader(
                day: day,
                itemCount: total,
                doneCount: done,
                primary: primary,
                isDark: isDark,
                isHighlighted: day == today,
                onAdd: () => onAddForDay(day),
              ),
              if (items.isEmpty)
                _InlineAddPlaceholder(
                  primary: primary,
                  isDark: isDark,
                  onAdd: () => onAddForDay(day),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: items
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
                _InlineAddPlaceholder(
                  primary: primary,
                  isDark: isDark,
                  onAdd: () => onAddForDay(day),
                ),
              ],
            ],
          );
        }),

        // 收件箱
        if (inbox.isNotEmpty) ...[
          const SizedBox(height: 8),
          _InboxSection(
            inbox: inbox,
            primary: primary,
            isDark: isDark,
            onTap: onTap,
            onLongPress: onLongPress,
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  周日历条（PageView 内的单页，参照滴答清单紧凑设计）
// ─────────────────────────────────────────────────────────────────

class _WeekCalendarStrip extends StatelessWidget {
  final List<DateTime> weekDays;
  final DateTime today;
  final DateTime focusDate;
  final Map<DateTime, List<Checklist>> grouped;
  final Color primary;
  final bool isDark;
  final ValueChanged<DateTime> onDayTap;

  const _WeekCalendarStrip({
    required this.weekDays,
    required this.today,
    required this.focusDate,
    required this.grouped,
    required this.primary,
    required this.isDark,
    required this.onDayTap,
  });

  static const _labels = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    // 月份标签（如果一周跨月，显示较早月份）
    final monthLabel =
        '${weekDays.first.year}年${weekDays.first.month}月';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding:
          const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
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
                )
              ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 月份标签
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              monthLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? Colors.white38
                    : const Color(0xFFAAAAAA),
              ),
            ),
          ),
          // 七天格
          Row(
            children: List.generate(7, (idx) {
              final day = weekDays[idx];
              final isToday = day == today;
              final isFocus = day == focusDate;
              final hasItems = grouped.containsKey(day) &&
                  grouped[day]!.isNotEmpty;
              final allDone = hasItems &&
                  grouped[day]!.every((c) => c.isAllDone);
              final count = grouped[day]?.length ?? 0;
              final dotColor = hasItems
                  ? (allDone ? Colors.green : primary)
                  : null;

              return Expanded(
                child: GestureDetector(
                  onTap: () => onDayTap(day),
                  child: AnimatedContainer(
                    duration:
                        const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(
                        horizontal: 2),
                    padding: const EdgeInsets.symmetric(
                        vertical: 5),
                    decoration: BoxDecoration(
                      color: isFocus
                          ? primary
                          : (isToday
                              ? primary
                                  .withValues(alpha: 0.1)
                              : Colors.transparent),
                      borderRadius:
                          BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _labels[idx],
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: isFocus
                                ? Colors.white70
                                : (isDark
                                    ? Colors.white38
                                    : const Color(
                                        0xFFAAAAAA)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${day.day}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight:
                                (isToday || isFocus)
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                            color: isFocus
                                ? Colors.white
                                : (isToday
                                    ? primary
                                    : (isDark
                                        ? Colors.white
                                        : const Color(
                                            0xFF333333))),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // 任务数气泡
                        if (dotColor != null)
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: isFocus
                                  ? Colors.white
                                      .withValues(alpha: 0.3)
                                  : dotColor
                                      .withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '$count',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: isFocus
                                      ? Colors.white
                                      : dotColor,
                                ),
                              ),
                            ),
                          )
                        else
                          const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  VIEW 4：月视图（参照滴答清单：月历 + 每格2条任务名 + 选中日详情）
// ─────────────────────────────────────────────────────────────────

class _MonthView extends StatelessWidget {
  final DateTime monthStart;
  final DateTime focusDate;
  final ChecklistProvider provider;
  final bool isDark;
  final Color primary;
  final ValueChanged<DateTime> onDayTap;
  final ValueChanged<int> onMonthChanged;

  const _MonthView({
    required this.monthStart,
    required this.focusDate,
    required this.provider,
    required this.isDark,
    required this.primary,
    required this.onDayTap,
    required this.onMonthChanged,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final firstDay = monthStart;
    final daysInMonth =
        DateTime(firstDay.year, firstDay.month + 1, 0).day;
    final firstWeekday = firstDay.weekday;
    final leadingBlanks = firstWeekday - 1;
    final totalCells =
        (leadingBlanks + daysInMonth + 6) ~/ 7 * 7;

    // 建立当月任务映射（每天 -> 清单列表）
    final monthItemsMap = <DateTime, List<Checklist>>{};
    for (final c in provider.scheduledTemporalChecklists) {
      final d = c.scheduledDate!;
      final key = DateTime(d.year, d.month, d.day);
      if (d.month == firstDay.month && d.year == firstDay.year) {
        monthItemsMap.putIfAbsent(key, () => []).add(c);
      }
    }

    // 选中日清单
    final selectedItems = provider.temporalForDay(focusDate);
    final total =
        selectedItems.fold<int>(0, (s, c) => s + c.totalCount);
    final done =
        selectedItems.fold<int>(0, (s, c) => s + c.checkedCount);

    final monthLabel = '${firstDay.year}年${firstDay.month}月';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 月份标题 + 前后翻月
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Row(
            children: [
              _NavBtn(
                icon: Icons.chevron_left_rounded,
                color: primary,
                isDark: isDark,
                onTap: () => onMonthChanged(-1),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  monthLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? Colors.white
                        : const Color(0xFF1A1410),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _NavBtn(
                icon: Icons.chevron_right_rounded,
                color: primary,
                isDark: isDark,
                onTap: () => onMonthChanged(1),
              ),
            ],
          ),
        ),

        // 月历（含每格最多2条任务名，参照滴答清单）
        Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
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
                    )
                  ],
          ),
          child: Column(
            children: [
              // 周标题行
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: ['一', '二', '三', '四', '五', '六', '日']
                      .map((label) => Expanded(
                            child: Center(
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white38
                                      : const Color(0xFFAAAAAA),
                                ),
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),
              // 日格（参照滴答清单：大日期数字 + 事件小条）
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: 0.62,
                ),
                itemCount: totalCells,
                itemBuilder: (_, idx) {
                  final dayNum = idx - leadingBlanks + 1;
                  if (dayNum < 1 || dayNum > daysInMonth) {
                    return const SizedBox.shrink();
                  }
                  final day = DateTime(
                      firstDay.year, firstDay.month, dayNum);
                  final isToday = day == today;
                  final isFocus = day == focusDate;
                  final dayItems = monthItemsMap[day] ?? [];
                  final hasItems = dayItems.isNotEmpty;
                  final allDone =
                      hasItems && dayItems.every((c) => c.isAllDone);
                  final dotColor = hasItems
                      ? (allDone ? Colors.green : primary)
                      : null;

                  // 显示最多2条任务名（参照滴答清单的事件密度）
                  final previewItems = dayItems.take(2).toList();
                  final moreCount = dayItems.length - previewItems.length;

                  return GestureDetector(
                    onTap: () => onDayTap(day),
                    child: Container(
                      margin: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: isFocus
                            ? primary.withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: isFocus
                            ? Border.all(
                                color: primary.withValues(alpha: 0.4),
                                width: 1.5)
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          // 日期数字
                          Center(
                            child: AnimatedContainer(
                              duration:
                                  const Duration(milliseconds: 150),
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: isToday
                                    ? primary
                                    : Colors.transparent,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '$dayNum',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: (isToday || isFocus)
                                        ? FontWeight.w800
                                        : FontWeight.w400,
                                    color: isToday
                                        ? Colors.white
                                        : (isFocus
                                            ? primary
                                            : (isDark
                                                ? Colors.white
                                                : const Color(
                                                    0xFF333333))),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // 事件条（参照滴答清单：emoji + 标题截断）
                          ...previewItems.map((c) {
                            final itemColor = _parseColor(
                                c.colorHex, primary);
                            return Container(
                              margin: const EdgeInsets.fromLTRB(
                                  2, 1, 2, 0),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 3, vertical: 1),
                              decoration: BoxDecoration(
                                color: itemColor
                                    .withValues(alpha: 0.12),
                                borderRadius:
                                    BorderRadius.circular(3),
                              ),
                              child: Text(
                                '${c.emoji} ${c.title}',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w600,
                                  color: itemColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.clip,
                              ),
                            );
                          }),
                          // 更多计数
                          if (moreCount > 0)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                  4, 1, 2, 0),
                              child: Text(
                                '+$moreCount',
                                style: TextStyle(
                                  fontSize: 8,
                                  color: dotColor ??
                                      (isDark
                                          ? Colors.white38
                                          : const Color(
                                              0xFFAAAAAA)),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        // 选中日详情面板（参照滴答清单：月历下方直接展示当日任务）
        const SizedBox(height: 8),
        _SelectedDayPanel(
          focusDate: focusDate,
          items: selectedItems,
          total: total,
          done: done,
          primary: primary,
          isDark: isDark,
        ),
      ],
    );
  }

  Color _parseColor(String hex, Color fallback) {
    try {
      final h = hex.replaceAll('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return fallback;
    }
  }
}

// ─────────────────────────────────────────────────────────────────
//  月视图：选中日详情面板
// ─────────────────────────────────────────────────────────────────

class _SelectedDayPanel extends StatelessWidget {
  final DateTime focusDate;
  final List<Checklist> items;
  final int total;
  final int done;
  final Color primary;
  final bool isDark;

  const _SelectedDayPanel({
    required this.focusDate,
    required this.items,
    required this.total,
    required this.done,
    required this.primary,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isToday = focusDate == today;
    final allDone = total > 0 && done == total;

    String dayLabel;
    if (isToday) {
      dayLabel = '今天';
    } else if (focusDate == today.add(const Duration(days: 1))) {
      dayLabel = '明天';
    } else if (focusDate == today.subtract(const Duration(days: 1))) {
      dayLabel = '昨天';
    } else {
      const wd = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      dayLabel = wd[focusDate.weekday - 1];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 面板标题
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${focusDate.month}月${focusDate.day}日 · $dayLabel',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? Colors.white
                      : const Color(0xFF1A1410),
                ),
              ),
              if (total > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: allDone
                        ? Colors.green.withValues(alpha: 0.1)
                        : primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    allDone ? '全部完成' : '$done/$total',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: allDone ? Colors.green : primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        // 任务列表
        if (items.isEmpty)
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Text(
              '这一天暂无任务',
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? Colors.white24
                    : const Color(0xFFCCCCCC),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: items
                  .map((c) => _ScheduleCard(
                        checklist: c,
                        primary: primary,
                        isDark: isDark,
                        onTap: () {},
                        onLongPress: () {},
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  快速添加面板
//
//  产品语义：「为这天加一件事」，而非「新建一张清单」。
//  用户感知的是记录一条待办事项，背后技术上创建的是一个
//  单条目的时态型 Checklist，但这层概念对用户透明。
//
//  交互设计：
//  · 极简——只有一个输入框，键盘弹起即可输入，回车即提交
//  · 日期用 chip 显示，可点击切换，不强制显示日期选择器
//  · 提交按钮语义改为「添加」
// ─────────────────────────────────────────────────────────────────

class _ScheduleCreateSheet extends StatefulWidget {
  final DateTime initialDate;
  const _ScheduleCreateSheet({required this.initialDate});

  @override
  State<_ScheduleCreateSheet> createState() =>
      _ScheduleCreateSheetState();
}

class _ScheduleCreateSheetState extends State<_ScheduleCreateSheet> {
  final _titleCtrl = TextEditingController();
  late DateTime _date;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  /// 日期 chip 的显示文字：今天/明天/后天/X月X日
  String _dateChipLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    final diff = d.difference(today).inDays;
    if (diff == 0) return '今天';
    if (diff == 1) return '明天';
    if (diff == 2) return '后天';
    if (diff == -1) return '昨天';
    return '${date.month}月${date.day}日';
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    if (_saving) return;
    setState(() => _saving = true);

    final provider = context.read<ChecklistProvider>();
    await provider.addChecklist(
      title: title,
      checklistType: ChecklistType.temporal,
      scheduledDate: _date,
    );

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = WeeklyTheme.getLightPalette();
    final primary = isDark ? AppColors.darkPrimary : palette.primary;
    final bg = isDark ? AppColors.surfaceDark : Colors.white;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 拖拽条
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF444444)
                    : const Color(0xFFDDDDDD),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── 标题行：「添加到 X月X日」+ 日期 chip ────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '添加到',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1A1410),
                ),
              ),
              const SizedBox(width: 8),
              // 日期 chip：可点击切换日期
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime.now().subtract(
                        const Duration(days: 365)),
                    lastDate: DateTime.now()
                        .add(const Duration(days: 365 * 2)),
                    builder: (ctx, child) => Theme(
                      data: Theme.of(ctx).copyWith(
                        colorScheme:
                            ColorScheme.light(primary: primary),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null && mounted) {
                    setState(() => _date =
                        DateTime(picked.year, picked.month, picked.day));
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _dateChipLabel(_date),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: primary,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(Icons.expand_more_rounded,
                          size: 14, color: primary),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── 输入框：极简，无边框，填充色背景 ────────────────────
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _titleCtrl,
                  autofocus: true,
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? Colors.white : const Color(0xFF1A1410),
                  ),
                  decoration: InputDecoration(
                    hintText: '这件事叫什么……',
                    hintStyle: TextStyle(
                      color: isDark
                          ? Colors.white38
                          : const Color(0xFFBBBBBB),
                      fontWeight: FontWeight.w400,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF2A2A2A)
                        : const Color(0xFFF2F2F2),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
                  ),
                  onSubmitted: (_) => _save(),
                  textInputAction: TextInputAction.done,
                ),
              ),
              const SizedBox(width: 10),
              // 发送按钮（圆形，轻量）
              GestureDetector(
                onTap: _saving ? null : _save,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: primary.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: _saving
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 22,
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
//  右键菜单
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
    final bg = isDark ? AppColors.surfaceDark : Colors.white;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖拽条
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF444444)
                  : const Color(0xFFDDDDDD),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          // 标题
          Row(
            children: [
              Text(
                checklist.emoji,
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 8),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),
          _MenuItem(
            icon: Icons.event_repeat_rounded,
            label: '重新安排日期',
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
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final Color? color;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ??
        (isDark ? Colors.white : const Color(0xFF333333));
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: c),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: c,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
