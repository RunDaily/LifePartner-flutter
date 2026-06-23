import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/activity_collection_provider.dart';
import '../providers/record_provider.dart';
import '../providers/checklist_provider.dart';
import '../providers/project_provider.dart';
import '../providers/goal_provider.dart';
import '../theme/app_theme.dart';
import 'journal_screen.dart';
import 'notes_screen.dart';
import 'checklist_screen.dart';
import 'plan_screen.dart';
import 'me_screen.dart';
import 'activity_collection_screen.dart';

// ─────────────────────────────────────────────────────────────────
//  SpaceScreen — 「空间」Tab
//
//  核心模块的汇聚入口，以大图标网格形式展示：
//  ① 📔 日记    —— 日记域：note / idea / mood（→ JournalScreen）
//  ② ☑️ 清单    —— 执行域：Checklist 统一管理（→ ChecklistScreen）
//  ③ 💎 知识库  —— 知识域：collect / reading（→ NotesScreen）
//  ④ 🎯 活动集  —— 活动域：event / habitLog（→ ActivityCollectionScreen）
//  ⑤ 🚀 项目    —— 项目域：Project / Goal（→ PlanScreen）
//  ⑥ ✨ 关于我  —— 用户设置（→ MeScreen）
//
//  【记录体系与域对应关系】
//  每个卡片只统计本域内的数据，不混用其他域的记录。
//  设计哲学：空间是你的「数字生活基地」，大卡片+渐变色，
//            导航本身也是一种美感体验。
// ─────────────────────────────────────────────────────────────────

class SpaceScreen extends StatefulWidget {
  const SpaceScreen({super.key});

  @override
  State<SpaceScreen> createState() => _SpaceScreenState();
}

class _SpaceScreenState extends State<SpaceScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([
      context.read<RecordProvider>().loadAllRecords(),
      context.read<ChecklistProvider>().loadChecklists(),
      context.read<ProjectProvider>().loadProjects(),
      context.read<GoalProvider>().loadGoals(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = WeeklyTheme.getLightPalette();

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: CustomScrollView(
            slivers: [
              _buildHeader(isDark, palette),
              _buildGrid(isDark, palette),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    );
  }

  // ── AppBar 标题区 ─────────────────────────────────────────────
  Widget _buildHeader(bool isDark, DayPalette palette) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Row(
          children: [
            Text(
              '空间',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF1A1410),
              ),
            ),
            const Spacer(),
            // 搜索按钮（预留）
            _HeaderIconBtn(
              icon: Icons.search_rounded,
              isDark: isDark,
              palette: palette,
              onTap: () {
                // TODO: 全局搜索
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── 大卡片网格 ────────────────────────────────────────────────
  Widget _buildGrid(bool isDark, DayPalette palette) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.05,
        ),
        delegate: SliverChildListDelegate([
          // 📔 日记 —— 日记域：note / idea / mood
          _SpaceModuleCard(
            config: _SpaceModuleConfig(
              title: '日记',
              subtitle: '记录每一天',
              emoji: '📔',
              gradientColors: [const Color(0xFFFF9A56), const Color(0xFFFF6B35)],
              darkGradientColors: [
                const Color(0xFF8B4513),
                const Color(0xFF6B3410)
              ],
              statBuilder: (ctx) => Consumer<RecordProvider>(
                builder: (context, rp, child) {
                  // 日记域：note + idea + mood
                  final count = rp.journalRecords.length;
                  return _StatBadge(
                    text: count > 0 ? '$count 天日记' : '开始记录',
                    isDark: isDark,
                  );
                },
              ),
            ),
            isDark: isDark,
            onTap: () => _navigate(context, const JournalScreen()),
          ),

          // 清单
          _SpaceModuleCard(
            config: _SpaceModuleConfig(
              title: '清单',
              subtitle: '井然有序的一切',
              emoji: '☑️',
              gradientColors: [const Color(0xFF56CCF2), const Color(0xFF2F80ED)],
              darkGradientColors: [
                const Color(0xFF1A4A6B),
                const Color(0xFF0D2E4A)
              ],
              statBuilder: (ctx) => Consumer<ChecklistProvider>(
                builder: (context, cp, child) {
                  final count = cp.checklists.length;
                  return _StatBadge(
                    text: count > 0 ? '$count 个清单' : '新建清单',
                    isDark: isDark,
                  );
                },
              ),
            ),
            isDark: isDark,
            onTap: () => _navigate(context, const ChecklistScreen()),
          ),

          // 💎 知识库 —— 知识域：collect / reading
          _SpaceModuleCard(
            config: _SpaceModuleConfig(
              title: '知识库',
              subtitle: '收藏 · 阅读',
              emoji: '💎',
              gradientColors: [const Color(0xFFA18CD1), const Color(0xFFFBC2EB)],
              darkGradientColors: [
                const Color(0xFF4A2D6B),
                const Color(0xFF2D1A45)
              ],
              statBuilder: (ctx) => Consumer<RecordProvider>(
                builder: (context, rp, child) {
                  // 知识域：collect + reading
                  final count = rp.knowledgeRecords.length;
                  return _StatBadge(
                    text: count > 0 ? '$count 条内容' : '开始沉淀',
                    isDark: isDark,
                  );
                },
              ),
            ),
            isDark: isDark,
            onTap: () => _navigate(context, const NotesScreen()),
          ),

          // 🎯 活动集 —— 活动域：event / habitLog
          _SpaceModuleCard(
            config: _SpaceModuleConfig(
              title: '活动集',
              subtitle: '活动记录 · 习惯打卡',
              emoji: '🎯',
              gradientColors: [const Color(0xFF43E97B), const Color(0xFF38F9D7)],
              darkGradientColors: [
                const Color(0xFF0D4A2D),
                const Color(0xFF083520)
              ],
              statBuilder: (ctx) =>
                  Consumer2<ActivityCollectionProvider, RecordProvider>(
                builder: (context, acp, rp, child) {
                  final activityKinds = acp.activities.length;
                  // 活动域：event + habitLog 记录总数
                  final logCount = rp.activityRecords.length;
                  return _StatBadge(
                    text: activityKinds > 0
                        ? '$activityKinds 种活动 · $logCount 次'
                        : '设置活动集',
                    isDark: isDark,
                  );
                },
              ),
            ),
            isDark: isDark,
            onTap: () => _navigate(context, const ActivityCollectionScreen()),
          ),

          // 项目
          _SpaceModuleCard(
            config: _SpaceModuleConfig(
              title: '项目',
              subtitle: '目标与长期计划',
              emoji: '🚀',
              gradientColors: [const Color(0xFFF093FB), const Color(0xFFF5576C)],
              darkGradientColors: [
                const Color(0xFF6B0A4A),
                const Color(0xFF45052E)
              ],
              statBuilder: (ctx) => Consumer2<ProjectProvider, GoalProvider>(
                builder: (context, pp, gp, child) {
                  final count = pp.projects.length + gp.goals.length;
                  return _StatBadge(
                    text: count > 0 ? '$count 个项目' : '制定计划',
                    isDark: isDark,
                  );
                },
              ),
            ),
            isDark: isDark,
            onTap: () => _navigate(context, const PlanScreen()),
          ),

          // 关于我
          _SpaceModuleCard(
            config: _SpaceModuleConfig(
              title: '关于我',
              subtitle: '个人资料与偏好设置',
              emoji: '✨',
              gradientColors: [const Color(0xFFFFD89B), const Color(0xFF19547B)],
              darkGradientColors: [
                const Color(0xFF3D2B00),
                const Color(0xFF0D2233)
              ],
              statBuilder: (ctx) => const _StatBadge(
                text: '设置 · 统计 · 主题',
                isDark: false,
                opacity: 0.7,
              ),
            ),
            isDark: isDark,
            onTap: () => _navigate(context, const MeScreen()),
          ),
        ]),
      ),
    );
  }

  void _navigate(BuildContext context, Widget screen) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      _FadeSlideRoute(builder: (_) => screen),
    );
  }

  // _navigateToNotes 已改为直接在 onTap 中调用 _navigate(context, const NotesScreen())
}

