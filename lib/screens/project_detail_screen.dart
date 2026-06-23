import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
// ignore: unused_import
import 'package:uuid/uuid.dart';
import '../models/project.dart';
import '../models/project_section.dart';
import '../models/record.dart';
import '../providers/project_provider.dart';
import '../providers/project_section_provider.dart';
import '../providers/record_provider.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────
//  ProjectDetailScreen —— 项目详情页（Tab 版）
//
//  三 Tab：
//  · 版图   —— 版块与任务分组管理，可展开任务详情，支持截止日期/优先级
//  · 笔记   —— 项目内笔记流，随手记录想法、决策、会议记录
//  · 概览   —— 进度环 + 时间轴 + 关键数字 + AI洞察
// ─────────────────────────────────────────────────────────────────

class ProjectDetailScreen extends StatefulWidget {
  final String projectId;

  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RecordProvider>().loadRecordsForProject(widget.projectId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = WeeklyTheme.getLightPalette();
    final primaryColor = isDark ? AppColors.darkPrimary : palette.primary;

    return Consumer<ProjectProvider>(
      builder: (ctx, projectProvider, _) {
        final project = projectProvider.findById(widget.projectId);
        if (project == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('项目详情')),
            body: const Center(child: Text('项目不存在')),
          );
        }
        final projectColor = _parseColor(project.colorHex);

        return Scaffold(
          backgroundColor:
              isDark ? AppColors.backgroundDark : palette.background,
          body: NestedScrollView(
            headerSliverBuilder: (ctx, innerBoxIsScrolled) => [
              _ProjectHeader(
                project: project,
                projectColor: projectColor,
                isDark: isDark,
                palette: palette,
                primaryColor: primaryColor,
                tabController: _tabController,
                onEdit: () =>
                    _showEditSheet(context, project, isDark, palette),
                onDelete: () =>
                    _confirmDelete(context, project, projectProvider),
                onStatusChanged: (s) => projectProvider.updateProject(
                  project.copyWith(status: s),
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [
                // ── Tab 0: 任务 ──────────────────────────
                _TaskTab(
                  projectId: project.id,
                  projectColor: projectColor,
                  isDark: isDark,
                  palette: palette,
                ),
                // ── Tab 1: 笔记 ──────────────────────────
                _NotesTab(
                  projectId: project.id,
                  projectColor: projectColor,
                  isDark: isDark,
                  palette: palette,
                ),
                // ── Tab 2: 概览 ──────────────────────────
                _OverviewTab(
                  project: project,
                  projectColor: projectColor,
                  isDark: isDark,
                  palette: palette,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditSheet(
    BuildContext context,
    Project project,
    bool isDark,
    DayPalette palette,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) =>
          _EditProjectSheet(project: project, isDark: isDark, palette: palette),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    Project project,
    ProjectProvider provider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除项目'),
        content: Text('删除「${project.title}」后，项目内的任务和笔记也会一并删除。确认删除？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除',
                style: TextStyle(color: Color(0xFFE74C3C))),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      final navigator = Navigator.of(context);
      await provider.deleteProject(project.id);
      navigator.pop();
    }
  }
}

// ─────────────────────────────────────────────────────────────────
//  Header —— SliverAppBar + Tab Bar
// ─────────────────────────────────────────────────────────────────
class _ProjectHeader extends StatelessWidget {
  final Project project;
  final Color projectColor;
  final bool isDark;
  final DayPalette palette;
  final Color primaryColor;
  final TabController tabController;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<ProjectStatus> onStatusChanged;

  const _ProjectHeader({
    required this.project,
    required this.projectColor,
    required this.isDark,
    required this.palette,
    required this.primaryColor,
    required this.tabController,
    required this.onEdit,
    required this.onDelete,
    required this.onStatusChanged,
  });

  Color _statusColor(ProjectStatus s) {
    switch (s) {
      case ProjectStatus.todo:
        return const Color(0xFF95A5A6);
      case ProjectStatus.inProgress:
        return const Color(0xFF27AE60);
      case ProjectStatus.paused:
        return const Color(0xFFE67E22);
      case ProjectStatus.completed:
        return const Color(0xFF4A90D9);
      case ProjectStatus.cancelled:
        return const Color(0xFFE74C3C);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(project.status);

    return SliverAppBar(
      expandedHeight: 160,
      pinned: true,
      backgroundColor: isDark ? AppColors.backgroundDark : palette.background,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          color: isDark ? Colors.white : const Color(0xFF1A1410),
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.edit_outlined,
              color: isDark ? Colors.white70 : const Color(0xFF666666),
              size: 20),
          onPressed: onEdit,
        ),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded,
              color: isDark ? Colors.white70 : const Color(0xFF666666),
              size: 20),
          color: isDark ? AppColors.surfaceDark : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: (v) {
            if (v == 'delete') onDelete();
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline_rounded,
                      size: 18, color: Color(0xFFE74C3C)),
                  SizedBox(width: 8),
                  Text('删除项目',
                      style: TextStyle(color: Color(0xFFE74C3C))),
                ],
              ),
            ),
          ],
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 56),
        title: Row(
          children: [
            // Emoji 图标
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: projectColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Center(
                child: Text(project.emoji,
                    style: const TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(width: 10),
            // 标题 + 状态
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    project.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1A1410),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  GestureDetector(
                    onTap: () => _showStatusPicker(context, statusColor),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            project.status.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(Icons.expand_more_rounded,
                              size: 10, color: statusColor),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                projectColor.withValues(alpha: 0.1),
                projectColor.withValues(alpha: 0.03),
              ],
            ),
          ),
          // 左侧装饰色条
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 4,
              margin: const EdgeInsets.only(left: 0),
              color: projectColor,
            ),
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(52),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.backgroundDark : palette.background,
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.06),
                width: 0.5,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: _PillTabBar(
              controller: tabController,
              projectColor: projectColor,
              isDark: isDark,
              tabs: const ['版图', '笔记', '概览'],
            ),
          ),
        ),
      ),
    );
  }

  void _showStatusPicker(BuildContext context, Color statusColor) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  '更改状态',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1A1410),
                  ),
                ),
                const SizedBox(height: 12),
                ...ProjectStatus.values.map((s) {
                  final c = _statusColor(s);
                  return ListTile(
                    leading: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                      ),
                    ),
                    title: Text(
                      s.label,
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF1A1410),
                        fontWeight: project.status == s
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                    trailing: project.status == s
                        ? Icon(Icons.check_rounded, color: c)
                        : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      onStatusChanged(s);
                    },
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  胶囊形 Tab Bar
// ─────────────────────────────────────────────────────────────────
class _PillTabBar extends StatefulWidget {
  final TabController controller;
  final Color projectColor;
  final bool isDark;
  final List<String> tabs;

  const _PillTabBar({
    required this.controller,
    required this.projectColor,
    required this.isDark,
    required this.tabs,
  });

  @override
  State<_PillTabBar> createState() => _PillTabBarState();
}

