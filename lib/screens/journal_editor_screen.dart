import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/record.dart';
import '../providers/record_provider.dart';
import '../providers/cursor_style_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/ink_cursor_field.dart';

// ─────────────────────────────────────────────────────────────────
//  JournalEditorScreen —— 日记编辑器（全屏沉浸式）
//
//  【使用方式】
//  新建：JournalEditorScreen(journalDate: someDate)
//  编辑：JournalEditorScreen(journalDate: someDate, existing: record)
//
//  【数据存储】
//  保存为 RecordType.note，extra['journalDate'] = 'yyyy-MM-dd'
//
//  【特色功能】
//  - 使用 InkCursorField（墨水粒子光标）作为正文输入
//  - 支持配图（相册 / 相机，最多 9 张）
//  - 心情选择条
//  - 沉浸纸张质感背景
// ─────────────────────────────────────────────────────────────────

class JournalEditorScreen extends StatefulWidget {
  /// 这篇日记属于哪一天
  final DateTime journalDate;

  /// 编辑已有记录（null = 新建）
  final Record? existing;

  const JournalEditorScreen({
    super.key,
    required this.journalDate,
    this.existing,
  });

  @override
  State<JournalEditorScreen> createState() => _JournalEditorScreenState();
}

class _JournalEditorScreenState extends State<JournalEditorScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  final FocusNode _contentFocus = FocusNode();
  String? _selectedMood;
  List<String> _imagePaths = [];
  bool _isSaving = false;
  bool _hasChanges = false;

  static const _maxImages = 9;

  // 心情选项
  static const _moodOptions = [
    ('happy', '😊', '开心'),
    ('excited', '🤩', '兴奋'),
    ('neutral', '😐', '平静'),
    ('touched', '🥹', '感动'),
    ('sad', '😢', '难过'),
    ('anxious', '😰', '焦虑'),
    ('tired', '😪', '疲惫'),
    ('angry', '😠', '生气'),
  ];

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.existing?.title ?? '',
    );
    _contentController = TextEditingController(
      text: widget.existing?.content ?? '',
    );
    _selectedMood = widget.existing?.mood;
    _imagePaths = List<String>.from(widget.existing?.imagePaths ?? []);

    _titleController.addListener(_onChanged);
    _contentController.addListener(_onChanged);

    // 新建时自动聚焦正文
    if (!_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _contentFocus.requestFocus();
      });
    }
  }

  void _onChanged() {
    if (!_hasChanges) setState(() => _hasChanges = true);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}'
      '-${date.month.toString().padLeft(2, '0')}'
      '-${date.day.toString().padLeft(2, '0')}';

  // ── 图片选择 ──────────────────────────────────────────────────

  Future<void> _pickImages() async {
    HapticFeedback.lightImpact();
    final remaining = _maxImages - _imagePaths.length;
    if (remaining <= 0) return;

    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(
      imageQuality: 85,
      limit: remaining,
    );
    if (picked.isEmpty) return;

    setState(() {
      _imagePaths.addAll(
        picked.map((f) => f.path).take(remaining),
      );
      _hasChanges = true;
    });
  }

  Future<void> _pickFromCamera() async {
    HapticFeedback.lightImpact();
    if (_imagePaths.length >= _maxImages) return;

    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (photo == null) return;

    setState(() {
      _imagePaths.add(photo.path);
      _hasChanges = true;
    });
  }

  void _removeImage(int index) {
    HapticFeedback.mediumImpact();
    setState(() {
      _imagePaths.removeAt(index);
      _hasChanges = true;
    });
  }

  void _showImageSourceSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF444444) : const Color(0xFFDDDDDD),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(Icons.photo_library_rounded,
                  color: isDark ? Colors.white70 : const Color(0xFF555555)),
              title: Text('从相册选择',
                  style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF1A1410))),
              onTap: () {
                Navigator.pop(ctx);
                _pickImages();
              },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt_rounded,
                  color: isDark ? Colors.white70 : const Color(0xFF555555)),
              title: Text('拍一张',
                  style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF1A1410))),
              onTap: () {
                Navigator.pop(ctx);
                _pickFromCamera();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── 保存 ──────────────────────────────────────────────────────

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (content.isEmpty && title.isEmpty && _imagePaths.isEmpty) {
      Navigator.pop(context);
      return;
    }
    setState(() => _isSaving = true);
    final provider = context.read<RecordProvider>();

    try {
      if (_isEditing) {
        final updated = widget.existing!.copyWith(
          title: title,
          content: content,
          mood: _selectedMood,
          imagePaths: _imagePaths,
          updatedAt: DateTime.now(),
          extra: {
            ...widget.existing!.extra,
            'journalDate': _dateKey(widget.journalDate),
          },
        );
        await provider.updateRecord(updated);
      } else {
        await provider.addRecord(
          type: RecordType.note,
          title: title,
          content: content,
          mood: _selectedMood,
          imagePaths: _imagePaths,
          extra: {'journalDate': _dateKey(widget.journalDate)},
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isSaving = false);
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('放弃这篇日记？'),
        content: const Text('内容尚未保存，确定离开吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('继续写'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('放弃',
                style: TextStyle(color: Color(0xFFE74C3C))),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  String _formatHeaderDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(date.year, date.month, date.day);
    final weekdayNames = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final weekday = weekdayNames[date.weekday - 1];
    if (d == today) return '今天 · $weekday';
    if (d == yesterday) return '昨天 · $weekday';
    return '${date.year}年${date.month}月${date.day}日 $weekday';
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = WeeklyTheme.getLightPalette();
    final accentColor = isDark ? AppColors.darkPrimary : palette.primary;

    // 纸张质感背景
    final bgColor =
        isDark ? const Color(0xFF1A1A1A) : const Color(0xFFFFFBF5);

    // 读取用户设置的光标风格
    final cursorStyle =
        context.watch<CursorStyleProvider>().style;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final canPop = await _onWillPop();
        if (canPop && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
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
            onPressed: () async {
              final canPop = await _onWillPop();
              if (canPop && context.mounted) Navigator.pop(context);
            },
          ),
          title: Text(
            _formatHeaderDate(widget.journalDate),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white54 : const Color(0xFF999999),
              letterSpacing: 0.3,
            ),
          ),
          centerTitle: true,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _isSaving
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : TextButton(
                      onPressed: _save,
                      style: TextButton.styleFrom(
                        foregroundColor: accentColor,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                      ),
                      child: Text(
                        _isEditing ? '更新' : '保存',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: accentColor,
                        ),
                      ),
                    ),
            ),
          ],
        ),
        body: Column(
          children: [
            // ── 心情选择条 ──────────────────────────────────────
            _buildMoodBar(isDark, accentColor),
            const Divider(height: 1, thickness: 0.5),
            // ── 正文区 ──────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题（普通 TextField，无需墨水效果）
                    TextField(
                      controller: _titleController,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1A1410),
                        height: 1.3,
                        letterSpacing: -0.3,
                      ),
                      decoration: InputDecoration(
                        hintText: '标题（可选）',
                        hintStyle: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? const Color(0xFF444444)
                              : const Color(0xFFDDDDDD),
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => _contentFocus.requestFocus(),
                      maxLines: null,
                    ),
                    const SizedBox(height: 16),
                    // ── 正文（InkCursorField 墨水粒子光标）───────
                    InkCursorField(
                      controller: _contentController,
                      focusNode: _contentFocus,
                      maxLines: null,
                      minLines: 12,
                      cursorColor: accentColor,
                      cursorStyle: cursorStyle,
                      style: TextStyle(
                        fontSize: 17,
                        height: 1.85,
                        color: isDark
                            ? const Color(0xFFDDDDDD)
                            : const Color(0xFF333333),
                        letterSpacing: 0.2,
                      ),
                      decoration: InputDecoration(
                        hintText: '今天想写点什么…',
                        hintStyle: TextStyle(
                          fontSize: 17,
                          height: 1.85,
                          color: isDark
                              ? const Color(0xFF444444)
                              : const Color(0xFFCCCCCC),
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      keyboardType: TextInputType.multiline,
                    ),
                    const SizedBox(height: 20),
                    // ── 配图区 ────────────────────────────────────
                    if (_imagePaths.isNotEmpty)
                      _buildImageGrid(isDark, accentColor),
                    // ── 添加图片按钮（图片少于上限时显示）─────────
                    if (_imagePaths.length < _maxImages)
                      _buildAddImageButton(isDark, accentColor),
                    // 底部键盘留白
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 心情选择条 ────────────────────────────────────────────────

  Widget _buildMoodBar(bool isDark, Color accentColor) {
    return Container(
      height: 52,
      color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFFFFBF5),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _moodOptions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (ctx, i) {
          final (value, emoji, label) = _moodOptions[i];
          final isSelected = _selectedMood == value;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _selectedMood = isSelected ? null : value;
                if (!isSelected) _hasChanges = true;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? accentColor.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: isSelected
                    ? Border.all(color: accentColor, width: 1.5)
                    : Border.all(
                        color: isDark
                            ? const Color(0xFF333333)
                            : const Color(0xFFEEEEEE),
                      ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 14)),
                  if (isSelected) ...[
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: accentColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── 配图网格 ──────────────────────────────────────────────────

  Widget _buildImageGrid(bool isDark, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ..._imagePaths.asMap().entries.map((entry) {
            final index = entry.key;
            final path = entry.value;
            return _ImageThumb(
              path: path,
              isDark: isDark,
              onRemove: () => _removeImage(index),
              onTap: () => _previewImage(index),
            );
          }),
        ],
      ),
    );
  }

  // ── 添加图片按钮 ──────────────────────────────────────────────

  Widget _buildAddImageButton(bool isDark, Color accentColor) {
    return GestureDetector(
      onTap: _showImageSourceSheet,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF252525)
              : const Color(0xFFF5F0EB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? const Color(0xFF333333)
                : const Color(0xFFE0D9D0),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_rounded,
              size: 22,
              color: isDark
                  ? const Color(0xFF666666)
                  : const Color(0xFFBBBBBB),
            ),
            const SizedBox(height: 2),
            Text(
              _imagePaths.isEmpty ? '配图' : '继续添加',
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

  // ── 图片预览 ──────────────────────────────────────────────────

  void _previewImage(int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ImagePreviewPage(
          paths: _imagePaths,
          initialIndex: initialIndex,
        ),
        fullscreenDialog: true,
      ),
    );
  }
}

// ── 图片缩略图组件 ────────────────────────────────────────────────

class _ImageThumb extends StatelessWidget {
  final String path;
  final bool isDark;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  const _ImageThumb({
    required this.path,
    required this.isDark,
    required this.onRemove,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(
              File(path),
              width: 100,
              height: 100,
              fit: BoxFit.cover,
              errorBuilder: (_, e, s) => Container(
                width: 100,
                height: 100,
                color: isDark
                    ? const Color(0xFF2A2A2A)
                    : const Color(0xFFEEEEEE),
                child: Icon(Icons.broken_image_rounded,
                    color: isDark
                        ? const Color(0xFF555555)
                        : const Color(0xFFCCCCCC)),
              ),
            ),
          ),
          // 删除按钮
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 13,
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

// ── 全屏图片预览页 ────────────────────────────────────────────────

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