// ─────────────────────────────────────────────────────────────────
//  模块配置数据
// ─────────────────────────────────────────────────────────────────

class _SpaceModuleConfig {
  final String title;
  final String subtitle;
  final String emoji;
  final List<Color> gradientColors;
  final List<Color> darkGradientColors;
  final Widget Function(BuildContext ctx)? statBuilder;

  const _SpaceModuleConfig({
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.gradientColors,
    required this.darkGradientColors,
    this.statBuilder,
  });
}

// ─────────────────────────────────────────────────────────────────
//  大卡片组件
// ─────────────────────────────────────────────────────────────────

class _SpaceModuleCard extends StatefulWidget {
  final _SpaceModuleConfig config;
  final bool isDark;
  final VoidCallback onTap;

  const _SpaceModuleCard({
    required this.config,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_SpaceModuleCard> createState() => _SpaceModuleCardState();
}

class _SpaceModuleCardState extends State<_SpaceModuleCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
      lowerBound: 0.95,
      upperBound: 1.0,
      value: 1.0,
    );
    _scaleAnimation = _pressController;
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _onTapDown(_) => _pressController.animateTo(0.95);
  void _onTapUp(_) {
    _pressController.animateTo(1.0);
    widget.onTap();
  }

  void _onTapCancel() => _pressController.animateTo(1.0);

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final isDark = widget.isDark;
    final gradients =
        isDark ? config.darkGradientColors : config.gradientColors;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (ctx, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradients,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: gradients.first.withValues(alpha: isDark ? 0.15 : 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 顶部行：Emoji
                Text(
                  config.emoji,
                  style: const TextStyle(fontSize: 32),
                ),
                const Spacer(),
                // 标题
                Text(
                  config.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                // 副标题
                Text(
                  config.subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                // 统计信息
                if (config.statBuilder != null)
                  config.statBuilder!(context),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  统计徽章
// ─────────────────────────────────────────────────────────────────

class _StatBadge extends StatelessWidget {
  final String text;
  final bool isDark;
  final double opacity;

  const _StatBadge({
    required this.text,
    required this.isDark,
    this.opacity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: Colors.white.withValues(alpha: opacity),
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Header 图标按钮
// ─────────────────────────────────────────────────────────────────

class _HeaderIconBtn extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final DayPalette palette;
  final VoidCallback onTap;

  const _HeaderIconBtn({
    required this.icon,
    required this.isDark,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : palette.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isDark ? Colors.white54 : palette.primary,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  自定义页面路由：淡入 + 轻微上移
// ─────────────────────────────────────────────────────────────────

class _FadeSlideRoute<T> extends PageRoute<T> {
  final WidgetBuilder builder;

  _FadeSlideRoute({required this.builder});

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 280);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    return builder(context);
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    final fadeAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOut,
    );
    final slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: Curves.easeOut,
    ));

    return FadeTransition(
      opacity: fadeAnimation,
      child: SlideTransition(
        position: slideAnimation,
        child: child,
      ),
    );
  }
}
