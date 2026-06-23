import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/record.dart';
import '../providers/record_provider.dart';
import '../theme/app_theme.dart';
import 'journal_editor_screen.dart';

// ─────────────────────────────────────────────────────────────────
//  JournalDayViewScreen —— 某天的日记页
//
//  展示某天所有日记段落，像一本翻开的日记本。
//  - 一天可以有多段日记（多次打开写）
//  - 每段有独立的写作时间 + 心情
//  - 支持新增、编辑、删除单段
//  - FAB：继续写今天的日记（追加一段）
// ─────────────────────────────────────────────────────────────────

class JournalDayViewScreen extends StatefulWidget {
  final DateTime date;

  const JournalDayViewScreen({super.key, required this.date});

  @override
  State<JournalDayViewScreen> createState() => _JournalDayViewScreenState();
}

class _JournalDayViewScreenState extends State<JournalDayViewScreen> {
  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}'
      '-${date.month.toString().padLeft(2, '0')}'
      '-${date.day.toString().padLeft(2, '0')}';

  /// 获取这一天的所有日记记录（按 extra.journalDate 过滤）
  List<Record> _dayRecords(RecordProvider provider) {
    final key = _dateKey(widget.date);
    return provider.journalRecords
        .where((r) => _getJournalDate(r) == key)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  String _getJournalDate(Record r) {
    final fromExtra = r.extra['journalDate'] as String?;
    if (fromExtra != null && fromExtra.isNotEmpty) return fromExtra;
    // 向后兼容：无 journalDate 的旧记录用 createdAt 日期
    return r.dateKey;
  }

  String _formatHeaderDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return '今天';
    if (d == yesterday) return '昨天';
    if (date.year == now.year) return '${date.month}月${date.day}日';
    return '${date.year}年${date.month}月${date.day}日';
  }

  String _formatSubDate(DateTime date) {
    final weekdayNames = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final weekday = weekdayNames[date.weekday - 1];
    if (date.year == DateTime.now().year) {
      return '$weekday · ${date.month}月${date.day}日';
    }
    return '$weekday · ${date.year}年${date.month}月${date.day}日';
  }

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _moodEmoji(String mood) {
    const map = {
      'happy': '😊', 'excited': '🤩', 'neutral': '😐',
      'touched': '🥹', 'sad': '😢', 'angry': '😠',
      'anxious': '😰', 'tired': '😪',
    };
    return map[mood] ?? '';
  }

  String _moodLabel(String mood) {
    const map = {
      'happy': '开心', 'excited': '兴奋', 'neutral': '平静',
      'touched': '感动', 'sad': '难过', 'angry': '生气',
      'anxious': '焦虑', 'tired': '疲惫',
    };
    return map[mood] ?? '';
  }

  Future<void> _openEditor({Record? existing}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => JournalEditorScreen(
          journalDate: widget.date,
          existing: existing,
        ),
        fullscreenDialog: true,
      ),
    );
    if (result == true && mounted) setState(() {});
  }

  Future<void> _confirmDelete(BuildContext context, Record record,
      RecordProvider provider) async {
    HapticFeedback.mediumImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这段日记？'),
        content: const Text('删除后无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              '删除',
              style: TextStyle(color: Color(0xFFE74C3C)),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await provider.deleteRecord(record.id);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = WeeklyTheme.getLightPalette();
    final accentColor = isDark ? AppColors.darkPrimary : palette.primary;
    final bgColor =
        isDark ? const Color(0xFF1A1A1A) : const Color(0xFFFFFBF5);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: isDark ? Colors.white70 : const Color(0xFF888888),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(
              _formatHeaderDate(widget.date),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1A1410),
              ),
            ),
            Text(
              _formatSubDate(widget.date),
              style: TextStyle(
                fontSize: 12,
                color:
                    isDark ? const Color(0xFF888888) : const Color(0xFFAAAAAA),
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Consumer<RecordProvider>(
        builder: (ctx, provider, _) {
          final records = _dayRecords(provider);

          if (records.isEmpty) {
            return _buildEmptyState(isDark, accentColor);
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            itemCount: records.length,
            itemBuilder: (ctx, i) {
              // 多段时在段落之间显示分割线
              if (i > 0) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: isDark
                                  ? const Color(0xFF2A2A2A)
                                  : const Color(0xFFEEEEEE),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              _formatTime(records[i].createdAt),
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? const Color(0xFF555555)
                                    : const Color(0xFFCCCCCC),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: isDark
                                  ? const Color(0xFF2A2A2A)
                                  : const Color(0xFFEEEEEE),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _JournalEntryWidget(
                      record: records[i],
                      isDark: isDark,
                      accentColor: accentColor,
                      moodEmoji: _moodEmoji,
                      moodLabel: _moodLabel,
                      onEdit: () => _openEditor(existing: records[i]),
                      onDelete: () =>
                          _confirmDelete(context, records[i], provider),
                    ),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 第一段显示时间
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _formatTime(records[0].createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? const Color(0xFF555555)
                            : const Color(0xFFCCCCCC),
                      ),
                    ),
                  ),
                  _JournalEntryWidget(
                    record: records[i],
                    isDark: isDark,
                    accentColor: accentColor,
                    moodEmoji: _moodEmoji,
                    moodLabel: _moodLabel,
                    onEdit: () => _openEditor(existing: records[i]),
                    onDelete: () =>
                        _confirmDelete(context, records[i], provider),
                  ),
                ],
              );
            },
          );
        },
      ),
      // 继续写一段 / 写今天的日记
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(Icons.edit_rounded, size: 18),
        label: const Text(
          '继续写',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, Color accentColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '📖',
            style: const TextStyle(fontSize: 56),
          ),
          const SizedBox(height: 20),
          Text(
            '这天还没有日记',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : const Color(0xFF999999),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '写下今天的感受和故事',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white30 : const Color(0xFFBBBBBB),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.edit_rounded, size: 16),
            label: const Text('开始写'),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 单段日记内容组件 ──────────────────────────────────────────────
