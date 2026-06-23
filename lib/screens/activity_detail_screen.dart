import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/activity_collection.dart';
import '../models/record.dart';
import '../providers/activity_collection_provider.dart';
import '../providers/record_provider.dart';
import '../services/ai_service.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────
//  ActivityDetailScreen —— 单个活动的详情页
//
//  【核心升级：五环专属记录形态】
//  不同维度的活动，打卡时弹出不同的记录表单，记录本身有血有肉：
//
//  🏃 身体力行 → 时长 + 强度 + 感受
//  ❤️ 关系连接 → 和谁 + 在哪里 + 心情
//  🎨 创造表达 → 做了什么 + 完成进度
//  🌱 心智成长 → 学了什么 + 一句话收获
//  🎯 心流专注 → 专注时长 + 完成了什么
//
//  所有扩展字段存于 Record.extra，不改变数据库结构。
//
//  【页面结构】
//  ① Hero 头部：渐变 + Emoji + 名称 + 五环标签
//  ② 统计行：累计 / 连续 / 本月（身体/专注维度额外展示时长）
//  ③ 本月热力格
//  ④ 活动记录时间线（按日分组，差异化卡片）
//  ⑤ 悬浮「记一下」按钮
// ─────────────────────────────────────────────────────────────────

class ActivityDetailScreen extends StatefulWidget {
  final ActivityDefinition activity;

  const ActivityDetailScreen({super.key, required this.activity});

  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  ActivityDefinition get _activity => widget.activity;

