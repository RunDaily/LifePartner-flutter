import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/goal.dart';
import '../models/project.dart';
import '../providers/goal_provider.dart';
import '../providers/habit_provider.dart';
import '../providers/project_provider.dart';
import '../theme/app_theme.dart';
import 'project_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────
//  GoalDetailScreen —— 目标详情页
//
//  功能：
//  · 查看目标基本信息（emoji、颜色、标题、描述、时间维度、截止日期）
//  · 里程碑管理（添加 / 勾选 / 删除）
//  · 关联项目列表（导航到项目详情）
//  · 手动调整进度 / 自动计算进度切换
//  · 修改状态（进行中 / 暂停 / 完成 / 放弃）
//  · 编辑目标（底部弹窗）
//  · 删除目标（确认弹窗）
// ─────────────────────────────────────────────────────────────────

class GoalDetailScreen extends StatelessWidget {
  final String goalId;

  const GoalDetailScreen({super.key, required this.goalId});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = WeeklyTheme.getLightPalette();
    final primaryColor = isDark ? AppColors.darkPrimary : palette.primary;

    return Consumer<GoalProvider>(
      builder: (ctx, goalProvider, _) {
        final goal = goalProvider.findById(goalId);
        if (goal == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('目标详情')),
            body: const Center(child: Text('目标不存在')),
          );
        }
        final goalColor = _parseColor(goal.colorHex);