class _PillTabBarState extends State<_PillTabBar> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.controller.index;
    widget.controller.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (widget.controller.index != _selectedIndex) {
      setState(() => _selectedIndex = widget.controller.index);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTabChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.05);

    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: List.generate(widget.tabs.length, (i) {
          final isSelected = _selectedIndex == i;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                widget.controller.animateTo(i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isSelected
                      ? widget.projectColor
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(17),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: widget.projectColor.withValues(alpha: 0.30),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    widget.tabs[i],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : (widget.isDark
                              ? const Color(0xFF888888)
                              : const Color(0xFFAAAAAA)),
                    ),
                  ),
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
//  Tab 0 — 版块与任务
//
//  层级结构：
//    版块（ProjectSection）
//      ├── 子版块（ProjectSection，parentSectionId 指向父版块）
//      │     └── 任务（Record，sectionId = 子版块 ID）
//      └── 任务（Record，sectionId = 版块 ID）
//    未分版块的任务（sectionId = null）单独归入"收件箱"
// ─────────────────────────────────────────────────────────────────

/// 任务优先级（存在 Record.extra['priority'] 中）
enum _TaskPriority {
  high('high', '高', '🔴'),
  medium('medium', '中', '🟡'),
  low('low', '低', '🟢'),
  none('none', '无', '⬜');

  const _TaskPriority(this.value, this.label, this.emoji);
  final String value;
  final String label;
  final String emoji;

  static _TaskPriority fromExtra(Map<String, dynamic> extra) {
    final v = extra['priority'] as String?;
    return _TaskPriority.values.firstWhere(
      (e) => e.value == v,
      orElse: () => _TaskPriority.none,
    );
  }
}

class _TaskTab extends StatefulWidget {
  final String projectId;
  final Color projectColor;
  final bool isDark;
  final DayPalette palette;

  const _TaskTab({
    required this.projectId,
    required this.projectColor,
    required this.isDark,
    required this.palette,
  });

  @override
  State<_TaskTab> createState() => _TaskTabState();
}

class _TaskTabState extends State<_TaskTab> {
// 正在添加任务的版块 ID（null 表示未分版块区）
  String? _addingToSectionId;
  // 用于添加版块
  bool _isAddingSection = false;
  // 正在添加子版块的父版块 ID
  String? _addingSubSectionToParentId;

  final _taskAddController = TextEditingController();
  final _taskAddFocus = FocusNode();
  final _sectionAddController = TextEditingController();
  final _sectionAddFocus = FocusNode();
  final _subSectionAddController = TextEditingController();
  final _subSectionAddFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<ProjectSectionProvider>()
          .loadSectionsForProject(widget.projectId);
    });
  }

  @override
  void dispose() {
    _taskAddController.dispose();
    _taskAddFocus.dispose();
    _sectionAddController.dispose();
    _sectionAddFocus.dispose();
    _subSectionAddController.dispose();
    _subSectionAddFocus.dispose();
    super.dispose();
  }

  bool get isDark => widget.isDark;

  // ── 任务操作 ──────────────────────────────────────────────────

  Future<void> _addTask(BuildContext context, {String? sectionId}) async {
    final title = _taskAddController.text.trim();
    if (title.isEmpty) return;
    final rp = context.read<RecordProvider>();
    final pp = context.read<ProjectProvider>();
    await rp.addRecord(
      type: RecordType.task,
      title: title,
      content: '',
      projectId: widget.projectId,
      sectionId: sectionId,
    );
    await pp.refreshStats(widget.projectId);
    _taskAddController.clear();
    setState(() => _addingToSectionId = null);
  }

  Future<void> _toggleTask(BuildContext context, Record record) async {
    HapticFeedback.selectionClick();
    final rp = context.read<RecordProvider>();
    final pp = context.read<ProjectProvider>();
    await rp.updateRecord(
      record.copyWith(
        isCompleted: !record.isCompleted,
        completedAt: !record.isCompleted ? DateTime.now() : null,
      ),
    );
    await pp.refreshStats(widget.projectId);
  }

  Future<void> _deleteTask(BuildContext context, Record record) async {
    final rp = context.read<RecordProvider>();
    final pp = context.read<ProjectProvider>();
    await rp.deleteRecord(record.id);
    await pp.refreshStats(widget.projectId);
  }

  void _openTaskDetail(BuildContext context, Record record) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _TaskDetailSheet(
        record: record,
        projectColor: widget.projectColor,
        isDark: widget.isDark,
        palette: widget.palette,
        onUpdate: (updated) async {
          await context.read<RecordProvider>().updateRecord(updated);
        },
        onDelete: () async {
          await _deleteTask(context, record);
        },
      ),
    );
  }

  // ── 版块操作 ──────────────────────────────────────────────────

  Future<void> _addSection(BuildContext context) async {
    final title = _sectionAddController.text.trim();
    if (title.isEmpty) return;
    await context.read<ProjectSectionProvider>().addSection(
          projectId: widget.projectId,
          title: title,
          colorHex: _colorHexFromProjectColor(widget.projectColor),
        );
    _sectionAddController.clear();
    setState(() => _isAddingSection = false);
  }

  Future<void> _addSubSection(
      BuildContext context, String parentSectionId) async {
    final title = _subSectionAddController.text.trim();
    if (title.isEmpty) return;
    await context.read<ProjectSectionProvider>().addSection(
          projectId: widget.projectId,
          parentSectionId: parentSectionId,
          title: title,
          colorHex: _colorHexFromProjectColor(widget.projectColor),
        );
    _subSectionAddController.clear();
    setState(() => _addingSubSectionToParentId = null);
  }

  Future<void> _deleteSection(BuildContext context, String sectionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除版块'),
        content: const Text('删除版块后，其中的任务和子版块也会一并删除。确认删除？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除',
                style: TextStyle(color: Color(0xFFE74C3C))),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<ProjectSectionProvider>().deleteSection(sectionId);
    }
  }

  void _showSectionContextMenu(
      BuildContext context, ProjectSection section) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SectionContextMenu(
        section: section,
        isDark: isDark,
        projectColor: widget.projectColor,
        onAddTask: () {
          Navigator.pop(ctx);
          setState(() => _addingToSectionId = section.id);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _taskAddFocus.requestFocus();
          });
        },
        onAddSubSection: () {
          Navigator.pop(ctx);
          setState(() => _addingSubSectionToParentId = section.id);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _subSectionAddFocus.requestFocus();
          });
        },
        onRename: () async {
          Navigator.pop(ctx);
          await _showRenameSectionDialog(context, section);
        },
        onDelete: () async {
          Navigator.pop(ctx);
          await _deleteSection(context, section.id);
        },
      ),
    );
  }

  Future<void> _showRenameSectionDialog(
      BuildContext context, ProjectSection section) async {
    final ctrl = TextEditingController(text: section.title);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名版块'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '版块名称',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('确认')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && context.mounted) {
      await context
          .read<ProjectSectionProvider>()
          .updateSection(section.copyWith(title: result));
    }
    ctrl.dispose();
  }

  String _colorHexFromProjectColor(Color c) {
    final argb = c.toARGB32();
    final hex = (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();
    return '#$hex';
  }

  // ── 构建 ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer2<RecordProvider, ProjectSectionProvider>(
      builder: (ctx, rp, sp, _) {
        final allTasks = rp
            .recordsForProject(widget.projectId)
            .where((r) =>
                r.type == RecordType.task || r.type == RecordType.checkItem)
            .toList();

        final topSections = sp.topLevelSections;

        // 未分配版块的任务（含已完成，版块是结构化组织，不按完成状态过滤）
        final unassigned = allTasks
            .where((r) => r.sectionId == null)
            .toList();
        final unassignedDoneCount = unassigned.where((r) => r.isCompleted).length;

        // 总待完成数
        final totalPending = allTasks.where((r) => !r.isCompleted).length;

        return CustomScrollView(
          slivers: [
            // ── 顶部操作栏 ──────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Row(
                  children: [
                    // 待完成数
                    Text(
                      '$totalPending 个待完成',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? Colors.white38
                            : const Color(0xFFAAAAAA),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    // 新建版块按钮（图标+文字小胶囊）
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isAddingSection = !_isAddingSection;
                          _addingToSectionId = null;
                        });
                        if (_isAddingSection) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _sectionAddFocus.requestFocus();
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: widget.projectColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.create_new_folder_outlined,
                                size: 13, color: widget.projectColor),
                            const SizedBox(width: 4),
                            Text(
                              '版块',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: widget.projectColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 新建任务按钮（主色实心小胶囊）
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _addingToSectionId = '';
                          _isAddingSection = false;
                        });
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _taskAddFocus.requestFocus();
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: widget.projectColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.add_rounded,
                                size: 13, color: Colors.white),
                            const SizedBox(width: 3),
                            const Text(
                              '任务',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── 新建版块输入框 ───────────────────────────────
            if (_isAddingSection)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _QuickAddRow(
                    controller: _sectionAddController,
                    focusNode: _sectionAddFocus,
                    color: widget.projectColor,
                    isDark: isDark,
                    hintText: '输入版块名称…',
                    onSubmit: () => _addSection(ctx),
                    onCancel: () =>
                        setState(() => _isAddingSection = false),
                  ),
                ),
              ),

            // ── 空状态 ───────────────────────────────────────
            if (allTasks.isEmpty && topSections.isEmpty && !_isAddingSection && _addingToSectionId == null)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('📂',
                          style: TextStyle(fontSize: 44)),
                      const SizedBox(height: 12),
                      Text(
                        '还没有版块或任务',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white38
                              : const Color(0xFFBBBBBB),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '创建版块来组织任务，或直接添加任务',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.white24
                              : const Color(0xFFCCCCCC),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              // ── 版块列表（顶级） ──────────────────────────
              for (final section in topSections)
                ..._buildSectionSliver(ctx, section, rp, sp, depth: 0),

              // ── 未分版块任务区（收件箱卡片）────────────────
              if (unassigned.isNotEmpty || _addingToSectionId == '')
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.07)
                              : Colors.black.withValues(alpha: 0.06),
                          width: 1,
                        ),
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
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 收件箱头部
                            Container(
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : const Color(0xFFF5F5F5),
                              ),
                              padding:
                                  const EdgeInsets.fromLTRB(0, 10, 12, 10),
                              child: Row(
                                children: [
                                  // 左侧灰色竖条
                                  Container(
                                    width: 4,
                                    height: 20,
                                    margin: const EdgeInsets.only(
                                        left: 12, right: 10),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white38
                                          : const Color(0xFFBBBBBB),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.inbox_outlined,
                                    size: 14,
                                    color: Color(0xFF999999),
                                  ),
                                  const SizedBox(width: 6),
                                  const Expanded(
                                    child: Text(
                                      '收件箱',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF888888),
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ),
                                  if (unassigned.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.white12
                                            : Colors.black
                                                .withValues(alpha: 0.06),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '$unassignedDoneCount/${unassigned.length}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? Colors.white54
                                              : const Color(0xFF888888),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            // 任务列表（已完成的 dimmed 显示，最后一项无分割线）
                            ...List.generate(unassigned.length, (i) {
                                  final t = unassigned[i];
                                  return Padding(
                                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                                    child: _TaskRow(
                                      record: t,
                                      color: widget.projectColor,
                                      isDark: isDark,
                                      onToggle: () => _toggleTask(ctx, t),
                                      onTap: () => _openTaskDetail(ctx, t),
                                      dimmed: t.isCompleted,
                                      isLast: i == unassigned.length - 1,
                                    ),
                                  );
                                }),
                            // 添加任务输入框
                            if (_addingToSectionId == '')
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(12, 6, 12, 6),
                                child: _QuickAddRow(
                                  controller: _taskAddController,
                                  focusNode: _taskAddFocus,
                                  color: widget.projectColor,
                                  isDark: isDark,
                                  hintText: '输入任务名称…',
                                  onSubmit: () =>
                                      _addTask(ctx, sectionId: null),
                                  onCancel: () =>
                                      setState(() => _addingToSectionId = null),
                                ),
                              ),
                            // 快速添加入口
                            if (_addingToSectionId != '')
                              InkWell(
                                onTap: () {
                                  setState(() => _addingToSectionId = '');
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    _taskAddFocus.requestFocus();
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      16, 8, 16, 10),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.add_rounded,
                                        size: 14,
                                        color: isDark
                                            ? Colors.white24
                                            : const Color(0xFFCCCCCC),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        '添加任务',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark
                                              ? Colors.white24
                                              : const Color(0xFFCCCCCC),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

            ],

            const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
          ],
        );
      },
    );
  }

  /// 构建一个版块的 Sliver（卡片化，递归支持子版块）
  List<Widget> _buildSectionSliver(
    BuildContext context,
    ProjectSection section,
    RecordProvider rp,
    ProjectSectionProvider sp, {
    required int depth,
  }) {
    final isCollapsed = section.isCollapsed;
    final sectionColor = _parseColor(section.colorHex);
    final children = sp.childSectionsOf(section.id);
    final allProjectTasks = rp
        .recordsForProject(widget.projectId)
        .where((r) => r.type == RecordType.task || r.type == RecordType.checkItem)
        .toList();
    // 直属任务（用于内容区渲染）
    final sectionTasks = allProjectTasks
        .where((r) => r.sectionId == section.id)
        .toList();
    final sectionDoneCount = sectionTasks.where((r) => r.isCompleted).length;

    // 递归总任务数（含所有子版块，用于头部徽章）
    List<String> _collectDescendantIds(String sId) {
      final result = <String>[sId];
      for (final c in sp.childSectionsOf(sId)) {
        result.addAll(_collectDescendantIds(c.id));
      }
      return result;
    }
    final allSectionIds = _collectDescendantIds(section.id);
    final totalTasks = allProjectTasks
        .where((r) => allSectionIds.contains(r.sectionId))
        .toList();
    final totalDoneCount = totalTasks.where((r) => r.isCompleted).length;

    final double hPad = 16.0 + depth * 12.0;
    final result = <Widget>[];

    // ── 整体卡片（标题 + 内容）
    result.add(
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(hPad, depth == 0 ? 12 : 8, 16, 0),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.07)
                    : sectionColor.withValues(alpha: 0.12),
                width: 1,
              ),
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 版块头部
                  InkWell(
                    onTap: () => sp.toggleCollapse(section.id),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(14)),
                    child: Container(
                      decoration: BoxDecoration(
                        color: sectionColor.withValues(
                            alpha: isDark ? 0.12 : 0.07),
                      ),
                      padding: const EdgeInsets.fromLTRB(0, 10, 12, 10),
                      child: Row(
                        children: [
                          // 左侧彩色竖条
                          Container(
                            width: 4,
                            height: 20,
                            margin: const EdgeInsets.only(left: 12, right: 10),
                            decoration: BoxDecoration(
                              color: sectionColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          // emoji
                          Text(section.emoji,
                              style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 7),
                          // 版块名
                          Expanded(
                            child: Text(
                              section.title,
                              style: TextStyle(
                                fontSize: depth == 0 ? 13 : 12,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.85)
                                    : const Color(0xFF333333),
                                letterSpacing: 0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // 任务数徽章（含子版块完成数/总数）
                          if (totalTasks.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: sectionColor.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$totalDoneCount/${totalTasks.length}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: sectionColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          // 折叠箭头
                          AnimatedRotation(
                            duration: const Duration(milliseconds: 200),
                            turns: isCollapsed ? -0.25 : 0,
                            child: Icon(
                              Icons.expand_more_rounded,
                              size: 18,
                              color: sectionColor.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // 更多菜单
                          GestureDetector(
                            onTap: () =>
                                _showSectionContextMenu(context, section),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.more_horiz_rounded,
                                size: 18,
                                color: isDark
                                    ? Colors.white30
                                    : const Color(0xFFBBBBBB),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── 内容区（仅展开时显示）
                  if (!isCollapsed) ...[
                    // 子版块（内嵌，无独立 Sliver）
                    if (children.isNotEmpty || _addingSubSectionToParentId == section.id)
                      _buildSubSectionsInCard(context, section, children, rp, sp),

                     // 当前版块直属任务列表（已完成的 dimmed 显示，最后一项无分割线）
                     if (sectionTasks.isNotEmpty)
                       ...List.generate(sectionTasks.length, (i) {
                             final t = sectionTasks[i];
                             return Padding(
                               padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                               child: _TaskRow(
                                 record: t,
                                 color: sectionColor,
                                 isDark: isDark,
                                 onToggle: () => _toggleTask(context, t),
                                 onTap: () => _openTaskDetail(context, t),
                                 dimmed: t.isCompleted,
                                 isLast: i == sectionTasks.length - 1,
                               ),
                             );
                           }),

                    // 添加任务输入框（仅无子版块时）
                    if (children.isEmpty && _addingToSectionId == section.id)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                        child: _QuickAddRow(
                          controller: _taskAddController,
                          focusNode: _taskAddFocus,
                          color: widget.projectColor,
                          isDark: isDark,
                          hintText: '输入任务名称…',
                          onSubmit: () => _addTask(ctx, sectionId: section.id),
                          onCancel: () =>
                              setState(() => _addingToSectionId = null),
                        ),
                      ),

                    // 快速添加任务入口（仅无子版块时）
                    if (children.isEmpty && _addingToSectionId != section.id)
                      InkWell(
                        onTap: () {
                          setState(() {
                            _addingToSectionId = section.id;
                            _isAddingSection = false;
                            _addingSubSectionToParentId = null;
                          });
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _taskAddFocus.requestFocus();
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                          child: Row(
                            children: [
                              Icon(
                                Icons.add_rounded,
                                size: 14,
                                color: isDark
                                    ? Colors.white24
                                    : const Color(0xFFCCCCCC),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '添加任务',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.white24
                                      : const Color(0xFFCCCCCC),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // 有子版块时底部留白
                    if (children.isNotEmpty)
                      const SizedBox(height: 4),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return result;
  }

  /// 在卡片内部渲染子版块（非 Sliver，普通 Widget）
  Widget _buildSubSectionsInCard(
    BuildContext context,
    ProjectSection parent,
    List<ProjectSection> children,
    RecordProvider rp,
    ProjectSectionProvider sp,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...children.map((child) {
          final childColor = _parseColor(child.colorHex);
          final childTasks = rp
              .recordsForProject(widget.projectId)
              .where((r) =>
                  (r.type == RecordType.task ||
                      r.type == RecordType.checkItem) &&
                  r.sectionId == child.id)
              .toList();
          final childDoneCount = childTasks.where((r) => r.isCompleted).length;
          final childCollapsed = child.isCollapsed;

          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : childColor.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : childColor.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 子版块头部
                  InkWell(
                    onTap: () => sp.toggleCollapse(child.id),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                      child: Row(
                        children: [
                          Container(
                            width: 3,
                            height: 14,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: childColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          Text(child.emoji,
                              style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              child.title,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white70
                                    : const Color(0xFF555555),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (childTasks.isNotEmpty) ...[ // 子版块徽章：完成/总数
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: childColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$childDoneCount/${childTasks.length}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: childColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          AnimatedRotation(
                            duration: const Duration(milliseconds: 200),
                            turns: childCollapsed ? -0.25 : 0,
                            child: Icon(
                              Icons.expand_more_rounded,
                              size: 15,
                              color: childColor.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(width: 2),
                          GestureDetector(
                            onTap: () =>
                                _showSectionContextMenu(context, child),
                            child: Padding(
                              padding: const EdgeInsets.all(3),
                              child: Icon(
                                Icons.more_horiz_rounded,
                                size: 15,
                                color: isDark
                                    ? Colors.white30
                                    : const Color(0xFFCCCCCC),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 子版块任务（最后一项无分割线）
                  if (!childCollapsed) ...[
                    ...List.generate(childTasks.length, (i) {
                          final t = childTasks[i];
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                            child: _TaskRow(
                              record: t,
                              color: childColor,
                              isDark: isDark,
                              onToggle: () => _toggleTask(context, t),
                              onTap: () => _openTaskDetail(context, t),
                              dimmed: t.isCompleted,
                              isLast: i == childTasks.length - 1,
                            ),
                          );
                        }),
                    if (_addingToSectionId == child.id)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
                        child: _QuickAddRow(
                          controller: _taskAddController,
                          focusNode: _taskAddFocus,
                          color: widget.projectColor,
                          isDark: isDark,
                          hintText: '输入任务名称…',
                          onSubmit: () =>
                              _addTask(ctx, sectionId: child.id),
                          onCancel: () =>
                              setState(() => _addingToSectionId = null),
                        ),
                      ),
                    if (_addingToSectionId != child.id)
                      InkWell(
                        onTap: () {
                          setState(() {
                            _addingToSectionId = child.id;
                            _isAddingSection = false;
                            _addingSubSectionToParentId = null;
                          });
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _taskAddFocus.requestFocus();
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
                          child: Row(
                            children: [
                              Icon(Icons.add_rounded,
                                  size: 12,
                                  color: isDark
                                      ? Colors.white24
                                      : const Color(0xFFCCCCCC)),
                              const SizedBox(width: 4),
                              Text(
                                '添加任务',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.white24
                                      : const Color(0xFFCCCCCC),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          );
        }),
        // 正在添加子版块的输入框
        if (_addingSubSectionToParentId == parent.id)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: _QuickAddRow(
              controller: _subSectionAddController,
              focusNode: _subSectionAddFocus,
              color: widget.projectColor,
              isDark: isDark,
              hintText: '子版块名称…',
              onSubmit: () => _addSubSection(ctx, parent.id),
              onCancel: () =>
                  setState(() => _addingSubSectionToParentId = null),
            ),
          ),
      ],
    );
  }

  BuildContext get ctx => context;
}

// ── 版块右键菜单 ──────────────────────────────────────────────────
class _SectionContextMenu extends StatelessWidget {
  final ProjectSection section;
  final bool isDark;
  final Color projectColor;
  final VoidCallback onAddTask;
  final VoidCallback onAddSubSection;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _SectionContextMenu({
    required this.section,
    required this.isDark,
    required this.projectColor,
    required this.onAddTask,
    required this.onAddSubSection,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 把手
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 版块标题
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  children: [
                    Text(section.emoji,
                        style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(
                      section.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color:
                            isDark ? Colors.white : const Color(0xFF1A1410),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              _MenuAction(
                icon: Icons.add_task_outlined,
                label: '添加任务到此版块',
                color: projectColor,
                isDark: isDark,
                onTap: onAddTask,
              ),
              _MenuAction(
                icon: Icons.create_new_folder_outlined,
                label: '添加子版块',
                color: projectColor,
                isDark: isDark,
                onTap: onAddSubSection,
              ),
              _MenuAction(
                icon: Icons.drive_file_rename_outline_rounded,
                label: '重命名版块',
                color: isDark ? Colors.white70 : const Color(0xFF444444),
                isDark: isDark,
                onTap: onRename,
              ),
              _MenuAction(
                icon: Icons.delete_outline_rounded,
                label: '删除版块',
                color: const Color(0xFFE74C3C),
                isDark: isDark,
                onTap: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _MenuAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color, size: 20),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
}

// ── 快速添加行 ────────────────────────────────────────────────────
class _QuickAddRow extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Color color;
  final bool isDark;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;
  final String hintText;

  const _QuickAddRow({
    required this.controller,
    required this.focusNode,
    required this.color,
    required this.isDark,
    required this.onSubmit,
    required this.onCancel,
    this.hintText = '输入任务名称…',
  });

@override
Widget build(BuildContext context) {
return Row(
children: [
// 轻量勾选框占位
Container(
width: 20,
height: 20,
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(5),
border: Border.all(
color: isDark
? const Color(0xFF444444)
: const Color(0xFFDDDDDD),
width: 1.5,
),
),
),
const SizedBox(width: 10),
// 输入框：无边框，仅底部细线作为焦点提示
Expanded(
child: TextField(
controller: controller,
focusNode: focusNode,
autofocus: true,
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
),
border: InputBorder.none,
focusedBorder: UnderlineInputBorder(
borderSide: BorderSide(
color: color.withValues(alpha: 0.5),
width: 1,
),
),
enabledBorder: InputBorder.none,
isDense: true,
contentPadding: const EdgeInsets.only(bottom: 4),
),
onSubmitted: (_) => onSubmit(),
),
),
// 取消
GestureDetector(
onTap: onCancel,
child: Padding(
padding: const EdgeInsets.all(4),
child: Icon(
Icons.close_rounded,
size: 15,
color: isDark ? Colors.white24 : const Color(0xFFCCCCCC),
),
),
),
const SizedBox(width: 4),
// 确认：轻量文字按钮，用版块色
GestureDetector(
onTap: onSubmit,
child: Container(
padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
decoration: BoxDecoration(
color: color.withValues(alpha: 0.12),
borderRadius: BorderRadius.circular(6),
),
        child: Text(
          '确认',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    ),
  ],
);
}
}

// ── 任务行 ────────────────────────────────────────────────────────
class _TaskRow extends StatelessWidget {
final Record record;
final Color color;
final bool isDark;
final VoidCallback onToggle;
final VoidCallback onTap;
final bool dimmed;
final bool isLast;

const _TaskRow({
required this.record,
required this.color,
required this.isDark,
required this.onToggle,
required this.onTap,
this.dimmed = false,
this.isLast = false,
});

  @override
  Widget build(BuildContext context) {
    final isDone = record.isCompleted;
    final priority = _TaskPriority.fromExtra(record.extra);
    final isOverdue = record.deadline != null &&
        record.deadline!.isBefore(DateTime.now()) &&
        !isDone;

    final textColor = isDone || dimmed
        ? (isDark ? Colors.white30 : const Color(0xFFCCCCCC))
        : (isDark ? Colors.white : const Color(0xFF1A1410));

    // 优先级小色点（仅未完成时显示）
    Color? priorityDotColor;
    if (priority != _TaskPriority.none && !isDone) {
      switch (priority) {
        case _TaskPriority.high:
          priorityDotColor = const Color(0xFFE74C3C);
          break;
        case _TaskPriority.medium:
          priorityDotColor = const Color(0xFFE67E22);
          break;
        case _TaskPriority.low:
          priorityDotColor = const Color(0xFF27AE60);
          break;
        case _TaskPriority.none:
          break;
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 9),
        decoration: isLast
            ? null
            : BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.04),
                    width: 0.5,
                  ),
                ),
              ),
        child: Row(
          children: [
            // 勾选框：已完成用淡色边框+淡勾，轻盈不突兀
            GestureDetector(
              onTap: onToggle,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDone
                        ? (isDark
                            ? Colors.white.withValues(alpha: 0.2)
                            : const Color(0xFFDDDDDD))
                        : (isDark
                            ? const Color(0xFF555555)
                            : const Color(0xFFCCCCCC)),
                    width: isDone ? 1.0 : 1.5,
                  ),
                ),
                child: isDone
                    ? Icon(
                        Icons.check_rounded,
                        size: 13,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.3)
                            : const Color(0xFFCCCCCC),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            // 内容
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 优先级色点（内嵌标题左侧，仅未完成时显示）
                      if (priorityDotColor != null) ...[
                        Container(
                          width: 5,
                          height: 5,
                          margin: const EdgeInsets.only(right: 5, top: 1),
                          decoration: BoxDecoration(
                            color: priorityDotColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                      Expanded(
                        child: Text(
                          record.title.isEmpty ? record.content : record.title,
                          style: TextStyle(
                            fontSize: 14,
                            color: textColor,
                            decoration:
                                isDone ? TextDecoration.lineThrough : null,
                            decorationColor: isDark
                                ? Colors.white.withValues(alpha: 0.25)
                                : const Color(0xFFCCCCCC),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (record.deadline != null || record.content.isNotEmpty)
                    const SizedBox(height: 2),
                  Row(
                    children: [
                      if (record.deadline != null)
                        Text(
                          '截止 ${_fmtDate(record.deadline!)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isOverdue
                                ? const Color(0xFFE74C3C)
                                : (isDark
                                    ? Colors.white30
                                    : const Color(0xFFBBBBBB)),
                            fontWeight: isOverdue
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      if (record.content.isNotEmpty &&
                          record.deadline != null)
                        const SizedBox(width: 8),
                      if (record.content.isNotEmpty)
                        Icon(
                          Icons.notes_rounded,
                          size: 11,
                          color: isDark
                              ? Colors.white30
                              : const Color(0xFFBBBBBB),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // 箭头：仅未完成时显示，且更细淡
            if (!isDone)
              Icon(
                Icons.chevron_right_rounded,
                size: 14,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : const Color(0xFFE5E5E5),
              ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) => '${d.month}/${d.day}';
}

// ── 任务详情弹窗 ──────────────────────────────────────────────────
class _TaskDetailSheet extends StatefulWidget {
  final Record record;
  final Color projectColor;
  final bool isDark;
  final DayPalette palette;
  final Future<void> Function(Record) onUpdate;
  final Future<void> Function() onDelete;

  const _TaskDetailSheet({
    required this.record,
    required this.projectColor,
    required this.isDark,
    required this.palette,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  State<_TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends State<_TaskDetailSheet> {
  late TextEditingController _titleCtrl;
  late TextEditingController _noteCtrl;
  late DateTime? _deadline;
  late _TaskPriority _priority;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(
      text: widget.record.title.isEmpty
          ? widget.record.content
          : widget.record.title,
    );
    _noteCtrl = TextEditingController(
      text: widget.record.content.isEmpty
          ? ''
          : (widget.record.title.isEmpty ? '' : widget.record.content),
    );
    _deadline = widget.record.deadline;
    _priority = _TaskPriority.fromExtra(widget.record.extra);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final updated = widget.record.copyWith(
        title: _titleCtrl.text.trim(),
        content: _noteCtrl.text.trim(),
        deadline: _deadline,
        extra: {
          ...widget.record.extra,
          'priority': _priority.value,
        },
      );
      await widget.onUpdate(updated);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final color = widget.projectColor;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // 把手
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 勾选 + 标题行
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () async {
                      final updated = widget.record.copyWith(
                        isCompleted: !widget.record.isCompleted,
                        completedAt: !widget.record.isCompleted
                            ? DateTime.now()
                            : null,
                      );
                      await widget.onUpdate(updated);
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: widget.record.isCompleted
                            ? color
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                          color: widget.record.isCompleted
                              ? color
                              : (isDark
                                  ? const Color(0xFF555555)
                                  : const Color(0xFFCCCCCC)),
                          width: 2,
                        ),
                      ),
                      child: widget.record.isCompleted
                          ? const Icon(Icons.check_rounded,
                              size: 14, color: Colors.white)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _titleCtrl,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1A1410),
                        decoration: widget.record.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 0, 20, bottomInset + 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 备注
                    Container(
                      constraints: const BoxConstraints(minHeight: 80),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1A1A1A)
                            : const Color(0xFFF8F8F8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _noteCtrl,
                        maxLines: null,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          color: isDark
                              ? Colors.white70
                              : const Color(0xFF555555),
                        ),
                        decoration: InputDecoration(
                          hintText: '添加备注…',
                          hintStyle: TextStyle(
                            color: isDark
                                ? const Color(0xFF444444)
                                : const Color(0xFFCCCCCC),
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 截止日期
                    _DetailRow(
                      icon: Icons.event_outlined,
                      label: '截止日期',
                      isDark: isDark,
                      child: GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _deadline ??
                                DateTime.now()
                                    .add(const Duration(days: 1)),
                            firstDate: DateTime.now()
                                .subtract(const Duration(days: 1)),
                            lastDate: DateTime.now()
                                .add(const Duration(days: 365 * 3)),
                            builder: (ctx, child) => Theme(
                              data: Theme.of(ctx).copyWith(
                                colorScheme: ColorScheme.light(
                                    primary: color,
                                    onPrimary: Colors.white),
                              ),
                              child: child!,
                            ),
                          );
                          if (picked != null) {
                            setState(() => _deadline = picked);
                          }
                        },
                        child: Row(
                          children: [
                            Text(
                              _deadline != null
                                  ? '${_deadline!.year}/${_deadline!.month.toString().padLeft(2, '0')}/${_deadline!.day.toString().padLeft(2, '0')}'
                                  : '未设置',
                              style: TextStyle(
                                fontSize: 14,
                                color: _deadline != null
                                    ? (isDark
                                        ? Colors.white
                                        : const Color(0xFF333333))
                                    : (isDark
                                        ? Colors.white38
                                        : const Color(0xFFCCCCCC)),
                              ),
                            ),
                            if (_deadline != null) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _deadline = null),
                                child: Icon(Icons.close_rounded,
                                    size: 14,
                                    color: isDark
                                        ? Colors.white30
                                        : const Color(0xFFCCCCCC)),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 优先级
                    _DetailRow(
                      icon: Icons.flag_outlined,
                      label: '优先级',
                      isDark: isDark,
                      child: Row(
                        children: _TaskPriority.values.map((p) {
                          final isSelected = _priority == p;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _priority = p),
                              child: AnimatedContainer(
                                duration:
                                    const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? color.withValues(alpha: 0.12)
                                      : (isDark
                                          ? const Color(0xFF2A2A2A)
                                          : const Color(0xFFF5F5F5)),
                                  borderRadius:
                                      BorderRadius.circular(8),
                                  border: isSelected
                                      ? Border.all(
                                          color: color, width: 1.5)
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    Text(p.emoji,
                                        style: const TextStyle(
                                            fontSize: 12)),
                                    const SizedBox(width: 4),
                                    Text(
                                      p.label,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isSelected
                                            ? color
                                            : (isDark
                                                ? Colors.white54
                                                : const Color(
                                                    0xFF888888)),
                                        fontWeight: isSelected
                                            ? FontWeight.w600
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
                    ),
                    const SizedBox(height: 20),
                    // 删除按钮
                    GestureDetector(
                      onTap: () async {
                        await widget.onDelete();
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: Row(
                        children: [
                          const Icon(Icons.delete_outline_rounded,
                              size: 16, color: Color(0xFFE74C3C)),
                          const SizedBox(width: 6),
                          const Text(
                            '删除任务',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFFE74C3C),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 保存按钮
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('保存',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 详情行 ────────────────────────────────────────────────────────
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final Widget child;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon,
              size: 16,
              color: isDark ? Colors.white38 : const Color(0xFFBBBBBB)),
          const SizedBox(width: 10),
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white54 : const Color(0xFF888888),
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Tab 1 — 笔记
// ─────────────────────────────────────────────────────────────────
class _NotesTab extends StatefulWidget {
  final String projectId;
  final Color projectColor;
  final bool isDark;
  final DayPalette palette;

  const _NotesTab({
    required this.projectId,
    required this.projectColor,
    required this.isDark,
    required this.palette,
  });

  @override
  State<_NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<_NotesTab> {
  bool _isAdding = false;
  final _addCtrl = TextEditingController();
  final _addFocus = FocusNode();

  @override
  void dispose() {
    _addCtrl.dispose();
    _addFocus.dispose();
    super.dispose();
  }

  Future<void> _addNote(BuildContext context) async {
    final content = _addCtrl.text.trim();
    if (content.isEmpty) return;
    await context.read<RecordProvider>().addRecord(
          type: RecordType.note,
          content: content,
          projectId: widget.projectId,
        );
    _addCtrl.clear();
    setState(() => _isAdding = false);
  }

  Future<void> _deleteNote(BuildContext context, Record record) async {
    await context.read<RecordProvider>().deleteRecord(record.id);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RecordProvider>(
      builder: (ctx, rp, _) {
        final notes = rp
            .recordsForProject(widget.projectId)
            .where((r) =>
                r.type == RecordType.note || r.type == RecordType.idea)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Text(
                      '${notes.length} 条记录',
                      style: TextStyle(
                        fontSize: 13,
                        color: widget.isDark
                            ? Colors.white54
                            : const Color(0xFF888888),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        setState(() => _isAdding = !_isAdding);
                        if (!_isAdding) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _addFocus.requestFocus();
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: widget.projectColor
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.add_rounded,
                                size: 14,
                                color: widget.projectColor),
                            const SizedBox(width: 4),
                            Text(
                              '新建笔记',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: widget.projectColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isAdding)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _NoteInputCard(
                    controller: _addCtrl,
                    focusNode: _addFocus,
                    color: widget.projectColor,
                    isDark: widget.isDark,
                    onSubmit: () => _addNote(ctx),
                    onCancel: () => setState(() => _isAdding = false),
                  ),
                ),
              ),
            if (notes.isEmpty && !_isAdding)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('📝',
                          style: TextStyle(fontSize: 40)),
                      const SizedBox(height: 12),
                      Text(
                        '还没有笔记',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: widget.isDark
                              ? Colors.white38
                              : const Color(0xFFBBBBBB),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '记录想法、决策过程、会议记录…',
                        style: TextStyle(
                          fontSize: 12,
                          color: widget.isDark
                              ? Colors.white24
                              : const Color(0xFFCCCCCC),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx2, i) => _NoteCard(
                      record: notes[i],
                      isDark: widget.isDark,
                      projectColor: widget.projectColor,
                      onDelete: () => _deleteNote(ctx, notes[i]),
                    ),
                    childCount: notes.length,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ── 笔记输入卡片 ──────────────────────────────────────────────────
class _NoteInputCard extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Color color;
  final bool isDark;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  const _NoteInputCard({
    required this.controller,
    required this.focusNode,
    required this.color,
    required this.isDark,
    required this.onSubmit,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: true,
            maxLines: 5,
            minLines: 3,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: isDark ? Colors.white : const Color(0xFF1A1410),
            ),
            decoration: InputDecoration(
              hintText: '写下你的想法、决策或会议记录…',
              hintStyle: TextStyle(
                color: isDark
                    ? const Color(0xFF444444)
                    : const Color(0xFFCCCCCC),
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: onCancel,
                child: Text(
                  '取消',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white38 : const Color(0xFFBBBBBB),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: onSubmit,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 7),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '保存',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
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

// ── 笔记卡片 ──────────────────────────────────────────────────────
class _NoteCard extends StatelessWidget {
  final Record record;
  final bool isDark;
  final Color projectColor;
  final VoidCallback onDelete;

  const _NoteCard({
    required this.record,
    required this.isDark,
    required this.projectColor,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dt = record.createdAt;
    final timeStr =
        '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
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
            // 内容
            Text(
              record.content,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: isDark ? Colors.white : const Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 10),
            // 底部：时间 + 操作
            Row(
              children: [
                Icon(
                  record.type == RecordType.idea
                      ? Icons.lightbulb_outline_rounded
                      : Icons.notes_rounded,
                  size: 12,
                  color: isDark ? Colors.white30 : const Color(0xFFCCCCCC),
                ),
                const SizedBox(width: 4),
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white30 : const Color(0xFFCCCCCC),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onDelete,
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    size: 16,
                    color: Color(0xFFE74C3C),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Tab 2 — 概览（项目日报）
// ─────────────────────────────────────────────────────────────────
class _OverviewTab extends StatelessWidget {
  final Project project;
  final Color projectColor;
  final bool isDark;
  final DayPalette palette;

  const _OverviewTab({
    required this.project,
    required this.projectColor,
    required this.isDark,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<RecordProvider>(
      builder: (ctx, rp, _) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final weekAgo = today.subtract(const Duration(days: 6));

        final allTasks = rp
            .recordsForProject(project.id)
            .where((r) =>
                r.type == RecordType.task || r.type == RecordType.checkItem)
            .toList();

        // ── 今日统计
        final todayCompleted = allTasks
            .where((t) =>
                t.isCompleted &&
                t.completedAt != null &&
                !t.completedAt!.isBefore(today))
            .length;
        final todayAdded = allTasks
            .where((t) => !t.createdAt.isBefore(today))
            .length;

        // ── 即将到期（7天内，未完成）
        final upcoming = allTasks
            .where((t) =>
                !t.isCompleted &&
                t.deadline != null &&
                !t.deadline!.isBefore(now) &&
                t.deadline!.isBefore(now.add(const Duration(days: 7))))
            .toList()
          ..sort((a, b) => a.deadline!.compareTo(b.deadline!));

        // ── 已逾期（未完成）
        final overdue = allTasks
            .where((t) =>
                !t.isCompleted &&
                t.deadline != null &&
                t.deadline!.isBefore(now))
            .toList()
          ..sort((a, b) => a.deadline!.compareTo(b.deadline!));

        // ── 本周每日完成数（用于迷你趋势图）
        final weeklyData = List.generate(7, (i) {
          final day = weekAgo.add(Duration(days: i));
          final nextDay = day.add(const Duration(days: 1));
          return allTasks
              .where((t) =>
                  t.isCompleted &&
                  t.completedAt != null &&
                  !t.completedAt!.isBefore(day) &&
                  t.completedAt!.isBefore(nextDay))
              .length;
        });

        // ── 健康度
        final taskProgress = project.completionRate;
        double? timeProgress;
        if (project.deadline != null) {
          final start = project.startDate ?? project.createdAt;
          final end = project.deadline!;
          final total = end.difference(start).inMinutes.toDouble();
          final elapsed = now.difference(start).inMinutes.toDouble();
          timeProgress = total > 0 ? (elapsed / total).clamp(0.0, 1.0) : 0.0;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 今日动态卡 ──────────────────────────────────
              _DailyPulseCard(
                isDark: isDark,
                projectColor: projectColor,
                todayCompleted: todayCompleted,
                todayAdded: todayAdded,
                overdueCount: overdue.length,
                totalPending: allTasks.where((t) => !t.isCompleted).length,
              ),
              const SizedBox(height: 12),

              // ── 本周趋势迷你图 ──────────────────────────────
              _WeeklyTrendCard(
                isDark: isDark,
                projectColor: projectColor,
                weeklyData: weeklyData,
                weekAgo: weekAgo,
              ),
              const SizedBox(height: 12),

              // ── 健康度（进度 vs 时间消耗对比）──────────────
              _HealthCard(
                isDark: isDark,
                projectColor: projectColor,
                project: project,
                taskProgress: taskProgress,
                timeProgress: timeProgress,
              ),
              const SizedBox(height: 12),

              // ── 即将到期倒计时 ──────────────────────────────
              if (overdue.isNotEmpty || upcoming.isNotEmpty)
                _DeadlineCard(
                  isDark: isDark,
                  projectColor: projectColor,
                  overdue: overdue,
                  upcoming: upcoming,
                  now: now,
                ),

              // ── 项目描述（如有）────────────────────────────
              if (project.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                _DailyCard(
                  isDark: isDark,
                  title: '项目简介',
                  icon: Icons.info_outline_rounded,
                  child: Text(
                    project.description,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.7,
                      color: isDark
                          ? Colors.white60
                          : const Color(0xFF666666),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ── 今日动态卡 ────────────────────────────────────────────────────
class _DailyPulseCard extends StatelessWidget {
  final bool isDark;
  final Color projectColor;
  final int todayCompleted;
  final int todayAdded;
  final int overdueCount;
  final int totalPending;

  const _DailyPulseCard({
    required this.isDark,
    required this.projectColor,
    required this.todayCompleted,
    required this.todayAdded,
    required this.overdueCount,
    required this.totalPending,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final weekday = weekdays[now.weekday - 1];
    final dateStr = '${now.month}月${now.day}日 $weekday';

    String greeting;
    if (now.hour < 12) {
      greeting = '早上好 ☀️';
    } else if (now.hour < 18) {
      greeting = '下午好 🌤';
    } else {
      greeting = '晚上好 🌙';
    }

    return _DailyCard(
      isDark: isDark,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white38 : const Color(0xFFAAAAAA),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateStr,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF222222),
                      ),
                    ),
                  ],
                ),
              ),
              // 今日完成大数字
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$todayCompleted',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: projectColor,
                      height: 1,
                    ),
                  ),
                  Text(
                    '今日完成',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : const Color(0xFFAAAAAA),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 小指标行
          Row(
            children: [
              _PulseStat(
                label: '今日新增',
                value: '$todayAdded',
                color: isDark ? Colors.white54 : const Color(0xFF888888),
                isDark: isDark,
              ),
              _PulseDivider(isDark: isDark),
              _PulseStat(
                label: '待完成',
                value: '$totalPending',
                color: isDark ? Colors.white54 : const Color(0xFF888888),
                isDark: isDark,
              ),
              _PulseDivider(isDark: isDark),
              _PulseStat(
                label: '已逾期',
                value: '$overdueCount',
                color: overdueCount > 0
                    ? const Color(0xFFE74C3C)
                    : (isDark ? Colors.white38 : const Color(0xFFCCCCCC)),
                isDark: isDark,
                highlight: overdueCount > 0,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PulseStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDark;
  final bool highlight;

  const _PulseStat({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.white38 : const Color(0xFFBBBBBB),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseDivider extends StatelessWidget {
  final bool isDark;
  const _PulseDivider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      color: isDark
          ? Colors.white.withValues(alpha: 0.07)
          : Colors.black.withValues(alpha: 0.06),
    );
  }
}

// ── 本周趋势迷你图 ────────────────────────────────────────────────
class _WeeklyTrendCard extends StatelessWidget {
  final bool isDark;
  final Color projectColor;
  final List<int> weeklyData;
  final DateTime weekAgo;

  const _WeeklyTrendCard({
    required this.isDark,
    required this.projectColor,
    required this.weeklyData,
    required this.weekAgo,
  });

  @override
  Widget build(BuildContext context) {
    final maxVal = weeklyData.reduce((a, b) => a > b ? a : b);
    final weekLabels = ['一', '二', '三', '四', '五', '六', '日'];
    final todayIndex = DateTime.now().weekday - 1;

    return _DailyCard(
      isDark: isDark,
      title: '本周完成趋势',
      icon: Icons.bar_chart_rounded,
      child: SizedBox(
        height: 72,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(7, (i) {
            final val = weeklyData[i];
            final barRatio = maxVal > 0 ? val / maxVal : 0.0;
            final isToday = i == todayIndex;
            final dayLabel = weekLabels[(weekAgo.add(Duration(days: i)).weekday - 1)];

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // 数量标签（仅非零时显示）
                    if (val > 0)
                      Text(
                        '$val',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: isToday
                              ? projectColor
                              : (isDark ? Colors.white38 : const Color(0xFFBBBBBB)),
                        ),
                      ),
                    const SizedBox(height: 3),
                    // 柱子
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOut,
                      height: barRatio > 0
                          ? (barRatio * 44).clamp(6.0, 44.0)
                          : 4,
                      decoration: BoxDecoration(
                        color: isToday
                            ? projectColor
                            : (val > 0
                                ? projectColor.withValues(alpha: 0.35)
                                : (isDark
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : Colors.black.withValues(alpha: 0.05))),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 5),
                    // 星期标签
                    Text(
                      dayLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight:
                            isToday ? FontWeight.w700 : FontWeight.w400,
                        color: isToday
                            ? projectColor
                            : (isDark
                                ? Colors.white38
                                : const Color(0xFFBBBBBB)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ── 健康度卡（进度 vs 时间消耗）────────────────────────────────────
class _HealthCard extends StatelessWidget {
  final bool isDark;
  final Color projectColor;
  final Project project;
  final double taskProgress;
  final double? timeProgress;

  const _HealthCard({
    required this.isDark,
    required this.projectColor,
    required this.project,
    required this.taskProgress,
    required this.timeProgress,
  });

  String _healthLabel(double task, double? time) {
    if (time == null) return '进行中';
    final diff = task - time;
    if (diff >= 0.1) return '领先 🟢';
    if (diff >= -0.1) return '正常 🟡';
    return '落后 🔴';
  }

  Color _healthColor(double task, double? time) {
    if (time == null) return const Color(0xFF888888);
    final diff = task - time;
    if (diff >= 0.1) return const Color(0xFF27AE60);
    if (diff >= -0.1) return const Color(0xFFE67E22);
    return const Color(0xFFE74C3C);
  }

  @override
  Widget build(BuildContext context) {
    final healthLabel = _healthLabel(taskProgress, timeProgress);
    final healthColor = _healthColor(taskProgress, timeProgress);

    return _DailyCard(
      isDark: isDark,
      title: '项目健康度',
      icon: Icons.monitor_heart_outlined,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: healthColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          healthLabel,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: healthColor,
          ),
        ),
      ),
      child: Column(
        children: [
          // 任务进度
          _ProgressRow(
            label: '任务完成',
            value: taskProgress,
            color: projectColor,
            isDark: isDark,
            valueLabel: '${(taskProgress * 100).round()}%',
            subLabel: '${project.completedTaskCount}/${project.taskCount} 个任务',
          ),
          const SizedBox(height: 12),
          // 时间消耗
          _ProgressRow(
            label: '时间消耗',
            value: timeProgress ?? 0,
            color: timeProgress != null
                ? _healthColor(taskProgress, timeProgress)
                : (isDark ? Colors.white24 : const Color(0xFFDDDDDD)),
            isDark: isDark,
            valueLabel: timeProgress != null
                ? '${(timeProgress! * 100).round()}%'
                : '—',
            subLabel: project.deadline != null
                ? '截止 ${project.deadline!.month}/${project.deadline!.day}'
                : '未设截止日期',
            dimmed: timeProgress == null,
          ),
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final bool isDark;
  final String valueLabel;
  final String subLabel;
  final bool dimmed;

  const _ProgressRow({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
    required this.valueLabel,
    required this.subLabel,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white60 : const Color(0xFF666666),
              ),
            ),
            const Spacer(),
            Text(
              valueLabel,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: dimmed
                    ? (isDark ? Colors.white30 : const Color(0xFFCCCCCC))
                    : color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value,
            backgroundColor: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
            valueColor: AlwaysStoppedAnimation(
              dimmed ? (isDark ? Colors.white12 : const Color(0xFFDDDDDD)) : color,
            ),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subLabel,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? Colors.white30 : const Color(0xFFBBBBBB),
          ),
        ),
      ],
    );
  }
}

// ── 即将到期 / 已逾期卡 ──────────────────────────────────────────
class _DeadlineCard extends StatelessWidget {
  final bool isDark;
  final Color projectColor;
  final List<Record> overdue;
  final List<Record> upcoming;
  final DateTime now;

  const _DeadlineCard({
    required this.isDark,
    required this.projectColor,
    required this.overdue,
    required this.upcoming,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    return _DailyCard(
      isDark: isDark,
      title: '截止日期',
      icon: Icons.schedule_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 逾期
          if (overdue.isNotEmpty) ...[
            _DeadlineSectionLabel(
              label: '已逾期',
              color: const Color(0xFFE74C3C),
              isDark: isDark,
            ),
            const SizedBox(height: 6),
            ...overdue.take(3).map((t) => _DeadlineItem(
                  task: t,
                  now: now,
                  isDark: isDark,
                  isOverdue: true,
                )),
            if (overdue.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '还有 ${overdue.length - 3} 个逾期任务…',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFE74C3C),
                  ),
                ),
              ),
          ],

          // 即将到期
          if (upcoming.isNotEmpty) ...[
            if (overdue.isNotEmpty) const SizedBox(height: 12),
            _DeadlineSectionLabel(
              label: '即将到期（7天内）',
              color: const Color(0xFFE67E22),
              isDark: isDark,
            ),
            const SizedBox(height: 6),
            ...upcoming.take(3).map((t) => _DeadlineItem(
                  task: t,
                  now: now,
                  isDark: isDark,
                  isOverdue: false,
                )),
            if (upcoming.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '还有 ${upcoming.length - 3} 个即将到期…',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : const Color(0xFFBBBBBB),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _DeadlineSectionLabel extends StatelessWidget {
  final String label;
  final Color color;
  final bool isDark;

  const _DeadlineSectionLabel({
    required this.label,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _DeadlineItem extends StatelessWidget {
  final Record task;
  final DateTime now;
  final bool isDark;
  final bool isOverdue;

  const _DeadlineItem({
    required this.task,
    required this.now,
    required this.isDark,
    required this.isOverdue,
  });

  @override
  Widget build(BuildContext context) {
    final deadline = task.deadline!;
    final diff = deadline.difference(now);
    String timeStr;
    if (isOverdue) {
      final days = now.difference(deadline).inDays;
      timeStr = days == 0 ? '今天逾期' : '逾期 $days 天';
    } else {
      final hours = diff.inHours;
      if (hours < 24) {
        timeStr = '还剩 $hours 小时';
      } else {
        timeStr = '还剩 ${diff.inDays} 天';
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            isOverdue ? Icons.error_outline_rounded : Icons.access_time_rounded,
            size: 13,
            color: isOverdue
                ? const Color(0xFFE74C3C)
                : const Color(0xFFE67E22),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              task.title.isEmpty ? task.content : task.title,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : const Color(0xFF444444),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            timeStr,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isOverdue
                  ? const Color(0xFFE74C3C)
                  : const Color(0xFFE67E22),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 通用卡片容器 ──────────────────────────────────────────────────
class _DailyCard extends StatelessWidget {
  final bool isDark;
  final String? title;
  final IconData? icon;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets? padding;

  const _DailyCard({
    required this.isDark,
    this.title,
    this.icon,
    this.trailing,
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: title != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (icon != null) ...[
                      Icon(icon,
                          size: 14,
                          color: isDark
                              ? Colors.white38
                              : const Color(0xFFAAAAAA)),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      title!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.white38
                            : const Color(0xFFAAAAAA),
                        letterSpacing: 0.3,
                      ),
                    ),
                    if (trailing != null) ...[
                      const Spacer(),
                      trailing!,
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                child,
              ],
            )
          : child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  编辑项目底部弹窗
// ─────────────────────────────────────────────────────────────────
class _EditProjectSheet extends StatefulWidget {
  final Project project;
  final bool isDark;
  final DayPalette palette;

  const _EditProjectSheet({
    required this.project,
    required this.isDark,
    required this.palette,
  });

  @override
  State<_EditProjectSheet> createState() => _EditProjectSheetState();
}

class _EditProjectSheetState extends State<_EditProjectSheet> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late String _selectedEmoji;
  late String _selectedColorHex;
  late ProjectPriority _selectedPriority;
  late DateTime? _selectedDeadline;
  late DateTime? _selectedStartDate;
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
    _titleController = TextEditingController(text: widget.project.title);
    _descController = TextEditingController(text: widget.project.description);
    _selectedEmoji = widget.project.emoji;
    _selectedColorHex = widget.project.colorHex;
    _selectedPriority = widget.project.priority;
    _selectedDeadline = widget.project.deadline;
    _selectedStartDate = widget.project.startDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      await context.read<ProjectProvider>().updateProject(
            widget.project.copyWith(
              title: title,
              description: _descController.text.trim(),
              emoji: _selectedEmoji,
              colorHex: _selectedColorHex,
              priority: _selectedPriority,
              deadline: _selectedDeadline,
              startDate: _selectedStartDate,
            ),
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
    final selectedColor = _parseColor(_selectedColorHex);

    return Container(
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92),
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
                    '编辑项目',
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
                    _SheetLabel('图标', isDark),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 48,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _emojiOptions.length,
                        separatorBuilder: (_, _) =>
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
                    _SheetLabel('颜色', isDark),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _colorOptions.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(width: 8),
                        itemBuilder: (ctx, i) {
                          final hex = _colorOptions[i];
                          final color = Color(int.parse(
                              'FF${hex.replaceAll('#', '')}',
                              radix: 16));
                          final isSelected = _selectedColorHex == hex;
                          return GestureDetector(
                            onTap: () => setState(
                                () => _selectedColorHex = hex),
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
                    _SheetLabel('项目名称', isDark),
                    const SizedBox(height: 8),
                    _buildTextField(
                        controller: _titleController,
                        hint: '如：备赛计划',
                        isDark: isDark),
                    const SizedBox(height: 12),
                    _SheetLabel('描述（可选）', isDark),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _descController,
                      hint: '项目背景或目标...',
                      isDark: isDark,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    _SheetLabel('优先级', isDark),
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
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SheetLabel('开始日期', isDark),
                              const SizedBox(height: 8),
                              _DatePickerBtn(
                                date: _selectedStartDate,
                                hint: '选择日期',
                                primaryColor: primaryColor,
                                isDark: isDark,
                                onChanged: (d) => setState(
                                    () => _selectedStartDate = d),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SheetLabel('截止日期', isDark),
                              const SizedBox(height: 8),
                              _DatePickerBtn(
                                date: _selectedDeadline,
                                hint: '选择日期',
                                primaryColor: primaryColor,
                                isDark: isDark,
                                onChanged: (d) => setState(
                                    () => _selectedDeadline = d),
                              ),
                            ],
                          ),
                        ),
                      ],
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
                      : const Text('保存',
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
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
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

// ─── 日期选择按钮 ─────────────────────────────────────────────────
class _DatePickerBtn extends StatelessWidget {
  final DateTime? date;
  final String hint;
  final Color primaryColor;
  final bool isDark;
  final ValueChanged<DateTime?> onChanged;

  const _DatePickerBtn({
    required this.date,
    required this.hint,
    required this.primaryColor,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.event_outlined,
              size: 16,
              color: date != null
                  ? primaryColor
                  : (isDark ? Colors.white38 : const Color(0xFFCCCCCC)),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                date != null ? '${date!.month}/${date!.day}' : hint,
                style: TextStyle(
                  fontSize: 13,
                  color: date != null
                      ? (isDark
                          ? const Color(0xDEFFFFFF)
                          : const Color(0xFF333333))
                      : (isDark
                          ? Colors.white38
                          : const Color(0xFFCCCCCC)),
                ),
              ),
            ),
            if (date != null)
              GestureDetector(
                onTap: () => onChanged(null),
                child: Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: isDark ? Colors.white30 : const Color(0xFFCCCCCC),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── 弹窗标签 ──────────────────────────────────────────────────────
class _SheetLabel extends StatelessWidget {
  final String text;
  final bool isDark;

  const _SheetLabel(this.text, this.isDark);

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

// ─── 工具函数 ─────────────────────────────────────────────────────
Color _parseColor(String hex) {
  try {
    return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
  } catch (_) {
    return const Color(0xFF4A90D9);
  }
}