  Color get _colorStart {
    try {
      final hex = _activity.gradientHex.first.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF43E97B);
    }
  }

  Color get _colorEnd {
    try {
      final hex = _activity.gradientHex.last.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF38F9D7);
    }
  }

  // 维度颜色（统一来源）
  Color get _catColor {
    switch (_activity.category) {
      case ActivityCategory.body:   return const Color(0xFFFF6B35);
      case ActivityCategory.people: return const Color(0xFFE8507A);
      case ActivityCategory.create: return const Color(0xFF7C4DFF);
      case ActivityCategory.grow:   return const Color(0xFF2E7D32);
      case ActivityCategory.flow:   return const Color(0xFF1565C0);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RecordProvider>().loadAllRecords();
    });
  }

  List<Record> _getCheckIns(RecordProvider rp) {
    return rp.allRecords.where((r) {
      if (r.type != RecordType.event) return false;
      return r.extra['activityId'] == _activity.id;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  int _calcStreak(List<Record> checkIns) {
    if (checkIns.isEmpty) return 0;
    final today = DateTime.now();
    final doneDays = checkIns
        .map((r) => DateTime(r.createdAt.year, r.createdAt.month, r.createdAt.day))
        .toSet();
    int streak = 0;
    DateTime cursor = DateTime(today.year, today.month, today.day);
    while (doneDays.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  int _calcThisMonth(List<Record> checkIns) {
    final now = DateTime.now();
    return checkIns.where((r) =>
        r.createdAt.year == now.year && r.createdAt.month == now.month).length;
  }

  Set<int> _calcThisMonthDays(List<Record> checkIns) {
    final now = DateTime.now();
    return checkIns
        .where((r) =>
            r.createdAt.year == now.year && r.createdAt.month == now.month)
        .map((r) => r.createdAt.day)
        .toSet();
  }

  // 计算总时长（身体/专注维度）
  int _calcTotalMinutes(List<Record> checkIns) {
    int total = 0;
    for (final r in checkIns) {
      final dur = r.extra['duration'] as int?;
      final focusDur = r.extra['focusDuration'] as int?;
      total += dur ?? focusDur ?? 0;
    }
    return total;
  }

  Map<String, List<Record>> _groupByDay(List<Record> checkIns) {
    final map = <String, List<Record>>{};
    for (final r in checkIns) {
      final key = _dayLabel(r.createdAt);
      map.putIfAbsent(key, () => []).add(r);
    }
    return map;
  }

  String _dayLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return '今天';
    if (diff == 1) return '昨天';
    if (diff <= 6) return '$diff 天前';
    return '${dt.month}月${dt.day}日';
  }

  String _formatMinutes(int minutes) {
    if (minutes < 60) return '$minutes 分钟';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m > 0 ? '$h 小时 $m 分' : '$h 小时';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: Consumer<RecordProvider>(
        builder: (ctx, rp, _) {
          final checkIns = _getCheckIns(rp);
          final streak = _calcStreak(checkIns);
          final thisMonth = _calcThisMonth(checkIns);
          final thisMonthDays = _calcThisMonthDays(checkIns);
          final grouped = _groupByDay(checkIns);
          final dayKeys = grouped.keys.toList();
          final totalMinutes = _calcTotalMinutes(checkIns);
          final showTime = _activity.category == ActivityCategory.body ||
              _activity.category == ActivityCategory.flow;

          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  _buildHeroHeader(isDark),

                  SliverToBoxAdapter(
                    child: _buildStatsRow(
                      total: checkIns.length,
                      streak: streak,
                      thisMonth: thisMonth,
                      totalMinutes: totalMinutes,
                      showTime: showTime,
                      isDark: isDark,
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: _buildMonthGrid(thisMonthDays, isDark),
                  ),

                  if (checkIns.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                        child: Row(
                          children: [
                            Text(
                              '活动记录',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1A1410),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: _colorStart.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '共 ${checkIns.length} 次',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _colorStart,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  if (checkIns.isEmpty)
                    SliverToBoxAdapter(child: _buildEmptyState(isDark))
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) {
                            final key = dayKeys[i];
                            final records = grouped[key]!;
                            return _DayGroup(
                              dayLabel: key,
                              records: records,
                              activity: _activity,
                              colorStart: _colorStart,
                              catColor: _catColor,
                              isDark: isDark,
                              onDeleteRecord: (r) =>
                                  _deleteRecord(context, r, rp),
                            );
                          },
                          childCount: dayKeys.length,
                        ),
                      ),
                    ),
                ],
              ),

              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildCheckInBar(context, isDark),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeroHeader(bool isDark) {
    // 从 provider 获取最新的 activity（可能已有 AI 文案）
    final latestActivity = context
            .watch<ActivityCollectionProvider>()
            .activities
            .firstWhere((a) => a.id == _activity.id, orElse: () => _activity);
    final motto = ActivityMottoFallback.best(latestActivity);

    return SliverAppBar(
      expandedHeight: 240,
      pinned: true,
      backgroundColor: _colorStart,
      leading: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: IconButton(
          icon: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 14,
              color: Colors.white,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: IconButton(
            icon: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.more_horiz_rounded,
                size: 16,
                color: Colors.white,
              ),
            ),
            onPressed: () => _showOptionsSheet(context),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_colorStart, _colorEnd],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 56, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    _activity.emoji,
                    style: const TextStyle(fontSize: 52),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _activity.name,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // 专属文案行（AI 生成 or 本地精选）
                  Text(
                    motto,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.80),
                      height: 1.5,
                      fontStyle: latestActivity.mottoLine != null
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  // 五环标签
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_activity.category.emoji} ${_activity.category.label}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        // AI 生成标记
                        if (latestActivity.mottoLine != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '✨ AI',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow({
    required int total,
    required int streak,
    required int thisMonth,
    required int totalMinutes,
    required bool showTime,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          _StatCell(
            value: '$total',
            label: '累计次数',
            color: _colorStart,
            isDark: isDark,
          ),
          _VerticalDivider(isDark: isDark),
          _StatCell(
            value: streak > 0 ? '🔥$streak' : '0',
            label: '连续记录',
            color: const Color(0xFFFF6B35),
            isDark: isDark,
          ),
          _VerticalDivider(isDark: isDark),
          if (showTime && totalMinutes > 0) ...[
            _StatCell(
              value: _formatMinutes(totalMinutes),
              label: '累计时长',
              color: _colorEnd,
              isDark: isDark,
              smallText: true,
            ),
          ] else ...[
            _StatCell(
              value: '$thisMonth',
              label: '本月次数',
              color: _colorEnd,
              isDark: isDark,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMonthGrid(Set<int> checkedDays, bool isDark) {
    final now = DateTime.now();
    final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
    final firstWeekday = DateTime(now.year, now.month, 1).weekday % 7;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${now.month}月记录',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1A1410),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${checkedDays.length} / $daysInMonth 天',
                style: TextStyle(
                  fontSize: 11,
                  color: _colorStart,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['日', '一', '二', '三', '四', '五', '六']
                .map((d) => SizedBox(
                      width: 28,
                      child: Center(
                        child: Text(
                          d,
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark
                                ? Colors.white38
                                : const Color(0xFFCCCCCC),
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1,
            ),
            itemCount: firstWeekday + daysInMonth,
            itemBuilder: (ctx, i) {
              if (i < firstWeekday) return const SizedBox.shrink();
              final day = i - firstWeekday + 1;
              final isToday = day == now.day;
              final isChecked = checkedDays.contains(day);
              final isFuture = day > now.day;

              return Container(
                decoration: BoxDecoration(
                  color: isChecked
                      ? _colorStart
                      : (isToday
                          ? _colorStart.withValues(alpha: 0.15)
                          : (isDark
                              ? const Color(0xFF2A2A2A)
                              : const Color(0xFFF5F5F5))),
                  borderRadius: BorderRadius.circular(6),
                  border: isToday && !isChecked
                      ? Border.all(color: _colorStart, width: 1.5)
                      : null,
                ),
                child: Center(
                  child: Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight:
                          isChecked || isToday ? FontWeight.w700 : FontWeight.w400,
                      color: isChecked
                          ? Colors.white
                          : (isFuture
                              ? (isDark
                                  ? const Color(0xFF333333)
                                  : const Color(0xFFDDDDDD))
                              : (isDark
                                  ? Colors.white54
                                  : const Color(0xFF666666))),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    // 从 provider 读取最新活动（可能已有 AI 文案）
    final latestActivity = context
        .read<ActivityCollectionProvider>()
        .activities
        .firstWhere((a) => a.id == _activity.id, orElse: () => _activity);
    final motto = ActivityMottoFallback.best(latestActivity);
    final actionHint = _emptyActionHint(_activity.category);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      child: Column(
        children: [
          // 专属文案大显示
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: _colorStart.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _colorStart.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Text(
                  _activity.emoji,
                  style: const TextStyle(fontSize: 36),
                ),
                const SizedBox(height: 10),
                Text(
                  motto,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white70 : const Color(0xFF444444),
                    height: 1.6,
                    fontStyle: latestActivity.mottoLine != null
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (latestActivity.mottoLine != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '✨ 专属文案已生成',
                    style: TextStyle(
                      fontSize: 11,
                      color: _colorStart,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            actionHint,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? const Color(0xFF555555) : const Color(0xFFCCCCCC),
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _emptyActionHint(ActivityCategory cat) {
    switch (cat) {
      case ActivityCategory.body:
        return '完成一次，记录时长和强度，让身体数据说话';
      case ActivityCategory.people:
        return '下次相聚后，记下和谁、在哪里，这些瞬间值得留存';
      case ActivityCategory.create:
        return '完成一次创作后，记下做了什么，见证你的积累';
      case ActivityCategory.grow:
        return '学到什么或有所感悟时，用一句话把收获留下来';
      case ActivityCategory.flow:
        return '完成一段深度工作后，记录专注时长和里程碑';
    }
  }

  Widget _buildCheckInBar(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: () => _showCheckInSheet(context, isDark),
          style: ElevatedButton.styleFrom(
            backgroundColor: _colorStart,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_activity.emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              const Text(
                '记一下',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCheckInSheet(BuildContext context, bool isDark) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CheckInSheet(
        activity: _activity,
        colorStart: _colorStart,
        catColor: _catColor,
        isDark: isDark,
      ),
    );
  }

  void _deleteRecord(BuildContext context, Record record, RecordProvider rp) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这条记录？'),
        content: const Text('删除后无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              rp.deleteRecord(record.id);
              Navigator.pop(ctx);
            },
            child: const Text('删除',
                style: TextStyle(color: Color(0xFFE74C3C))),
          ),
        ],
      ),
    );
  }

  void _showOptionsSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _OptionsSheet(
        activity: _activity,
        isDark: isDark,
        colorStart: _colorStart,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  五套专属打卡弹窗 —— 统一入口，按维度智能路由
// ─────────────────────────────────────────────────────────────────

class _CheckInSheet extends StatefulWidget {
  final ActivityDefinition activity;
  final Color colorStart;
  final Color catColor;
  final bool isDark;

  const _CheckInSheet({
    required this.activity,
    required this.colorStart,
    required this.catColor,
    required this.isDark,
  });

  @override
  State<_CheckInSheet> createState() => _CheckInSheetState();
}

class _CheckInSheetState extends State<_CheckInSheet> {
  final _noteController = TextEditingController();
  bool _isSaving = false;

  // ── 通用字段 ─────────────────────────────────────────────────
  String? _mood; // 关系维度用

  // ── 🏃 身体维度 ───────────────────────────────────────────────
  int _duration = 30; // 时长（分钟）
  String _intensity = 'medium'; // 轻松 / 中等 / 高强度

  // ── ❤️ 关系维度 ───────────────────────────────────────────────
  final _withWhoController = TextEditingController();
  final _placeController = TextEditingController();

  // ── 🎨 创造维度 ───────────────────────────────────────────────
  final _outputController = TextEditingController(); // 做了什么
  int _progress = -1; // -1 = 不填进度

  // ── 🌱 成长维度 ───────────────────────────────────────────────
  final _subjectController = TextEditingController(); // 学/读的内容
  final _insightController = TextEditingController(); // 一句话收获

  // ── 🎯 专注维度 ───────────────────────────────────────────────
  int _focusDuration = 60;
  final _milestoneController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    _withWhoController.dispose();
    _placeController.dispose();
    _outputController.dispose();
    _subjectController.dispose();
    _insightController.dispose();
    _milestoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final extra = <String, dynamic>{
        'activityId': widget.activity.id,
        'activityEmoji': widget.activity.emoji,
        'categoryValue': widget.activity.category.value,
      };

      // 按维度注入专属字段
      switch (widget.activity.category) {
        case ActivityCategory.body:
          extra['duration'] = _duration;
          extra['intensity'] = _intensity;
          break;
        case ActivityCategory.people:
          final who = _withWhoController.text.trim();
          final place = _placeController.text.trim();
          if (who.isNotEmpty) extra['withWho'] = who;
          if (place.isNotEmpty) extra['place'] = place;
          break;
        case ActivityCategory.create:
          final output = _outputController.text.trim();
          if (output.isNotEmpty) extra['output'] = output;
          if (_progress >= 0) extra['progress'] = _progress;
          break;
        case ActivityCategory.grow:
          final subject = _subjectController.text.trim();
          final insight = _insightController.text.trim();
          if (subject.isNotEmpty) extra['subject'] = subject;
          if (insight.isNotEmpty) extra['insight'] = insight;
          break;
        case ActivityCategory.flow:
          extra['focusDuration'] = _focusDuration;
          final milestone = _milestoneController.text.trim();
          if (milestone.isNotEmpty) extra['milestone'] = milestone;
          break;
      }

      await context.read<RecordProvider>().addRecord(
            type: RecordType.event,
            title: widget.activity.name,
            content: _noteController.text.trim(),
            mood: _mood,
            tags: [widget.activity.name, widget.activity.category.label],
            extra: extra,
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.activity.emoji} 记录成功！'),
            backgroundColor: widget.colorStart,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: BoxDecoration(
        color: widget.isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
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
              // 头部
              _buildSheetHeader(),
              const SizedBox(height: 20),
              // 维度专属内容区
              _buildDimensionFields(),
              // 备注（通用）
              const SizedBox(height: 16),
              _buildNoteField(),
              const SizedBox(height: 20),
              // 保存按钮
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.colorStart,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          '${widget.activity.emoji} 记一下',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSheetHeader() {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                widget.colorStart,
                widget.colorStart.withValues(alpha: 0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(
              widget.activity.emoji,
              style: const TextStyle(fontSize: 24),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.activity.name,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: widget.isDark ? Colors.white : const Color(0xFF1A1410),
                ),
              ),
              Text(
                '${widget.activity.category.emoji} ${widget.activity.category.label}',
                style: TextStyle(
                  fontSize: 12,
                  color: widget.catColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 根据维度渲染专属字段
  Widget _buildDimensionFields() {
    switch (widget.activity.category) {
      case ActivityCategory.body:
        return _buildBodyFields();
      case ActivityCategory.people:
        return _buildPeopleFields();
      case ActivityCategory.create:
        return _buildCreateFields();
      case ActivityCategory.grow:
        return _buildGrowFields();
      case ActivityCategory.flow:
        return _buildFlowFields();
    }
  }

  // ── 🏃 身体维度字段 ───────────────────────────────────────────

  Widget _buildBodyFields() {
    final durations = [15, 20, 30, 45, 60, 90, 120];
    final intensities = [
      ('easy', '😌', '轻松'),
      ('medium', '💪', '适中'),
      ('hard', '🔥', '高强度'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('时长', isDark: widget.isDark),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: durations.map((d) {
              final isSelected = _duration == d;
              return GestureDetector(
                onTap: () => setState(() => _duration = d),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? widget.colorStart
                        : (widget.isDark
                            ? const Color(0xFF2A2A2A)
                            : const Color(0xFFF2F2F2)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    d < 60 ? '$d 分' : '${d ~/ 60}小时${d % 60 > 0 ? '${d % 60}分' : ''}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : (widget.isDark
                              ? Colors.white60
                              : const Color(0xFF555555)),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        _SectionLabel('强度', isDark: widget.isDark),
        const SizedBox(height: 8),
        Row(
          children: intensities.map((opt) {
            final isSelected = _intensity == opt.$1;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _intensity = opt.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? widget.colorStart.withValues(alpha: 0.12)
                        : (widget.isDark
                            ? const Color(0xFF2A2A2A)
                            : const Color(0xFFF5F5F5)),
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected
                        ? Border.all(
                            color: widget.colorStart, width: 1.5)
                        : null,
                  ),
                  child: Column(
                    children: [
                      Text(opt.$2,
                          style: const TextStyle(fontSize: 22)),
                      const SizedBox(height: 4),
                      Text(
                        opt.$3,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: isSelected
                              ? widget.colorStart
                              : (widget.isDark
                                  ? Colors.white54
                                  : const Color(0xFF888888)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── ❤️ 关系维度字段 ───────────────────────────────────────────

  Widget _buildPeopleFields() {
    final moods = [
      ('happy', '😊', '开心'),
      ('touched', '🥹', '感动'),
      ('neutral', '😐', '平静'),
      ('tired', '😪', '疲惫'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('和谁在一起', isDark: widget.isDark),
        const SizedBox(height: 8),
        _StyledTextField(
          controller: _withWhoController,
          hintText: '如：妈妈、老王和小李、3个朋友...',
          isDark: widget.isDark,
          prefixEmoji: '👥',
        ),
        const SizedBox(height: 14),
        _SectionLabel('在哪里', isDark: widget.isDark),
        const SizedBox(height: 8),
        _StyledTextField(
          controller: _placeController,
          hintText: '如：家里、咖啡馆、公园...',
          isDark: widget.isDark,
          prefixEmoji: '📍',
        ),
        const SizedBox(height: 14),
        _SectionLabel('心情如何', isDark: widget.isDark),
        const SizedBox(height: 8),
        Row(
          children: moods.map((opt) {
            final isSelected = _mood == opt.$1;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(
                    () => _mood = isSelected ? null : opt.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? widget.colorStart.withValues(alpha: 0.12)
                        : (widget.isDark
                            ? const Color(0xFF2A2A2A)
                            : const Color(0xFFF5F5F5)),
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected
                        ? Border.all(
                            color: widget.colorStart, width: 1.5)
                        : null,
                  ),
                  child: Column(
                    children: [
                      Text(opt.$2,
                          style: const TextStyle(fontSize: 20)),
                      const SizedBox(height: 3),
                      Text(
                        opt.$3,
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected
                              ? widget.colorStart
                              : (widget.isDark
                                  ? Colors.white54
                                  : const Color(0xFF888888)),
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── 🎨 创造维度字段 ───────────────────────────────────────────

  Widget _buildCreateFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('这次做了什么', isDark: widget.isDark),
        const SizedBox(height: 8),
        _StyledTextField(
          controller: _outputController,
          hintText: '如：写了1500字、完成了草稿、录了一段...',
          isDark: widget.isDark,
          prefixEmoji: '✨',
        ),
        const SizedBox(height: 14),
        _SectionLabel('完成进度（可选）', isDark: widget.isDark),
        const SizedBox(height: 8),
        _ProgressSelector(
          value: _progress,
          color: widget.colorStart,
          isDark: widget.isDark,
          onChanged: (v) => setState(() => _progress = v),
        ),
      ],
    );
  }

  // ── 🌱 成长维度字段 ───────────────────────────────────────────

  Widget _buildGrowFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('学了什么 / 读了什么', isDark: widget.isDark),
        const SizedBox(height: 8),
        _StyledTextField(
          controller: _subjectController,
          hintText: '如：《原则》第三章、李笑来的播客、React Hooks...',
          isDark: widget.isDark,
          prefixEmoji: '📖',
        ),
        const SizedBox(height: 14),
        _SectionLabel('一句话收获', isDark: widget.isDark),
        const SizedBox(height: 8),
        _StyledTextField(
          controller: _insightController,
          hintText: '把最触动你的那句话留下来...',
          isDark: widget.isDark,
          prefixEmoji: '💡',
          maxLines: 2,
        ),
      ],
    );
  }

  // ── 🎯 专注维度字段 ───────────────────────────────────────────

  Widget _buildFlowFields() {
    final durations = [15, 25, 30, 45, 60, 90, 120];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('专注时长', isDark: widget.isDark),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: durations.map((d) {
              final isSelected = _focusDuration == d;
              return GestureDetector(
                onTap: () => setState(() => _focusDuration = d),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? widget.colorStart
                        : (widget.isDark
                            ? const Color(0xFF2A2A2A)
                            : const Color(0xFFF2F2F2)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    d < 60 ? '$d 分钟' : '${d ~/ 60}h${d % 60 > 0 ? '${d % 60}m' : ''}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : (widget.isDark
                              ? Colors.white60
                              : const Color(0xFF555555)),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        _SectionLabel('这次完成了什么', isDark: widget.isDark),
        const SizedBox(height: 8),
        _StyledTextField(
          controller: _milestoneController,
          hintText: '如：写完了需求文档、完成了代码 review...',
          isDark: widget.isDark,
          prefixEmoji: '🎯',
        ),
      ],
    );
  }

  // ── 通用备注 ──────────────────────────────────────────────────

  Widget _buildNoteField() {
    // 关系和成长维度已有足够字段，备注设为"其他想说的"
    final hintMap = {
      ActivityCategory.body: '身体感受，或者今天状态特别好/差的原因...',
      ActivityCategory.people: '这次相聚最让你印象深刻的一刻...',
      ActivityCategory.create: '创作过程中的想法、灵感或卡住的地方...',
      ActivityCategory.grow: '（可选）延伸思考或行动计划...',
      ActivityCategory.flow: '状态复盘，进入心流了吗？',
    };
    final hint = hintMap[widget.activity.category] ?? '留下一句话（可选）';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('备注', isDark: widget.isDark, optional: true),
        const SizedBox(height: 8),
        TextField(
          controller: _noteController,
          maxLines: 2,
          style: TextStyle(
            fontSize: 14,
            color: widget.isDark ? Colors.white : const Color(0xFF1A1410),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: widget.isDark
                  ? const Color(0xFF555555)
                  : const Color(0xFFCCCCCC),
              fontSize: 13,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: widget.isDark
                ? const Color(0xFF2A2A2A)
                : const Color(0xFFF5F5F5),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  辅助 Widget：分区标签
// ─────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  final bool isDark;
  final bool optional;

  const _SectionLabel(this.text,
      {required this.isDark, this.optional = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFF888888) : const Color(0xFF666666),
          ),
        ),
        if (optional) ...[
          const SizedBox(width: 4),
          Text(
            '可选',
            style: TextStyle(
              fontSize: 11,
              color: isDark
                  ? const Color(0xFF555555)
                  : const Color(0xFFBBBBBB),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  辅助 Widget：带 emoji 前缀的输入框
// ─────────────────────────────────────────────────────────────────

class _StyledTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool isDark;
  final String prefixEmoji;
  final int maxLines;

  const _StyledTextField({
    required this.controller,
    required this.hintText,
    required this.isDark,
    required this.prefixEmoji,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(prefixEmoji,
                style: const TextStyle(fontSize: 18)),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: maxLines,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white : const Color(0xFF1A1410),
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(
                  color: isDark
                      ? const Color(0xFF555555)
                      : const Color(0xFFCCCCCC),
                  fontSize: 13,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  辅助 Widget：进度选择器（创造维度）
// ─────────────────────────────────────────────────────────────────

class _ProgressSelector extends StatelessWidget {
  final int value; // -1 = 未选
  final Color color;
  final bool isDark;
  final void Function(int) onChanged;

  const _ProgressSelector({
    required this.value,
    required this.color,
    required this.isDark,
    required this.onChanged,
  });

  static const _options = [25, 50, 75, 100];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // 跳过按钮
        GestureDetector(
          onTap: () => onChanged(-1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: value == -1
                  ? (isDark ? const Color(0xFF333333) : const Color(0xFFEEEEEE))
                  : (isDark ? const Color(0xFF252525) : const Color(0xFFF8F8F8)),
              borderRadius: BorderRadius.circular(10),
              border: value == -1
                  ? Border.all(
                      color: isDark ? Colors.white24 : Colors.black12)
                  : null,
            ),
            child: Text(
              '不填',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : const Color(0xFF999999),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ..._options.map((p) {
          final isSelected = value == p;
          return GestureDetector(
            onTap: () => onChanged(isSelected ? -1 : p),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: 0.15)
                    : (isDark
                        ? const Color(0xFF2A2A2A)
                        : const Color(0xFFF2F2F2)),
                borderRadius: BorderRadius.circular(10),
                border: isSelected
                    ? Border.all(color: color, width: 1.5)
                    : null,
              ),
              child: Text(
                '$p%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? color
                      : (isDark
                          ? Colors.white60
                          : const Color(0xFF555555)),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  每日分组
// ─────────────────────────────────────────────────────────────────

class _DayGroup extends StatelessWidget {
  final String dayLabel;
  final List<Record> records;
  final ActivityDefinition activity;
  final Color colorStart;
  final Color catColor;
  final bool isDark;
  final void Function(Record) onDeleteRecord;

  const _DayGroup({
    required this.dayLabel,
    required this.records,
    required this.activity,
    required this.colorStart,
    required this.catColor,
    required this.isDark,
    required this.onDeleteRecord,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: colorStart,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                dayLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? const Color(0xFF888888)
                      : const Color(0xFF999999),
                ),
              ),
            ],
          ),
        ),
        ...records.map((r) => _CheckInCard(
              record: r,
              activity: activity,
              colorStart: colorStart,
              catColor: catColor,
              isDark: isDark,
              onDelete: () => onDeleteRecord(r),
            )),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  单条活动记录卡片 —— 按维度差异化渲染
// ─────────────────────────────────────────────────────────────────

class _CheckInCard extends StatelessWidget {
  final Record record;
  final ActivityDefinition activity;
  final Color colorStart;
  final Color catColor;
  final bool isDark;
  final VoidCallback onDelete;

  const _CheckInCard({
    required this.record,
    required this.activity,
    required this.colorStart,
    required this.catColor,
    required this.isDark,
    required this.onDelete,
  });

  String get _timeStr {
    final h = record.createdAt.hour.toString().padLeft(2, '0');
    final m = record.createdAt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  // 根据维度提取核心摘要行
  String? _buildSummaryLine() {
    final e = record.extra;
    final cat = ActivityCategory.values.firstWhere(
      (c) => c.value == (e['categoryValue'] as String? ?? ''),
      orElse: () => activity.category,
    );

    switch (cat) {
      case ActivityCategory.body:
        final dur = e['duration'] as int?;
        final intensity = e['intensity'] as String?;
        final intensityLabel = {
          'easy': '😌 轻松',
          'medium': '💪 适中',
          'hard': '🔥 高强度',
        }[intensity ?? ''] ?? '';
        if (dur != null) {
          return '⏱ ${_fmtMin(dur)}${intensityLabel.isNotEmpty ? '  $intensityLabel' : ''}';
        }
        return null;

      case ActivityCategory.people:
        final who = e['withWho'] as String?;
        final place = e['place'] as String?;
        final parts = <String>[];
        if (who != null && who.isNotEmpty) parts.add('👥 $who');
        if (place != null && place.isNotEmpty) parts.add('📍 $place');
        return parts.isNotEmpty ? parts.join('  ') : null;

      case ActivityCategory.create:
        final output = e['output'] as String?;
        final progress = e['progress'] as int?;
        final parts = <String>[];
        if (output != null && output.isNotEmpty) parts.add('✨ $output');
        if (progress != null && progress >= 0) parts.add('$progress% 完成');
        return parts.isNotEmpty ? parts.join('  ') : null;

      case ActivityCategory.grow:
        final subject = e['subject'] as String?;
        if (subject != null && subject.isNotEmpty) return '📖 $subject';
        return null;

      case ActivityCategory.flow:
        final focusDur = e['focusDuration'] as int?;
        final milestone = e['milestone'] as String?;
        final parts = <String>[];
        if (focusDur != null) parts.add('⏱ ${_fmtMin(focusDur)}');
        if (milestone != null && milestone.isNotEmpty) parts.add('🎯 $milestone');
        return parts.isNotEmpty ? parts.join('  ') : null;
    }
  }

  // 成长维度的「一句话收获」
  String? _buildInsightLine() {
    final e = record.extra;
    final cat = ActivityCategory.values.firstWhere(
      (c) => c.value == (e['categoryValue'] as String? ?? ''),
      orElse: () => activity.category,
    );
    if (cat != ActivityCategory.grow) return null;
    final insight = e['insight'] as String?;
    if (insight == null || insight.isEmpty) return null;
    return '💡 $insight';
  }

  String _fmtMin(int m) {
    if (m < 60) return '$m 分钟';
    final h = m ~/ 60;
    final rem = m % 60;
    return rem > 0 ? '$h 小时 $rem 分' : '$h 小时';
  }

  String? get _moodEmoji {
    switch (record.mood) {
      case 'happy':    return '😊';
      case 'excited':  return '🤩';
      case 'neutral':  return '😐';
      case 'tired':    return '😪';
      case 'satisfied': return '😌';
      case 'touched':  return '🥹';
      default:         return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final summaryLine = _buildSummaryLine();
    final insightLine = _buildInsightLine();
    final hasContent = record.content.isNotEmpty;
    final hasAnyInfo = summaryLine != null || hasContent || insightLine != null;

    return GestureDetector(
      onLongPress: onDelete,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border(
            left: BorderSide(color: colorStart, width: 3),
          ),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 时间 + 心情行
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  _timeStr,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colorStart,
                  ),
                ),
                if (_moodEmoji != null) ...[
                  const SizedBox(width: 6),
                  Text(_moodEmoji!,
                      style: const TextStyle(fontSize: 14)),
                ],
                const Spacer(),
                // 维度标签小角标
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    activity.category.emoji,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
            // 摘要行（维度专属）
            if (summaryLine != null) ...[
              const SizedBox(height: 8),
              Text(
                summaryLine,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1A1410),
                  height: 1.4,
                ),
              ),
            ],
            // 成长维度收获行
            if (insightLine != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                  border: Border(
                    left: BorderSide(
                        color: catColor.withValues(alpha: 0.5),
                        width: 2),
                  ),
                ),
                child: Text(
                  insightLine,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.8)
                        : const Color(0xFF333333),
                    fontStyle: FontStyle.italic,
                    height: 1.5,
                  ),
                ),
              ),
            ],
            // 备注内容
            if (hasContent) ...[
              SizedBox(height: hasAnyInfo ? 6 : 0),
              Text(
                record.content,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: isDark
                      ? const Color(0xFF999999)
                      : const Color(0xFF666666),
                ),
              ),
            ],
            // 无任何内容
            if (!hasAnyInfo)
              Text(
                '已记录',
                style: TextStyle(
                  fontSize: 13,
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

// ─────────────────────────────────────────────────────────────────
//  小标签 Chip
// ─────────────────────────────────────────────────────────────────

class _SmallChip extends StatelessWidget {
  final String text;
  final Color color;
  final bool isDark;

  const _SmallChip(
      {required this.text, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  统计数据单元格
// ─────────────────────────────────────────────────────────────────

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final bool isDark;
  final bool smallText;

  const _StatCell({
    required this.value,
    required this.label,
    required this.color,
    required this.isDark,
    this.smallText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: smallText ? 15 : 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark
                  ? const Color(0xFF888888)
                  : const Color(0xFFAAAAAA),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  final bool isDark;
  const _VerticalDivider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      color: isDark ? const Color(0xFF333333) : const Color(0xFFEEEEEE),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  更多选项底部弹窗
// ─────────────────────────────────────────────────────────────────

class _OptionsSheet extends StatelessWidget {
  final ActivityDefinition activity;
  final bool isDark;
  final Color colorStart;

  const _OptionsSheet({
    required this.activity,
    required this.isDark,
    required this.colorStart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _OptionTile(
                icon: Icons.edit_rounded,
                label: '编辑活动信息',
                color: colorStart,
                isDark: isDark,
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              _OptionTile(
                icon: Icons.share_rounded,
                label: '分享活动记录',
                color: const Color(0xFF2F80ED),
                isDark: isDark,
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 8),
              _OptionTile(
                icon: Icons.delete_outline_rounded,
                label: '从活动集中移除',
                color: const Color(0xFFE74C3C),
                isDark: isDark,
                onTap: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : const Color(0xFF1A1410),
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}