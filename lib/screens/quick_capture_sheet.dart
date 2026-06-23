import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/record.dart';
import '../providers/record_provider.dart';
import '../providers/habit_provider.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────
//  QuickCaptureSheet —— 快速捕获底部弹窗（全功能版）
//
//  【设计原则】
//  捕获优先于整理。用户先写，再选类型。
//  尽量少的操作步骤，最快地把想法/事件记下来。
//
//  【类型与域对应】
//  📔 日记域：灵感(idea) / 笔记(note) / 心情(mood)
//  💎 知识域：收藏(collect) / 阅读(reading)
//  🎯 活动域：活动(event) / 打卡(habitLog)
//
//  ⚠️ 执行域（task/checkItem/schedule）已迁移至 Checklist 模块，
//     不再在快速捕获中对用户暴露，请使用清单入口新建。
// ─────────────────────────────────────────────────────────────────

class QuickCaptureSheet extends StatefulWidget {
  /// 预设类型（可选，来自导航栏快捷入口）
  final RecordType? initialType;

  const QuickCaptureSheet({super.key, this.initialType});

  /// 显示快速捕获弹窗
  static Future<bool?> show(BuildContext context, {RecordType? initialType}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => QuickCaptureSheet(initialType: initialType),
    );
  }

  @override
  State<QuickCaptureSheet> createState() => _QuickCaptureSheetState();
}

class _QuickCaptureSheetState extends State<QuickCaptureSheet> {
  final _contentController = TextEditingController();
  final _contentFocus = FocusNode();

  late RecordType _selectedType;
  String? _selectedMood;
  List<String> _tags = [];
  bool _isSaving = false;

  // 日程/活动相关
  DateTime? _selectedTime;
  bool _isAllDay = false;

  // 打卡联动（习惯 habitLog 类型）
  String? _selectedHabitId;

  // ── 类型选项（按域边界组织）──────────────────────────────────
  // 📔 日记域 | 💎 知识域 | 🎯 活动域
  // ⚠️ task/checkItem/schedule 已迁移至 Checklist，此处不再暴露
  static const _typeOptions = [
    // 📔 日记域
    (RecordType.idea, '💡', '灵感'),
    (RecordType.note, '📝', '笔记'),
    (RecordType.mood, '😊', '心情'),
    // 💎 知识域
    (RecordType.collect, '🔖', '收藏'),
    (RecordType.reading, '📚', '阅读'),
    // 🎯 活动域
    (RecordType.event, '🎉', '活动'),
    (RecordType.habitLog, '🔁', '打卡'),
  ];

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

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType ?? RecordType.idea;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _contentFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _contentController.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  bool get _requiresMood =>
      _selectedType == RecordType.mood;

  // 活动类型需要选择时间；schedule 已迁移至 Checklist，此处不再判断
  bool get _requiresTime => _selectedType == RecordType.event;

  bool get _requiresHabit =>
      _selectedType == RecordType.habitLog;

  Future<void> _save() async {
    final content = _contentController.text.trim();

    // 打卡类型必须选择习惯
    if (_requiresHabit && _selectedHabitId == null) {
      _showError('请选择要打卡的习惯');
      return;
    }

    // 心情或内容至少有一个
    if (content.isEmpty && _selectedMood == null) return;

    setState(() => _isSaving = true);
    HapticFeedback.lightImpact();

    try {
      final rp = context.read<RecordProvider>();

      if (_requiresHabit && _selectedHabitId != null) {
        // 打卡逻辑
        await rp.checkInHabit(
          habitId: _selectedHabitId!,
          content: content,
          mood: _selectedMood,
        );
        // 同步习惯统计
        if (mounted) {
          await context.read<HabitProvider>().onCheckIn(_selectedHabitId!);
        }
      } else {
        await rp.addRecord(
          type: _selectedType,
          content: content,
          mood: _selectedMood,
          tags: _tags,
          scheduledAt: _selectedTime,
          isAllDay: _isAllDay,
        );
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = WeeklyTheme.getLightPalette();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return GestureDetector(
      onTap: () {},
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDragHandle(),
              _buildTypeSelector(isDark, palette),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildContentInput(isDark, palette),
                      // 根据类型显示不同的扩展区域
                      if (_requiresMood)
                        _buildMoodPicker(isDark)
                      else
                        _buildMoodQuickRow(isDark),
                      if (_requiresTime)
                        _buildTimePicker(isDark, palette),
                      if (_requiresHabit)
                        _buildHabitPicker(isDark, palette),
                    ],
                  ),
                ),
              ),
              _buildToolbar(isDark, palette),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDragHandle() {
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildTypeSelector(bool isDark, DayPalette palette) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: _typeOptions.map((opt) {
          final (type, emoji, label) = opt;
          final isSelected = _selectedType == type;
          final color = isDark ? AppColors.darkPrimary : palette.primary;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _selectedType = type;
                // 切换类型时清除时间选择
                if (!_requiresTime) {
                  _selectedTime = null;
                }
                // 切换到非打卡类型时清除习惯选择
                if (!_requiresHabit) {
                  _selectedHabitId = null;
                }
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: 0.12)
                    : (isDark
                        ? const Color(0xFF2A2A2A)
                        : const Color(0xFFF5F5F5)),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? color : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected
                          ? color
                          : (isDark
                              ? Colors.white60
                              : const Color(0xFF666666)),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildContentInput(bool isDark, DayPalette palette) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: TextField(
        controller: _contentController,
        focusNode: _contentFocus,
        maxLines: 5,
        minLines: 3,
        style: TextStyle(
          fontSize: 16,
          height: 1.6,
          color: isDark ? Colors.white : const Color(0xFF1A1410),
        ),
        decoration: InputDecoration(
          hintText: _hintText,
          border: InputBorder.none,
          hintStyle: TextStyle(
            color: isDark ? const Color(0xFF555555) : const Color(0xFFCCCCCC),
            fontSize: 16,
          ),
          filled: false,
        ),
        textInputAction: TextInputAction.newline,
      ),
    );
  }

