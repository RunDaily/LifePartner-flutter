import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/checklist.dart';
import '../models/user_profile.dart';
import '../providers/checklist_provider.dart';
import '../providers/user_profile_provider.dart';
import '../services/ai_service.dart';
import '../theme/app_theme.dart';
import 'checklist_detail_screen.dart';
import 'checklist_discover_screen.dart';
import 'checklist_filter_screen.dart';

// ─────────────────────────────────────────────────────────────────
//  ChecklistScreen —— 清单模块主页（v4 新用户引导 + 重构老用户布局）
//
//  【两种形态】
//  A. 新用户（首次进入）：_OnboardingView —— 沉浸式引导，介绍三大能力
//  B. 老用户（有数据）  ：_MainChecklistView —— 重构布局
//
//  【老用户布局结构】
//
//  ┌─────────────────────────────────────────────────────┐
//  │  清单           [🔍] [+]                            │  紧凑 AppBar
//  ├─────────────────────────────────────────────────────┤
//  │ [全部] [工作] [旅行] [健康] ··· →                   │  常驻标签筛选栏
//  ├─────────────────────────────────────────────────────┤
//  │  📅 今日待办                      ∙ 3项待完成        │  今日区标题
//  │  ┌──────────────────────────────────────────────┐  │
//  │  │ ○ 清单A（可直接勾选完成）            今天 →  │  │  今日清单行
//  │  │ ○ 清单B（逾期 · 昨天）               昨天 →  │  │
//  │  └──────────────────────────────────────────────┘  │
//  ├─────────────────────────────────────────────────────┤
//  │  📂 清单库                      [+ 新建]            │  库区标题
//  │  ┌───────────┐  ┌───────────┐                      │
//  │  │  emoji    │  │  emoji    │  ← 正方形两列网格    │
//  │  │  标题      │  │  标题      │                      │
//  │  │  3/5 ●●   │  │  0/3 ─   │                      │
//  │  └───────────┘  └───────────┘                      │
//  ├─────────────────────────────────────────────────────┤
//  │  [🗂️ 模板库  浏览 50+ 模板]  [✨ AI 生成  智能创建] │  底部双入口
//  └─────────────────────────────────────────────────────┘
// ─────────────────────────────────────────────────────────────────

const _kOnboardingShownKey = 'checklist_onboarding_shown_v1';

class ChecklistScreen extends StatefulWidget {
  const ChecklistScreen({super.key});

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  // null = 正在加载偏好设置，true = 首次，false = 已引导过
  bool? _isFirstTime;