class _JournalEntryWidget extends StatelessWidget {
  final Record record;
  final bool isDark;
  final Color accentColor;
  final String Function(String) moodEmoji;
  final String Function(String) moodLabel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _JournalEntryWidget({
    required this.record,
    required this.isDark,
    required this.accentColor,
    required this.moodEmoji,
    required this.moodLabel,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _showContextMenu(context),
      onTap: onEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题（如果有）
          if (record.title.isNotEmpty) ...[
            Text(
              record.title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1A1410),
                height: 1.3,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 12),
          ],
          // 正文
          if (record.content.isNotEmpty)
            Text(
              record.content,
              style: TextStyle(
                fontSize: 17,
                height: 1.85,
                color: isDark
                    ? const Color(0xFFDDDDDD)
                    : const Color(0xFF333333),
                letterSpacing: 0.2,
              ),
            ),
          // 配图（如果有）
          if (record.imagePaths.isNotEmpty) ...[
            const SizedBox(height: 14),
            _ImageGrid(
              paths: record.imagePaths,
              isDark: isDark,
            ),
          ],
          // 心情标签（如果有）
          if (record.mood != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  moodEmoji(record.mood!),
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 6),
                Text(
                  moodLabel(record.mood!),
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? const Color(0xFF888888)
                        : const Color(0xFFAAAAAA),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF444444) : const Color(0xFFDDDDDD),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(Icons.edit_rounded, color: accentColor),
              title: Text(
                '编辑这段',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF1A1410),
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                onEdit();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_rounded,
                  color: Color(0xFFE74C3C)),
              title: const Text(
                '删除这段',
                style: TextStyle(color: Color(0xFFE74C3C)),
              ),
              onTap: () {
                Navigator.pop(ctx);
                onDelete();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── 配图网格（只读展示）──────────────────────────────────────────
class _ImageGrid extends StatelessWidget {
  final List<String> paths;
  final bool isDark;

  const _ImageGrid({required this.paths, required this.isDark});

  void _preview(BuildContext context, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ImagePreviewPage(paths: paths, initialIndex: index),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (paths.isEmpty) return const SizedBox.shrink();

    // 1 张：全宽展示
    if (paths.length == 1) {
      return GestureDetector(
        onTap: () => _preview(context, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            File(paths[0]),
            width: double.infinity,
            height: 220,
            fit: BoxFit.cover,
            errorBuilder: (_, e, s) => _broken(isDark),
          ),
        ),
      );
    }

    // 2 张：横向各半
    if (paths.length == 2) {
      return Row(
        children: [
          for (int i = 0; i < 2; i++) ...[
            Expanded(
              child: GestureDetector(
                onTap: () => _preview(context, i),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    File(paths[i]),
                    height: 150,
                    fit: BoxFit.cover,
                    errorBuilder: (_, e, s) => _broken(isDark),
                  ),
                ),
              ),
            ),
            if (i == 0) const SizedBox(width: 6),
          ],
        ],
      );
    }

    // 3 张及以上：Wrap 网格
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: paths.asMap().entries.map((e) {
        final i = e.key;
        final path = e.value;
        if (i > 8) return const SizedBox.shrink();
        // 超过8张时，第9格显示 "+N"
        if (i == 8 && paths.length > 9) {
          return GestureDetector(
            onTap: () => _preview(context, i),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(path),
                    width: 90, height: 90,
                    fit: BoxFit.cover,
                    errorBuilder: (_, e, s) => _broken(isDark, size: 90),
                  ),
                ),
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.5),
                      child: Center(
                        child: Text(
                          '+${paths.length - 9}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return GestureDetector(
          onTap: () => _preview(context, i),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(path),
              width: 90, height: 90,
              fit: BoxFit.cover,
              errorBuilder: (_, e, s) => _broken(isDark, size: 90),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _broken(bool isDark, {double size = 150}) {
    return Container(
      width: size, height: size,
      color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE),
      child: Icon(
        Icons.broken_image_rounded,
        color: isDark ? const Color(0xFF555555) : const Color(0xFFCCCCCC),
      ),
    );
  }
}

// ── 全屏图片预览（只读）────────────────────────────────────────────
class _ImagePreviewPage extends StatefulWidget {
  final List<String> paths;
  final int initialIndex;

  const _ImagePreviewPage({
    required this.paths,
    required this.initialIndex,
  });

  @override
  State<_ImagePreviewPage> createState() => _ImagePreviewPageState();
}

class _ImagePreviewPageState extends State<_ImagePreviewPage> {
  late int _current;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: widget.paths.length > 1
            ? Text(
                '${_current + 1} / ${widget.paths.length}',
                style: const TextStyle(fontSize: 15, color: Colors.white70),
              )
            : null,
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.paths.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (ctx, i) => InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Center(
            child: Image.file(
              File(widget.paths[i]),
              fit: BoxFit.contain,
              errorBuilder: (_, e, s) => const Icon(
                Icons.broken_image_rounded,
                color: Colors.white38,
                size: 64,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
