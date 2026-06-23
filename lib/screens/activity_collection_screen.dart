import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/activity_collection.dart';
import '../providers/activity_collection_provider.dart';
import '../models/record.dart';
import '../providers/record_provider.dart';
import '../theme/app_theme.dart';
import 'activity_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────
//  ActivityCollectionScreen —— 活动集主页（生活五环）
//
//  【核心理念】
//  生活五环：身体力行 / 关系连接 / 创造表达 / 心智成长 / 心流专注
//  五环以五边形雷达图显化在页面顶部，让用户直觉感受到生活均衡度。
//
//  【页面结构】
//  ① SliverAppBar：标题 + 添加按钮
//  ② 五边形均衡图：五个维度，亮度 = 本周活动次数，点击跳转分组
//  ③ 一行洞察文字：最活跃 / 最需关注的维度
//  ④ 按五环分组的活动列表：有活动 → 展开卡片；无活动 → 引导添加
//  ⑤ 空状态：全屏引导卡片（首次进入）
// ─────────────────────────────────────────────────────────────────

class ActivityCollectionScreen extends StatefulWidget {
  const ActivityCollectionScreen({super.key});

  @override
  State<ActivityCollectionScreen> createState() =>
      _ActivityCollectionScreenState();
}

class _ActivityCollectionScreenState extends State<ActivityCollectionScreen> {
  // 当前高亮的维度（点击五边形角时）
  ActivityCategory? _highlightedCategory;
  final _scrollController = ScrollController();

  // 每个分组的 GlobalKey，用于点击五边形角时滚动定位
  final Map<ActivityCategory, GlobalKey> _groupKeys = {
    for (final cat in ActivityCategory.values) cat: GlobalKey(),
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RecordProvider>().loadAllRecords();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // 计算每个维度本周活动次数
  Map<ActivityCategory, int> _weeklyCountByCategory(
      RecordProvider rp, ActivityCollectionProvider acp) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartDay =
        DateTime(weekStart.year, weekStart.month, weekStart.day);

    final result = <ActivityCategory, int>{
      for (final cat in ActivityCategory.values) cat: 0,
    };

    for (final record in rp.allRecords) {
      if (record.type != RecordType.event) continue;
      final activityId = record.extra['activityId'] as String?;
      if (activityId == null) continue;
      if (record.createdAt.isBefore(weekStartDay)) continue;

      final activity = acp.activities
          .where((a) => a.id == activityId)
          .firstOrNull;
      if (activity == null) continue;
      result[activity.category] = (result[activity.category] ?? 0) + 1;
    }
    return result;
  }