        return Scaffold(
          backgroundColor: isDark ? AppColors.backgroundDark : palette.background,
          body: CustomScrollView(
            slivers: [
              _GoalSliverAppBar(
                goal: goal,
                goalColor: goalColor,
                isDark: isDark,
                palette: palette,
                primaryColor: primaryColor,
                onEdit: () => _showEditGoalSheet(context, goal, isDark, palette),
                onDelete: () => _confirmDelete(context, goal, goalProvider),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 进度卡片
                      _ProgressCard(
                        goal: goal,
                        goalColor: goalColor,
                        isDark: isDark,
                        onProgressChanged: (v) =>
                            goalProvider.updateProgress(goalId, v),
                        onToggleAutoProgress: () => goalProvider.updateGoal(
                          goal.copyWith(autoProgress: !goal.autoProgress),
                        ),
                        onStatusChanged: (s) =>
                            goalProvider.updateGoal(goal.copyWith(status: s)),
                      ),
                      const SizedBox(height: 16),
                      // 里程碑
                      _MilestoneSection(
                        goal: goal,
                        goalColor: goalColor,
                        isDark: isDark,
                        onToggle: (mid) =>
                            goalProvider.toggleMilestone(goalId, mid),
                        onAdd: (title) => _addMilestone(context, goal, title, goalProvider),
                        onDelete: (mid) => _deleteMilestone(context, goal, mid, goalProvider),
                      ),
                      const SizedBox(height: 16),
                      // 关联项目
                      _RelatedProjectsSection(
                        goalId: goalId,
                        isDark: isDark,
                        primaryColor: primaryColor,
                      ),
                      const SizedBox(height: 16),
                      // 支撑习惯
                      _RelatedHabitsSection(
                        goalId: goalId,
                        goalColor: goalColor,
                        isDark: isDark,
                      ),
                      // 描述
                      if (goal.description.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _DescriptionCard(goal: goal, isDark: isDark),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── 添加里程碑 ─────────────────────────────────────────────────
  Future<void> _addMilestone(
    BuildContext context,
    Goal goal,
    String title,
    GoalProvider provider,
  ) async {
    final newMilestone = Milestone(
      id: const Uuid().v4(),
      title: title,
    );
    await provider.updateGoal(
      goal.copyWith(milestones: [...goal.milestones, newMilestone]),
    );
  }

  // ── 删除里程碑 ─────────────────────────────────────────────────
  Future<void> _deleteMilestone(
    BuildContext context,
    Goal goal,
    String milestoneId,
    GoalProvider provider,
  ) async {
    await provider.updateGoal(
      goal.copyWith(
        milestones: goal.milestones.where((m) => m.id != milestoneId).toList(),
      ),
    );
  }

  // ── 编辑目标底部弹窗 ───────────────────────────────────────────
  void _showEditGoalSheet(
    BuildContext context,
    Goal goal,
    bool isDark,
    DayPalette palette,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _EditGoalSheet(
        goal: goal,
        isDark: isDark,
        palette: palette,
      ),
    );
  }

  // ── 删除确认 ───────────────────────────────────────────────────
  Future<void> _confirmDelete(
    BuildContext context,
    Goal goal,
    GoalProvider provider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除目标'),
        content: Text('删除「${goal.title}」后，关联项目不会被删除，但关联关系会解除。确认删除？'),
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
      await provider.deleteGoal(goal.id);
      navigator.pop();
    }
  }
}

// ─── Sliver AppBar ────────────────────────────────────────────────
class _GoalSliverAppBar extends StatelessWidget {
  final Goal goal;
  final Color goalColor;
  final bool isDark;
  final DayPalette palette;
  final Color primaryColor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _GoalSliverAppBar({
    required this.goal,
    required this.goalColor,
    required this.isDark,
    required this.palette,
    required this.primaryColor,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
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
              color: isDark ? Colors.white70 : const Color(0xFF666666), size: 20),
          onPressed: onEdit,
        ),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded,
              color: isDark ? Colors.white70 : const Color(0xFF666666), size: 20),
          color: isDark ? AppColors.surfaceDark : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                  Text('删除目标', style: TextStyle(color: Color(0xFFE74C3C))),
                ],
              ),
            ),
          ],
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 52),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: goalColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Center(
                child: Text(goal.emoji,
                    style: const TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                goal.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1A1410),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
                goalColor.withValues(alpha: 0.08),
                goalColor.withValues(alpha: 0.02),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _InfoPill(
                      label: goal.timeframe.label,
                      color: goalColor,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    if (goal.deadline != null)
                      _InfoPill(
                        label: _formatDate(goal.deadline!),
                        color: goal.isOverdue
                            ? const Color(0xFFE74C3C)
                            : goalColor,
                        isDark: isDark,
                        icon: Icons.event_outlined,
                      ),
                    const SizedBox(width: 8),
                    _StatusPill(status: goal.status),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
}

// ─── 进度卡片 ─────────────────────────────────────────────────────
class _ProgressCard extends StatefulWidget {
  final Goal goal;
  final Color goalColor;
  final bool isDark;
  final ValueChanged<int> onProgressChanged;
  final VoidCallback onToggleAutoProgress;
  final ValueChanged<GoalStatus> onStatusChanged;

  const _ProgressCard({
    required this.goal,
    required this.goalColor,
    required this.isDark,
    required this.onProgressChanged,
    required this.onToggleAutoProgress,
    required this.onStatusChanged,
  });

  @override
  State<_ProgressCard> createState() => _ProgressCardState();
}

class _ProgressCardState extends State<_ProgressCard> {
  late double _sliderValue;

  @override
  void initState() {
    super.initState();
    _sliderValue = widget.goal.progress.toDouble();
  }

  @override
  void didUpdateWidget(_ProgressCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.goal.progress != widget.goal.progress) {
      _sliderValue = widget.goal.progress.toDouble();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final color = widget.goalColor;
    final goal = widget.goal;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '进度',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : const Color(0xFF888888),
                ),
              ),
              const Spacer(),
              // 自动/手动切换
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  widget.onToggleAutoProgress();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: goal.autoProgress
                        ? color.withValues(alpha: 0.12)
                        : (isDark
                            ? const Color(0xFF2A2A2A)
                            : const Color(0xFFF5F5F5)),
                    borderRadius: BorderRadius.circular(8),
                    border: goal.autoProgress
                        ? Border.all(
                            color: color.withValues(alpha: 0.4), width: 1)
                        : null,
                  ),
                  child: Text(
                    goal.autoProgress ? '自动计算' : '手动调整',
                    style: TextStyle(
                      fontSize: 11,
                      color: goal.autoProgress
                          ? color
                          : (isDark
                              ? Colors.white38
                              : const Color(0xFF999999)),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                '${_sliderValue.round()}%',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const Spacer(),
              // 状态快速切换
              _StatusDropdown(
                currentStatus: goal.status,
                isDark: isDark,
                onChanged: widget.onStatusChanged,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _sliderValue / 100,
              backgroundColor:
                  isDark ? const Color(0xFF333333) : const Color(0xFFF0F0F0),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 8,
            ),
          ),
          if (!goal.autoProgress) ...[
            const SizedBox(height: 8),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: color,
                thumbColor: color,
                inactiveTrackColor:
                    isDark ? const Color(0xFF333333) : const Color(0xFFF0F0F0),
                overlayColor: color.withValues(alpha: 0.15),
                trackHeight: 4,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 10),
              ),
              child: Slider(
                value: _sliderValue,
                min: 0,
                max: 100,
                divisions: 20,
                onChanged: (v) {
                  setState(() => _sliderValue = v);
                },
                onChangeEnd: (v) {
                  widget.onProgressChanged(v.round());
                },
              ),
            ),
          ],
          if (goal.milestones.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '里程碑 ${goal.milestoneProgress}',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white38 : const Color(0xFFBBBBBB),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── 里程碑区域 ───────────────────────────────────────────────────
class _MilestoneSection extends StatefulWidget {
  final Goal goal;
  final Color goalColor;
  final bool isDark;
  final ValueChanged<String> onToggle;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onDelete;

  const _MilestoneSection({
    required this.goal,
    required this.goalColor,
    required this.isDark,
    required this.onToggle,
    required this.onAdd,
    required this.onDelete,
  });

  @override
  State<_MilestoneSection> createState() => _MilestoneSectionState();
}

class _MilestoneSectionState extends State<_MilestoneSection> {
  final _controller = TextEditingController();
  bool _isAdding = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final color = widget.goalColor;
    final milestones = widget.goal.milestones;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '里程碑',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1A1410),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _isAdding = !_isAdding),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _isAdding ? Icons.close_rounded : Icons.add_rounded,
                    size: 16,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          if (_isAdding) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white : const Color(0xFF1A1410),
                    ),
                    decoration: InputDecoration(
                      hintText: '里程碑名称...',
                      hintStyle: TextStyle(
                        color: isDark
                            ? const Color(0xFF555555)
                            : const Color(0xFFCCCCCC),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF2A2A2A)
                          : const Color(0xFFF5F5F5),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                    onSubmitted: (v) {
                      if (v.trim().isEmpty) return;
                      widget.onAdd(v.trim());
                      _controller.clear();
                      setState(() => _isAdding = false);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    final v = _controller.text.trim();
                    if (v.isEmpty) return;
                    widget.onAdd(v);
                    _controller.clear();
                    setState(() => _isAdding = false);
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.check_rounded,
                        size: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
          if (milestones.isEmpty && !_isAdding) ...[
            const SizedBox(height: 12),
            Center(
              child: Text(
                '暂无里程碑，点击 + 添加',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white30 : const Color(0xFFCCCCCC),
                ),
              ),
            ),
          ] else if (milestones.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...milestones.map((m) => _MilestoneItem(
                  milestone: m,
                  color: color,
                  isDark: isDark,
                  onToggle: () => widget.onToggle(m.id),
                  onDelete: () => widget.onDelete(m.id),
                )),
          ],
        ],
      ),
    );
  }
}

