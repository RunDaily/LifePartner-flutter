import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/record.dart';
import '../providers/record_provider.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────
//  NotesScreen —— 知识视图（知识域）
//
//  【域归属】💎 知识域
//  只展示：收藏(collect) / 阅读(reading)
//
//  这是你的"知识库"，沉淀了所有值得二次回顾的外部内容。
//  笔记/灵感/心情归「日记域」(JournalScreen)；
//  活动/打卡归「活动域」(ActivityCollectionScreen)。
//
//  支持：
//  - 按内容类型筛选（全部 / 收藏 / 阅读）
//  - 全文搜索
//  - 两种视图：时间流 / 阅读进度（阅读类型专属）
//  - 收藏内容高亮（isFavorite）
// ─────────────────────────────────────────────────────────────────

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen>
    with SingleTickerProviderStateMixin {
  RecordType? _selectedFilter; // null = 全部
  bool _isSearching = false;
  final _searchController = TextEditingController();
  List<Record>? _searchResults;
  bool _isSearchLoading = false;

  // 知识域筛选器：收藏 / 阅读
  static const _filters = [
    (null, '全部', '💎'),
    (RecordType.collect, '收藏', '🔖'),
    (RecordType.reading, '阅读', '📚'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RecordProvider>().loadAllRecords();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Record> _filteredRecords(List<Record> knowledge) {
    if (_selectedFilter == null) return knowledge;
    return knowledge.where((r) => r.type == _selectedFilter).toList();
  }

  List<_DayGroup> _groupByDay(List<Record> records) {
    final groups = <String, List<Record>>{};
    for (final r in records) {
      groups.putIfAbsent(r.dateKey, () => []).add(r);
    }
    final sortedKeys = groups.keys.toList()..sort((a, b) => b.compareTo(a));
    return sortedKeys
        .map((k) => _DayGroup(dateKey: k, records: groups[k]!))
        .toList();
  }

  Future<void> _performSearch(String query, RecordProvider provider) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = null;
        _isSearchLoading = false;
      });
      return;
    }
    setState(() => _isSearchLoading = true);
    // 只搜索知识域数据
    final allResults = await provider.search(query);
    final knowledgeResults =
        allResults.where((r) => r.type.isKnowledgeDomain).toList();
    if (mounted) {
      setState(() {
        _searchResults = knowledgeResults;
        _isSearchLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = WeeklyTheme.getLightPalette();

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : palette.background,
      body: Consumer<RecordProvider>(
        builder: (ctx, provider, _) {
          // 知识域记录（collect / reading）
          final knowledgeRecords = provider.knowledgeRecords;
          final displayRecords = _isSearching && _searchResults != null
              ? _searchResults!
              : _filteredRecords(knowledgeRecords);
          final groups = _groupByDay(displayRecords);

          return CustomScrollView(
            slivers: [
              _buildAppBar(context, isDark, palette, provider),
              _buildFilterBar(isDark, palette),
              // 阅读进度摘要（有阅读中的书时展示）
              if (_selectedFilter == null || _selectedFilter == RecordType.reading)
                _buildReadingProgress(provider, isDark),
              if (_isSearching && _isSearchLoading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else if (groups.isEmpty)
                _buildEmptyState(isDark)
              else
                _buildRecordList(groups, isDark),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          );
        },
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────
  Widget _buildAppBar(BuildContext context, bool isDark, DayPalette palette,
      RecordProvider provider) {
    return SliverAppBar(
      floating: true,
      backgroundColor: isDark ? AppColors.backgroundDark : palette.background,
      elevation: 0,
      expandedHeight: 80,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF1A1410),
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  hintText: '搜索收藏与阅读...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                    color: isDark
                        ? const Color(0xFF666666)
                        : const Color(0xFFBBBBBB),
                  ),
                ),
                onChanged: (v) => _performSearch(v, provider),
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '知识库',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1A1410),
                    ),
                  ),
                  const Spacer(),
                  // 知识域总数
                  Consumer<RecordProvider>(
                    builder: (ctx, rp, _) => Text(
                      '共 ${rp.knowledgeRecords.length} 条',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? const Color(0xFF666666)
                            : const Color(0xFFBBBBBB),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => setState(() => _isSearching = true),
                    child: Icon(
                      Icons.search_rounded,
                      color: isDark
                          ? const Color(0xFF888888)
                          : const Color(0xFFBBBBBB),
                      size: 22,
                    ),
                  ),
                ],
              ),
      ),
      actions: _isSearching
          ? [
              TextButton(
                onPressed: () {
                  setState(() {
                    _isSearching = false;
                    _searchResults = null;
                    _searchController.clear();
                  });
                },
                child: const Text('取消'),
              ),
            ]
          : null,
    );
  }

  // ── 筛选栏 ─────────────────────────────────────────────────────
  Widget _buildFilterBar(bool isDark, DayPalette palette) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _filters.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (ctx, i) {
            final (type, label, emoji) = _filters[i];
            final isSelected = _selectedFilter == type;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedFilter = type);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? AppColors.darkPrimary : palette.primary)
                      : (isDark ? AppColors.surfaceDark : Colors.white),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : (isDark
                            ? const Color(0xFF333333)
                            : const Color(0xFFE8E8E8)),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : (isDark
                                ? Colors.white70
                                : const Color(0xFF555555)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── 阅读进度摘要条 ─────────────────────────────────────────────
  Widget _buildReadingProgress(RecordProvider provider, bool isDark) {
    final inProgress = provider.readings
        .where((r) => r.readingProgress > 0 && r.readingProgress < 100)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    if (inProgress.isEmpty) return const SliverToBoxAdapter(child: SizedBox());

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1A2A1A)
              : const Color(0xFFF0FAF0),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? const Color(0xFF27AE60).withValues(alpha: 0.2)
                : const Color(0xFF27AE60).withValues(alpha: 0.15),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('📚', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 6),
                Text(
                  '正在阅读 ${inProgress.length} 本',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFF27AE60)
                        : const Color(0xFF27AE60),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...inProgress.take(3).map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          r.title.isNotEmpty ? r.title : r.content,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white70 : const Color(0xFF333333),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 80,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: r.readingProgress / 100,
                            backgroundColor: isDark
                                ? const Color(0xFF333333)
                                : const Color(0xFFE0E0E0),
                            valueColor: const AlwaysStoppedAnimation(
                                Color(0xFF27AE60)),
                            minHeight: 5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${r.readingProgress}%',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF27AE60),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  // ── 空状态 ─────────────────────────────────────────────────────
  Widget _buildEmptyState(bool isDark) {
    final isCollect = _selectedFilter == RecordType.collect;
    final isReading = _selectedFilter == RecordType.reading;
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isReading ? '📚' : isCollect ? '🔖' : '💎',
              style: const TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 16),
            Text(
              isReading
                  ? '还没有阅读记录'
                  : isCollect
                      ? '还没有收藏内容'
                      : '知识库还是空的',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white54 : const Color(0xFF999999),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isReading
                  ? '点击底部 ＋ 记录正在读的书或文章'
                  : isCollect
                      ? '点击底部 ＋ 收藏好文章、好链接'
                      : '点击底部 ＋ 开始积累你的知识库',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white30 : const Color(0xFFBBBBBB),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── 记录列表 ───────────────────────────────────────────────────
  Widget _buildRecordList(List<_DayGroup> groups, bool isDark) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (ctx, i) => _DayGroupWidget(group: groups[i], isDark: isDark),
        childCount: groups.length,
      ),
    );
  }
}