  void _scrollToCategory(ActivityCategory cat) {
    setState(() => _highlightedCategory = cat);
    final key = _groupKeys[cat];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0.0,
      );
    }
    // 高亮 1.5 秒后消除
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _highlightedCategory = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = WeeklyTheme.getLightPalette();

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: Consumer2<ActivityCollectionProvider, RecordProvider>(
        builder: (ctx, acp, rp, _) {
          if (!acp.isLoaded) {
            return const Center(child: CircularProgressIndicator());
          }

          final weeklyCount = _weeklyCountByCategory(rp, acp);

          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              _buildAppBar(context, isDark, palette, acp),
              if (acp.isEmpty)
                SliverToBoxAdapter(
                  child: _EmptyGuide(isDark: isDark, palette: palette),
                )
              else ...[
                // 五边形均衡图
                SliverToBoxAdapter(
                  child: _PentagonBalanceCard(
                    weeklyCount: weeklyCount,
                    isDark: isDark,
                    onCategoryTap: (cat) {
                      HapticFeedback.selectionClick();
                      _scrollToCategory(cat);
                    },
                  ),
                ),
                // 洞察文字
                SliverToBoxAdapter(
                  child: _InsightBar(
                    weeklyCount: weeklyCount,
                    isDark: isDark,
                  ),
                ),
                // 按五环分组的活动列表
                ..._buildGroupedSlivers(context, isDark, palette, acp, rp),
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ],
          );
        },
      ),
      // FAB
      floatingActionButton: Consumer<ActivityCollectionProvider>(
        builder: (ctx, provider, _) {
          if (!provider.isLoaded || provider.isEmpty) {
            return const SizedBox.shrink();
          }
          final color = isDark ? AppColors.darkPrimary : palette.primary;
          return FloatingActionButton.extended(
            onPressed: () => _showAddSheet(context, isDark, palette),
            backgroundColor: color,
            foregroundColor: Colors.white,
            elevation: 4,
            icon: const Icon(Icons.add_rounded),
            label: const Text(
              '添加活动',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          );
        },
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────
  Widget _buildAppBar(BuildContext context, bool isDark, DayPalette palette,
      ActivityCollectionProvider provider) {
    return SliverAppBar(
      floating: true,
      backgroundColor: isDark ? AppColors.backgroundDark : palette.background,
      elevation: 0,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 18,
          color: isDark ? Colors.white : const Color(0xFF1A1410),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '活动集',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1A1410),
            ),
          ),
          Text(
            '生活五环',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? const Color(0xFF666666)
                  : const Color(0xFFAAAAAA),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
      centerTitle: false,
      titleSpacing: 0,
      actions: [
        if (!provider.isEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: () => _showAddSheet(context, isDark, palette),
              icon: Icon(
                Icons.add_rounded,
                size: 16,
                color: isDark ? AppColors.darkPrimary : palette.primary,
              ),
              label: Text(
                '添加',
                style: TextStyle(
                  color: isDark ? AppColors.darkPrimary : palette.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
          ),
      ],
    );
  }

  // ── 按五环分组的 Sliver 列表 ───────────────────────────────────
  List<Widget> _buildGroupedSlivers(
    BuildContext context,
    bool isDark,
    DayPalette palette,
    ActivityCollectionProvider acp,
    RecordProvider rp,
  ) {
    final slivers = <Widget>[];

    for (final cat in ActivityCategory.values) {
      final activities = acp.byCategory(cat);
      final isHighlighted = _highlightedCategory == cat;

      slivers.add(
        SliverToBoxAdapter(
          key: _groupKeys[cat],
          child: _CategoryGroupSection(
            category: cat,
            activities: activities,
            isDark: isDark,
            palette: palette,
            isHighlighted: isHighlighted,
            allRecords: rp.allRecords,
            onActivityTap: (activity) =>
                _onActivityTap(context, activity, isDark, palette),
            onActivityLongPress: (activity) =>
                _showRemoveDialog(context, activity, acp),
            onAddTap: () => _showAddSheetWithCategory(
                context, isDark, palette, cat),
          ),
        ),
      );
    }

    return slivers;
  }

  void _onActivityTap(BuildContext context, ActivityDefinition activity,
      bool isDark, DayPalette palette) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActivityDetailScreen(activity: activity),
      ),
    );
  }

  void _showRemoveDialog(BuildContext context, ActivityDefinition activity,
      ActivityCollectionProvider provider) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('从活动集移除「${activity.name}」？'),
        content: const Text('历史参与记录不会删除，只是从活动集移除这个活动。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              provider.remove(activity.id);
              Navigator.pop(ctx);
            },
            child: const Text(
              '移除',
              style: TextStyle(color: Color(0xFFE74C3C)),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddSheet(BuildContext context, bool isDark, DayPalette palette) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddActivitySheet(isDark: isDark, palette: palette),
    );
  }

  void _showAddSheetWithCategory(BuildContext context, bool isDark,
      DayPalette palette, ActivityCategory initialCategory) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddActivitySheet(
        isDark: isDark,
        palette: palette,
        initialCategory: initialCategory,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  五边形均衡图卡片
// ─────────────────────────────────────────────────────────────────

class _PentagonBalanceCard extends StatelessWidget {
  final Map<ActivityCategory, int> weeklyCount;
  final bool isDark;
  final void Function(ActivityCategory) onCategoryTap;

  const _PentagonBalanceCard({
    required this.weeklyCount,
    required this.isDark,
    required this.onCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    final maxCount = weeklyCount.values.fold(0, math.max);
    final total = weeklyCount.values.fold(0, (a, b) => a + b);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // 标题行
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  '本周生活均衡度',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFF888888)
                        : const Color(0xFF999999),
                    letterSpacing: 0.3,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF2A2A2A)
                        : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '本周 $total 次',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFF666666)
                          : const Color(0xFFAAAAAA),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // 五边形图
          SizedBox(
            height: 260,
            child: _PentagonChart(
              weeklyCount: weeklyCount,
              maxCount: maxCount < 1 ? 1 : maxCount,
              isDark: isDark,
              onCategoryTap: onCategoryTap,
            ),
          ),
          // 底部五个维度图例
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ActivityCategory.values.map((cat) {
                final count = weeklyCount[cat] ?? 0;
                final catColor = _categoryColor(cat);
                return GestureDetector(
                  onTap: () => onCategoryTap(cat),
                  child: Column(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: catColor.withValues(
                              alpha: count > 0 ? 0.15 : 0.05),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: catColor.withValues(
                                alpha: count > 0 ? 0.6 : 0.2),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            cat.emoji,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        cat.label.replaceAll('力行', '').replaceAll('表达', '').replaceAll('连接', '').replaceAll('成长', '').replaceAll('专注', ''),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: count > 0
                              ? catColor
                              : (isDark
                                  ? const Color(0xFF555555)
                                  : const Color(0xFFCCCCCC)),
                        ),
                      ),
                      if (count > 0)
                        Text(
                          '$count次',
                          style: TextStyle(
                            fontSize: 9,
                            color: catColor.withValues(alpha: 0.7),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  static Color _categoryColor(ActivityCategory cat) {
    switch (cat) {
      case ActivityCategory.body:
        return const Color(0xFFFF6B35);
      case ActivityCategory.people:
        return const Color(0xFFE8507A);
      case ActivityCategory.create:
        return const Color(0xFF7C4DFF);
      case ActivityCategory.grow:
        return const Color(0xFF2E7D32);
      case ActivityCategory.flow:
        return const Color(0xFF1565C0);
    }
  }
}

// ─────────────────────────────────────────────────────────────────
//  五边形雷达图 CustomPainter
// ─────────────────────────────────────────────────────────────────

class _PentagonChart extends StatelessWidget {
  final Map<ActivityCategory, int> weeklyCount;
  final int maxCount;
  final bool isDark;
  final void Function(ActivityCategory) onCategoryTap;

  const _PentagonChart({
    required this.weeklyCount,
    required this.maxCount,
    required this.isDark,
    required this.onCategoryTap,
  });

  // 五边形顶点顺序（从顶部顺时针）：身体、关系、专注、成长、创造
  // 顶部=身体，右上=关系，右下=专注，左下=成长，左上=创造
  static const _order = [
    ActivityCategory.body,
    ActivityCategory.people,
    ActivityCategory.flow,
    ActivityCategory.grow,
    ActivityCategory.create,
  ];

  // 计算五边形的5个顶点坐标（以中心为原点，半径 r，从顶部开始顺时针）
  static List<Offset> _pentagonPoints(Offset center, double r) {
    return List.generate(5, (i) {
      final angle = -math.pi / 2 + i * 2 * math.pi / 5;
      return Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      final center = Offset(size.width / 2, size.height / 2);
      final maxR = math.min(size.width, size.height) / 2 - 48;

      // 计算每个维度的比例
      final ratios = _order.map((cat) {
        final count = weeklyCount[cat] ?? 0;
        // 最少显示10%让图形可见，最多100%
        return count > 0 ? (0.15 + 0.85 * count / maxCount).clamp(0.0, 1.0) : 0.0;
      }).toList();

      // 计算标签顶点（超出图形一段距离）
      final labelR = maxR + 36.0;
      final outerPoints = _pentagonPoints(center, maxR);
      final labelPoints = _pentagonPoints(center, labelR);

      return GestureDetector(
        onTapUp: (details) {
          // 检测点击了哪个顶点附近
          final tapPos = details.localPosition;
          for (int i = 0; i < 5; i++) {
            final lp = labelPoints[i];
            if ((tapPos - lp).distance < 36) {
              onCategoryTap(_order[i]);
              return;
            }
            // 也检测图形顶点附近
            final op = outerPoints[i];
            if ((tapPos - op).distance < 28) {
              onCategoryTap(_order[i]);
              return;
            }
          }
        },
        child: CustomPaint(
          size: size,
          painter: _PentagonPainter(
            center: center,
            maxR: maxR,
            ratios: ratios,
            order: _order,
            weeklyCount: weeklyCount,
            isDark: isDark,
          ),
        ),
      );
    });
  }
}

class _PentagonPainter extends CustomPainter {
  final Offset center;
  final double maxR;
  final List<double> ratios;
  final List<ActivityCategory> order;
  final Map<ActivityCategory, int> weeklyCount;
  final bool isDark;

  const _PentagonPainter({
    required this.center,
    required this.maxR,
    required this.ratios,
    required this.order,
    required this.weeklyCount,
    required this.isDark,
  });

  static Color _catColor(ActivityCategory cat) {
    switch (cat) {
      case ActivityCategory.body:
        return const Color(0xFFFF6B35);
      case ActivityCategory.people:
        return const Color(0xFFE8507A);
      case ActivityCategory.create:
        return const Color(0xFF7C4DFF);
      case ActivityCategory.grow:
        return const Color(0xFF2E7D32);
      case ActivityCategory.flow:
        return const Color(0xFF1565C0);
    }
  }

  List<Offset> _points(double r) {
    return List.generate(5, (i) {
      final angle = -math.pi / 2 + i * 2 * math.pi / 5;
      return Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    // ── 1. 底部网格（3层同心五边形）──────────────────────────────
    final gridPaint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.black.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int layer = 1; layer <= 3; layer++) {
      final r = maxR * layer / 3;
      final pts = _points(r);
      final path = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (int i = 1; i < 5; i++) {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    // ── 2. 从中心到顶点的辐射线 ──────────────────────────────────
    final spokePaint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.black.withValues(alpha: 0.06)
      ..strokeWidth = 1.0;

    final outerPts = _points(maxR);
    for (final pt in outerPts) {
      canvas.drawLine(center, pt, spokePaint);
    }

    // ── 3. 数据多边形（渐变填充）────────────────────────────────
    final dataPts = List.generate(5, (i) {
      final angle = -math.pi / 2 + i * 2 * math.pi / 5;
      final r = maxR * ratios[i];
      return Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );
    });

    if (ratios.any((r) => r > 0)) {
      final dataPath = Path()..moveTo(dataPts[0].dx, dataPts[0].dy);
      for (int i = 1; i < 5; i++) {
        dataPath.lineTo(dataPts[i].dx, dataPts[i].dy);
      }
      dataPath.close();

      // 混合色填充：使用第一个有值的类别颜色为主，白色透明叠加
      final fillPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF6B8FFF).withValues(alpha: 0.25),
            const Color(0xFFB57BFF).withValues(alpha: 0.12),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: maxR))
        ..style = PaintingStyle.fill;
      canvas.drawPath(dataPath, fillPaint);

      // 描边
      final strokePaint = Paint()
        ..color = const Color(0xFF7C9FFF).withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(dataPath, strokePaint);
    }

    // ── 4. 各维度顶点圆点 ────────────────────────────────────────
    for (int i = 0; i < 5; i++) {
      final cat = order[i];
      final catColor = _catColor(cat);
      final count = weeklyCount[cat] ?? 0;
      final dp = dataPts[i];

      if (count > 0) {
        // 有活动：实心彩色圆点
        canvas.drawCircle(
          dp,
          6,
          Paint()..color = catColor,
        );
        canvas.drawCircle(
          dp,
          6,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      } else {
        // 无活动：空心暗淡圆点（在中心位置画一个小点）
        final emptyPt = Offset(
          center.dx + 8 * math.cos(-math.pi / 2 + i * 2 * math.pi / 5),
          center.dy + 8 * math.sin(-math.pi / 2 + i * 2 * math.pi / 5),
        );
        canvas.drawCircle(
          emptyPt,
          4,
          Paint()
            ..color = isDark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.1)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }

    // ── 5. 各维度 Emoji + 标签（外圈） ──────────────────────────
    final labelR = maxR + 36.0;
    for (int i = 0; i < 5; i++) {
      final cat = order[i];
      final catColor = _catColor(cat);
      final count = weeklyCount[cat] ?? 0;
      final angle = -math.pi / 2 + i * 2 * math.pi / 5;
      final lx = center.dx + labelR * math.cos(angle);
      final ly = center.dy + labelR * math.sin(angle);

      // Emoji
      final emojiPainter = TextPainter(
        text: TextSpan(
          text: cat.emoji,
          style: TextStyle(
            fontSize: count > 0 ? 22 : 18,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      emojiPainter.paint(
        canvas,
        Offset(lx - emojiPainter.width / 2, ly - emojiPainter.height / 2 - 8),
      );

      // 名称标签（短版）
      final shortLabel = _shortLabel(cat);
      final labelPainter = TextPainter(
        text: TextSpan(
          text: shortLabel,
          style: TextStyle(
            fontSize: 10,
            fontWeight: count > 0 ? FontWeight.w700 : FontWeight.w400,
            color: count > 0
                ? catColor
                : (isDark
                    ? Colors.white.withValues(alpha: 0.3)
                    : Colors.black.withValues(alpha: 0.25)),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      labelPainter.paint(
        canvas,
        Offset(
            lx - labelPainter.width / 2, ly - labelPainter.height / 2 + 12),
      );
    }
  }

  String _shortLabel(ActivityCategory cat) {
    switch (cat) {
      case ActivityCategory.body:
        return '身体';
      case ActivityCategory.people:
        return '关系';
      case ActivityCategory.create:
        return '创造';
      case ActivityCategory.grow:
        return '成长';
      case ActivityCategory.flow:
        return '专注';
    }
  }

  @override
  bool shouldRepaint(_PentagonPainter old) =>
      old.ratios != ratios || old.isDark != isDark;
}

// ─────────────────────────────────────────────────────────────────
//  洞察文字条
// ─────────────────────────────────────────────────────────────────

class _InsightBar extends StatelessWidget {
  final Map<ActivityCategory, int> weeklyCount;
  final bool isDark;

  const _InsightBar({required this.weeklyCount, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final sorted = weeklyCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final total = weeklyCount.values.fold(0, (a, b) => a + b);
    final emptyCount = weeklyCount.values.where((v) => v == 0).length;

    String insight;
    Color insightColor;

    if (total == 0) {
      insight = '✨ 记录你的第一个活动，让生活五环亮起来';
      insightColor = isDark ? const Color(0xFF888888) : const Color(0xFF999999);
    } else if (emptyCount == 0) {
      insight = '🎉 五环全亮！本周生活真的很均衡';
      insightColor = const Color(0xFF2E7D32);
    } else {
      final top = sorted.first;
      final empty =
          weeklyCount.entries.where((e) => e.value == 0).map((e) => e.key);
      final emptyLabels = empty.map((c) => '${c.emoji}${_shortLabel(c)}').join('、');
      insight =
          '${top.key.emoji}${_shortLabel(top.key)} 最活跃 · $emptyLabels 还等着你';
      insightColor = isDark ? const Color(0xFF888888) : const Color(0xFF888888);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                  ),
                ],
        ),
        child: Text(
          insight,
          style: TextStyle(
            fontSize: 12.5,
            color: insightColor,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  String _shortLabel(ActivityCategory cat) {
    switch (cat) {
      case ActivityCategory.body:
        return '身体';
      case ActivityCategory.people:
        return '关系';
      case ActivityCategory.create:
        return '创造';
      case ActivityCategory.grow:
        return '成长';
      case ActivityCategory.flow:
        return '专注';
    }
  }
}

// ─────────────────────────────────────────────────────────────────
//  分组区块（每个五环维度一个）
// ─────────────────────────────────────────────────────────────────

class _CategoryGroupSection extends StatelessWidget {
  final ActivityCategory category;
  final List<ActivityDefinition> activities;
  final bool isDark;
  final DayPalette palette;
  final bool isHighlighted;
  final List<Record> allRecords;
  final void Function(ActivityDefinition) onActivityTap;
  final void Function(ActivityDefinition) onActivityLongPress;
  final VoidCallback onAddTap;

  const _CategoryGroupSection({
    required this.category,
    required this.activities,
    required this.isDark,
    required this.palette,
    required this.isHighlighted,
    required this.allRecords,
    required this.onActivityTap,
    required this.onActivityLongPress,
    required this.onAddTap,
  });

  Color get _catColor {
    switch (category) {
      case ActivityCategory.body:
        return const Color(0xFFFF6B35);
      case ActivityCategory.people:
        return const Color(0xFFE8507A);
      case ActivityCategory.create:
        return const Color(0xFF7C4DFF);
      case ActivityCategory.grow:
        return const Color(0xFF2E7D32);
      case ActivityCategory.flow:
        return const Color(0xFF1565C0);
    }
  }

  String _lastCheckInLabel(ActivityDefinition activity) {
    final records = allRecords
        .where((r) =>
            r.type == RecordType.event &&
            r.extra['activityId'] == activity.id)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (records.isEmpty) return '还没记录过';

    final last = records.first.createdAt;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDay = DateTime(last.year, last.month, last.day);
    final diff = today.difference(lastDay).inDays;

    if (diff == 0) return '今天 ✓';
    if (diff == 1) return '昨天';
    if (diff <= 6) return '$diff 天前';
    if (diff <= 13) return '上周';
    return '${(diff / 7).floor()} 周前';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      decoration: BoxDecoration(
        color: isHighlighted
            ? _catColor.withValues(alpha: isDark ? 0.12 : 0.05)
            : (isDark ? const Color(0xFF1C1C1E) : Colors.white),
        borderRadius: BorderRadius.circular(20),
        border: isHighlighted
            ? Border.all(color: _catColor.withValues(alpha: 0.4), width: 1.5)
            : Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.04),
                width: 1,
              ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 分组标题行
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                // 维度色标
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _catColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _catColor.withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      category.emoji,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1A1410),
                      ),
                    ),
                    Text(
                      activities.isEmpty
                          ? '还没有活动'
                          : '${activities.length} 个活动',
                      style: TextStyle(
                        fontSize: 11,
                        color: activities.isEmpty
                            ? _catColor.withValues(alpha: 0.6)
                            : (isDark
                                ? const Color(0xFF666666)
                                : const Color(0xFFAAAAAA)),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // 添加按钮
                GestureDetector(
                  onTap: onAddTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _catColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, size: 14, color: _catColor),
                        const SizedBox(width: 3),
                        Text(
                          '添加',
                          style: TextStyle(
                            fontSize: 12,
                            color: _catColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 活动列表 or 空状态
          if (activities.isEmpty)
            _buildEmptyState()
          else
            ...activities.map((activity) => _ActivityRow(
                  activity: activity,
                  isDark: isDark,
                  lastLabel: _lastCheckInLabel(activity),
                  catColor: _catColor,
                  onTap: () => onActivityTap(activity),
                  onLongPress: () => onActivityLongPress(activity),
                )),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: GestureDetector(
        onTap: onAddTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: _catColor.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _catColor.withValues(alpha: 0.15),
              width: 1,
              // ignore: deprecated_member_use
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.add_circle_outline_rounded,
                color: _catColor.withValues(alpha: 0.5),
                size: 24,
              ),
              const SizedBox(height: 6),
              Text(
                '为「${category.label}」添加第一个活动',
                style: TextStyle(
                  fontSize: 13,
                  color: _catColor.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
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
//  活动行（分组内的单条活动）
// ─────────────────────────────────────────────────────────────────

class _ActivityRow extends StatelessWidget {
  final ActivityDefinition activity;
  final bool isDark;
  final String lastLabel;
  final Color catColor;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ActivityRow({
    required this.activity,
    required this.isDark,
    required this.lastLabel,
    required this.catColor,
    required this.onTap,
    required this.onLongPress,
  });

  Color get _gradientStart {
    try {
      final hex = activity.gradientHex.first.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return catColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isToday = lastLabel.startsWith('今天');

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            // Emoji 圆形色块
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _gradientStart,
                    _gradientStart.withValues(alpha: 0.65),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  activity.emoji,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 名称 + 描述
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        activity.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1A1410),
                        ),
                      ),
                      if (isToday) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: _gradientStart.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '今天 ✓',
                            style: TextStyle(
                              fontSize: 9,
                              color: _gradientStart,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (activity.description.isNotEmpty)
                    Text(
                      activity.description,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? const Color(0xFF666666)
                            : const Color(0xFFBBBBBB),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            // 最近打卡时间 + 记录按钮
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isToday)
                  Text(
                    lastLabel,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark
                          ? const Color(0xFF555555)
                          : const Color(0xFFCCCCCC),
                    ),
                  ),
                const SizedBox(height: 4),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: _gradientStart.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    size: 18,
                    color: _gradientStart,
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
//  空状态引导区（首次进入）
// ─────────────────────────────────────────────────────────────────

class _EmptyGuide extends StatelessWidget {
  final bool isDark;
  final DayPalette palette;

  const _EmptyGuide({required this.isDark, required this.palette});

  @override
  Widget build(BuildContext context) {
    final accentColor = isDark ? AppColors.darkPrimary : palette.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        children: [
          // 五环预览小图示
          _MiniPentagonPreview(isDark: isDark),
          const SizedBox(height: 28),
          Text(
            '开启你的生活五环',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1A1410),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '身体 · 关系 · 创造 · 成长 · 专注\n五个维度构成完整的生活，选择你的活动\n让每一环都发出属于你的光',
            style: TextStyle(
              fontSize: 15,
              height: 1.75,
              color: isDark ? const Color(0xFF888888) : const Color(0xFF999999),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          // 五个维度小卡片预览
          ...ActivityCategory.values.map((cat) => _CategoryPreviewRow(
                category: cat,
                isDark: isDark,
              )),
          const SizedBox(height: 32),
          // 主按钮
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => _showAddSheet(context, isDark, palette),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                '选择我的活动',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: () => _showCreateSheet(context, isDark, palette),
              style: OutlinedButton.styleFrom(
                foregroundColor: accentColor,
                side: BorderSide(
                    color: accentColor.withValues(alpha: 0.5), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                '手动创建活动',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddSheet(BuildContext context, bool isDark, DayPalette palette) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddActivitySheet(isDark: isDark, palette: palette),
    );
  }

  void _showCreateSheet(
      BuildContext context, bool isDark, DayPalette palette) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          _CreateActivitySheet(isDark: isDark, palette: palette),
    );
  }
}

// 空状态里的五边形小预览
class _MiniPentagonPreview extends StatelessWidget {
  final bool isDark;
  const _MiniPentagonPreview({required this.isDark});

  static const _cats = ActivityCategory.values;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      width: 120,
      child: CustomPaint(
        painter: _MiniPentagonPainter(isDark: isDark),
      ),
    );
  }
}

class _MiniPentagonPainter extends CustomPainter {
  final bool isDark;
  const _MiniPentagonPainter({required this.isDark});

  static const _colors = [
    Color(0xFFFF6B35),
    Color(0xFFE8507A),
    Color(0xFF1565C0),
    Color(0xFF2E7D32),
    Color(0xFF7C4DFF),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2 - 8;

    // 底部五边形轮廓
    final gridPaint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final outerPts = _points(center, maxR);
    final outerPath = Path()..moveTo(outerPts[0].dx, outerPts[0].dy);
    for (int i = 1; i < 5; i++) outerPath.lineTo(outerPts[i].dx, outerPts[i].dy);
    outerPath.close();
    canvas.drawPath(outerPath, gridPaint);

    // 数据多边形（演示用，均等分布）
    const ratios = [0.85, 0.6, 0.4, 0.75, 0.5];
    final dataPts = List.generate(5, (i) {
      final angle = -math.pi / 2 + i * 2 * math.pi / 5;
      final r = maxR * ratios[i];
      return Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );
    });

    final fillPath = Path()..moveTo(dataPts[0].dx, dataPts[0].dy);
    for (int i = 1; i < 5; i++) fillPath.lineTo(dataPts[i].dx, dataPts[i].dy);
    fillPath.close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF6B8FFF).withValues(alpha: 0.3),
            const Color(0xFFB57BFF).withValues(alpha: 0.15),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: maxR))
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      fillPath,
      Paint()
        ..color = const Color(0xFF7C9FFF).withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // 顶点彩色圆
    for (int i = 0; i < 5; i++) {
      canvas.drawCircle(dataPts[i], 5, Paint()..color = _colors[i]);
    }

    // 维度 emoji（外圈）
    final emojiList = ['🏃', '❤️', '🎯', '🌱', '🎨'];
    final labelR = maxR + 14.0;
    for (int i = 0; i < 5; i++) {
      final angle = -math.pi / 2 + i * 2 * math.pi / 5;
      final lx = center.dx + labelR * math.cos(angle);
      final ly = center.dy + labelR * math.sin(angle);
      final ep = TextPainter(
        text: TextSpan(text: emojiList[i], style: const TextStyle(fontSize: 12)),
        textDirection: TextDirection.ltr,
      )..layout();
      ep.paint(canvas, Offset(lx - ep.width / 2, ly - ep.height / 2));
    }
  }

  List<Offset> _points(Offset center, double r) {
    return List.generate(5, (i) {
      final angle = -math.pi / 2 + i * 2 * math.pi / 5;
      return Offset(center.dx + r * math.cos(angle), center.dy + r * math.sin(angle));
    });
  }

  @override
  bool shouldRepaint(_MiniPentagonPainter old) => old.isDark != isDark;
}

// 空状态里的维度预览行
class _CategoryPreviewRow extends StatelessWidget {
  final ActivityCategory category;
  final bool isDark;

  const _CategoryPreviewRow({required this.category, required this.isDark});

  Color get _catColor {
    switch (category) {
      case ActivityCategory.body:
        return const Color(0xFFFF6B35);
      case ActivityCategory.people:
        return const Color(0xFFE8507A);
      case ActivityCategory.create:
        return const Color(0xFF7C4DFF);
      case ActivityCategory.grow:
        return const Color(0xFF2E7D32);
      case ActivityCategory.flow:
        return const Color(0xFF1565C0);
    }
  }

  String get _description {
    switch (category) {
      case ActivityCategory.body:
        return '运动、健身、照顾好自己的身体';
      case ActivityCategory.people:
        return '亲情、爱情、友情，与重要的人连接';
      case ActivityCategory.create:
        return '写作、绘画、烹饪，从无到有的创造';
      case ActivityCategory.grow:
        return '阅读、冥想、学习，让内心更丰盈';
      case ActivityCategory.flow:
        return '深度工作、专注投入，进入心流状态';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _catColor.withValues(alpha: isDark ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _catColor.withValues(alpha: isDark ? 0.2 : 0.12),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Text(category.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _catColor,
                  ),
                ),
                Text(
                  _description,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? const Color(0xFF666666)
                        : const Color(0xFFAAAAAA),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  添加活动底部弹窗（预置库多选，支持按五环维度筛选）
// ─────────────────────────────────────────────────────────────────

class _AddActivitySheet extends StatefulWidget {
  final bool isDark;
  final DayPalette palette;
  final ActivityCategory? initialCategory;

  const _AddActivitySheet({
    required this.isDark,
    required this.palette,
    this.initialCategory,
  });

  @override
  State<_AddActivitySheet> createState() => _AddActivitySheetState();
}

class _AddActivitySheetState extends State<_AddActivitySheet> {
  final Set<String> _selectedIds = {};
  ActivityCategory? _activeCategory;
  bool _isSaving = false;

  bool get _isDark => widget.isDark;
  DayPalette get _palette => widget.palette;
  Color get _accent => _isDark ? AppColors.darkPrimary : _palette.primary;

  @override
  void initState() {
    super.initState();
    _activeCategory = widget.initialCategory;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ActivityCollectionProvider>();
      setState(() {
        for (final preset in ActivityPresets.all) {
          if (provider.contains(preset.id)) {
            _selectedIds.add(preset.id);
          }
        }
      });
    });
  }

  List<ActivityDefinition> get _filteredPresets {
    if (_activeCategory == null) return ActivityPresets.all;
    return ActivityPresets.all
        .where((a) => a.category == _activeCategory)
        .toList();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final provider = context.read<ActivityCollectionProvider>();
    final toAdd =
        ActivityPresets.all.where((p) => _selectedIds.contains(p.id)).toList();
    await provider.addPresets(toAdd);
    final toRemove = ActivityPresets.all
        .where(
            (p) => !_selectedIds.contains(p.id) && provider.contains(p.id))
        .toList();
    for (final a in toRemove) {
      await provider.remove(a.id);
    }
    if (mounted) Navigator.pop(context);
  }

  Color _catColor(ActivityCategory cat) {
    switch (cat) {
      case ActivityCategory.body:
        return const Color(0xFFFF6B35);
      case ActivityCategory.people:
        return const Color(0xFFE8507A);
      case ActivityCategory.create:
        return const Color(0xFF7C4DFF);
      case ActivityCategory.grow:
        return const Color(0xFF2E7D32);
      case ActivityCategory.flow:
        return const Color(0xFF1565C0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final selectedCount =
        _selectedIds.where((id) => !_isAlreadyInCollection(id)).length;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: _isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 拖拽把手
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // 标题行
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '选择活动',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _isDark ? Colors.white : const Color(0xFF1A1410),
                      ),
                    ),
                    Text(
                      '按五环维度找到适合你的活动',
                      style: TextStyle(
                        fontSize: 12,
                        color: _isDark
                            ? const Color(0xFF888888)
                            : const Color(0xFFAAAAAA),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (ctx) => _CreateActivitySheet(
                        isDark: _isDark,
                        palette: _palette,
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  child: Text(
                    '自定义',
                    style: TextStyle(
                      color: _accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 五环维度筛选：大卡片横向滚动
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // 「全部」按钮
                _RingFilterChip(
                  label: '全部',
                  emoji: '✦',
                  isSelected: _activeCategory == null,
                  color: _accent,
                  isDark: _isDark,
                  onTap: () => setState(() => _activeCategory = null),
                ),
                ...ActivityCategory.values.map((cat) => _RingFilterChip(
                      label: cat.label,
                      emoji: cat.emoji,
                      isSelected: _activeCategory == cat,
                      color: _catColor(cat),
                      isDark: _isDark,
                      onTap: () => setState(() => _activeCategory = cat),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // 预置活动网格
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.88,
              ),
              itemCount: _filteredPresets.length,
              itemBuilder: (ctx, i) {
                final preset = _filteredPresets[i];
                final isSelected = _selectedIds.contains(preset.id);
                return _PresetActivityCard(
                  preset: preset,
                  isSelected: isSelected,
                  isDark: _isDark,
                  ringColor: _catColor(preset.category),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      if (isSelected) {
                        _selectedIds.remove(preset.id);
                      } else {
                        _selectedIds.add(preset.id);
                      }
                    });
                  },
                );
              },
            ),
          ),
          // 底部确认
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _selectedIds.isEmpty
                              ? '确认（未选择）'
                              : '加入活动集（${_selectedIds.length} 项）',
                          style: const TextStyle(
                            fontSize: 15,
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

  bool _isAlreadyInCollection(String id) {
    return false;
  }
}

class _RingFilterChip extends StatelessWidget {
  final String label;
  final String emoji;
  final bool isSelected;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _RingFilterChip({
    required this.label,
    required this.emoji,
    required this.isSelected,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.12)
              : (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF2F2F2)),
          borderRadius: BorderRadius.circular(14),
          border: isSelected
              ? Border.all(color: color, width: 1.5)
              : Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.06),
                  width: 1,
                ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? color
                    : (isDark ? Colors.white60 : const Color(0xFF666666)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  预置活动选择卡片
// ─────────────────────────────────────────────────────────────────

class _PresetActivityCard extends StatelessWidget {
  final ActivityDefinition preset;
  final bool isSelected;
  final bool isDark;
  final Color ringColor;
  final VoidCallback onTap;

  const _PresetActivityCard({
    required this.preset,
    required this.isSelected,
    required this.isDark,
    required this.ringColor,
    required this.onTap,
  });

  Color get _gradientStart {
    try {
      final hex = preset.gradientHex.first.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return ringColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isSelected
              ? _gradientStart.withValues(alpha: 0.12)
              : (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF7F7F7)),
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: _gradientStart, width: 2)
              : Border.all(
                  color: isDark
                      ? const Color(0xFF333333)
                      : const Color(0xFFEEEEEE),
                  width: 1,
                ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _gradientStart.withValues(alpha: 0.15)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.03)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(preset.emoji, style: const TextStyle(fontSize: 26)),
                  ),
                ),
                if (isSelected)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: _gradientStart,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                          width: 2,
                        ),
                      ),
                      child: const Icon(Icons.check, size: 11, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              preset.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? _gradientStart
                    : (isDark ? Colors.white70 : const Color(0xFF333333)),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: ringColor.withValues(alpha: isSelected ? 0.15 : 0.07),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(preset.category.emoji, style: const TextStyle(fontSize: 8)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  手动创建活动底部弹窗
// ─────────────────────────────────────────────────────────────────

class _CreateActivitySheet extends StatefulWidget {
  final bool isDark;
  final DayPalette palette;

  const _CreateActivitySheet({required this.isDark, required this.palette});

  @override
  State<_CreateActivitySheet> createState() => _CreateActivitySheetState();
}

class _CreateActivitySheetState extends State<_CreateActivitySheet> {
  final _nameController = TextEditingController();
  final _nameFocus = FocusNode();
  String _selectedEmoji = '🎯';
  ActivityCategory _selectedCategory = ActivityCategory.body;
  bool _isSaving = false;

  bool get _isDark => widget.isDark;
  Color get _accent => _isDark ? AppColors.darkPrimary : widget.palette.primary;

  static const _emojiOptions = [
    '🎯', '🏃', '🏊', '🚴', '⛰️', '🎵', '🎨', '📚', '✍️', '🍳',
    '🧘', '💪', '🎸', '📷', '🤸', '🎭', '🌊', '🏋️', '⚽', '🎾',
    '🎲', '🌿', '☕', '🎬', '🎮', '🧩', '🌍', '🦋', '🌸', '💼',
    '🚀', '📔', '🌙', '🎙️', '🫶', '🗣️', '🤝', '🥂', '📞', '💑',
  ];

  Color _catColor(ActivityCategory cat) {
    switch (cat) {
      case ActivityCategory.body:   return const Color(0xFFFF6B35);
      case ActivityCategory.people: return const Color(0xFFE8507A);
      case ActivityCategory.create: return const Color(0xFF7C4DFF);
      case ActivityCategory.grow:   return const Color(0xFF2E7D32);
      case ActivityCategory.flow:   return const Color(0xFF1565C0);
    }
  }

  String _catDescription(ActivityCategory cat) {
    switch (cat) {
      case ActivityCategory.body:   return '运动、健身、照顾好自己的身体';
      case ActivityCategory.people: return '亲情、爱情、友情，与重要的人连接';
      case ActivityCategory.create: return '写作、绘画、烹饪，从无到有的创造';
      case ActivityCategory.grow:   return '阅读、冥想、学习，让内心更丰盈';
      case ActivityCategory.flow:   return '深度工作、专注投入，进入心流状态';
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _nameFocus.requestFocus());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      await context.read<ActivityCollectionProvider>().createCustom(
            name: name,
            emoji: _selectedEmoji,
            category: _selectedCategory,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final currentCatColor = _catColor(_selectedCategory);

    return Container(
      decoration: BoxDecoration(
        color: _isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                '创建活动',
                style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800,
                  color: _isDark ? Colors.white : const Color(0xFF1A1410),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '为你独特的活动起个名字',
                style: TextStyle(
                  fontSize: 13,
                  color: _isDark ? const Color(0xFF666666) : const Color(0xFFAAAAAA),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _emojiOptions.length,
                  separatorBuilder: (_, i) => const SizedBox(width: 8),
                  itemBuilder: (ctx, i) {
                    final emoji = _emojiOptions[i];
                    final isSelected = _selectedEmoji == emoji;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedEmoji = emoji),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? currentCatColor.withValues(alpha: 0.15)
                              : (_isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5)),
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected
                              ? Border.all(color: currentCatColor, width: 1.5)
                              : null,
                        ),
                        child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                focusNode: _nameFocus,
                style: TextStyle(
                  fontSize: 16,
                  color: _isDark ? Colors.white : const Color(0xFF1A1410),
                ),
                decoration: InputDecoration(
                  hintText: '给活动起个名字，如：晨跑、画水彩...',
                  hintStyle: TextStyle(
                    color: _isDark ? const Color(0xFF555555) : const Color(0xFFCCCCCC),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: _isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '属于哪个维度？',
                style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: _isDark ? const Color(0xFF888888) : const Color(0xFF999999),
                ),
              ),
              const SizedBox(height: 8),
              ...ActivityCategory.values.map((cat) {
                final isSelected = _selectedCategory == cat;
                final catColor = _catColor(cat);
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? catColor.withValues(alpha: 0.1)
                          : (_isDark ? const Color(0xFF252525) : const Color(0xFFF7F7F7)),
                      borderRadius: BorderRadius.circular(14),
                      border: isSelected
                          ? Border.all(color: catColor, width: 1.5)
                          : Border.all(
                              color: _isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : Colors.black.withValues(alpha: 0.06),
                              width: 1,
                            ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: catColor.withValues(alpha: isSelected ? 0.18 : 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(child: Text(cat.emoji, style: const TextStyle(fontSize: 18))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cat.label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected
                                      ? catColor
                                      : (_isDark ? Colors.white70 : const Color(0xFF333333)),
                                ),
                              ),
                              Text(
                                _catDescription(cat),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isSelected
                                      ? catColor.withValues(alpha: 0.7)
                                      : (_isDark ? const Color(0xFF555555) : const Color(0xFFBBBBBB)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(Icons.check_circle_rounded, color: catColor, size: 20),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
              ListenableBuilder(
                listenable: _nameController,
                builder: (ctx, _) {
                  final name = _nameController.text.trim();
                  return SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: currentCatColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              '创建「$_selectedEmoji ${name.isEmpty ? '活动' : name}」',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