  @override
  void initState() {
    super.initState();
    _checkFirstTime();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChecklistProvider>().loadChecklists();
    });
  }

  Future<void> _checkFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getBool(_kOnboardingShownKey) ?? false;
    if (mounted) {
      setState(() => _isFirstTime = !shown);
    }
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingShownKey, true);
    if (mounted) {
      setState(() => _isFirstTime = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = WeeklyTheme.getLightPalette();
    final primary = isDark ? AppColors.darkPrimary : palette.primary;
    final bg = isDark ? AppColors.backgroundDark : palette.background;

    // 等待偏好设置加载
    if (_isFirstTime == null) {
      return Scaffold(
        backgroundColor: bg,
        body: Center(child: CircularProgressIndicator(color: primary, strokeWidth: 2)),
      );
    }

    // 新用户：显示引导页
    if (_isFirstTime!) {
      return _OnboardingView(
        primary: primary,
        isDark: isDark,
        bg: bg,
        onComplete: _completeOnboarding,
        onSkip: _completeOnboarding,
      );
    }

    // 老用户：显示重构后的主页
    return _MainChecklistView(
      primary: primary,
      isDark: isDark,
      bg: bg,
      onOpenCreate: ({ChecklistType? type}) => _openCreate(context, type: type),
      onOpenDetail: (c) => _openDetail(context, c),
      onShowContextMenu: (c) => _showContextMenu(context, c, isDark),
      onConfirmDelete: (c) => _confirmDelete(context, c),
    );
  }

  void _openCreate(BuildContext context, {ChecklistType? type}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateChecklistSheet(initialType: type),
    );
  }

  void _openDetail(BuildContext context, Checklist checklist) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChecklistDetailScreen(checklistId: checklist.id),
      ),
    );
  }

  void _showContextMenu(
      BuildContext context, Checklist checklist, bool isDark) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ContextMenu(
        checklist: checklist,
        isDark: isDark,
        onEdit: () {
          Navigator.pop(context);
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => _CreateChecklistSheet(editing: checklist),
          );
        },
        onArchive: () {
          Navigator.pop(context);
          context.read<ChecklistProvider>().archiveChecklist(checklist.id);
        },
        onDelete: () {
          Navigator.pop(context);
          _confirmDelete(context, checklist);
        },
        onTogglePin: () {
          Navigator.pop(context);
          context.read<ChecklistProvider>().togglePin(checklist.id);
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, Checklist checklist) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('删除清单', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('确定删除「${checklist.title}」？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<ChecklistProvider>().deleteChecklist(checklist.id);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  新用户引导页 —— _OnboardingView
//  分三步展示：① 今日待办 ② 结构清单 ③ AI 生成
//  每步：大 emoji + 标题 + 副标题 + 示例截图（用简洁 Widget 模拟）
//  底部：步骤点 + 继续/完成按钮 + 右上角跳过
// ─────────────────────────────────────────────────────────────────

class _OnboardingView extends StatefulWidget {
  final Color primary;
  final bool isDark;
  final Color bg;
  final VoidCallback onComplete;
  final VoidCallback onSkip;

  const _OnboardingView({
    required this.primary,
    required this.isDark,
    required this.bg,
    required this.onComplete,
    required this.onSkip,
  });

  @override
  State<_OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<_OnboardingView>
    with SingleTickerProviderStateMixin {
  final _pageCtrl = PageController();
  int _currentPage = 0;

  // 画像页：用户已选中的标签 value 集合
  final Set<String> _selectedTagValues = {};

  static const _pages = [
    _OnboardingPage(
      emoji: '📅',
      title: '今日待办，一目了然',
      subtitle: '把今天要做的事都放进来\n直接在首页勾选完成，清爽高效',
      demoType: _DemoType.today,
      accentHex: '#339AF0',
    ),
    _OnboardingPage(
      emoji: '📂',
      title: '结构清单，长期复用',
      subtitle: '旅行打包清单、工作 SOP、购物清单\n创建一次，反复使用',
      demoType: _DemoType.structural,
      accentHex: '#20C997',
    ),
    _OnboardingPage(
      emoji: '✨',
      title: 'AI 帮你生成清单',
      subtitle: '告诉 AI 你想做什么\n几秒内帮你整理好完整清单',
      demoType: _DemoType.ai,
      accentHex: '#9775FA',
    ),
  ];

  // 总页数 = 功能介绍页 + 1 张画像选择页
  int get _totalPages => _pages.length + 1;
  bool get _isPortraitPage => _currentPage == _pages.length;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  Future<void> _finishOnboarding() async {
    // 保存已选的生活方式标签
    if (_selectedTagValues.isNotEmpty) {
      await context.read<UserProfileProvider>().updateLifestyleTags(
            _selectedTagValues.toList(),
          );
    }
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final primary = widget.primary;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1A1410);
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : const Color(0xFF777777);

    return Scaffold(
      backgroundColor: widget.bg,
      body: SafeArea(
        child: Column(
          children: [
            // 顶部跳过按钮
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 20, 0),
                child: GestureDetector(
                  onTap: widget.onSkip,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '跳过',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 主内容 PageView
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _totalPages,
                itemBuilder: (ctx, i) {
                  // 最后一页：画像标签选择页
                  if (i == _pages.length) {
                    return _PortraitTagPage(
                      selectedValues: _selectedTagValues,
                      primary: primary,
                      isDark: isDark,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      onToggleTag: (value) {
                        setState(() {
                          if (_selectedTagValues.contains(value)) {
                            _selectedTagValues.remove(value);
                          } else {
                            _selectedTagValues.add(value);
                          }
                        });
                      },
                    );
                  }
                  // 前3页：功能介绍页
                  final page = _pages[i];
                  Color accentColor;
                  try {
                    accentColor = Color(int.parse(
                        'FF${page.accentHex.replaceAll('#', '')}',
                        radix: 16));
                  } catch (_) {
                    accentColor = primary;
                  }
                  return _OnboardingPageView(
                    page: page,
                    accentColor: accentColor,
                    isDark: isDark,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  );
                },
              ),
            ),

            // 底部导航区
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                children: [
                  // 步骤点
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_totalPages, (i) {
                      final isActive = i == _currentPage;
                      // 画像页用紫色主题色
                      final dotColor = i == _pages.length
                          ? const Color(0xFF9775FA)
                          : (() {
                              try {
                                return Color(int.parse(
                                    'FF${_pages[i].accentHex.replaceAll('#', '')}',
                                    radix: 16));
                              } catch (_) {
                                return primary;
                              }
                            })();
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive
                              ? dotColor
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.2)
                                  : Colors.black.withValues(alpha: 0.15)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  // 继续/完成按钮
                  GestureDetector(
                    onTap: _nextPage,
                    child: Container(
                      width: double.infinity,
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _isPortraitPage
                              ? [const Color(0xFF9775FA), const Color(0xFF7048E8)]
                              : [primary, primary.withValues(alpha: 0.82)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: (_isPortraitPage
                                    ? const Color(0xFF9775FA)
                                    : primary)
                                .withValues(alpha: 0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _isPortraitPage
                              ? (_selectedTagValues.isEmpty
                                  ? '跳过，直接开始 →'
                                  : '完成，开始使用 ✨')
                              : (_currentPage == _pages.length - 1
                                  ? '下一步'
                                  : '继续'),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Onboarding 第4页：生活方式标签选择（画像收集）
//
//  设计原则：
//  - 正向标签，用户看到后有认同感（「对，这就是我」）
//  - 分组展示，不超过4组，每组标签一目了然
//  - 多选，选0个也可以跳过
//  - 选中有动效，有即时视觉反馈
// ─────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────
//  Onboarding 第4页：人物原型选择（第一层10个大标签）
//
//  设计：
//  - 展示 PersonaArchetype 10个大标签
//  - 每个标签是一张小卡片（emoji + 标签名）
//  - 两列网格，触感清晰，30秒选完
//  - 多选，选0个可跳过
// ─────────────────────────────────────────────────────────────────
class _PortraitTagPage extends StatelessWidget {
  final Set<String> selectedValues;
  final ValueChanged<String> onToggleTag;
  final Color primary;
  final bool isDark;
  final Color textPrimary;
  final Color textSecondary;

  const _PortraitTagPage({
    required this.selectedValues,
    required this.onToggleTag,
    required this.primary,
    required this.isDark,
    required this.textPrimary,
    required this.textSecondary,
  });

  static const Color _accentPurple = Color(0xFF9775FA);

  @override
  Widget build(BuildContext context) {
    final archetypes = PersonaArchetype.values;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 标题区 ──────────────────────────────────────────
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _accentPurple.withValues(alpha: isDark ? 0.18 : 0.1),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('🙋', style: TextStyle(fontSize: 30)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '你最像哪种人？',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: textPrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'AI 会根据你的身份推荐最合适的清单\n可以多选，之后随时可以修改',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.6,
              color: textSecondary,
            ),
          ),
          if (selectedValues.isNotEmpty) ...[
            const SizedBox(height: 10),
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: _accentPurple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '已选 ${selectedValues.length} 个',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _accentPurple,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),

          // ── 人物原型网格（2列）──────────────────────────────
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.6,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: archetypes.length,
            itemBuilder: (_, i) {
              final p = archetypes[i];
              final isSelected = selectedValues.contains(p.value);
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onToggleTag(p.value);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _accentPurple
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.07)
                            : Colors.white),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? _accentPurple
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.black.withValues(alpha: 0.08)),
                      width: isSelected ? 0 : 0.8,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color:
                                  _accentPurple.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : [],
                  ),
                  child: Row(
                    children: [
                      Text(p.emoji,
                          style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          p.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : (isDark
                                    ? Colors.white.withValues(alpha: 0.85)
                                    : const Color(0xFF333333)),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_rounded,
                            size: 14, color: Colors.white),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

enum _DemoType { today, structural, ai }

class _OnboardingPage {
  final String emoji;
  final String title;
  final String subtitle;
  final _DemoType demoType;
  final String accentHex;

  const _OnboardingPage({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.demoType,
    required this.accentHex,
  });
}

class _OnboardingPageView extends StatelessWidget {
  final _OnboardingPage page;
  final Color accentColor;
  final bool isDark;
  final Color textPrimary;
  final Color textSecondary;

  const _OnboardingPageView({
    required this.page,
    required this.accentColor,
    required this.isDark,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // 大 emoji 徽章
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: isDark ? 0.15 : 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(page.emoji,
                  style: const TextStyle(fontSize: 46)),
            ),
          ),
          const SizedBox(height: 24),
          // 标题
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: textPrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          // 副标题
          Text(
            page.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.65,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 36),
          // Demo 示意图
          Expanded(
            child: _OnboardingDemo(
              demoType: page.demoType,
              accentColor: accentColor,
              isDark: isDark,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// 每页的示意 Widget（模拟 UI 截图，轻量实现）
class _OnboardingDemo extends StatelessWidget {
  final _DemoType demoType;
  final Color accentColor;
  final bool isDark;

  const _OnboardingDemo({
    required this.demoType,
    required this.accentColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.surfaceDark : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    switch (demoType) {
      case _DemoType.today:
        return _buildTodayDemo(cardBg, borderColor);
      case _DemoType.structural:
        return _buildStructuralDemo(cardBg, borderColor);
      case _DemoType.ai:
        return _buildAiDemo(cardBg, borderColor);
    }
  }

  Widget _buildTodayDemo(Color cardBg, Color borderColor) {
    final items = [
      ('📝 完成周报', false),
      ('☕ 买咖啡', true),
      ('📞 给客户打电话', false),
    ];
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(child: Text('📅', style: TextStyle(fontSize: 16))),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '今日工作安排',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1A1410),
                    ),
                  ),
                  Text(
                    '今天 · 2/3 完成',
                    style: TextStyle(
                      fontSize: 11,
                      color: accentColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map((item) {
            final done = item.$2;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done
                          ? accentColor
                          : Colors.transparent,
                      border: done
                          ? null
                          : Border.all(
                              color: isDark
                                  ? Colors.white30
                                  : const Color(0xFFCCCCCC),
                              width: 1.5,
                            ),
                    ),
                    child: done
                        ? const Icon(Icons.check_rounded,
                            size: 12, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    item.$1,
                    style: TextStyle(
                      fontSize: 13,
                      color: done
                          ? (isDark
                              ? Colors.white30
                              : const Color(0xFFBBBBBB))
                          : (isDark ? Colors.white70 : const Color(0xFF444444)),
                      decoration: done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStructuralDemo(Color cardBg, Color borderColor) {
    final cards = [
      ('🧳', '旅行打包', '24项', const Color(0xFF339AF0)),
      ('💼', '工作 SOP', '8项', const Color(0xFF20C997)),
      ('🛒', '购物清单', '12项', const Color(0xFFFAB005)),
      ('🏠', '家居整理', '6项', const Color(0xFFCC5DE8)),
    ];
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.1,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: cards.map((c) {
        return Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.04),
                blurRadius: 8,
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: c.$4.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                    child: Text(c.$1,
                        style: const TextStyle(fontSize: 18))),
              ),
              const Spacer(),
              Text(
                c.$2,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1A1410),
                ),
              ),
              Text(
                c.$3,
                style: TextStyle(
                  fontSize: 11,
                  color: c.$4,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAiDemo(Color cardBg, Color borderColor) {
    final demoItems = ['带护照和签证', '打印酒店预订单', '换外汇', '下载离线地图', '准备旅行保险'];
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 输入框模拟
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: accentColor.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Text('✨',
                    style: TextStyle(
                        fontSize: 14, color: accentColor)),
                const SizedBox(width: 8),
                Text(
                  '"帮我生成一份出境旅行清单"',
                  style: TextStyle(
                    fontSize: 12,
                    color: accentColor,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // AI 生成的事项
          ...demoItems.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark
                            ? Colors.white70
                            : const Color(0xFF444444),
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.auto_awesome_rounded,
                        size: 11, color: accentColor.withValues(alpha: 0.5)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  老用户主页 —— _MainChecklistView（v5 拟物桌面版）
//
//  【整体设计】
//  进入清单模块后看到一张「木质桌面」，用户正在使用的清单
//  像真实纸张一样随机旋转堆叠在桌面上。
//  点击某张清单卡片 → 进入 PageView 分页器浏览所有清单内容。
//
//  【布局结构】
//  ┌────────────────────────────────────────────┐
//  │  清单                              [+]      │  顶部 AppBar
//  ├────────────────────────────────────────────┤
//  │                                            │
//  │   🪵  木质桌面纹理背景                      │
//  │                                            │
//  │  ╔══════╗                                  │
//  │╔══════╗ ║  ← 清单卡片像纸张堆叠            │
//  │║ 📋   ║ ║    随机旋转 ±6°                  │
//  │║ 旅行  ║ ╝    多层投影营造厚度感            │
//  │║ 打包  ║                                   │
//  │╚══════╝  ╔══════╗                          │
//  │          ║ 💼   ║                          │
//  │          ║ 工作  ║                          │
//  │          ╚══════╝                          │
//  │                                            │
//  ├────────────────────────────────────────────┤
//  │  [🗂️ 模板库]          [✨ AI 生成]          │  底部工具栏
//  └────────────────────────────────────────────┘
// ─────────────────────────────────────────────────────────────────

class _MainChecklistView extends StatefulWidget {
  final Color primary;
  final bool isDark;
  final Color bg;
  final void Function({ChecklistType? type}) onOpenCreate;
  final ValueChanged<Checklist> onOpenDetail;
  final ValueChanged<Checklist> onShowContextMenu;
  final ValueChanged<Checklist> onConfirmDelete;

  const _MainChecklistView({
    required this.primary,
    required this.isDark,
    required this.bg,
    required this.onOpenCreate,
    required this.onOpenDetail,
    required this.onShowContextMenu,
    required this.onConfirmDelete,
  });

  @override
  State<_MainChecklistView> createState() => _MainChecklistViewState();
}

class _MainChecklistViewState extends State<_MainChecklistView> {
  static const double _kBottomBarHeight = 98.0; // 搜索行(44) + gap(8) + 胶囊行(28) + 上下padding(18)

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final primary = widget.primary;
    final bg = widget.bg;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF141414) : const Color(0xFFF5EFE6),
      body: Consumer<ChecklistProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return Center(
              child: CircularProgressIndicator(color: primary, strokeWidth: 2),
            );
          }

          // 所有「正在使用」的结构型清单（active 状态）
          final structural = List<Checklist>.from(
            provider.structuralChecklists
                .where((c) => c.status == ChecklistStatus.active),
          )..sort((a, b) {
              if (a.isPinned && !b.isPinned) return -1;
              if (!a.isPinned && b.isPinned) return 1;
              return b.updatedAt.compareTo(a.updatedAt);
            });

          // 今日 + 逾期（时态清单）
          final todayList = [
            ...provider.overdueChecklists,
            ...provider.todayChecklists,
            ...provider.undatedTemporalChecklists,
          ];

          // 所有清单合并：今日 + 结构型（供 PageView 使用）
          final allForPager = [...todayList, ...structural];

          final hasAnything = allForPager.isNotEmpty;

          if (!hasAnything) {
            return _buildEmptyState(context, primary, isDark, bottomPadding, bg);
          }

          return Stack(
            children: [
              // ── 主内容 ─────────────────────────────────────────
              CustomScrollView(
                slivers: [
                  // ── AppBar ─────────────────────────────────────
                  _buildAppBar(context, primary, isDark, bg),

                  // ── 桌面主体区域 ───────────────────────────────
                  SliverToBoxAdapter(
                    child: _DeskView(
                      checklists: structural,
                      todayList: todayList,
                      primary: primary,
                      isDark: isDark,
                      allForPager: allForPager,
                      onOpenCreate: widget.onOpenCreate,
                      onOpenDetail: widget.onOpenDetail,
                      onShowContextMenu: widget.onShowContextMenu,
                    ),
                  ),

                  // ── 底部工具栏 ─────────────────────────────────
                  SliverToBoxAdapter(
                    child: _BottomToolBar(primary: primary, isDark: isDark),
                  ),

                  SliverToBoxAdapter(
                    child: SizedBox(height: _kBottomBarHeight + bottomPadding + 16),
                  ),
                ],
              ),

              // ── 底部固定搜索卡片 ────────────────────────────────
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _BottomSearchBar(
                  primary: primary,
                  isDark: isDark,
                  onSearch: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ChecklistDiscoverScreen(),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  SliverAppBar _buildAppBar(
      BuildContext context, Color primary, bool isDark, Color bg) {
    return SliverAppBar(
      floating: true,
      pinned: true,
      snap: false,
      backgroundColor: isDark ? const Color(0xFF141414) : const Color(0xFFF5EFE6),
      elevation: 0,
      toolbarHeight: 60,
      titleSpacing: 0,
      automaticallyImplyLeading: false,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '清单',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF3D2B1A),
              ),
            ),
            const Spacer(),
            // 新建按钮
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onOpenCreate(type: ChecklistType.structural);
              },
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.add_rounded, size: 21, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, Color primary, bool isDark,
      double bottomPadding, Color bg) {
    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            _buildAppBar(context, primary, isDark, bg),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: EdgeInsets.only(bottom: 72 + bottomPadding + 16),
                child: _EmptyHomeState(
                  primary: primary,
                  isDark: isDark,
                  onCreateTemporal: () =>
                      widget.onOpenCreate(type: ChecklistType.temporal),
                  onCreateStructural: () =>
                      widget.onOpenCreate(type: ChecklistType.structural),
                ),
              ),
            ),
          ],
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _BottomSearchBar(
            primary: primary,
            isDark: isDark,
            onSearch: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChecklistDiscoverScreen()),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  拟物桌面视图 —— _DeskView（v2 托盘叠放版）
//
//  核心概念：所有结构型清单像一叠真实纸张/便签，
//  整齐叠放在一个深色木质托盘里。
//
//  【视觉层次】
//  ┌─────────────────────────────────────────────────────────┐
//  │  🪣 托盘（深色，带内阴影和边框，营造容器感）              │
//  │                                                         │
//  │    ╔══════════════════════════════╗  ← 最上层（最新）   │
//  │   ╔══════════════════════════════╗║ ← 第2张露出右下边缘 │
//  │  ╔══════════════════════════════╗║║ ← 第3张              │
//  │  ║  📋  旅行打包清单            ║║║                      │
//  │  ║  ████████░░░░  3/8 完成      ║║╝                      │
//  │  ║  「轻触查看全部清单」         ║╝                       │
//  │  ╚══════════════════════════════╝                        │
//  │                                                         │
//  └─────────────────────────────────────────────────────────┘
//
//  点击叠放的纸张 → 进入 PageView 分页器浏览每张清单
// ─────────────────────────────────────────────────────────────────

class _DeskView extends StatefulWidget {
  final List<Checklist> checklists;
  final List<Checklist> todayList;
  final List<Checklist> allForPager;
  final Color primary;
  final bool isDark;
  final void Function({ChecklistType? type}) onOpenCreate;
  final ValueChanged<Checklist> onOpenDetail;
  final ValueChanged<Checklist> onShowContextMenu;

  const _DeskView({
    required this.checklists,
    required this.todayList,
    required this.allForPager,
    required this.primary,
    required this.isDark,
    required this.onOpenCreate,
    required this.onOpenDetail,
    required this.onShowContextMenu,
  });

  @override
  State<_DeskView> createState() => _DeskViewState();
}

// ── 清单维度分组模式 ──────────────────────────────────────────────
enum _GroupMode {
  all('全部', '📋'),
  byNature('按性质', '✨'),
  byScene('按场景', '🗺️'),
  byProgress('按进度', '📊'),
  byFunction('按用途', '🔧');

  const _GroupMode(this.label, this.emoji);
  final String label;
  final String emoji;
}

class _DeskViewState extends State<_DeskView>
    with TickerProviderStateMixin {
  late AnimationController _entranceCtrl;
  late Animation<double> _entranceAnim;

  // 当前维度
  _GroupMode _groupMode = _GroupMode.all;

  // ── Spotlight 双 Tab 状态 ─────────────────────────────────────────
  // 0 = 最近使用，1 = 为你推荐
  int _spotlightTab = 0;
  late PageController _spotlightPageCtrl;
  // 当前正在展示的页码（用于指示点）
  int _spotlightPage = 0;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _entranceAnim = CurvedAnimation(
      parent: _entranceCtrl,
      curve: Curves.easeOutCubic,
    );
    _entranceCtrl.forward();
    _spotlightPageCtrl = PageController(viewportFraction: 0.92);
    _spotlightPageCtrl.addListener(() {
      final page = _spotlightPageCtrl.page?.round() ?? 0;
      if (page != _spotlightPage) {
        setState(() => _spotlightPage = page);
      }
    });
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _spotlightPageCtrl.dispose();
    super.dispose();
  }

  /// 打开 PageView 分页器
  void _openPager(BuildContext context, int initialIndex, String heroTag) {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      _ReceiptExpandRoute(
        heroTag: heroTag,
        child: _ChecklistPageViewer(
          checklists: widget.allForPager,
          initialIndex: initialIndex,
          primary: widget.primary,
          isDark: widget.isDark,
          sourceHeroTag: heroTag,
        ),
      ),
    );
  }

  // ── 分组逻辑 ─────────────────────────────────────────────────────

  // 辅助：取一个清单所有标签的小写文本集合
  Set<String> _tagLabels(Checklist c) {
    return {
      ...c.userTags.map((t) => t.label.toLowerCase()),
      ...c.aiTags.map((t) => t.label.toLowerCase()),
    };
  }

  /// 按「性质」分组：利用 tags/scene 映射到 ChecklistNature 语义
  Map<String, List<Checklist>> _groupByNature(List<Checklist> list) {
    // 性质桶定义（key=显示名，val=判断函数）
    final buckets = <String, bool Function(Checklist)>{
      '⚡ 日常惯例': (c) {
        final tags = _tagLabels(c);
        return tags.any((t) =>
            t.contains('习惯') || t.contains('每日') || t.contains('惯例') ||
            t.contains('晨') || t.contains('睡前') || t.contains('routine'));
      },
      '🎯 重大事件': (c) {
        final tags = _tagLabels(c);
        return tags.any((t) =>
            t.contains('婚') || t.contains('搬') || t.contains('入职') ||
            t.contains('毕业') || t.contains('事件')) ||
            (c.scene == ChecklistScene.work && c.items.length > 10);
      },
      '🛒 采购备货': (c) {
        final tags = _tagLabels(c);
        return c.function == ChecklistFunction.purchase ||
            tags.any((t) =>
                t.contains('购') || t.contains('买') || t.contains('备货') ||
                t.contains('采购') || t.contains('清单')) ||
            c.scene == ChecklistScene.shopping;
      },
      '🌱 成长学习': (c) {
        final tags = _tagLabels(c);
        return c.scene == ChecklistScene.study ||
            tags.any((t) =>
                t.contains('学') || t.contains('读') || t.contains('技能') ||
                t.contains('目标') || t.contains('成长') || t.contains('课'));
      },
      '✈️ 旅行出行': (c) {
        final tags = _tagLabels(c);
        return tags.any((t) =>
            t.contains('旅') || t.contains('出行') || t.contains('打包') ||
            t.contains('travel') || t.contains('行李'));
      },
      '💼 工作职场': (c) {
        final tags = _tagLabels(c);
        return c.scene == ChecklistScene.work ||
            c.function == ChecklistFunction.sop ||
            tags.any((t) =>
                t.contains('工作') || t.contains('职场') || t.contains('会议') ||
                t.contains('项目') || t.contains('sop'));
      },
    };

    final grouped = <String, List<Checklist>>{};
    final placed = <String>{};

    for (final entry in buckets.entries) {
      final matched = list.where((c) => !placed.contains(c.id) && entry.value(c)).toList();
      if (matched.isNotEmpty) {
        grouped[entry.key] = matched;
        placed.addAll(matched.map((c) => c.id));
      }
    }
    // 未匹配的放「其他」
    final others = list.where((c) => !placed.contains(c.id)).toList();
    if (others.isNotEmpty) grouped['📁 其他'] = others;

    return grouped;
  }

  /// 按「场景」分组
  Map<String, List<Checklist>> _groupByScene(List<Checklist> list) {
    final sceneMap = {
      '💼 工作': ChecklistScene.work,
      '📚 学习': ChecklistScene.study,
      '🏠 生活': ChecklistScene.life,
      '🛒 购物': ChecklistScene.shopping,
    };
    final grouped = <String, List<Checklist>>{};
    for (final entry in sceneMap.entries) {
      final matched = list.where((c) => c.scene == entry.value).toList();
      if (matched.isNotEmpty) grouped[entry.key] = matched;
    }
    final placed = grouped.values.expand((e) => e).map((c) => c.id).toSet();
    final others = list.where((c) => !placed.contains(c.id)).toList();
    if (others.isNotEmpty) grouped['📋 通用'] = others;
    return grouped;
  }

  /// 按「进度」分组
  Map<String, List<Checklist>> _groupByProgress(List<Checklist> list) {
    final grouped = <String, List<Checklist>>{
      '🔴 未开始': [],
      '🟡 进行中': [],
      '🟢 已完成': [],
    };
    for (final c in list) {
      final total = c.items.length;
      final done = c.items.where((i) => i.isChecked).length;
      if (total == 0 || done == 0) {
        grouped['🔴 未开始']!.add(c);
      } else if (done >= total) {
        grouped['🟢 已完成']!.add(c);
      } else {
        grouped['🟡 进行中']!.add(c);
      }
    }
    grouped.removeWhere((_, v) => v.isEmpty);
    return grouped;
  }

  /// 按「用途」分组（ChecklistFunction）
  Map<String, List<Checklist>> _groupByFunction(List<Checklist> list) {
    final fnLabels = {
      ChecklistFunction.checklist: '✅ 核对清单',
      ChecklistFunction.sop: '🔢 流程 SOP',
      ChecklistFunction.purchase: '🛍️ 采购单',
      ChecklistFunction.plan: '🗓️ 规划',
      ChecklistFunction.review: '🔍 回顾复盘',
    };
    final grouped = <String, List<Checklist>>{};
    for (final entry in fnLabels.entries) {
      final matched = list.where((c) => c.function == entry.key).toList();
      if (matched.isNotEmpty) grouped[entry.value] = matched;
    }
    return grouped;
  }

  /// 根据当前 mode 返回分组结果
  Map<String, List<Checklist>> _getGroups() {
    final list = widget.checklists;
    return switch (_groupMode) {
      _GroupMode.byNature => _groupByNature(list),
      _GroupMode.byScene => _groupByScene(list),
      _GroupMode.byProgress => _groupByProgress(list),
      _GroupMode.byFunction => _groupByFunction(list),
      _ => {},
    };
  }

  // ── Spotlight 打分逻辑 ────────────────────────────────────────────

  /// 对一张结构型清单打「顶级显示」分数
  /// 分数越高 → 越值得浮现为 Spotlight Hero 卡
  double _scoreChecklist(Checklist c) {
    double score = 0;
    final now = DateTime.now();

    // ① 手动置顶 → 最高优先级
    if (c.isPinned) score += 100;

    // ② 截止日期紧迫：距今 ≤ 7 天
    if (c.dueDate != null) {
      final daysLeft = c.dueDate!.difference(now).inDays;
      if (daysLeft <= 1) {
        score += 60; // 今明两天
      } else if (daysLeft <= 3) {
        score += 45;
      } else if (daysLeft <= 7) {
        score += 25;
      }
    }

    // ③ 进度接近完成：≥ 70% 且未全部完成
    final prog = c.progress;
    if (prog >= 0.7 && prog < 1.0) {
      score += 25 + (prog * 20); // 最高 45 分
    }

    // ④ 周期清单（每日/每周）且本周期尚未完成
    if (c.repeatType == RepeatType.daily && prog < 1.0) {
      score += 30;
    } else if (c.repeatType == RepeatType.weekly && prog < 1.0) {
      score += 20;
    }

    // ⑤ 近期活跃度：最近 7 天有更新
    final daysSinceUpdate = now.difference(c.updatedAt).inDays;
    if (daysSinceUpdate <= 1) {
      score += 15;
    } else if (daysSinceUpdate <= 3) {
      score += 8;
    }

    // ⑥ 已全部完成的清单降权（不需要再聚焦）
    if (c.isAllDone) score -= 30;

    // ⑦ 空清单降权
    if (c.items.isEmpty) score -= 20;

    return score;
  }

  /// 计算 Spotlight 列表：得分 > 30 的前 3 张（为你推荐 Tab）
  List<Checklist> _getSpotlightList() {
    if (widget.checklists.isEmpty) return [];
    final scored = widget.checklists
        .map((c) => (c, _scoreChecklist(c)))
        .where((e) => e.$2 > 30)
        .toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));
    return scored.take(3).map((e) => e.$1).toList();
  }

  /// 最近使用列表：按 updatedAt 倒序取前 5 张
  List<Checklist> _getRecentList() {
    if (widget.checklists.isEmpty) return [];
    final sorted = [...widget.checklists]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sorted.take(5).toList(); // 最多 5 条，足够覆盖高频使用场景
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final primary = widget.primary;

    return AnimatedBuilder(
      animation: _entranceAnim,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 40 * (1 - _entranceAnim.value)),
          child: Opacity(opacity: _entranceAnim.value, child: child),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 今日清单区 ──────────────────────────────────────
          if (widget.todayList.isNotEmpty) ...[
            _buildTodaySection(context, primary, isDark),
            const SizedBox(height: 16),
          ],

          // ── Spotlight 聚焦区（智能浮现最重要的 1-2 张清单）──
          if (widget.checklists.isNotEmpty) ...[
            _buildSpotlightSection(context, primary, isDark),
          ],

          // ── 我的清单标题栏 + 维度切换栏 ────────────────────
          if (widget.checklists.isNotEmpty) ...[
            _buildChecklistHeader(context, primary, isDark),

            // ── 正文区：全部视图 or 分组视图 ──────────────────
            if (_groupMode == _GroupMode.all) ...[
              _buildReceiptDesk(context, primary, isDark),
              const SizedBox(height: 8),
            ] else ...[
              _buildGroupedDesk(context, primary, isDark),
              const SizedBox(height: 8),
            ],
          ] else ...[
            _buildEmptyDesk(context, primary, isDark),
          ],
        ],
      ),
    );
  }

  /// 我的清单区标题 + 维度切换胶囊栏
  Widget _buildChecklistHeader(
      BuildContext context, Color primary, bool isDark) {
    final textPrimary = isDark ? Colors.white : const Color(0xFF3D2B1A);
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : const Color(0xFF888888);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题行
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
          child: Row(
            children: [
              Text(
                '清单库',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${widget.checklists.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: primary,
                  ),
                ),
              ),
              const Spacer(),
              // 搜索/筛选按钮（跳转 ChecklistFilterScreen）
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ChecklistFilterScreen(),
                    ),
                  );
                },
                child: Container(
                  width: 30,
                  height: 30,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.search_rounded,
                    size: 17,
                    color: isDark ? Colors.white70 : const Color(0xFF5A4A3A),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  widget.onOpenCreate(type: ChecklistType.structural);
                },
                child: Text(
                  '+ 新建',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        // 维度切换胶囊栏
        SizedBox(
          height: 32,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: _GroupMode.values.map((mode) {
              final isActive = _groupMode == mode;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _groupMode = mode);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isActive
                        ? primary
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(mode.emoji,
                          style: const TextStyle(fontSize: 11)),
                      const SizedBox(width: 4),
                      Text(
                        mode.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isActive
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isActive
                              ? Colors.white
                              : textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  /// 分组视图：多个折叠托盘区域
  Widget _buildGroupedDesk(BuildContext context, Color primary, bool isDark) {
    final groups = _getGroups();
    if (groups.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Center(
          child: Text(
            '当前维度下暂无分组数据',
            style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? AppColors.textTertiaryDark
                  : const Color(0xFFAAAAAA),
            ),
          ),
        ),
      );
    }

    final todayOffset = widget.todayList.length;

    return Column(
      children: groups.entries.map((entry) {
        final groupLabel = entry.key;
        final groupItems = entry.value;
        // 计算每个 item 在 allForPager 中的索引（用于 PageView）
        final indices = groupItems.map((c) {
          return todayOffset + widget.checklists.indexWhere((x) => x.id == c.id);
        }).toList();

        return _GroupedDeskSection(
          label: groupLabel,
          checklists: groupItems,
          pagerIndices: indices,
          primary: primary,
          isDark: isDark,
          allForPager: widget.allForPager,
          onOpenCreate: widget.onOpenCreate,
          onShowContextMenu: widget.onShowContextMenu,
        );
      }).toList(),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  Spotlight 顶部聚焦区
  //
  //  结构：
  //  ① 左对齐 Tab 切换器（最近使用 / 为你推荐，直接作为区域标题）
  //  ② 横向 PageView（viewportFraction: 0.92，两侧露边）
  //     每一页 = 一张全宽大 SpotlightCard，内嵌可勾选事项
  //  ③ 底部居中 Dots 指示条
  // ─────────────────────────────────────────────────────────────────
  Widget _buildSpotlightSection(
      BuildContext context, Color primary, bool isDark) {
    final recentList = _getRecentList();
    final recommendList = _getSpotlightList();

    // 两个 Tab 都为空时不显示
    if (recentList.isEmpty && recommendList.isEmpty) {
      return const SizedBox.shrink();
    }

    // 当前 Tab 对应的清单列表
    final cards = _spotlightTab == 0 ? recentList : recommendList;

    // Tab 切换时重置 PageView 到第一页
    void switchTab(int tab) {
      if (_spotlightTab == tab) return;
      HapticFeedback.selectionClick();
      setState(() {
        _spotlightTab = tab;
        _spotlightPage = 0;
      });
      // 跳回第一页（无动画，避免残留位置感）
      if (_spotlightPageCtrl.hasClients) {
        _spotlightPageCtrl.jumpToPage(0);
      }
    }

    final textTertiary =
        isDark ? AppColors.textTertiaryDark : const Color(0xFFBBBBBB);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── ① Tab 切换器（左对齐，直接作为区域标题）────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SpotlightTabChip(
                  label: '最近使用',
                  isActive: _spotlightTab == 0,
                  primary: primary,
                  isDark: isDark,
                  onTap: () => switchTab(0),
                ),
                const SizedBox(width: 2),
                _SpotlightTabChip(
                  label: '为你推荐',
                  isActive: _spotlightTab == 1,
                  primary: primary,
                  isDark: isDark,
                  onTap: () => switchTab(1),
                ),
              ],
            ),
          ),
        ),

        // ── ② 横向 PageView 大卡 ────────────────────────────────
        if (cards.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Text(
              _spotlightTab == 1 ? '暂无推荐，先创建几张清单吧 ✨' : '暂无最近使用的清单',
              style: TextStyle(fontSize: 13, color: textTertiary),
            ),
          )
        else
          SizedBox(
            // 卡片高度：固定，足够展示 5 条事项 + 进度条 + 底部
            height: 260,
            child: PageView.builder(
              controller: _spotlightPageCtrl,
              itemCount: cards.length,
              physics: const BouncingScrollPhysics(),
              itemBuilder: (ctx, i) {
                final c = cards[i];
                return Padding(
                  // 左右内边距产生露边效果
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: _SpotlightCard(
                    checklist: c,
                    primary: primary,
                    isDark: isDark,
                    isRecentMode: _spotlightTab == 0,
                    onTap: () => widget.onOpenDetail(c),
                    onToggleItem: (itemId) {
                      context
                          .read<ChecklistProvider>()
                          .toggleItem(c.id, itemId);
                    },
                  ),
                );
              },
            ),
          ),

        // ── ③ Dots 指示条 ──────────────────────────────────────
        if (cards.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(cards.length, (i) {
                final isActive = i == _spotlightPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isActive ? 18.0 : 6.0,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isActive
                        ? primary
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.25)
                            : Colors.black.withValues(alpha: 0.15)),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          )
        else
          const SizedBox(height: 8),
      ],
    );
  }

  /// 收据纸条桌面 —— 横向滚动的多张 🧾 收据条
  ///
  /// 设计语言：每个清单 = 一张细长的收据纸条
  /// · 纸条宽度固定（约 110px），高度随内容适中
  /// · 顶部有小圆孔（订书钉/挂孔效果）
  /// · 内容区有淡蓝色横线纸纹
  /// · 底部撕边波浪（锯齿感）
  /// · 每张纸有微小随机旋转（±3°）
  /// · 多张并排横向滚动
  Widget _buildReceiptDesk(BuildContext context, Color primary, bool isDark) {
    final checklists = widget.checklists;
    final todayCount = widget.todayList.length;

    // 随机旋转角度（固定种子，避免每次 rebuild 变化）
    final rotations = List.generate(checklists.length, (i) {
      final seed = checklists[i].id.hashCode;
      final rng = math.Random(seed);
      return (rng.nextDouble() - 0.5) * 0.08; // ±0.04 rad ≈ ±2.3°
    });

    return SizedBox(
      height: 260,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        itemCount: checklists.length,
        itemBuilder: (ctx, i) {
          final c = checklists[i];
          final heroTag = 'receipt_slip_${c.id}';
          return Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Transform.rotate(
              angle: rotations[i],
              child: Hero(
                tag: heroTag,
                // Hero 动画期间保持原始外观，由 flightShuttleBuilder 控制
                flightShuttleBuilder: (flightContext, animation, direction,
                    fromContext, toContext) {
                  return AnimatedBuilder(
                    animation: animation,
                    builder: (ctx, _) {
                      // 进场时纸条旋转角归零
                      final angle =
                          rotations[i] * (1 - animation.value);
                      return Transform.rotate(
                        angle: angle,
                        child: Material(
                          color: Colors.transparent,
                          child: _ReceiptSlip(
                            checklist: c,
                            primary: primary,
                            isDark: isDark,
                            onTap: () {},
                            onLongPress: () {},
                          ),
                        ),
                      );
                    },
                  );
                },
                child: _ReceiptSlip(
                  checklist: c,
                  primary: primary,
                  isDark: isDark,
                  onTap: () => _openPager(context, todayCount + i, heroTag),
                  onLongPress: () => widget.onShowContextMenu(c),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 今日清单区域（水平滚动迷你卡片）
  Widget _buildTodaySection(BuildContext context, Color primary, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
          child: Row(
            children: [
              const Text('📅', style: TextStyle(fontSize: 15)),
              const SizedBox(width: 7),
              Text(
                '今日',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF3D2B1A),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${widget.todayList.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: primary,
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  widget.onOpenCreate(type: ChecklistType.temporal);
                },
                child: Text(
                  '+ 新增',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 88,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: widget.todayList.length,
            itemBuilder: (ctx, i) {
              final c = widget.todayList[i];
              return _TodayMiniCard(
                checklist: c,
                primary: primary,
                isDark: isDark,
                onTap: () => _openPager(context, i, 'today_slip_${c.id}'),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 空桌面提示
  Widget _buildEmptyDesk(BuildContext context, Color primary, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: GestureDetector(
        onTap: () => widget.onOpenCreate(type: ChecklistType.structural),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.surfaceDark
                : Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white10
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          child: Column(
            children: [
              Text(
                '🗂️',
                style: TextStyle(
                  fontSize: 40,
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : const Color(0xFFCCCCCC),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '还没有清单',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : const Color(0xFF666666),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '创建旅行打包、SOP、采购等长期清单',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : const Color(0xFFAAAAAA),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Text(
                  '+ 新建清单',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Spotlight 顶部 Tab 切换胶囊 —— _SpotlightTabChip
//
//  两个胶囊嵌套在一个圆角背景容器内，共同实现「iOS 风格」切换器：
//  · 激活态：填充 primary 色，白色文字
//  · 非激活态：透明背景，灰色文字
// ─────────────────────────────────────────────────────────────────
class _SpotlightTabChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color primary;
  final bool isDark;
  final VoidCallback onTap;

  const _SpotlightTabChip({
    required this.label,
    required this.isActive,
    required this.primary,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive
                ? Colors.white
                : (isDark ? Colors.white54 : const Color(0xFF888888)),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  🌟 Spotlight 聚焦卡 —— _SpotlightCard
//
//  一张结构型清单的「嵌入式」大卡展示：
//  · 左侧彩色边条（清单主题色）
//  · 顶部：emoji + 标题 + 进度数字（x/total）
//  · 中部：线性进度条
//  · 下部：前 4 条未完成事项，可直接在卡内勾选
//  · 底部：「→ 查看全部」按钮
//  · 若存在 dueDate：右上角显示截止日倒计时
// ─────────────────────────────────────────────────────────────────
class _SpotlightCard extends StatelessWidget {
  final Checklist checklist;
  final Color primary;
  final bool isDark;
  final VoidCallback onTap;
  final ValueChanged<String> onToggleItem;
  // 「最近使用」Tab 时为 true，展示「最近使用」标签而非推荐原因
  final bool isRecentMode;

  const _SpotlightCard({
    required this.checklist,
    required this.primary,
    required this.isDark,
    required this.onTap,
    required this.onToggleItem,
    this.isRecentMode = false,
  });

  Color get _accent {
    try {
      final hex = checklist.colorHex.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return primary;
    }
  }

  /// 生成截止日倒计时文案
  String? _dueDateHint() {
    if (checklist.dueDate == null) return null;
    final days = checklist.dueDate!.difference(DateTime.now()).inDays;
    if (days < 0) return '已逾期';
    if (days == 0) return '今天截止';
    if (days == 1) return '明天截止';
    return '还剩 $days 天';
  }

  /// 生成智能浮现原因文案（「为你推荐」模式）
  String _reasonHint() {
    if (checklist.isPinned) return '📌 已置顶';
    if (checklist.dueDate != null) {
      final days = checklist.dueDate!.difference(DateTime.now()).inDays;
      if (days <= 1) return '⏰ 即将截止';
      if (days <= 3) return '📅 快到期了';
    }
    if (checklist.progress >= 0.7) return '🎯 即将完成';
    if (checklist.repeatType == RepeatType.daily) return '🔄 每日清单';
    if (checklist.repeatType == RepeatType.weekly) return '📆 每周清单';
    return '🔥 最近活跃';
  }

  /// 「最近使用」模式下的时间戳文案
  String _recentHint() {
    final diff = DateTime.now().difference(checklist.updatedAt);
    if (diff.inMinutes < 60) return '🕐 ${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '🕐 ${diff.inHours} 小时前';
    if (diff.inDays == 1) return '📅 昨天';
    if (diff.inDays < 7) return '📅 ${diff.inDays} 天前';
    return '📅 ${checklist.updatedAt.month}/${checklist.updatedAt.day}';
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1A1410);
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : const Color(0xFF777777);
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    // 未完成的事项，最多展示 4 条
    final pendingItems = checklist.items
        .where((i) => !i.isChecked)
        .take(4)
        .toList();
    final totalCount = checklist.totalCount;
    final checkedCount = checklist.checkedCount;
    final progress = checklist.progress;

    final dueDateHint = _dueDateHint();
    final isDueUrgent = checklist.dueDate != null &&
        checklist.dueDate!.difference(DateTime.now()).inDays <= 1;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: isDark ? 0.12 : 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 左侧彩色边条
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
              ),
              // 主内容区
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── 顶部：emoji + 标题 + 截止/原因标签 ──
                      Row(
                        children: [
                          Text(checklist.emoji,
                              style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  checklist.title,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Text(
                                      isRecentMode ? _recentHint() : _reasonHint(),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isRecentMode
                                            ? (isDark ? Colors.white54 : const Color(0xFF999999))
                                            : accent,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (dueDateHint != null) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: isDueUrgent
                                              ? const Color(0xFFFF6B6B)
                                                  .withValues(alpha: 0.12)
                                              : accent.withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          dueDateHint,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: isDueUrgent
                                                ? const Color(0xFFFF6B6B)
                                                : accent,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // 右侧进度数字
                          Text(
                            '$checkedCount/$totalCount',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: accent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // ── 进度条 ───────────────────────────────
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor:
                              accent.withValues(alpha: isDark ? 0.15 : 0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(accent),
                          minHeight: 5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // ── 待办事项列表（可勾选）────────────────
                      if (pendingItems.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            totalCount == 0 ? '暂无事项' : '🎉 所有事项已完成',
                            style: TextStyle(
                              fontSize: 13,
                              color: accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else
                        ...pendingItems.map((item) => _SpotlightItem(
                              item: item,
                              accent: accent,
                              isDark: isDark,
                              onToggle: () => onToggleItem(item.id),
                            )),
                      // ── 底部：查看全部 ───────────────────────
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (totalCount > 4 && pendingItems.length == 4) ...[
                            Text(
                              '还有 ${checklist.uncheckedCount - 4} 项未完成',
                              style: TextStyle(
                                fontSize: 11,
                                color: textSecondary,
                              ),
                            ),
                          ],
                          const Spacer(),
                          Text(
                            '查看全部 →',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: accent,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Spotlight 卡内单条事项（可直接勾选）
class _SpotlightItem extends StatelessWidget {
  final ChecklistItem item;
  final Color accent;
  final bool isDark;
  final VoidCallback onToggle;

  const _SpotlightItem({
    required this.item,
    required this.accent,
    required this.isDark,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white70 : const Color(0xFF444444);
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onToggle();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            // 勾选圆圈
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? Colors.white30 : const Color(0xFFCCCCCC),
                  width: 1.5,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.title,
                style: TextStyle(
                  fontSize: 13,
                  color: textColor,
                  height: 1.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (item.quantity != null && item.quantity!.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                item.quantity!,
                style: TextStyle(
                  fontSize: 11,
                  color: accent.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  分组桌面区域 —— _GroupedDeskSection
//
//  每个分组是一个「可折叠托盘」：
//  · 标题行：分组 emoji + 名称 + 数量角标 + 折叠箭头
//  · 展开后：与原始收据纸条完全一致的横向滚动区域
//  · 折叠时：高度收缩到标题行，带流畅动画
// ─────────────────────────────────────────────────────────────────
class _GroupedDeskSection extends StatefulWidget {
  final String label;
  final List<Checklist> checklists;
  final List<int> pagerIndices;
  final Color primary;
  final bool isDark;
  final List<Checklist> allForPager;
  final void Function({ChecklistType? type}) onOpenCreate;
  final ValueChanged<Checklist> onShowContextMenu;

  const _GroupedDeskSection({
    required this.label,
    required this.checklists,
    required this.pagerIndices,
    required this.primary,
    required this.isDark,
    required this.allForPager,
    required this.onOpenCreate,
    required this.onShowContextMenu,
  });

  @override
  State<_GroupedDeskSection> createState() => _GroupedDeskSectionState();
}

class _GroupedDeskSectionState extends State<_GroupedDeskSection>
    with SingleTickerProviderStateMixin {
  bool _expanded = true;
  late AnimationController _expandCtrl;
  late Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();
    _expandCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      value: 1.0,
    );
    _expandAnim = CurvedAnimation(
      parent: _expandCtrl,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _expandCtrl.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    HapticFeedback.selectionClick();
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _expandCtrl.forward();
    } else {
      _expandCtrl.reverse();
    }
  }

  void _openPager(BuildContext context, int pagerIndex, String heroTag) {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      _ReceiptExpandRoute(
        heroTag: heroTag,
        child: _ChecklistPageViewer(
          checklists: widget.allForPager,
          initialIndex: pagerIndex,
          primary: widget.primary,
          isDark: widget.isDark,
          sourceHeroTag: heroTag,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final primary = widget.primary;
    final textPrimary = isDark ? Colors.white : const Color(0xFF3D2B1A);
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : const Color(0xFF888888);
    final sectionBg = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.black.withValues(alpha: 0.025);

    // 随机旋转（与原桌面一致）
    final rotations = List.generate(widget.checklists.length, (i) {
      final seed = widget.checklists[i].id.hashCode;
      final rng = math.Random(seed);
      return (rng.nextDouble() - 0.5) * 0.08;
    });

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      decoration: BoxDecoration(
        color: sectionBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 标题行（可点击折叠）──────────────────────────────
          GestureDetector(
            onTap: _toggleExpand,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  // 分组名
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(width: 7),
                  // 数量角标
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 1),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${widget.checklists.length}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: primary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // 折叠箭头
                  AnimatedRotation(
                    turns: _expanded ? 0 : -0.25,
                    duration: const Duration(milliseconds: 260),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ── 内容区（可折叠）─────────────────────────────────
          SizeTransition(
            sizeFactor: _expandAnim,
            child: SizedBox(
              height: 256,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                itemCount: widget.checklists.length,
                itemBuilder: (ctx, i) {
                  final c = widget.checklists[i];
                  final pagerIdx = widget.pagerIndices[i];
                  final heroTag = 'grouped_slip_${c.id}';
                  return Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: Transform.rotate(
                      angle: rotations[i],
                      child: Hero(
                        tag: heroTag,
                        flightShuttleBuilder: (flightCtx, animation,
                            direction, fromCtx, toCtx) {
                          return AnimatedBuilder(
                            animation: animation,
                            builder: (ctx2, _) {
                              return Transform.rotate(
                                angle: rotations[i] * (1 - animation.value),
                                child: Material(
                                  color: Colors.transparent,
                                  child: _ReceiptSlip(
                                    checklist: c,
                                    primary: primary,
                                    isDark: isDark,
                                    onTap: () {},
                                    onLongPress: () {},
                                  ),
                                ),
                              );
                            },
                          );
                        },
                        child: _ReceiptSlip(
                          checklist: c,
                          primary: primary,
                          isDark: isDark,
                          onTap: () => _openPager(ctx, pagerIdx, heroTag),
                          onLongPress: () =>
                              widget.onShowContextMenu(c),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  🧾 收据纸条 —— _ReceiptSlip
//
//  模拟真实收据/收据单子放在桌面的拟物效果：
//  · 细长纸条形态（宽约 106px，高约 236px）
//  · 纸张质感背景（奶白色）+ 极细边框
//  · 顶部彩色标签区（清单主题色）
//  · 顶部订书钉/孔眼（小圆点）
//  · 内容区横线纸纹（淡蓝色线条）
//  · emoji 大图 + 标题 + 进度数字
//  · 底部锯齿撕边（CustomPainter）
//  · 阴影模拟纸张厚度
// ─────────────────────────────────────────────────────────────────

class _ReceiptSlip extends StatefulWidget {
  final Checklist checklist;
  final Color primary;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ReceiptSlip({
    required this.checklist,
    required this.primary,
    required this.isDark,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_ReceiptSlip> createState() => _ReceiptSlipState();
}

class _ReceiptSlipState extends State<_ReceiptSlip>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  Color get _accent {
    try {
      final hex = widget.checklist.colorHex.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return widget.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final checklist = widget.checklist;
    final isDark = widget.isDark;
    final accent = _accent;
    final totalCount = checklist.totalCount;
    final checkedCount = checklist.checkedCount;

    // 纸张基础色
    final paperBg = isDark ? const Color(0xFF2A2415) : const Color(0xFFFFFBF3);
    final paperBorder = isDark
        ? const Color(0xFF3E3020)
        : const Color(0xFFE5DECE);
    // 墨水色
    final inkColor = isDark
        ? const Color(0xFFEAE0CC)
        : const Color(0xFF2A1A08);
    final inkSecondary = isDark
        ? const Color(0xFF9A8A70)
        : const Color(0xFF8B6E50);
    // 横线颜色（极淡）
    final lineColor = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : const Color(0xFFB8D4EF).withValues(alpha: 0.45);

    return GestureDetector(
      onTapDown: (_) => _pressCtrl.forward(),
      onTapUp: (_) => _pressCtrl.reverse(),
      onTapCancel: () => _pressCtrl.reverse(),
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onLongPress: () {
        HapticFeedback.mediumImpact();
        widget.onLongPress();
      },
      child: ScaleTransition(
        scale: _scaleAnim,
        child: SizedBox(
          width: 106,
          // 底部多留 8px 给撕边的 CustomPaint
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── 主纸条体 ──────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: paperBg,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    topRight: Radius.circular(6),
                  ),
                  border: Border.all(color: paperBorder, width: 0.8),
                  boxShadow: [
                    // 主阴影
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.18),
                      blurRadius: 10,
                      offset: const Offset(2, 6),
                      spreadRadius: -1,
                    ),
                    // 轻微高光
                    BoxShadow(
                      color: Colors.white.withValues(alpha: isDark ? 0.04 : 0.9),
                      blurRadius: 1,
                      offset: const Offset(-1, -1),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    topRight: Radius.circular(6),
                  ),
                  child: Stack(
                    children: [
                      // ── 横线纸纹（背景装饰）──────────────────
                      Positioned.fill(
                        top: 52, // 色带区下方开始画线
                        child: CustomPaint(
                          painter: _LinedPaperPainter(lineColor: lineColor),
                        ),
                      ),

                      // ── 主内容列 ─────────────────────────────
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // ── 顶部彩色标签区（含孔眼）────────────
                          _buildReceiptHeader(accent, isDark),

                          // ── 内容区 ───────────────────────────
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Emoji 大图
                                Text(
                                  checklist.emoji,
                                  style: const TextStyle(fontSize: 30),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),

                                // 标题（居中）
                                Text(
                                  checklist.title,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: inkColor,
                                    height: 1.35,
                                    letterSpacing: 0.1,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 10),

                                // 虚线分割（像收据的分割线）
                                _DashedDivider(
                                    color: inkSecondary.withValues(alpha: 0.3)),
                                const SizedBox(height: 8),

                                // 进度数字
                                if (totalCount > 0) ...[
                                  Text(
                                    '$checkedCount / $totalCount',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: checklist.isAllDone
                                          ? Colors.green.shade600
                                          : accent,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  // 细进度条
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(2),
                                    child: LinearProgressIndicator(
                                      value: checkedCount / totalCount,
                                      backgroundColor:
                                          isDark
                                              ? Colors.white.withValues(alpha: 0.08)
                                              : Colors.black.withValues(alpha: 0.06),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        checklist.isAllDone
                                            ? Colors.green.shade400
                                            : accent.withValues(alpha: 0.8),
                                      ),
                                      minHeight: 2.5,
                                    ),
                                  ),
                                ] else ...[
                                  Text(
                                    '暂无事项',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: inkSecondary.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 8),

                                // 底部小字（类似收据底部的公司名）
                                if (checklist.isPinned)
                                  Icon(Icons.push_pin_rounded,
                                      size: 10,
                                      color: accent.withValues(alpha: 0.5)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── 底部撕边效果 ──────────────────────────────────
              CustomPaint(
                size: const Size(106, 10),
                painter: _TearEdgePainter(
                  paperColor: paperBg,
                  borderColor: paperBorder,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 顶部彩色标签区 + 孔眼
  Widget _buildReceiptHeader(Color accent, bool isDark) {
    return Container(
      width: double.infinity,
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accent,
            accent.withValues(alpha: 0.82),
          ],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 孔眼（圆形白色小点）
          Positioned(
            top: 8,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.9),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
          // 色带下方渐变到纸张色的过渡
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: isDark ? 0.12 : 0.06),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 横线纸纹 Painter
class _LinedPaperPainter extends CustomPainter {
  final Color lineColor;
  const _LinedPaperPainter({required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 0.6;
    const lineSpacing = 14.0;
    var y = lineSpacing;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      y += lineSpacing;
    }
  }

  @override
  bool shouldRepaint(_LinedPaperPainter oldDelegate) =>
      oldDelegate.lineColor != lineColor;
}

/// 虚线分割线 Widget
class _DashedDivider extends StatelessWidget {
  final Color color;
  const _DashedDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      child: CustomPaint(
        painter: _DashedLinePainter(color: color),
        size: const Size(double.infinity, 1),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  const _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.8;
    double x = 0;
    const dashWidth = 4.0;
    const gapWidth = 3.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dashWidth, 0), paint);
      x += dashWidth + gapWidth;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// 收据撕边效果 Painter（底部锯齿）
class _TearEdgePainter extends CustomPainter {
  final Color paperColor;
  final Color borderColor;
  final bool isDark;

  const _TearEdgePainter({
    required this.paperColor,
    required this.borderColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = paperColor
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    // 绘制锯齿波浪：从左到右，交替上下锯齿
    final path = Path();
    path.moveTo(0, 0);
    const toothWidth = 7.0;
    const toothHeight = 5.0;
    double x = 0;
    bool up = true;
    while (x < size.width) {
      final nextX = (x + toothWidth).clamp(0.0, size.width);
      final midX = (x + nextX) / 2;
      path.quadraticBezierTo(
        midX,
        up ? -toothHeight : toothHeight,
        nextX,
        0,
      );
      x = nextX;
      up = !up;
    }
    // 封闭路径（矩形下方）
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    // 先画阴影
    canvas.drawShadow(path, Colors.black.withValues(alpha: isDark ? 0.3 : 0.12), 3, true);
    // 填充纸张色
    canvas.drawPath(path, fillPaint);
    // 描边
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(_TearEdgePainter oldDelegate) =>
      oldDelegate.paperColor != paperColor ||
      oldDelegate.isDark != isDark;
}

// ─────────────────────────────────────────────────────────────────
//  旧版拟物纸张卡片 —— _DeskCard（保留供其他地方引用）
// ─────────────────────────────────────────────────────────────────

class _DeskCard extends StatefulWidget {
  final Checklist checklist;
  final Color primary;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _DeskCard({
    required this.checklist,
    required this.primary,
    required this.isDark,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_DeskCard> createState() => _DeskCardState();
}

class _DeskCardState extends State<_DeskCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  Color get _accent {
    try {
      final hex = widget.checklist.colorHex.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return widget.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    final checklist = widget.checklist;
    final isDark = widget.isDark;
    final totalCount = checklist.totalCount;
    final checkedCount = checklist.checkedCount;
    final progress = totalCount > 0 ? checkedCount / totalCount : 0.0;

    // 卡片纸张背景色
    final cardBg = isDark
        ? const Color(0xFF2A2018)
        : const Color(0xFFFFFBF5);
    final cardBorder = isDark
        ? const Color(0xFF3D3020)
        : const Color(0xFFE8DDD0);

    return GestureDetector(
      onTapDown: (_) => _pressCtrl.forward(),
      onTapUp: (_) => _pressCtrl.reverse(),
      onTapCancel: () => _pressCtrl.reverse(),
      onTap: widget.onTap,
      onLongPress: () {
        HapticFeedback.mediumImpact();
        widget.onLongPress();
      },
      child: ScaleTransition(
        scale: _scaleAnim,
        child: SizedBox(
          width: 140,
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cardBorder, width: 0.8),
              boxShadow: [
                // 主阴影（正常阴影）
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                  spreadRadius: 0,
                ),
                // 次阴影（模拟厚度/第二层纸）
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.10),
                  blurRadius: 4,
                  offset: const Offset(2, 8),
                  spreadRadius: -2,
                ),
                // 高光（顶部）
                BoxShadow(
                  color: Colors.white.withValues(alpha: isDark ? 0.04 : 0.8),
                  blurRadius: 1,
                  offset: const Offset(0, -1),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 顶部色带 ─────────────────────────────────
                  Container(
                    height: 5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accent,
                          accent.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Emoji 大图 ───────────────────────────
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: isDark ? 0.15 : 0.1),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Center(
                            child: Text(
                              checklist.emoji,
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // ── 标题 ─────────────────────────────────
                        Text(
                          checklist.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? const Color(0xFFEEE8DC)
                                : const Color(0xFF2D1F0D),
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),

                        // ── 进度区 ───────────────────────────────
                        if (totalCount > 0) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.06),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                checklist.isAllDone ? Colors.green : accent,
                              ),
                              minHeight: 3,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '$checkedCount/$totalCount',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppColors.textTertiaryDark
                                      : const Color(0xFF999999),
                                ),
                              ),
                              if (checklist.isAllDone)
                                const Icon(Icons.check_circle_rounded,
                                    size: 12, color: Colors.green)
                              else if (checklist.isPinned)
                                Icon(Icons.push_pin_rounded,
                                    size: 11, color: accent.withValues(alpha: 0.6)),
                            ],
                          ),
                        ] else ...[
                          Text(
                            '暂无事项',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark
                                  ? AppColors.textTertiaryDark
                                  : const Color(0xFFBBBBBB),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  今日迷你卡片 —— _TodayMiniCard（水平滚动）
// ─────────────────────────────────────────────────────────────────

class _TodayMiniCard extends StatelessWidget {
  final Checklist checklist;
  final Color primary;
  final bool isDark;
  final VoidCallback onTap;

  const _TodayMiniCard({
    required this.checklist,
    required this.primary,
    required this.isDark,
    required this.onTap,
  });

  Color get _accent {
    try {
      final hex = checklist.colorHex.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    final cardBg = isDark ? AppColors.surfaceDark : Colors.white;
    final totalCount = checklist.totalCount;
    final checkedCount = checklist.checkedCount;

    String? overdueLabel;
    if (checklist.isOverdue && checklist.scheduledDate != null) {
      final diff = DateTime.now().difference(checklist.scheduledDate!).inDays;
      overdueLabel = diff <= 1 ? '昨天' : '$diff天前';
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 10, bottom: 4),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Row(
            children: [
              Container(width: 4, color: accent),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Text(checklist.emoji,
                              style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 5),
                          if (overdueLabel != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF6B6B)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                overdueLabel,
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFE05555),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        checklist.title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF1A1410),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (totalCount > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          '$checkedCount/$totalCount 完成',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark
                                ? AppColors.textTertiaryDark
                                : const Color(0xFFAAAAAA),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  清单 PageView 分页器 —— _ChecklistPageViewer
//
//  点击桌面上任意清单卡片后进入此页面。
//  支持左右滑动翻页浏览所有清单（今日 + 结构型）。
//  底部有页码指示点 + 关闭按钮。
// ─────────────────────────────────────────────────────────────────

class _ChecklistPageViewer extends StatefulWidget {
  final List<Checklist> checklists;
  final int initialIndex;
  final Color primary;
  final bool isDark;
  /// 来源纸条的 Hero tag，用于内容入场序列
  final String? sourceHeroTag;

  const _ChecklistPageViewer({
    required this.checklists,
    required this.initialIndex,
    required this.primary,
    required this.isDark,
    this.sourceHeroTag,
  });

  @override
  State<_ChecklistPageViewer> createState() => _ChecklistPageViewerState();
}

class _ChecklistPageViewerState extends State<_ChecklistPageViewer>
    with SingleTickerProviderStateMixin {
  late PageController _pageCtrl;
  late int _currentIndex;

  // 其他卡片从两侧飞入的动画控制器
  late AnimationController _sideCardsCtrl;
  late Animation<double> _sideCardsAnim;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.checklists.length - 1);
    _pageCtrl = PageController(
      initialPage: _currentIndex,
      viewportFraction: 0.88,
    );

    // 其他卡片延迟飞入（等 Hero 动画完成附近时再进场）
    _sideCardsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _sideCardsAnim = CurvedAnimation(
      parent: _sideCardsCtrl,
      curve: Curves.easeOutCubic,
    );
    // 等 Hero 动画开始后稍延启动两侧卡片动画
    Future.delayed(const Duration(milliseconds: 180), () {
      if (mounted) _sideCardsCtrl.forward();
    });
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _sideCardsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final primary = widget.primary;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final topPadding = MediaQuery.of(context).padding.top;

    final bgColor = isDark ? const Color(0xFF141414) : const Color(0xFFF5EFE6);

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
          // ── 顶部栏 ───────────────────────────────────────────
          SizedBox(
            height: topPadding + 60,
            child: Padding(
              padding: EdgeInsets.only(
                  top: topPadding, left: 20, right: 20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 22,
                        color: isDark ? Colors.white70 : const Color(0xFF555555),
                      ),
                    ),
                  ),
                  const Spacer(),
                  // 当前页码
                  Text(
                    '${_currentIndex + 1} / ${widget.checklists.length}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : const Color(0xFF888888),
                    ),
                  ),
                  const Spacer(),
                  // 打开详情按钮
                  GestureDetector(
                    onTap: () {
                      final checklist = widget.checklists[_currentIndex];
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChecklistDetailScreen(
                              checklistId: checklist.id),
                        ),
                      );
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: primary,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: primary.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.open_in_new_rounded,
                          size: 17, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── PageView 主体 ────────────────────────────────────
          Expanded(
            child: PageView.builder(
              controller: _pageCtrl,
              itemCount: widget.checklists.length,
              onPageChanged: (i) => setState(() => _currentIndex = i),
              itemBuilder: (ctx, i) {
                final checklist = widget.checklists[i];
                final isSelected = i == _currentIndex;
                // 左側卡片从左飞入，右侧卡片从右飞入
                final isLeft = i < _currentIndex;

                return AnimatedBuilder(
                  animation: Listenable.merge([_pageCtrl, _sideCardsAnim]),
                  builder: (ctx, child) {
                    double pageScale = 1.0;
                    if (_pageCtrl.position.haveDimensions) {
                      final pageOffset = _pageCtrl.page! - i;
                      pageScale =
                          (1 - pageOffset.abs() * 0.06).clamp(0.9, 1.0);
                    }

                    // 非选中卡片：初始从两侧远处飞入
                    double slideX = 0.0;
                    double opacity = 1.0;
                    if (!isSelected) {
                      final t = _sideCardsAnim.value;
                      slideX = isLeft
                          ? -(1.0 - t) * 80 // 左侧卡片从左外飞入
                          : (1.0 - t) * 80; // 右侧卡片从右外飞入
                      opacity = t.clamp(0.0, 1.0);
                    }

                    return Transform.translate(
                      offset: Offset(slideX, 0),
                      child: Opacity(
                        opacity: opacity,
                        child: Transform.scale(
                          scale: pageScale,
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 12),
                    child: _PageCard(
                      checklist: checklist,
                      primary: primary,
                      isDark: isDark,
                      heroTag: isSelected ? 'receipt_slip_${checklist.id}' : null,
                      onOpen: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChecklistDetailScreen(
                                checklistId: checklist.id),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),

          // ── 页码指示点 ───────────────────────────────────────
          Padding(
            padding: EdgeInsets.only(
                bottom: bottomPadding + 24, top: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.checklists.length.clamp(0, 12),
                (i) {
                  final isActive = i == _currentIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isActive ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isActive
                          ? primary
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.2)
                              : Colors.black.withValues(alpha: 0.15)),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  PageView 内的单张清单预览卡 —— _PageCard
//
//  展示清单的详细信息：
//  · 顶部渐变色块（主题色）+ emoji + 标题
//  · 进度环 + 数字统计
//  · 前 6 条事项预览（可勾选完成）
//  · 底部「查看全部」按钮
// ─────────────────────────────────────────────────────────────────

class _PageCard extends StatelessWidget {
  final Checklist checklist;
  final Color primary;
  final bool isDark;
  final VoidCallback onOpen;
  /// 非空时将卡片内容包袹在 Hero 中，实现从小纸条放大的连续性动画
  final String? heroTag;

  const _PageCard({
    required this.checklist,
    required this.primary,
    required this.isDark,
    required this.onOpen,
    this.heroTag,
  });

  Color get _accent {
    try {
      final hex = checklist.colorHex.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    final isDark = this.isDark;
    final totalCount = checklist.totalCount;
    final checkedCount = checklist.checkedCount;
    final progress = totalCount > 0 ? checkedCount / totalCount : 0.0;

    final cardBg = isDark ? const Color(0xFF1E1A14) : Colors.white;
    final cardBorder = isDark
        ? const Color(0xFF2E2820)
        : const Color(0xFFEEE8E0);

    // 预览的事项（最多 8 条）
    final previewItems = checklist.items.take(8).toList();

    final card = Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: accent.withValues(alpha: isDark ? 0.06 : 0.04),
            blurRadius: 32,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 顶部渐变色块 ──────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent,
                    accent.withValues(alpha: 0.75),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // emoji + 置顶图标
                  Row(
                    children: [
                      Text(checklist.emoji,
                          style: const TextStyle(fontSize: 36)),
                      const Spacer(),
                      if (checklist.isPinned)
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.push_pin_rounded,
                              size: 14, color: Colors.white),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // 标题
                  Text(
                    checklist.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (checklist.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      checklist.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 16),
                  // 进度信息
                  Row(
                    children: [
                      // 进度条
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.25),
                                valueColor:
                                    const AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                minHeight: 5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              totalCount > 0
                                  ? '$checkedCount / $totalCount 项完成'
                                  : '暂无事项',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // 进度百分比圆形
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                        child: Center(
                          child: Text(
                            totalCount > 0
                                ? '${(progress * 100).round()}%'
                                : '0%',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── 事项预览列表 ──────────────────────────────────
            Expanded(
              child: previewItems.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.playlist_add_rounded,
                              size: 40,
                              color: isDark
                                  ? AppColors.textTertiaryDark
                                  : const Color(0xFFDDDDDD),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '还没有事项',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark
                                    ? AppColors.textTertiaryDark
                                    : const Color(0xFFBBBBBB),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      itemCount: previewItems.length,
                      physics: const NeverScrollableScrollPhysics(),
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.05),
                      ),
                      itemBuilder: (ctx, i) {
                        final item = previewItems[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              // 勾选圆圈
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: item.isChecked
                                      ? accent
                                      : Colors.transparent,
                                  border: item.isChecked
                                      ? null
                                      : Border.all(
                                          color: isDark
                                              ? Colors.white30
                                              : const Color(0xFFCCCCCC),
                                          width: 1.5,
                                        ),
                                ),
                                child: item.isChecked
                                    ? const Icon(Icons.check_rounded,
                                        size: 12, color: Colors.white)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              // 事项文字
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: item.isChecked
                                        ? (isDark
                                            ? Colors.white30
                                            : const Color(0xFFBBBBBB))
                                        : (isDark
                                            ? Colors.white.withValues(alpha: 0.87)
                                            : const Color(0xFF333333)),
                                    decoration: item.isChecked
                                        ? TextDecoration.lineThrough
                                        : null,
                                    decorationColor: isDark
                                        ? Colors.white30
                                        : const Color(0xFFBBBBBB),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

            // ── 底部「查看全部」按钮 ───────────────────────────
            GestureDetector(
              onTap: onOpen,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: isDark ? 0.12 : 0.06),
                  border: Border(
                    top: BorderSide(
                      color: accent.withValues(alpha: isDark ? 0.15 : 0.1),
                      width: 0.8,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '查看全部事项',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.arrow_forward_rounded, size: 16, color: accent),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (heroTag != null) {
      return Hero(
        tag: heroTag!,
        // 在 Hero 飞行过程中保持卡片深色背景
        flightShuttleBuilder: (flightContext, animation, direction,
            fromContext, toContext) {
          return Material(
            color: Colors.transparent,
            child: card,
          );
        },
        child: Material(color: Colors.transparent, child: card),
      );
    }
    return card;
  }
}

// ─────────────────────────────────────────────────────────────────
//  收据纸条放大路由 —— _ReceiptExpandRoute
//
//  进场：选中纸条通过 Hero 放大 + 背景淡入
//  退出：反向，纸条缩回原位
// ─────────────────────────────────────────────────────────────────

class _ReceiptExpandRoute extends PageRouteBuilder {
  final String heroTag;

  _ReceiptExpandRoute({
    required this.heroTag,
    required Widget child,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: const Duration(milliseconds: 450),
          reverseTransitionDuration: const Duration(milliseconds: 380),
          transitionsBuilder:
              (context, animation, secondaryAnimation, child) {
            // 背景淡入（非 Hero 元素的拤登效果）
            final fadeAnim = CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
            );
            return FadeTransition(
              opacity: fadeAnim,
              child: child,
            );
          },
        );
}

// ─────────────────────────────────────────────────────────────────
//  底部搜索 + 快捷筛选条 —— _BottomSearchBar
//
//  始终贴在页面底部（Stack + Positioned），分两层：
//
//  ┌──────────────────────────────────────────────────────────┐
//  │ 🔍  [搜索清单…轮播 hint]                    [✨ 发现]   │  ← 搜索区
//  ├──────────────────────────────────────────────────────────┤
//  │  [今日]  [逾期]  [进行中]  [已完成]  [置顶]             │  ← 快捷筛选胶囊
//  └──────────────────────────────────────────────────────────┘
//
//  交互：
//  · 搜索区点击 → 进入 ChecklistFilterScreen（搜索 + 全维度筛选）
//  · 快捷胶囊点击 → 带预设条件进入 ChecklistFilterScreen
//  · 快捷胶囊激活时高亮，再次点击取消
// ─────────────────────────────────────────────────────────────────

// 底部搜索栏轮播 hint（描述搜索场景）
const List<String> _kBottomHints = [
  '搜索清单名称或事项…',
  '旅行打包、装修检查…',
  '下周工作计划…',
  '购物备货、健身计划…',
  '按场景、用途快速定位…',
];

// ─────────────────────────────────────────────────────────────────
//  底部工具栏 —— _BottomToolBar（模板库 + AI 生成入口）
// ─────────────────────────────────────────────────────────────────

class _BottomToolBar extends StatelessWidget {
  final Color primary;
  final bool isDark;

  const _BottomToolBar({required this.primary, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ChecklistDiscoverScreen(),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🗂️', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      '模板库',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.white70
                            : const Color(0xFF555555),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                // AI 生成清单（暂时也跳转发现页）
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ChecklistDiscoverScreen(),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: isDark ? 0.12 : 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('✨', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      'AI 生成',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 快捷筛选胶囊定义：(显示文案, 状态条件函数)
class _QuickFilter {
  final String label;
  final String emoji;
  final bool Function(Checklist) test;
  const _QuickFilter({required this.label, required this.emoji, required this.test});
}

final _kQuickFilters = <_QuickFilter>[
  _QuickFilter(
    label: '今日',
    emoji: '📅',
    test: (c) => c.isToday,
  ),
  _QuickFilter(
    label: '逾期',
    emoji: '🔴',
    test: (c) {
      if (c.dueDate == null) return false;
      return c.dueDate!.isBefore(DateTime.now()) && !c.isAllDone;
    },
  ),
  _QuickFilter(
    label: '进行中',
    emoji: '🟡',
    test: (c) {
      final done = c.items.where((i) => i.isChecked).length;
      return c.items.isNotEmpty && done > 0 && done < c.items.length;
    },
  ),
  _QuickFilter(
    label: '已完成',
    emoji: '✅',
    test: (c) => c.isAllDone && c.items.isNotEmpty,
  ),
  _QuickFilter(
    label: '置顶',
    emoji: '📌',
    test: (c) => c.isPinned,
  ),
];

class _BottomSearchBar extends StatefulWidget {
  final Color primary;
  final bool isDark;
  final VoidCallback onSearch;

  const _BottomSearchBar({
    required this.primary,
    required this.isDark,
    required this.onSearch,
  });

  @override
  State<_BottomSearchBar> createState() => _BottomSearchBarState();
}

class _BottomSearchBarState extends State<_BottomSearchBar> {
  int _hintIndex = 0;
  Timer? _timer;
  // 当前激活的快捷筛选索引（-1 = 无）
  int _activeFilter = -1;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      setState(() {
        _hintIndex = (_hintIndex + 1) % _kBottomHints.length;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _openFilterWithPreset(BuildContext context, int filterIndex) {
    HapticFeedback.selectionClick();
    setState(() {
      _activeFilter = _activeFilter == filterIndex ? -1 : filterIndex;
    });
    // 带预设条件跳转筛选页
    // 目前 ChecklistFilterScreen 不接受参数，直接跳转；
    // 后续可扩展传入预设 ChecklistFilterState
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChecklistFilterScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final primary = widget.primary;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final cardBg = isDark
        ? Colors.black.withValues(alpha: 0.80)
        : Colors.white.withValues(alpha: 0.94);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.07);
    final iconColor = isDark
        ? const Color(0xFF888888)
        : const Color(0xFF999999);
    final hintColor = isDark
        ? const Color(0xFF777777)
        : const Color(0xFFAAAAAA);
    final chipInactiveBg = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.05);
    final chipInactiveText = isDark
        ? const Color(0xFF999999)
        : const Color(0xFF888888);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 8 + bottomPadding),
          decoration: BoxDecoration(
            color: cardBg,
            border: Border(
              top: BorderSide(color: borderColor, width: 0.5),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── 上行：搜索输入区 ──────────────────────────────
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  widget.onSearch();
                },
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.07)
                        : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.07),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 13),
                      Icon(Icons.search_rounded, size: 18, color: iconColor),
                      const SizedBox(width: 8),
                      // 轮播 hint
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 320),
                          transitionBuilder: (child, anim) => FadeTransition(
                            opacity: anim,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.35),
                                end: Offset.zero,
                              ).animate(CurvedAnimation(
                                parent: anim,
                                curve: Curves.easeOut,
                              )),
                              child: child,
                            ),
                          ),
                          child: Align(
                            key: ValueKey(_hintIndex),
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _kBottomHints[_hintIndex],
                              style: TextStyle(
                                fontSize: 14,
                                color: hintColor,
                                fontWeight: FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                      // 右侧「筛选」文字提示
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Row(
                          children: [
                            Icon(Icons.tune_rounded, size: 14, color: hintColor),
                            const SizedBox(width: 3),
                            Text(
                              '筛选',
                              style: TextStyle(
                                fontSize: 12,
                                color: hintColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // ── 下行：快捷筛选胶囊 ────────────────────────────
              SizedBox(
                height: 28,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _kQuickFilters.length,
                  itemBuilder: (ctx, i) {
                    final qf = _kQuickFilters[i];
                    final isActive = _activeFilter == i;
                    return GestureDetector(
                      onTap: () => _openFilterWithPreset(ctx, i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 11, vertical: 0),
                        decoration: BoxDecoration(
                          color: isActive
                              ? primary.withValues(alpha: 0.15)
                              : chipInactiveBg,
                          borderRadius: BorderRadius.circular(14),
                          border: isActive
                              ? Border.all(
                                  color: primary.withValues(alpha: 0.45),
                                  width: 1,
                                )
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(qf.emoji,
                                style: const TextStyle(fontSize: 11)),
                            const SizedBox(width: 4),
                            Text(
                              qf.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isActive
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isActive ? primary : chipInactiveText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// ─────────────────────────────────────────────────────────────────
//  空状态（什么都没有时）
// ─────────────────────────────────────────────────────────────────

class _EmptyHomeState extends StatelessWidget {
  final Color primary;
  final bool isDark;
  final VoidCallback onCreateTemporal;
  final VoidCallback onCreateStructural;

  const _EmptyHomeState({
    required this.primary,
    required this.isDark,
    required this.onCreateTemporal,
    required this.onCreateStructural,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📋', style: TextStyle(fontSize: 60)),
            const SizedBox(height: 20),
            Text(
              '还没有清单',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF1A1410),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '清单分为两种：\n「今日待办」记录要做的事\n「结构清单」整理复用型内容',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.7,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : const Color(0xFF888888),
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: _CreateButton(
                    emoji: '📅',
                    label: '今日待办',
                    desc: '有日期，可重复',
                    color: primary,
                    isDark: isDark,
                    onTap: onCreateTemporal,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _CreateButton(
                    emoji: '📂',
                    label: '结构清单',
                    desc: '长期有效，可复用',
                    color: const Color(0xFF20C997),
                    isDark: isDark,
                    onTap: onCreateStructural,
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

class _CreateButton extends StatelessWidget {
  final String emoji;
  final String label;
  final String desc;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _CreateButton({
    required this.emoji,
    required this.label,
    required this.desc,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              desc,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: isDark
                    ? AppColors.textTertiaryDark
                    : const Color(0xFFAAAAAA),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  右键菜单
// ─────────────────────────────────────────────────────────────────

class _ContextMenu extends StatelessWidget {
  final Checklist checklist;
  final bool isDark;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onDelete;
  final VoidCallback onTogglePin;

  const _ContextMenu({
    required this.checklist,
    required this.isDark,
    required this.onEdit,
    required this.onArchive,
    required this.onDelete,
    required this.onTogglePin,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? AppColors.surfaceDark : Colors.white;
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 头部预览
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Row(
              children: [
                Text(checklist.emoji,
                    style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        checklist.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color:
                              isDark ? Colors.white : const Color(0xFF1A1410),
                        ),
                      ),
                      Text(
                        checklist.checklistType == ChecklistType.temporal
                            ? '时态清单'
                            : '结构清单',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.textTertiaryDark
                              : const Color(0xFFAAAAAA),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(
              height: 1,
              color: isDark
                  ? Colors.white10
                  : Colors.black.withValues(alpha: 0.08)),
          _MenuItem(
            icon: Icons.edit_outlined,
            label: '编辑',
            isDark: isDark,
            onTap: onEdit,
          ),
          if (checklist.checklistType == ChecklistType.structural)
            _MenuItem(
              icon: checklist.isPinned
                  ? Icons.push_pin_rounded
                  : Icons.push_pin_outlined,
              label: checklist.isPinned ? '取消置顶' : '置顶',
              isDark: isDark,
              onTap: onTogglePin,
            ),
          _MenuItem(
            icon: Icons.archive_outlined,
            label: '归档',
            isDark: isDark,
            onTap: onArchive,
          ),
          _MenuItem(
            icon: Icons.delete_outline_rounded,
            label: '删除',
            isDark: isDark,
            color: Colors.red,
            onTap: onDelete,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback onTap;
  final Color? color;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = color ??
        (isDark ? AppColors.textPrimaryDark : const Color(0xFF1A1410));
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: textColor),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: textColor),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  _CreateChecklistSheet —— 新建/编辑清单底部弹窗（v2）
//
//  新增：清单类型选择（时态/结构），类型不同则展示不同字段
//  时态型：必须选日期，可选重复类型
//  结构型：场景、展示风格、主题色
// ─────────────────────────────────────────────────────────────────

class _CreateChecklistSheet extends StatefulWidget {
  final ChecklistType? initialType;
  final Checklist? editing;

  const _CreateChecklistSheet({this.initialType, this.editing});

  @override
  State<_CreateChecklistSheet> createState() => _CreateChecklistSheetState();
}

class _CreateChecklistSheetState extends State<_CreateChecklistSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  // 清单类型
  ChecklistType _type = ChecklistType.structural;

  // 通用字段
  String _emoji = '📋';
  String _colorHex = '#5C7CFA';

  // 时态型专属
  DateTime _scheduledDate = DateTime.now();
  RepeatType _repeatType = RepeatType.none;

  // 结构型专属
  ChecklistScene _scene = ChecklistScene.general;
  ChecklistStyle _style = ChecklistStyle.simple;
  ChecklistFunction _function = ChecklistFunction.checklist;

  // 交互范式（结构型专属，由 AI 自动推断）
  ChecklistInteractionMode _interactionMode = ChecklistInteractionMode.execution;

  // ── AI 智能识别 ──────────────────────────────────────────
  // 用户是否手动修改过类型/场景（手动修改后不再 AI 覆盖）
  bool _userManuallySetType = false;
  // ignore: prefer_final_fields
  bool _userManuallySetScene = false;
  // ignore: prefer_final_fields
  bool _userManuallySetStyle = false;
  // ignore: prefer_final_fields
  bool _userManuallySetEmoji = false;
  // AI 推断状态
  bool _isAiInferring = false;
  // 防抖 Timer
  Timer? _inferDebounce;
  // 上次推断的标题（避免重复请求）
  String _lastInferredTitle = '';

  // ── 方案B：分流入口标志 ──────────────────────────────────
  // 从「日程清单」入口进来：强制 temporal，隐藏场景/风格/类型选择
  bool get _isForcedTemporal =>
      !_isEditing && widget.initialType == ChecklistType.temporal;
  // 从「我的清单」入口进来：强制 structural，隐藏日期/重复/类型选择
  bool get _isForcedStructural =>
      !_isEditing && widget.initialType == ChecklistType.structural;

  static const _colorOptions = [
    '#5C7CFA', '#339AF0', '#20C997', '#51CF66',
    '#FAB005', '#FF6B6B', '#CC5DE8', '#FF922B',
    '#F06595', '#74C0FC',
  ];

  static const _emojiOptions = [
    '📋', '✅', '📝', '🛒', '✈️', '💼',
    '📚', '💪', '🏠', '🎉', '💰', '🍳',
    '🎯', '💡', '⚡', '🔥', '🌟', '🎨',
    '📅', '🗓️', '⏰', '🌅', '🌙', '☀️',
  ];

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      _titleCtrl.text = e.title;
      _descCtrl.text = e.description;
      _emoji = e.emoji;
      _colorHex = e.colorHex;
      _type = e.checklistType;
      _scene = e.scene;
      _style = e.style;
      _function = e.function;
      _interactionMode = e.interactionMode;
      _repeatType = e.repeatType;
      _scheduledDate = e.scheduledDate ?? DateTime.now();
    } else if (widget.initialType != null) {
      _type = widget.initialType!;
      _userManuallySetType = true; // 外部指定的类型也算手动
      if (_type == ChecklistType.temporal) {
        _emoji = '📅';
        _colorHex = '#339AF0';
      } else {
        _emoji = '📋';
        _colorHex = '#5C7CFA';
      }
    }

  }

  // 点击键盘「完成」后触发 AI 推断
  void _onTitleEditingComplete() {
    final title = _titleCtrl.text.trim();
    if (title.length < 3) return;
    if (title == _lastInferredTitle) return;
    _triggerAiInfer(title);
  }

  Future<void> _triggerAiInfer(String title) async {
    if (!mounted) return;
    // 若用户已手动设置全部字段，不再推断
    if (_userManuallySetType && _userManuallySetScene && _userManuallySetEmoji) return;
    // 分流入口时，类型已固定，仅当 emoji/scene 未手动设置时才值得推断
    if (_isForcedTemporal && _userManuallySetEmoji) return;
    if (_isForcedStructural && _userManuallySetScene && _userManuallySetStyle && _userManuallySetEmoji) return;

    setState(() => _isAiInferring = true);
    _lastInferredTitle = title;

    try {
      final result = await AiService.instance.inferChecklistDimensions(title);
      if (!mounted) return;
      if (result == null) {
        setState(() => _isAiInferring = false);
        return;
      }

      setState(() {
        _isAiInferring = false;
        // 仅在没有强制类型且用户未手动设置时，才覆盖类型
        if (!_isForcedTemporal && !_isForcedStructural && !_userManuallySetType) {
          _type = result.checklistType == 'temporal'
              ? ChecklistType.temporal
              : ChecklistType.structural;
          // 类型变为时态时，更新默认色
          if (_type == ChecklistType.temporal && !_userManuallySetEmoji) {
            _colorHex = '#339AF0';
          }
        }
        // 场景推断：仅结构型表单适用
        if (!_isForcedTemporal && !_userManuallySetScene) {
          _scene = ChecklistScene.fromValue(result.scene);
        }
        // 展示风格推断：仅结构型表单适用
        if (!_isForcedTemporal && !_userManuallySetStyle) {
          _style = ChecklistStyle.fromValue(result.style);
        }
        // 交互范式推断：根据 AI 返回的 interactionMode 直接设置
        if (!_isForcedTemporal) {
          _interactionMode = ChecklistInteractionMode.fromValue(
              result.interactionMode);
        }
        if (!_userManuallySetEmoji) {
          _emoji = result.emoji;
          // 如果不是时态型，也更新颜色（仅当未手动设置时）
          if (_type == ChecklistType.structural) {
            _colorHex = result.colorHex;
          }
        }
      });
    } catch (_) {
      if (mounted) setState(() => _isAiInferring = false);
    }
  }

  @override
  void dispose() {
    _inferDebounce?.cancel();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Color get _accentColor {
    try {
      return Color(int.parse('FF${_colorHex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return const Color(0xFF5C7CFA);
    }
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入清单标题')),
      );
      return;
    }
    final provider = context.read<ChecklistProvider>();
    if (_isEditing) {
      await provider.updateChecklist(widget.editing!.copyWith(
        title: title,
        description: _descCtrl.text.trim(),
        emoji: _emoji,
        colorHex: _colorHex,
        checklistType: _type,
        scene: _scene,
        style: _style,
        function: _function,
        interactionMode: _interactionMode,
        scheduledDate: _type == ChecklistType.temporal ? _scheduledDate : null,
        repeatType: _type == ChecklistType.temporal ? _repeatType : RepeatType.none,
      ));
    } else {
      await provider.addChecklist(
        title: title,
        description: _descCtrl.text.trim(),
        emoji: _emoji,
        colorHex: _colorHex,
        checklistType: _type,
        scene: _scene,
        style: _style,
        function: _function,
        interactionMode: _interactionMode,
        scheduledDate: _type == ChecklistType.temporal ? _scheduledDate : null,
        repeatType: _type == ChecklistType.temporal ? _repeatType : RepeatType.none,
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.surfaceDark : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1410);
    final hintColor =
        isDark ? AppColors.textTertiaryDark : const Color(0xFFBBBBBB);
    final inputFill =
        isDark ? AppColors.inputFillDark : const Color(0xFFF5F5F5);
    final accent = _accentColor;

    // 编辑模式依然展示完整表单
    if (_isEditing) {
      return _buildEditSheet(
          context, isDark, bgColor, textColor, hintColor, inputFill);
    }

    // ── 新建模式：极简三步设计 ────────────────────────────────────
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 拖拽手柄 ──────────────────────────────────────────
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white24
                          : Colors.black.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // ── 步骤①：Emoji + 大标题输入（唯一必填）────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // emoji 可点击切换
                    GestureDetector(
                      onTap: () => _pickEmoji(context, isDark),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: isDark ? 0.18 : 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(_emoji,
                              style: const TextStyle(fontSize: 28)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextField(
                        controller: _titleCtrl,
                        autofocus: true,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                          height: 1.2,
                        ),
                        textInputAction: TextInputAction.done,
                        onEditingComplete: () {
                          FocusScope.of(context).unfocus();
                          _onTitleEditingComplete();
                        },
                        decoration: InputDecoration(
                          hintText: _isForcedTemporal
                              ? '今日工作安排、本周计划…'
                              : '旅行打包、装修检查、购物清单…',
                          hintStyle: TextStyle(
                            color: hintColor,
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                          // AI 推断指示器
                          suffixIcon: _isAiInferring
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      color: accent.withValues(alpha: 0.5),
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── 时态型专属：日期 + 重复 ──────────────────────────
                if (_type == ChecklistType.temporal) ...[
                  _SectionLabel(label: '属于哪天', isDark: isDark),
                  const SizedBox(height: 8),
                  _DateSelector(
                    selected: _scheduledDate,
                    accentColor: accent,
                    isDark: isDark,
                    onSelect: (d) => setState(() => _scheduledDate = d),
                  ),
                  const SizedBox(height: 14),
                  _SectionLabel(label: '重复周期', isDark: isDark),
                  const SizedBox(height: 8),
                  _RepeatSelector(
                    selected: _repeatType,
                    accentColor: accent,
                    isDark: isDark,
                    onSelect: (r) => setState(() => _repeatType = r),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── 步骤②：AI 配置预览胶囊行 ─────────────────────────
                // AI 推断完成后，用胶囊展示 emoji+场景+用途，可点击修改
                _AiConfigPreviewRow(
                  scene: _scene,
                  function: _function,
                  style: _style,
                  accent: accent,
                  isDark: isDark,
                  hasAiInferred: _lastInferredTitle.isNotEmpty,
                  isInferring: _isAiInferring,
                  onTapScene: () => _pickScene(context, isDark),
                  onTapFunction: () => _pickFunction(context, isDark),
                ),
                const SizedBox(height: 20),

                // ── 步骤③：创建按钮 ──────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: GestureDetector(
                    onTap: _save,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [accent, accent.withValues(alpha: 0.82)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          '创建清单',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 编辑模式保留完整表单（含描述、颜色等）
  Widget _buildEditSheet(BuildContext context, bool isDark, Color bgColor,
      Color textColor, Color hintColor, Color inputFill) {
    final accent = _accentColor;
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 拖拽手柄
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white24
                          : Colors.black.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '编辑清单',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 16),
                // Emoji + 标题
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _pickEmoji(context, isDark),
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child:
                              Text(_emoji, style: const TextStyle(fontSize: 26)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _titleCtrl,
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: textColor),
                        textInputAction: TextInputAction.done,
                        onEditingComplete: () => FocusScope.of(context).unfocus(),
                        decoration: InputDecoration(
                          hintText: '清单名称',
                          hintStyle: TextStyle(
                              color: hintColor, fontWeight: FontWeight.w400),
                          filled: true,
                          fillColor: inputFill,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // 描述
                TextField(
                  controller: _descCtrl,
                  maxLines: 2,
                  style: TextStyle(fontSize: 14, color: textColor),
                  decoration: InputDecoration(
                    hintText: '描述（可选）',
                    hintStyle: TextStyle(
                        color: hintColor, fontWeight: FontWeight.w400),
                    filled: true,
                    fillColor: inputFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 20),
                // 时态型：日期 + 重复
                if (_type == ChecklistType.temporal) ...[
                  _SectionLabel(label: '属于哪天', isDark: isDark),
                  const SizedBox(height: 10),
                  _DateSelector(
                    selected: _scheduledDate,
                    accentColor: accent,
                    isDark: isDark,
                    onSelect: (d) => setState(() => _scheduledDate = d),
                  ),
                  const SizedBox(height: 20),
                  _SectionLabel(label: '重复周期', isDark: isDark),
                  const SizedBox(height: 10),
                  _RepeatSelector(
                    selected: _repeatType,
                    accentColor: accent,
                    isDark: isDark,
                    onSelect: (r) => setState(() => _repeatType = r),
                  ),
                  const SizedBox(height: 20),
                ],
                // 主题色
                _SectionLabel(label: '主题色', isDark: isDark),
                const SizedBox(height: 10),
                _ColorPicker(
                  colors: _colorOptions,
                  selected: _colorHex,
                  onSelect: (c) => setState(() => _colorHex = c),
                ),
                const SizedBox(height: 28),
                // 底部按钮
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF2A2A2A)
                                : const Color(0xFFF0F0F0),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text(
                              '取消',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : const Color(0xFF888888),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        onTap: _save,
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                accent,
                                accent.withValues(alpha: 0.85)
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              '保存',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 点击场景胶囊 → 弹出选择器
  void _pickScene(BuildContext context, bool isDark) {
    final sceneOptions = [
      (ChecklistScene.general, '📋', '通用'),
      (ChecklistScene.work, '💼', '工作'),
      (ChecklistScene.life, '🏠', '生活'),
      (ChecklistScene.study, '📚', '学习'),
      (ChecklistScene.shopping, '🛒', '购物'),
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SimplePickerSheet(
        title: '选择场景',
        options: sceneOptions.map((e) => (e.$2, e.$3)).toList(),
        selectedIndex:
            sceneOptions.indexWhere((e) => e.$1 == _scene).clamp(0, 999),
        isDark: isDark,
        onSelect: (i) {
          setState(() {
            _scene = sceneOptions[i].$1;
            _userManuallySetScene = true;
          });
        },
      ),
    );
  }

  /// 点击用途胶囊 → 弹出选择器
  void _pickFunction(BuildContext context, bool isDark) {
    final fnOptions = [
      (ChecklistFunction.checklist, '✅', '核对清单'),
      (ChecklistFunction.sop, '🔢', '流程 SOP'),
      (ChecklistFunction.purchase, '🛍️', '采购单'),
      (ChecklistFunction.plan, '🗓️', '规划'),
      (ChecklistFunction.review, '🔍', '回顾复盘'),
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SimplePickerSheet(
        title: '选择用途',
        options: fnOptions.map((e) => (e.$2, e.$3)).toList(),
        selectedIndex:
            fnOptions.indexWhere((e) => e.$1 == _function).clamp(0, 999),
        isDark: isDark,
        onSelect: (i) {
          setState(() => _function = fnOptions[i].$1);
        },
      ),
    );
  }

  void _pickEmoji(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('选择图标',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color:
                        isDark ? Colors.white : const Color(0xFF1A1410))),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _emojiOptions.map((e) {
                final isSelected = _emoji == e;
                return GestureDetector(
                  onTap: () {
                    setState(() => _emoji = e);
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _accentColor.withValues(alpha: 0.15)
                          : (isDark
                              ? const Color(0xFF2A2A2A)
                              : const Color(0xFFF5F5F5)),
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(color: _accentColor, width: 2)
                          : null,
                    ),
                    child: Center(
                        child:
                            Text(e, style: const TextStyle(fontSize: 22))),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  AI 配置预览胶囊行 —— _AiConfigPreviewRow
//
//  新建清单时展示在标题下方，以轻量胶囊展示 AI 已推断的：
//  · 场景（如：💼 工作、🏠 生活）
//  · 用途（如：✅ 核对清单、🛒 采购单）
//  · 展示风格（如：📋 简洁、🏷️ 标签）
//  每个胶囊可轻触弹出修改选择器
//  未触发 AI 推断时：显示占位提示文字
// ─────────────────────────────────────────────────────────────────

class _AiConfigPreviewRow extends StatelessWidget {
  final ChecklistScene scene;
  final ChecklistFunction function;
  final ChecklistStyle style;
  final Color accent;
  final bool isDark;
  final bool hasAiInferred;
  final bool isInferring;
  final VoidCallback onTapScene;
  final VoidCallback onTapFunction;

  const _AiConfigPreviewRow({
    required this.scene,
    required this.function,
    required this.style,
    required this.accent,
    required this.isDark,
    required this.hasAiInferred,
    required this.isInferring,
    required this.onTapScene,
    required this.onTapFunction,
  });

  String get _sceneLabel {
    switch (scene) {
      case ChecklistScene.work:
        return '💼 工作';
      case ChecklistScene.study:
        return '📚 学习';
      case ChecklistScene.life:
        return '🏠 生活';
      case ChecklistScene.shopping:
        return '🛒 购物';
      case ChecklistScene.general:
        return '📋 通用';
    }
  }

  String get _functionLabel {
    const map = {
      ChecklistFunction.checklist: '✅ 核对清单',
      ChecklistFunction.sop: '🔢 流程 SOP',
      ChecklistFunction.purchase: '🛍️ 采购单',
      ChecklistFunction.plan: '🗓️ 规划',
      ChecklistFunction.review: '🔍 复盘',
    };
    return map[function] ?? '✅ 核对清单';
  }

  @override
  Widget build(BuildContext context) {
    final chipBg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.05);
    final chipBorder = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);
    final labelColor = isDark ? Colors.white70 : const Color(0xFF555555);
    final hintColor = isDark
        ? AppColors.textTertiaryDark
        : const Color(0xFFBBBBBB);

    if (isInferring) {
      // 推断中：显示骨架占位
      return Row(
        children: [
          const Icon(Icons.auto_awesome_rounded,
              size: 13, color: Color(0xFF9775FA)),
          const SizedBox(width: 6),
          Text(
            'AI 正在分析清单类型…',
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? const Color(0xFF9775FA)
                  : const Color(0xFF9775FA).withValues(alpha: 0.8),
            ),
          ),
        ],
      );
    }

    if (!hasAiInferred) {
      // 未推断：显示提示，告知用户输入标题后 AI 会自动配置
      return Row(
        children: [
          Icon(Icons.auto_awesome_outlined, size: 13, color: hintColor),
          const SizedBox(width: 6),
          Text(
            '输入标题后 AI 自动配置场景与用途',
            style: TextStyle(fontSize: 12, color: hintColor),
          ),
        ],
      );
    }

    // 推断完成：展示可点击胶囊
    Widget chip(String label, VoidCallback onTap) {
      return GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: chipBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: chipBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: labelColor)),
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down_rounded,
                  size: 12, color: hintColor),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        const Icon(Icons.auto_awesome_rounded,
            size: 13, color: Color(0xFF9775FA)),
        const SizedBox(width: 6),
        chip(_sceneLabel, onTapScene),
        const SizedBox(width: 8),
        chip(_functionLabel, onTapFunction),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  通用胶囊选择器底部弹窗 —— _SimplePickerSheet
//
//  传入 options（emoji + 名称）列表和当前选中索引，
//  用户点击一项后回调 onSelect(index) 并自动关闭弹窗
// ─────────────────────────────────────────────────────────────────

class _SimplePickerSheet extends StatelessWidget {
  final String title;
  final List<(String, String)> options; // (emoji, label)
  final int selectedIndex;
  final bool isDark;
  final ValueChanged<int> onSelect;

  const _SimplePickerSheet({
    required this.title,
    required this.options,
    required this.selectedIndex,
    required this.isDark,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? AppColors.surfaceDark : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1410);
    final accent = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 手柄
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(title,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textColor)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: options.asMap().entries.map((entry) {
              final i = entry.key;
              final opt = entry.value;
              final isSelected = i == selectedIndex;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onSelect(i);
                  Navigator.pop(context);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? accent.withValues(alpha: 0.12)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.07)
                            : const Color(0xFFF5F5F5)),
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected
                        ? Border.all(
                            color: accent.withValues(alpha: 0.5), width: 1.5)
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(opt.$1,
                          style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Text(
                        opt.$2,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected
                              ? accent
                              : textColor,
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
}


// ─────────────────────────────────────────────────────────────────
//  日期选择器（时态型专属）
// ─────────────────────────────────────────────────────────────────

class _DateSelector extends StatelessWidget {
  final DateTime selected;
  final Color accentColor;
  final bool isDark;
  final ValueChanged<DateTime> onSelect;

  const _DateSelector({
    required this.selected,
    required this.accentColor,
    required this.isDark,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dayAfter = today.add(const Duration(days: 2));

    // 快捷选项
    final shortcuts = <(String, DateTime)>[
      ('今天', today),
      ('明天', tomorrow),
      ('后天', dayAfter),
    ];

    final selectedDate =
        DateTime(selected.year, selected.month, selected.day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 快捷按钮
        Row(
          children: [
            ...shortcuts.map((s) {
              final isActive = selectedDate == s.$2;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => onSelect(s.$2),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isActive
                          ? accentColor
                          : (isDark
                              ? const Color(0xFF2A2A2A)
                              : const Color(0xFFF0F0F0)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      s.$1,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isActive
                            ? Colors.white
                            : (isDark
                                ? AppColors.textSecondaryDark
                                : const Color(0xFF555555)),
                      ),
                    ),
                  ),
                ),
              );
            }),
            // 自定义日期按钮
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selected,
                  firstDate: today,
                  lastDate: today.add(const Duration(days: 365)),
                  builder: (ctx, child) {
                    return Theme(
                      data: Theme.of(ctx).copyWith(
                        colorScheme: ColorScheme.light(primary: accentColor),
                      ),
                      child: child!,
                    );
                  },
                );
                if (picked != null) onSelect(picked);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: !shortcuts.any((s) => selectedDate == s.$2)
                      ? accentColor
                      : (isDark
                          ? const Color(0xFF2A2A2A)
                          : const Color(0xFFF0F0F0)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 13,
                      color: !shortcuts.any((s) => selectedDate == s.$2)
                          ? Colors.white
                          : (isDark
                              ? AppColors.textSecondaryDark
                              : const Color(0xFF555555)),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      !shortcuts.any((s) => selectedDate == s.$2)
                          ? '${selected.month}/${selected.day}'
                          : '选择',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: !shortcuts.any((s) => selectedDate == s.$2)
                            ? Colors.white
                            : (isDark
                                ? AppColors.textSecondaryDark
                                : const Color(0xFF555555)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  重复类型选择器（时态型专属）
// ─────────────────────────────────────────────────────────────────

class _RepeatSelector extends StatelessWidget {
  final RepeatType selected;
  final Color accentColor;
  final bool isDark;
  final ValueChanged<RepeatType> onSelect;

  const _RepeatSelector({
    required this.selected,
    required this.accentColor,
    required this.isDark,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: RepeatType.values.map((r) {
        final isActive = selected == r;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(r),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isActive
                    ? accentColor
                    : (isDark
                        ? const Color(0xFF2A2A2A)
                        : const Color(0xFFF0F0F0)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  r.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isActive
                        ? Colors.white
                        : (isDark
                            ? AppColors.textSecondaryDark
                            : const Color(0xFF555555)),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  颜色选择器
// ─────────────────────────────────────────────────────────────────

class _ColorPicker extends StatelessWidget {
  final List<String> colors;
  final String selected;
  final ValueChanged<String> onSelect;

  const _ColorPicker({
    required this.colors,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: colors.map((hex) {
        Color c;
        try {
          c = Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
        } catch (_) {
          c = Colors.blue;
        }
        final isSelected = selected == hex;
        return GestureDetector(
          onTap: () => onSelect(hex),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
              boxShadow: isSelected
                  ? [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 6)]
                  : null,
            ),
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : null,
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  通用 Section 标签
// ─────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final bool isDark;

  const _SectionLabel({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: isDark ? AppColors.textTertiaryDark : const Color(0xFF999999),
      ),
    );
  }
}