class _MilestoneItem extends StatelessWidget {
  final Milestone milestone;
  final Color color;
  final bool isDark;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _MilestoneItem({
    required this.milestone,
    required this.color,
    required this.isDark,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDone = milestone.isCompleted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onToggle();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isDone ? color : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isDone
                      ? color
                      : (isDark
                          ? const Color(0xFF555555)
                          : const Color(0xFFCCCCCC)),
                  width: 1.5,
                ),
              ),
              child: isDone
                  ? const Icon(Icons.check_rounded,
                      size: 13, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              milestone.title,
              style: TextStyle(
                fontSize: 14,
                color: isDone
                    ? (isDark ? Colors.white38 : const Color(0xFFCCCCCC))
                    : (isDark ? const Color(0xDEFFFFFF) : const Color(0xFF333333)),
                decoration: isDone ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          GestureDetector(
            onTap: onDelete,
            child: Icon(
              Icons.close_rounded,
              size: 16,
              color: isDark ? Colors.white30 : const Color(0xFFCCCCCC),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 关联项目区域 ─────────────────────────────────────────────────
class _RelatedProjectsSection extends StatelessWidget {
  final String goalId;
  final bool isDark;
  final Color primaryColor;

  const _RelatedProjectsSection({
    required this.goalId,
    required this.isDark,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ProjectProvider>(
      builder: (ctx, projectProvider, _) {
        final projects = projectProvider.projectsForGoal(goalId);

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '关联项目',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1A1410),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${projects.length}',
                      style: TextStyle(
                        fontSize: 12,
                        color: primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              if (projects.isEmpty) ...[
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    '暂无关联项目',
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          isDark ? Colors.white30 : const Color(0xFFCCCCCC),
                    ),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 12),
                ...projects.map((p) => _ProjectItem(
                      project: p,
                      isDark: isDark,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ProjectDetailScreen(projectId: p.id),
                        ),
                      ),
                    )),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ProjectItem extends StatelessWidget {
  final Project project;
  final bool isDark;
  final VoidCallback onTap;

  const _ProjectItem({
    required this.project,
    required this.isDark,
    required this.onTap,
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Center(
                child: Text(project.emoji,
                    style: const TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xDEFFFFFF) : const Color(0xFF333333),
                    ),
                  ),
                  if (project.taskCount > 0)
                    Text(
                      '${project.completedTaskCount}/${project.taskCount} 个任务',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? Colors.white38
                            : const Color(0xFFBBBBBB),
                      ),
                    ),
                ],
              ),
            ),
            if (project.taskCount > 0)
              SizedBox(
                width: 36,
                height: 36,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: project.completionRate,
                      strokeWidth: 3,
                      backgroundColor: isDark
                          ? const Color(0xFF333333)
                          : const Color(0xFFEEEEEE),
                      valueColor: AlwaysStoppedAnimation(_color),
                    ),
                    Text(
                      '${(project.completionRate * 100).round()}%',
                      style: TextStyle(
                        fontSize: 8,
                        color: _color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            else
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: isDark ? Colors.white30 : const Color(0xFFCCCCCC)),
          ],
        ),
      ),
    );
  }
}

