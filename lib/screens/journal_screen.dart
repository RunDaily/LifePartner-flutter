import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/record.dart';
import '../providers/record_provider.dart';
import '../theme/app_theme.dart';
import 'journal_day_view_screen.dart';
import 'journal_editor_screen.dart';

// ─────────────────────────────────────────────────────────────────
//  JournalScreen —— 日记主页（时间线视图）
//
//  【设计理念】
//  日记是按天组织的，每天是一个"页"。
//  - 不按类型（笔记/灵感/心情）分类——那是杂记，不是日记
//  - 按日期降序排列，今天置顶高亮
//  - 每天只显示：日期 + 心情 + 内容预览（点进去才看全文）
//  - FAB："写今天的日记"
//
//  【数据来源】
//  journalRecords（note / idea / mood 域）
//  其中 note 类型 + extra['journalDate'] 是日记主体
//  idea / mood 也按日期归入对应天（作为当天的附属内容）
//
//  【导航关系】
//  JournalScreen → JournalDayViewScreen（某天详情）
//                → JournalEditorScreen（写今天的日记）
// ─────────────────────────────────────────────────────────────────

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RecordProvider>().loadAllRecords();
    });
  }

  // ── 工具方法 ──────────────────────────────────────────────────

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}'
      '-${date.month.toString().padLeft(2, '0')}'
      '-${date.day.toString().padLeft(2, '0')}';

  String _getJournalDate(Record r) {
    final fromExtra = r.extra['journalDate'] as String?;
    if (fromExtra != null && fromExtra.isNotEmpty) return fromExtra;
    return r.dateKey; // 向后兼容
  }

  /// 按日期分组，key = 'yyyy-MM-dd'
  Map<String, List<Record>> _groupByDate(List<Record> records) {
    final groups = <String, List<Record>>{};
    for (final r in records) {
      final key = _getJournalDate(r);
      groups.putIfAbsent(key, () => []).add(r);
    }
    return groups;
  }

  // ── 导航 ──────────────────────────────────────────────────────

  void _openToday() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => JournalEditorScreen(journalDate: DateTime.now()),
        fullscreenDialog: true,
      ),
    ).then((_) => setState(() {}));
  }

  void _openDay(DateTime date) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => JournalDayViewScreen(date: date),
      ),
    ).then((_) => setState(() {}));
  }

  // ── 日期显示格式 ──────────────────────────────────────────────

  /// 用于卡片主标题（今天/昨天/周X）
  String _formatDayTitle(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return '今天';
    if (d == yesterday) return '昨天';
    final weekdayNames = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return weekdayNames[date.weekday - 1];
  }

  /// 用于卡片副标题（月日）
  String _formatDaySubtitle(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year) {
      return '${date.month}月${date.day}日';
    }
    return '${date.year}年${date.month}月${date.day}日';
  }

  // ── 心情辅助 ─────────────────────────────────────────────────

  String? _dominantMood(List<Record> records) {
    final moods =
        records.where((r) => r.mood != null).map((r) => r.mood!).toList();
    if (moods.isEmpty) return null;
    final freq = <String, int>{};
    for (final m in moods) {
      freq[m] = (freq[m] ?? 0) + 1;
    }
    return (freq.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .first
        .key;
  }

  String _moodEmoji(String mood) {
    const map = {
      'happy': '😊', 'excited': '🤩', 'neutral': '😐',
      'touched': '🥹', 'sad': '😢', 'angry': '😠',
      'anxious': '😰', 'tired': '😪',
    };
    return map[mood] ?? '😊';
  }

  // ── 内容预览 ─────────────────────────────────────────────────

  /// 当天内容摘要（优先正文，取前80字）
  String _dayPreview(List<Record> records) {
    // 优先找有内容的笔记
    for (final r in records) {
      if (r.content.trim().isNotEmpty) {
        final text = r.content.trim().replaceAll('\n', ' ');
        return text.length > 80 ? '${text.substring(0, 80)}…' : text;
      }
    }
    // 都没有正文，看有没有标题
    for (final r in records) {
      if (r.title.trim().isNotEmpty) return r.title.trim();
    }
    return '';
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = WeeklyTheme.getLightPalette();
    final accentColor = isDark ? AppColors.darkPrimary : palette.primary;
    final bgColor =
        isDark ? AppColors.backgroundDark : const Color(0xFFF7F3EE);

    return Scaffold(
      backgroundColor: bgColor,
      body: Consumer<RecordProvider>(
        builder: (ctx, provider, _) {
          final records = provider.journalRecords;
          final groups = _groupByDate(records);
          final sortedKeys = groups.keys.toList()
            ..sort((a, b) => b.compareTo(a));

          // 今天是否已有日记
          final todayKey = _dateKey(DateTime.now());
          final hasTodayJournal = sortedKeys.contains(todayKey);

          return CustomScrollView(
            slivers: [
              // ── AppBar ──────────────────────────────────────────
              SliverAppBar(
                floating: true,
                backgroundColor: bgColor,
                elevation: 0,
                scrolledUnderElevation: 0,
                expandedHeight: 72,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding:
                      const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  title: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '日记',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1A1410),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${sortedKeys.length} 天',
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
              ),

              // ── 今天写日记入口（置顶 Banner）─────────────────
              SliverToBoxAdapter(
                child: _buildTodayBanner(
                  context,
                  isDark,
                  accentColor,
                  hasTodayJournal,
                  groups[todayKey],
                ),
              ),

              // ── 空状态 ──────────────────────────────────────
              if (sortedKeys.isEmpty ||
                  (sortedKeys.length == 1 &&
                      sortedKeys.first == todayKey &&
                      (groups[todayKey]?.isEmpty ?? true)))
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Column(
                      children: [
                        const Text('✍️',
                            style: TextStyle(fontSize: 52)),
                        const SizedBox(height: 16),
                        Text(
                          '还没有日记',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white54
                                : const Color(0xFF999999),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '点击上方开始写今天的第一篇',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? Colors.white30
                                : const Color(0xFFBBBBBB),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // ── 历史日记时间线 ────────────────────────────────
              if (sortedKeys.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final key = sortedKeys[i];
                        // 今天的 Banner 已在上方展示，跳过
                        if (key == todayKey) return const SizedBox.shrink();
                        final dayRecords = groups[key]!;
                        final date = DateTime.parse(key);
                        return _buildDayCard(
                          context,
                          date,
                          dayRecords,
                          isDark,
                          accentColor,
                          isToday: false,
                        );
                      },
                      childCount: sortedKeys.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),

      // ── FAB ─────────────────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openToday,
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(Icons.edit_rounded, size: 18),
        label: const Text(
          '写今天的日记',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  // ── 今天 Banner ──────────────────────────────────────────────

  Widget _buildTodayBanner(
    BuildContext context,
    bool isDark,
    Color accentColor,
    bool hasJournal,
    List<Record>? todayRecords,
  ) {
    final today = DateTime.now();
    final weekdayNames = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final weekday = weekdayNames[today.weekday - 1];
    final mood = todayRecords != null ? _dominantMood(todayRecords) : null;
    final preview =
        todayRecords != null ? _dayPreview(todayRecords) : null;

    return GestureDetector(
      onTap: hasJournal
          ? () => _openDay(today)
          : _openToday,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark
              ? accentColor.withValues(alpha: 0.15)
              : accentColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.25),
            width: 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 左侧：日期数字
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${today.day}',
                  style: TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                    height: 1.0,
                  ),
                ),
                Text(
                  '$weekday · ${today.month}月',
                  style: TextStyle(
                    fontSize: 13,
                    color: accentColor.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            // 右侧：内容预览 or 引导文案
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasJournal && preview != null && preview.isNotEmpty) ...[
                    if (mood != null) ...[
                      Text(
                        _moodEmoji(mood),
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      preview,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.8)
                            : const Color(0xFF333333),
                      ),
                    ),
                  ] else ...[
                    Text(
                      hasJournal ? '今天已有日记 →' : '今天还没写日记',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : const Color(0xFF555555),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasJournal ? '点击查看今天的内容' : '记录此刻的想法和感受',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? Colors.white38
                            : const Color(0xFF999999),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // 右侧箭头
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: accentColor.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  // ── 历史日记卡片 ─────────────────────────────────────────────

  Widget _buildDayCard(
    BuildContext context,
    DateTime date,
    List<Record> records,
    bool isDark,
    Color accentColor, {
    required bool isToday,
  }) {
    final mood = _dominantMood(records);
    final preview = _dayPreview(records);
    final hasContent = preview.isNotEmpty;

    return GestureDetector(
      onTap: () => _openDay(date),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 左侧：日期
            SizedBox(
              width: 48,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? Colors.white
                          : const Color(0xFF1A1410),
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDayTitle(date),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? const Color(0xFF888888)
                          : const Color(0xFFAAAAAA),
                    ),
                  ),
                  Text(
                    _formatDaySubtitle(date),
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark
                          ? const Color(0xFF666666)
                          : const Color(0xFFCCCCCC),
                    ),
                  ),
                ],
              ),
            ),
            // 分割线
            Container(
              width: 1,
              height: 56,
              margin: const EdgeInsets.symmetric(horizontal: 14),
              color: isDark
                  ? const Color(0xFF2A2A2A)
                  : const Color(0xFFEEEEEE),
            ),
            // 右侧：内容预览
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (mood != null) ...[
                    Text(
                      _moodEmoji(mood),
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (hasContent)
                    Text(
                      preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.55,
                        color: isDark
                            ? const Color(0xFFCCCCCC)
                            : const Color(0xFF444444),
                      ),
                    )
                  else
                    Text(
                      '${records.length} 条记录',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? const Color(0xFF888888)
                            : const Color(0xFFAAAAAA),
                      ),
                    ),
                ],
              ),
            ),
            // 箭头
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 2),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 12,
                color: isDark
                    ? const Color(0xFF555555)
                    : const Color(0xFFCCCCCC),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
