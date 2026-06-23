import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/energy_beans.dart';
import '../models/user_profile.dart';
import '../providers/energy_provider.dart';
import '../providers/user_profile_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/cursor_style_provider.dart';
import '../providers/goal_provider.dart';
import '../providers/project_provider.dart';
import '../providers/record_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/energy_beans_widget.dart';
import 'profile_screen.dart';
import 'primitives_preview_screen.dart';

// ─────────────────────────────────────────────────────────────────
//  MeScreen — 「我」Tab
//
//  设计思路：
//  ① 头像 + 昵称 + 身份
//  ② 核心数据三格（主题数 / 条目数 / 累计字数）
//  ③ 功能入口列表（AI 能量豆、个人资料、设置）
//  ④ 深色/浅色切换
// ─────────────────────────────────────────────────────────────────

class MeScreen extends StatelessWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: Consumer4<UserProfileProvider, GoalProvider, ProjectProvider, RecordProvider>(
        builder: (ctx, profileProvider, goalProvider, projectProvider, recordProvider, child) {
          final profile = profileProvider.profile;
          final goalProjectCount = goalProvider.goals.length + projectProvider.projects.length;
          final entries = recordProvider.allRecords;
          final recordCount = entries.length;
          final totalChars =
              entries.fold<int>(0, (sum, e) => sum + e.content.length);

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _Header(
                  profile: profile,
                  isDark: isDark,
                  onTapAvatar: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: _StatsRow(
                  topicCount: goalProjectCount,
                  entryCount: recordCount,
                  totalChars: totalChars,
                  isDark: isDark,
                ),
              ),

              SliverToBoxAdapter(
                child: _MenuSection(
                  isDark: isDark,
                  profile: profile,
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 8),
                  child: Column(
                    children: [
                      AppLogoSmall(
                        size: 40,
                        primaryColor: AppColors.primary,
                        lightColor: AppColors.primaryLight,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '瞬时',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFF444444)
                              : AppColors.primary.withValues(alpha: 0.45),
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 60)),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  头部（头像 + 昵称 + 身份）
// ─────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final UserProfile profile;
  final bool isDark;
  final VoidCallback onTapAvatar;

  const _Header({
    required this.profile,
    required this.isDark,
    required this.onTapAvatar,
  });

  @override
  Widget build(BuildContext context) {
    final name = profile.nickname.isNotEmpty ? profile.nickname : '我的空间';
    final textPrimary =
        isDark ? Colors.white : const Color(0xFF1A1A2E);
    final textSub = isDark
        ? const Color(0xFF666666)
        : const Color(0xFF9B8FBB);

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 头像
            GestureDetector(
              onTap: onTapAvatar,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.primaryLight],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    profile.identityType.emoji,
                    style: const TextStyle(fontSize: 30),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${profile.identityType.emoji} ${profile.identityType.label}',
                    style: TextStyle(
                      fontSize: 13,
                      color: textSub,
                    ),
                  ),
                  if (profile.primaryGoal.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Text('🎯', style: TextStyle(fontSize: 11)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            profile.primaryGoal,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primary
                                  .withValues(alpha: 0.85),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            GestureDetector(
              onTap: onTapAvatar,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF252525)
                      : AppColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.edit_outlined,
                  size: 16,
                  color: AppColors.primary.withValues(alpha: 0.8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  核心数据三格
// ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final int topicCount;
  final int entryCount;  // 实为 recordCount
  final int totalChars;
  final bool isDark;

  const _StatsRow({
    required this.topicCount,
    required this.entryCount,
    required this.totalChars,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF252525)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              _StatCell(
                value: '$topicCount',
                label: '目标项目',
                emoji: '🧭',
                isDark: isDark,
              ),
              _VertDivider(isDark: isDark),
              _StatCell(
                value: '$entryCount',
                label: '记录数',
                emoji: '📝',
                isDark: isDark,
              ),
              _VertDivider(isDark: isDark),
              _StatCell(
                value: _formatCount(totalChars),
                label: '累计字数',
                emoji: '✍️',
                isDark: isDark,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCount(int n) {
    if (n >= 10000) return '${(n / 10000).toStringAsFixed(1)}w';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  final String emoji;
  final bool isDark;

  const _StatCell({
    required this.value,
    required this.label,
    required this.emoji,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark
                  ? const Color(0xFF666666)
                  : const Color(0xFF9B8FBB),
            ),
          ),
        ],
      ),
    );
  }
}

class _VertDivider extends StatelessWidget {
  final bool isDark;
  const _VertDivider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 0.5,
      color: isDark
          ? const Color(0xFF3D3260)
          : const Color(0xFFE8E0F0),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  功能入口菜单
// ─────────────────────────────────────────────────────────────────

class _MenuSection extends StatelessWidget {
  final bool isDark;
  final UserProfile profile;

  const _MenuSection({
    required this.isDark,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF252525) : Colors.white;
    final textPrimary =
        isDark ? Colors.white : const Color(0xFF1A1A2E);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 功能入口卡片
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                // AI 能量豆入口
                Consumer<EnergyProvider>(
                  builder: (ctx, ep, _) => _MenuItem(
                    icon: Icons.bolt_rounded,
                    iconColor: const Color(0xFFFFB300),
                    label: 'AI 能量豆',
                    subtitle: '剩余 ${ep.current} 颗 · 每日补充 $kDailyRewardBeans 颗',
                    isDark: isDark,
                    isFirst: true,
                    trailingWidget: ep.canClaimDailyReward
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primary,
                                  AppColors.primaryLight,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              '可领取',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : null,
                    onTap: () => showEnergyBeansPanel(ctx),
                  ),
                ),
                _Divider(isDark: isDark),
                _MenuItem(
                  icon: Icons.person_outline_rounded,
                  iconColor: const Color(0xFF4DB6AC),
                  label: '个人资料',
                  subtitle: profile.nickname.isNotEmpty
                      ? profile.nickname
                      : '设置昵称与身份',
                  isDark: isDark,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ProfileScreen()),
                  ),
                ),
                _Divider(isDark: isDark),
                _MenuItem(
                  icon: Icons.widgets_outlined,
                  iconColor: AppColors.primary,
                  label: '原语组件预览',
                  subtitle: '10 种认知原语 · UI 形态一览',
                  isDark: isDark,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PrimitivesPreviewScreen()),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 光标风格选择
          Consumer<CursorStyleProvider>(
            builder: (ctx, cursorProvider, _) {
              final curStyle = cursorProvider.style;
              return GestureDetector(
                onTap: () => _showCursorStyleSheet(context),
                child: Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary.withValues(alpha: 0.15),
                                AppColors.primaryLight.withValues(alpha: 0.25),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(
                            child: Text('📝', style: TextStyle(fontSize: 18)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '光标风格',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                ),
                              ),
                              Text(
                                '${curStyle.emoji} ${curStyle.label}·${curStyle.description}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? const Color(0xFF666666)
                                      : const Color(0xFF9B8FBB),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: isDark
                              ? const Color(0xFF444444)
                              : const Color(0xFFCCBBEE),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // 深色模式切换
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Consumer<ThemeProvider>(
              builder: (ctx2, tp, child) => Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF3D3260)
                            : const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isDark
                            ? Icons.dark_mode_rounded
                            : Icons.light_mode_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '深色模式',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    Switch(
                      value: tp.isDarkMode,
                      onChanged: (value) {
                        context.read<ThemeProvider>().toggleTheme();
                      },
                      activeThumbColor: AppColors.primary,
                      activeTrackColor:
                          AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          Center(
            child: Text(
              '「${profile.aiName}」正在陪伴你 ✨',
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? const Color(0xFF444444)
                    : const Color(0xFFAA99CC),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  光标风格选择弹窗
// ─────────────────────────────────────────────────────────────────

void _showCursorStyleSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _CursorStyleSheet(),
  );
}

class _CursorStyleSheet extends StatefulWidget {
  const _CursorStyleSheet();

  @override
  State<_CursorStyleSheet> createState() => _CursorStyleSheetState();
}

class _CursorStyleSheetState extends State<_CursorStyleSheet>
    with SingleTickerProviderStateMixin {
  late CursorStyle _selected;
  late AnimationController _previewCtrl;
  late Animation<double> _previewAnim;

  @override
  void initState() {
    super.initState();
    _selected = context.read<CursorStyleProvider>().style;
    _previewCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
    _previewAnim = CurvedAnimation(parent: _previewCtrl, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _previewCtrl.dispose();
    super.dispose();
  }

  void _select(CursorStyle s) {
    if (_selected == s) return;
    HapticFeedback.selectionClick();
    setState(() => _selected = s);
    _previewCtrl.forward(from: 0);
    context.read<CursorStyleProvider>().setStyle(s);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1830) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final textSub = isDark ? const Color(0xFF666666) : const Color(0xFF9B8FBB);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF3D3260) : const Color(0xFFE8E0F5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Row(
              children: [
                Text('光标风格',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textPrimary)),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF252525) : const Color(0xFFFFF3E0),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close_rounded, size: 16, color: textSub),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Text('选择你在写作时喜欢的光标样式',
                style: TextStyle(fontSize: 13, color: textSub)),
          ),

          AnimatedBuilder(
            animation: _previewAnim,
            builder: (_, child) => Opacity(
              opacity: _previewAnim.value,
              child: Transform.translate(
                offset: Offset(0, 6 * (1 - _previewAnim.value)),
                child: child,
              ),
            ),
            child: _CursorPreviewCard(style: _selected, isDark: isDark),
          ),

          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: CursorStyle.values.map((s) {
                final isSelected = s == _selected;
                return GestureDetector(
                  onTap: () => _select(s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.08)
                          : (isDark ? const Color(0xFF252525) : const Color(0xFFFFF8F0)),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.5)
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(s.emoji, style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.label,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected ? AppColors.primary : textPrimary,
                                  )),
                              Text(s.description,
                                  style: TextStyle(fontSize: 12, color: textSub)),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Container(
                            width: 22, height: 22,
                            decoration: BoxDecoration(
                              color: AppColors.primary, shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
        ],
      ),
    );
  }
}

class _CursorPreviewCard extends StatefulWidget {
  final CursorStyle style;
  final bool isDark;
  const _CursorPreviewCard({required this.style, required this.isDark});

  @override
  State<_CursorPreviewCard> createState() => _CursorPreviewCardState();
}

class _CursorPreviewCardState extends State<_CursorPreviewCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = widget.isDark ? const Color(0xFF252525) : const Color(0xFFFFF8F0);
    final color = AppColors.primary;
    const lineHeight = 16.0 * 1.7;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 60, 0),
              child: Text(
                '今天心情很好...',
                style: TextStyle(
                  fontSize: 16, height: 1.7,
                  color: widget.isDark ? const Color(0xFFCDBFE8) : const Color(0xFF3D3050),
                ),
              ),
            ),
            Positioned(
              left: 20 + 128,
              top: 28,
              child: AnimatedBuilder(
                animation: _anim,
                builder: (context, child) => CustomPaint(
                  size: const Size(20, lineHeight),
                  painter: _PreviewCursorPainter(
                    pulse: _anim.value,
                    color: color,
                    lineHeight: lineHeight,
                    style: widget.style,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewCursorPainter extends CustomPainter {
  final double pulse;
  final Color color;
  final double lineHeight;
  final CursorStyle style;

  const _PreviewCursorPainter({
    required this.pulse,
    required this.color,
    required this.lineHeight,
    required this.style,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final halfH = lineHeight / 2 - 1;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final top = Offset(cx, cy - halfH);
    final bottom = Offset(cx, cy + halfH);

    switch (style) {
      case CursorStyle.inkDrop:
        final glowR = 3.0 + pulse * 4;
        canvas.drawLine(top, bottom,
            Paint()
              ..color = color.withValues(alpha: 0.10 + pulse * 0.18)
              ..strokeWidth = glowR
              ..strokeCap = StrokeCap.round
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowR / 2));
        canvas.drawLine(top, bottom,
            Paint()
              ..color = color.withValues(alpha: 0.75 + pulse * 0.25)
              ..strokeWidth = 2.0
              ..strokeCap = StrokeCap.round);
        canvas.drawCircle(top, 2.5,
            Paint()..color = color.withValues(alpha: 0.75 + pulse * 0.25)..style = PaintingStyle.fill);

      case CursorStyle.neon:
        final outerGlow = 8.0 + pulse * 10;
        canvas.drawLine(top, bottom,
            Paint()
              ..color = color.withValues(alpha: 0.06 + pulse * 0.10)
              ..strokeWidth = outerGlow
              ..strokeCap = StrokeCap.round
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, outerGlow * 0.7));
        final midGlow = 4.0 + pulse * 4;
        canvas.drawLine(top, bottom,
            Paint()
              ..color = color.withValues(alpha: 0.20 + pulse * 0.20)
              ..strokeWidth = midGlow
              ..strokeCap = StrokeCap.round
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, midGlow * 0.4));
        canvas.drawLine(top, bottom,
            Paint()
              ..color = color.withValues(alpha: 0.6 + pulse * 0.4)
              ..strokeWidth = 2.0
              ..strokeCap = StrokeCap.round);
        canvas.drawCircle(top, 2.0 + pulse * 1.5,
            Paint()..color = Colors.white.withValues(alpha: 0.7 + pulse * 0.3)..style = PaintingStyle.fill);

      case CursorStyle.minimal:
        canvas.drawLine(top, bottom,
            Paint()
              ..color = color.withValues(alpha: 0.55 + pulse * 0.20)
              ..strokeWidth = 1.5
              ..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(_PreviewCursorPainter old) => old.pulse != pulse || old.style != style;
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final bool isDark;
  final bool isFirst;
  final VoidCallback onTap;
  final Widget? trailingWidget;

  const _MenuItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.isDark,
    required this.onTap,
    this.isFirst = false,
    this.trailingWidget,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        isDark ? Colors.white : const Color(0xFF1A1A2E);
    final textSub = isDark
        ? const Color(0xFF666666)
        : const Color(0xFF9B8FBB);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            16, isFirst ? 16 : 14, 16, 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: isDark ? 0.15 : 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: textSub,
                      ),
                    ),
                ],
              ),
            ),
            if (trailingWidget != null) ...[
              trailingWidget!,
              const SizedBox(width: 6),
            ],
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: isDark
                  ? const Color(0xFF444444)
                  : const Color(0xFFCCBBEE),
            ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final bool isDark;
  const _Divider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 64),
      height: 0.5,
      color: isDark
          ? const Color(0xFF3D3260)
          : const Color(0xFFEDE8F5),
    );
  }
}