// ── 日期分组数据 ──────────────────────────────────────────────────
class _DayGroup {
  final String dateKey;
  final List<Record> records;
  const _DayGroup({required this.dateKey, required this.records});

  DateTime get date => DateTime.parse(dateKey);
}

// ── 日期分组组件 ──────────────────────────────────────────────────
class _DayGroupWidget extends StatelessWidget {
  final _DayGroup group;
  final bool isDark;

  const _DayGroupWidget({required this.group, required this.isDark});

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return '今天';
    if (d == yesterday) return '昨天';
    final weekdayNames = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final weekday = weekdayNames[date.weekday - 1];
    return '${date.month}月${date.day}日 $weekday';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 日期标题行
          Row(
            children: [
              Text(
                _formatDate(group.date),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? const Color(0xFF666666)
                      : const Color(0xFFBBBBBB),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF2A2A2A)
                      : const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${group.records.length}',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark
                        ? const Color(0xFF888888)
                        : const Color(0xFFBBBBBB),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...group.records
              .map((r) => _KnowledgeCard(record: r, isDark: isDark)),
        ],
      ),
    );
  }
}

// ── 知识卡片 ──────────────────────────────────────────────────────
class _KnowledgeCard extends StatelessWidget {
  final Record record;
  final bool isDark;

  const _KnowledgeCard({required this.record, required this.isDark});

  Color get _typeColor {
    switch (record.type) {
      case RecordType.collect:
        return const Color(0xFFA18CD1);
      case RecordType.reading:
        return const Color(0xFF27AE60);
      default:
        return const Color(0xFF95A5A6);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
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
          // 顶行：类型标签 + 收藏标记 + 时间
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _typeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      record.type.emoji,
                      style: const TextStyle(fontSize: 11),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      record.type.label,
                      style: TextStyle(
                        fontSize: 11,
                        color: _typeColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (record.isFavorite) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '⭐ 精选',
                    style: TextStyle(
                      fontSize: 10,
                      color: Color(0xFFB8860B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Text(
                _formatTime(record.createdAt),
                style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? const Color(0xFF666666)
                      : const Color(0xFFBBBBBB),
                ),
              ),
            ],
          ),
          // 标题
          if (record.title.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              record.title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1A1410),
                height: 1.3,
              ),
            ),
          ],
          // 正文
          if (record.content.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              record.content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: isDark ? Colors.white70 : const Color(0xFF555555),
              ),
            ),
          ],
          // 阅读进度条（reading 类型）
          if (record.type == RecordType.reading &&
              record.readingProgress > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: record.readingProgress / 100,
                      backgroundColor: isDark
                          ? const Color(0xFF333333)
                          : const Color(0xFFF0F0F0),
                      valueColor:
                          const AlwaysStoppedAnimation(Color(0xFF27AE60)),
                      minHeight: 4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  record.readingProgress == 100
                      ? '✓ 已读完'
                      : '${record.readingProgress}%',
                  style: TextStyle(
                    fontSize: 11,
                    color: record.readingProgress == 100
                        ? const Color(0xFF27AE60)
                        : const Color(0xFF27AE60),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          // 链接（collect 类型）
          if (record.url != null && record.url!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.link_rounded,
                  size: 12,
                  color: isDark
                      ? const Color(0xFF888888)
                      : const Color(0xFFBBBBBB),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    record.url!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF4A90D9),
                    ),
                  ),
                ),
              ],
            ),
          ],
          // 标签
          if (record.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: record.tags
                  .map((tag) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF333333)
                              : const Color(0xFFF0F0F0),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '#$tag',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? Colors.white54
                                : const Color(0xFF888888),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