// ─── 描述卡片 ─────────────────────────────────────────────────────
class _DescriptionCard extends StatelessWidget {
  final Goal goal;
  final bool isDark;

  const _DescriptionCard({required this.goal, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '描述',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : const Color(0xFF888888),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            goal.description,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: isDark ? const Color(0xDEFFFFFF) : const Color(0xFF444444),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 状态下拉 ─────────────────────────────────────────────────────
class _StatusDropdown extends StatelessWidget {
  final GoalStatus currentStatus;
  final bool isDark;
  final ValueChanged<GoalStatus> onChanged;

  const _StatusDropdown({
    required this.currentStatus,
    required this.isDark,
    required this.onChanged,
  });

  Color _statusColor(GoalStatus s) {
    switch (s) {
      case GoalStatus.active:
        return const Color(0xFF27AE60);
      case GoalStatus.paused:
        return const Color(0xFFE67E22);
      case GoalStatus.completed:
        return const Color(0xFF4A90D9);
      case GoalStatus.abandoned:
        return const Color(0xFF95A5A6);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(currentStatus);
    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              currentStatus.label,
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 4),
            Icon(Icons.expand_more_rounded, size: 14, color: color),
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
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
                Text(
                  '更改状态',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1A1410),
                  ),
                ),
                const SizedBox(height: 12),
                ...GoalStatus.values.map((s) => ListTile(
                      leading: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _statusColor(s),
                          shape: BoxShape.circle,
                        ),
                      ),
                      title: Text(
                        s.label,
                        style: TextStyle(
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1A1410),
                          fontWeight: currentStatus == s
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                      trailing: currentStatus == s
                          ? Icon(Icons.check_rounded,
                              color: _statusColor(s))
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        onChanged(s);
                      },
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 编辑目标底部弹窗 ─────────────────────────────────────────────
class _EditGoalSheet extends StatefulWidget {
  final Goal goal;
  final bool isDark;
  final DayPalette palette;

  const _EditGoalSheet({
    required this.goal,
    required this.isDark,
    required this.palette,
  });

  @override
  State<_EditGoalSheet> createState() => _EditGoalSheetState();
}

class _EditGoalSheetState extends State<_EditGoalSheet> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late String _selectedEmoji;
  late String _selectedColorHex;
  late GoalTimeframe _selectedTimeframe;
  late DateTime? _selectedDeadline;
  bool _isSaving = false;

  static const _emojiOptions = [
    '🎯', '🏆', '💪', '🌟', '🚀', '📚', '💰', '❤️',
    '🏃', '🧘', '🎸', '🎨', '✍️', '🌿', '🔬', '💻',
    '🌏', '🏠', '👨‍👩‍👧', '🎓', '⚡', '🦋', '🌸', '🔑',
  ];

  static const _colorOptions = [
    '#E07818', '#4A90D9', '#27AE60', '#9B59B6',
    '#E74C3C', '#E67E22', '#1ABC9C', '#F39C12',
    '#D44470', '#7E5FC0', '#2878CC', '#CC5828',
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.goal.title);
    _descController = TextEditingController(text: widget.goal.description);
    _selectedEmoji = widget.goal.emoji;
    _selectedColorHex = widget.goal.colorHex;
    _selectedTimeframe = widget.goal.timeframe;
    _selectedDeadline = widget.goal.deadline;
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
      await context.read<GoalProvider>().updateGoal(
            widget.goal.copyWith(
              title: title,
              description: _descController.text.trim(),
              emoji: _selectedEmoji,
              colorHex: _selectedColorHex,
              timeframe: _selectedTimeframe,
              deadline: _selectedDeadline,
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
            // 把手
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 标题行
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Row(
                children: [
                  Text(
                    '编辑目标',
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
                    // Emoji
                    _SectionLabel('图标', isDark),
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
                    // 颜色
                    _SectionLabel('颜色', isDark),
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
                                          color: color.withValues(alpha: 0.4),
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
                    // 名称
                    _SectionLabel('目标名称', isDark),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _titleController,
                      hint: '如：今年跑完一个马拉松',
                      isDark: isDark,
                    ),
                    const SizedBox(height: 12),
                    // 描述
                    _SectionLabel('描述（可选）', isDark),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _descController,
                      hint: '为什么要达成这个目标？',
                      isDark: isDark,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    // 时间维度
                    _SectionLabel('时间维度', isDark),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: GoalTimeframe.values.map((tf) {
                        final isSelected = _selectedTimeframe == tf;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedTimeframe = tf),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? primaryColor.withValues(alpha: 0.12)
                                  : (isDark
                                      ? const Color(0xFF2A2A2A)
                                      : const Color(0xFFF5F5F5)),
                              borderRadius: BorderRadius.circular(20),
                              border: isSelected
                                  ? Border.all(
                                      color: primaryColor, width: 1.5)
                                  : null,
                            ),
                            child: Text(
                              tf.label,
                              style: TextStyle(
                                fontSize: 13,
                                color: isSelected
                                    ? primaryColor
                                    : (isDark
                                        ? Colors.white60
                                        : const Color(0xFF666666)),
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    // 截止日期
                    _SectionLabel('截止日期（可选）', isDark),
                    const SizedBox(height: 8),
                    _DeadlinePicker(
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
          color: isDark ? const Color(0xFF555555) : const Color(0xFFCCCCCC),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

// ─── 截止日期选择器 ───────────────────────────────────────────────
class _DeadlinePicker extends StatelessWidget {
  final DateTime? deadline;
  final bool isDark;
  final Color primaryColor;
  final ValueChanged<DateTime?> onChanged;

  const _DeadlinePicker({
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
          initialDate: deadline ?? DateTime.now().add(const Duration(days: 30)),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
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
                      ? (isDark ? const Color(0xDEFFFFFF) : const Color(0xFF333333))
                      : (isDark ? Colors.white38 : const Color(0xFFCCCCCC)),
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

// ─── 支撑习惯区域 ─────────────────────────────────────────────────
class _RelatedHabitsSection extends StatelessWidget {
  final String goalId;
  final Color goalColor;
  final bool isDark;

  const _RelatedHabitsSection({
    required this.goalId,
    required this.goalColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<HabitProvider>(
      builder: (ctx, habitProvider, _) {
        final habits =
            habitProvider.habits.where((h) => h.goalId == goalId).toList();

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '支撑习惯',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1A1410),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: goalColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${habits.length}',
                      style: TextStyle(
                        fontSize: 12,
                        color: goalColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              if (habits.isEmpty) ...[
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    '暂无关联习惯',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white30 : const Color(0xFFCCCCCC),
                    ),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 12),
                ...habits.map((h) {
                  Color hColor;
                  try {
                    hColor = Color(int.parse(
                        'FF${h.colorHex.replaceAll('#', '')}',
                        radix: 16));
                  } catch (_) {
                    hColor = goalColor;
                  }
                  final isChecked = habitProvider.isTodayCheckedIn(h.id);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2A2A2A)
                          : const Color(0xFFF7F7F7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: hColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Center(
                            child: Text(h.emoji,
                                style: const TextStyle(fontSize: 16)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                h.title,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? const Color(0xDEFFFFFF)
                                      : const Color(0xFF333333),
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    h.frequency.label,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? Colors.white38
                                          : const Color(0xFFBBBBBB),
                                    ),
                                  ),
                                  if (h.currentStreak > 0) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      '🔥 ${h.currentStreak}天',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? Colors.white38
                                            : const Color(0xFFBBBBBB),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (isChecked)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: hColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '✓ 已打卡',
                              style: TextStyle(
                                fontSize: 10,
                                color: hColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        else
                          Icon(Icons.radio_button_unchecked_rounded,
                              size: 18,
                              color: isDark
                                  ? Colors.white30
                                  : const Color(0xFFCCCCCC)),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ─── 工具类 ───────────────────────────────────────────────────────
Color _parseColor(String hex) {
  try {
    return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
  } catch (_) {
    return const Color(0xFFE07818);
  }
}

// ─── 信息标签 ─────────────────────────────────────────────────────
class _InfoPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool isDark;
  final IconData? icon;

  const _InfoPill({
    required this.label,
    required this.color,
    required this.isDark,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 状态标签 ─────────────────────────────────────────────────────
class _StatusPill extends StatelessWidget {
  final GoalStatus status;

  const _StatusPill({required this.status});

  Color get _color {
    switch (status) {
      case GoalStatus.active:
        return const Color(0xFF27AE60);
      case GoalStatus.paused:
        return const Color(0xFFE67E22);
      case GoalStatus.completed:
        return const Color(0xFF4A90D9);
      case GoalStatus.abandoned:
        return const Color(0xFF95A5A6);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 11,
          color: _color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

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