  // 日程/活动 时间选择器
  Widget _buildTimePicker(bool isDark, DayPalette palette) {
    final primaryColor = isDark ? AppColors.darkPrimary : palette.primary;
    final timeStr = _selectedTime != null
        ? '${_selectedTime!.month}月${_selectedTime!.day}日 '
            '${_selectedTime!.hour.toString().padLeft(2, '0')}:'
            '${_selectedTime!.minute.toString().padLeft(2, '0')}'
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Row(
        children: [
          // 全天开关
          GestureDetector(
            onTap: () => setState(() => _isAllDay = !_isAllDay),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _isAllDay
                    ? primaryColor.withValues(alpha: 0.12)
                    : (isDark
                        ? const Color(0xFF2A2A2A)
                        : const Color(0xFFF5F5F5)),
                borderRadius: BorderRadius.circular(8),
                border: _isAllDay
                    ? Border.all(color: primaryColor, width: 1.5)
                    : null,
              ),
              child: Text(
                '全天',
                style: TextStyle(
                  fontSize: 12,
                  color: _isAllDay
                      ? primaryColor
                      : (isDark ? Colors.white38 : const Color(0xFFBBBBBB)),
                  fontWeight:
                      _isAllDay ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 时间选择
          if (!_isAllDay)
            GestureDetector(
              onTap: () => _pickDateTime(isDark, palette),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _selectedTime != null
                      ? primaryColor.withValues(alpha: 0.12)
                      : (isDark
                          ? const Color(0xFF2A2A2A)
                          : const Color(0xFFF5F5F5)),
                  borderRadius: BorderRadius.circular(8),
                  border: _selectedTime != null
                      ? Border.all(color: primaryColor, width: 1.5)
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 13,
                      color: _selectedTime != null
                          ? primaryColor
                          : (isDark
                              ? Colors.white38
                              : const Color(0xFFBBBBBB)),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      timeStr ?? '选择时间',
                      style: TextStyle(
                        fontSize: 12,
                        color: _selectedTime != null
                            ? primaryColor
                            : (isDark
                                ? Colors.white38
                                : const Color(0xFFBBBBBB)),
                        fontWeight: _selectedTime != null
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_selectedTime != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() => _selectedTime = null),
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: isDark ? Colors.white38 : const Color(0xFFBBBBBB),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 打卡习惯选择器
  Widget _buildHabitPicker(bool isDark, DayPalette palette) {
    return Consumer<HabitProvider>(
      builder: (ctx, habitProvider, _) {
        final habits = habitProvider.activeHabits;
        if (habits.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF2A2A2A)
                    : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Text('🔁', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(
                    '还没有习惯计划，去「规划」页面添加',
                    style: TextStyle(
                      fontSize: 13,
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

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '选择要打卡的习惯',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? Colors.white38
                      : const Color(0xFFBBBBBB),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: habits.map((habit) {
                  final isSelected = _selectedHabitId == habit.id;
                  Color color;
                  try {
                    final hex = habit.colorHex.replaceAll('#', '');
                    color = Color(int.parse('FF$hex', radix: 16));
                  } catch (_) {
                    color = const Color(0xFF27AE60);
                  }
                  final isCheckedToday =
                      habitProvider.isTodayCheckedIn(habit.id);

                  return GestureDetector(
                    onTap: isCheckedToday
                        ? null
                        : () => setState(
                            () => _selectedHabitId = isSelected ? null : habit.id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isCheckedToday
                            ? (isDark
                                ? const Color(0xFF1A2A1A)
                                : const Color(0xFFF0FFF0))
                            : isSelected
                                ? color.withValues(alpha: 0.15)
                                : (isDark
                                    ? const Color(0xFF2A2A2A)
                                    : const Color(0xFFF5F5F5)),
                        borderRadius: BorderRadius.circular(10),
                        border: isSelected
                            ? Border.all(color: color, width: 1.5)
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            habit.emoji,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            habit.title,
                            style: TextStyle(
                              fontSize: 13,
                              color: isCheckedToday
                                  ? const Color(0xFF27AE60)
                                  : (isDark
                                      ? Colors.white70
                                      : const Color(0xFF333333)),
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              decoration: isCheckedToday
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          if (isCheckedToday) ...[
                            const SizedBox(width: 4),
                            const Text(
                              '✓',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF27AE60),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  // 心情完整选择（心情类型专属）
  Widget _buildMoodPicker(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '此刻心情',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white38 : const Color(0xFFBBBBBB),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: _moodOptions.map((opt) {
              final (mood, emoji, label) = opt;
              final isSelected = _selectedMood == mood;
              final moodColor = AppColors.getMoodColor(mood);
              return GestureDetector(
                onTap: () => setState(
                    () => _selectedMood = isSelected ? null : mood),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? moodColor.withValues(alpha: 0.15)
                        : (isDark
                            ? const Color(0xFF2A2A2A)
                            : const Color(0xFFF5F5F5)),
                    borderRadius: BorderRadius.circular(10),
                    border: isSelected
                        ? Border.all(color: moodColor, width: 1.5)
                        : null,
                  ),
                  child: Column(
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 20)),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected
                              ? moodColor
                              : (isDark
                                  ? Colors.white54
                                  : const Color(0xFF888888)),
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // 心情快速行（非心情类型时，作为附加情绪标注）
  Widget _buildMoodQuickRow(bool isDark) {
    if (_requiresHabit) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Row(
        children: [
          Text(
            '心情',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white38 : const Color(0xFFBBBBBB),
            ),
          ),
          const SizedBox(width: 8),
          ..._moodOptions.map((opt) {
            final (mood, emoji, _) = opt;
            final isSelected = _selectedMood == mood;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedMood = isSelected ? null : mood;
                });
              },
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.getMoodColor(mood).withValues(alpha: 0.2)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isSelected
                        ? Border.all(
                            color: AppColors.getMoodColor(mood),
                            width: 1.5,
                          )
                        : null,
                  ),
                  child: Center(
                    child: Text(emoji,
                        style: TextStyle(
                            fontSize: isSelected ? 18 : 16)),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildToolbar(bool isDark, DayPalette palette) {
    final saveColor = isDark ? AppColors.darkPrimary : palette.primary;
    final canSave =
        _contentController.text.trim().isNotEmpty || _selectedMood != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          // 标签按钮
          GestureDetector(
            onTap: _showTagInput,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF2A2A2A)
                    : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.tag_rounded,
                      size: 14,
                      color: isDark
                          ? Colors.white38
                          : const Color(0xFFBBBBBB)),
                  const SizedBox(width: 4),
                  Text(
                    _tags.isEmpty ? '标签' : _tags.join(' '),
                    style: TextStyle(
                      fontSize: 12,
                      color: _tags.isEmpty
                          ? (isDark
                              ? Colors.white38
                              : const Color(0xFFBBBBBB))
                          : (isDark
                              ? Colors.white70
                              : const Color(0xFF555555)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          // 保存按钮
          GestureDetector(
            onTap: canSave && !_isSaving ? _save : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: canSave
                    ? saveColor
                    : saveColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      '记录',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String get _hintText {
    switch (_selectedType) {
      case RecordType.idea:
        return '捕获你的灵感...';
      case RecordType.note:
        return '写下你的想法...';
      case RecordType.task:
        return '添加一个任务...';
      case RecordType.checkItem:
        return '添加一条清单项...';
      case RecordType.collect:
        return '粘贴链接或描述要收藏的内容...';
      case RecordType.schedule:
        return '添加日程安排...';
      case RecordType.event:
        return '描述这个活动或事件...';
      case RecordType.mood:
        return '说说此刻的感受...（选心情即可，文字可选）';
      case RecordType.habitLog:
        return '打卡备注（可选）...';
      default:
        return '写点什么...';
    }
  }

  Future<void> _pickDateTime(bool isDark, DayPalette palette) async {
    final now = DateTime.now();
    // 先选日期
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedTime ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      builder: (ctx, child) => Theme(
        data: isDark ? ThemeData.dark() : ThemeData.light(),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;

    // 再选时间
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedTime ?? now),
      builder: (ctx, child) => Theme(
        data: isDark ? ThemeData.dark() : ThemeData.light(),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;

    setState(() {
      _selectedTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _showTagInput() {
    final controller = TextEditingController(text: _tags.join(' '));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加标签'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '用空格分隔多个标签',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final tags = controller.text
                  .trim()
                  .split(' ')
                  .where((t) => t.isNotEmpty)
                  .toList();
              setState(() => _tags = tags);
              Navigator.pop(ctx);
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }
}
