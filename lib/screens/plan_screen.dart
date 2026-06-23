import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/project.dart';
import '../providers/project_provider.dart';
import '../theme/app_theme.dart';
import 'project_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────
//  PlanScreen —— 项目视图
//
//  只保留【项目】功能，去掉目标和习惯 Tab。
//  标题：项目
// ─────────────────────────────────────────────────────────────────

class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    await context.read<ProjectProvider>().loadProjects();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = WeeklyTheme.getLightPalette();

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : palette.background,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, innerBoxIsScrolled) => [
          SliverAppBar(
            floating: true,
            pinned: true,
            backgroundColor:
                isDark ? AppColors.backgroundDark : palette.background,
            elevation: 0,
            expandedHeight: 80,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              title: Text(
                '项目',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1A1410),
                ),
              ),
            ),
          ),
        ],
        body: Consumer<ProjectProvider>(
          builder: (ctx, projectProvider, _) {
            if (projectProvider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            final projects = projectProvider.projects;
            if (projects.isEmpty) {
              return _buildEmpty(isDark);
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: projects.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) => GestureDetector(
                onTap: () => Navigator.push(
                  ctx,
                  MaterialPageRoute(
                    builder: (_) =>
                        ProjectDetailScreen(projectId: projects[i].id),
                  ),
                ),
                child: _ProjectCard(
                  project: projects[i],
                  isDark: isDark,
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: _buildFab(context, isDark, palette),
    );
  }

  Widget _buildFab(BuildContext context, bool isDark, DayPalette palette) {
    return FloatingActionButton(
      onPressed: () => _showCreateProjectSheet(context, isDark, palette),
      backgroundColor: isDark ? AppColors.darkPrimary : palette.primary,
      foregroundColor: Colors.white,
      child: const Icon(Icons.add_rounded),
    );
  }

  void _showCreateProjectSheet(
      BuildContext context, bool isDark, DayPalette palette) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _CreateProjectSheet(isDark: isDark, palette: palette),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('📁', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(
            '还没有项目',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : const Color(0xFF999999),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '创建一个项目，把行动组织起来',
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

// ── 项目卡片 ──────────────────────────────────────────────────────
class _ProjectCard extends StatelessWidget {
  final Project project;
  final bool isDark;

  const _ProjectCard({
    required this.project,
    required this.isDark,
  });

  Color get _color {
    try {
      final hex = project.colorHex.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF4A90D9);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(project.emoji,
                      style: const TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  project.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1A1410),
                  ),
                ),
              ),
              _PriorityBadge(priority: project.priority),
            ],
          ),
          if (project.taskCount > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: project.completionRate,
                      backgroundColor: isDark
                          ? const Color(0xFF333333)
                          : const Color(0xFFF0F0F0),
                      valueColor: AlwaysStoppedAnimation(_color),
                      minHeight: 4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${project.completedTaskCount}/${project.taskCount}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _color,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── 优先级徽章 ────────────────────────────────────────────────────
class _PriorityBadge extends StatelessWidget {
  final ProjectPriority priority;
  const _PriorityBadge({required this.priority});

  @override
  Widget build(BuildContext context) {
    return Text(
      priority.emoji,
      style: const TextStyle(fontSize: 16),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  新建项目底部弹窗
// ─────────────────────────────────────────────────────────────────
class _CreateProjectSheet extends StatefulWidget {
  final bool isDark;
  final DayPalette palette;

  const _CreateProjectSheet({required this.isDark, required this.palette});

  @override
  State<_CreateProjectSheet> createState() => _CreateProjectSheetState();
}

class _CreateProjectSheetState extends State<_CreateProjectSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _titleFocus = FocusNode();

  String _selectedEmoji = '📁';
  String _selectedColorHex = '#4A90D9';
  ProjectPriority _selectedPriority = ProjectPriority.medium;
  DateTime? _selectedDeadline;
  bool _isSaving = false;

  static const _emojiOptions = [
    '📁', '💼', '🚀', '🏗️', '💡', '🔬', '🎯', '🌟',
    '📱', '💻', '🎨', '✍️', '🎸', '🏋️', '🌿', '🔑',
    '📊', '🗓️', '🏠', '🎓', '⚡', '🎥', '🌏', '🛠️',
  ];

  static const _colorOptions = [
    '#4A90D9', '#E07818', '#27AE60', '#9B59B6',
    '#E74C3C', '#E67E22', '#1ABC9C', '#F39C12',
    '#D44470', '#7E5FC0', '#2878CC', '#CC5828',
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
    _descController.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      await context.read<ProjectProvider>().addProject(
            title: title,
            description: _descController.text.trim(),
            emoji: _selectedEmoji,
            colorHex: _selectedColorHex,
            priority: _selectedPriority,
            goalId: null,
            deadline: _selectedDeadline,
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
    final selectedColor = _parseHexColor(_selectedColorHex);

    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Row(
                children: [
                  Text(
                    '新建项目',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1A1410),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 0, 20, bottomInset + 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionLabel('图标', isDark),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 48,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _emojiOptions.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 8),
                        itemBuilder: (ctx, i) {
                          final emoji = _emojiOptions[i];
                          final isSelected = _selectedEmoji == emoji;
                          return GestureDetector(
                            onTap: () =>
                                setState(() => _selectedEmoji = emoji),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? selectedColor.withValues(alpha: 0.15)
                                    : (isDark
                                        ? const Color(0xFF2A2A2A)
                                        : const Color(0xFFF5F5F5)),
                                borderRadius: BorderRadius.circular(10),
                                border: isSelected
                                    ? Border.all(
                                        color: selectedColor, width: 1.5)
                                    : null,
                              ),
                              child: Center(
                                child: Text(emoji,
                                    style:
                                        const TextStyle(fontSize: 22)),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SectionLabel('颜色', isDark),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _colorOptions.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 8),
                        itemBuilder: (ctx, i) {
                          final hex = _colorOptions[i];
                          final color = _parseHexColor(hex);
                          final isSelected = _selectedColorHex == hex;
                          return GestureDetector(
                            onTap: () =>
                                setState(() => _selectedColorHex = hex),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(
                                        color: Colors.white, width: 2.5)
                                    : null,
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: color
                                              .withValues(alpha: 0.4),
                                          blurRadius: 6,
                                        )
                                      ]
                                    : null,
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check_rounded,
                                      color: Colors.white, size: 16)
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SectionLabel('项目名称', isDark),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _titleController,
                      focusNode: _titleFocus,
                      hint: '如：备赛计划',
                      isDark: isDark,
                    ),
                    const SizedBox(height: 12),
                    _SectionLabel('描述（可选）', isDark),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _descController,
                      hint: '项目背景或目标...',
                      isDark: isDark,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    _SectionLabel('优先级', isDark),
                    const SizedBox(height: 8),
                    Row(
                      children: ProjectPriority.values.map((p) {
                        final isSelected = _selectedPriority == p;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () => setState(
                                  () => _selectedPriority = p),
                              child: AnimatedContainer(
                                duration:
                                    const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? primaryColor
                                          .withValues(alpha: 0.12)
                                      : (isDark
                                          ? const Color(0xFF2A2A2A)
                                          : const Color(0xFFF5F5F5)),
                                  borderRadius: BorderRadius.circular(10),
                                  border: isSelected
                                      ? Border.all(
                                          color: primaryColor, width: 1.5)
                                      : null,
                                ),
                                child: Column(
                                  children: [
                                    Text(p.emoji,
                                        style: const TextStyle(
                                            fontSize: 18)),
                                    const SizedBox(height: 2),
                                    Text(
                                      p.label,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isSelected
                                            ? primaryColor
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
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    _SectionLabel('截止日期（可选）', isDark),
                    const SizedBox(height: 8),
                    _DeadlinePickerRow(
                      deadline: _selectedDeadline,
                      isDark: isDark,
                      primaryColor: primaryColor,
                      onChanged: (d) =>
                          setState(() => _selectedDeadline = d),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('创建项目',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required bool isDark,
    FocusNode? focusNode,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      maxLines: maxLines,
      style: TextStyle(
        fontSize: 15,
        color: isDark ? Colors.white : const Color(0xFF1A1410),
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color:
              isDark ? const Color(0xFF555555) : const Color(0xFFCCCCCC),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor:
            isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

// ─── 表单 section 标签 ────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  final bool isDark;

  const _SectionLabel(this.text, this.isDark);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white54 : const Color(0xFF888888),
      ),
    );
  }
}

// ─── 截止日期选择行 ───────────────────────────────────────────────
class _DeadlinePickerRow extends StatelessWidget {
  final DateTime? deadline;
  final bool isDark;
  final Color primaryColor;
  final ValueChanged<DateTime?> onChanged;

  const _DeadlinePickerRow({
    required this.deadline,
    required this.isDark,
    required this.primaryColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: deadline ??
              DateTime.now().add(const Duration(days: 30)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: ColorScheme.light(
                primary: primaryColor,
                onPrimary: Colors.white,
              ),
            ),
            child: child!,
          ),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF2A2A2A)
              : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.event_outlined,
              size: 18,
              color: deadline != null
                  ? primaryColor
                  : (isDark ? Colors.white38 : const Color(0xFFCCCCCC)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                deadline != null
                    ? '${deadline!.year}年${deadline!.month}月${deadline!.day}日'
                    : '不设截止日期',
                style: TextStyle(
                  fontSize: 15,
                  color: deadline != null
                      ? (isDark
                          ? const Color(0xDEFFFFFF)
                          : const Color(0xFF333333))
                      : (isDark
                          ? Colors.white38
                          : const Color(0xFFCCCCCC)),
                ),
              ),
            ),
            if (deadline != null)
              GestureDetector(
                onTap: () => onChanged(null),
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: isDark ? Colors.white38 : const Color(0xFFCCCCCC),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── 工具函数 ─────────────────────────────────────────────────────
Color _parseHexColor(String hex) {
  try {
    return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
  } catch (_) {
    return const Color(0xFF4A90D9);
  }
}
