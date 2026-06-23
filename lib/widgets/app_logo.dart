import 'dart:math' as math;
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  AppLogo —— 「瞬间」App 矢量 Logo
//
//  设计语言：
//  • 外圆：温暖橙金渐变圆盘，带柔光晕影
//  • 中心：一支纤细羽毛笔（象征记录与书写）
//  • 放射光芒：8 条长短交替的细线（象征时光流动与"瞬间"的光）
//  • 配色：与 WeeklyTheme 橙金主色呼应
//
//  尺寸：默认 100×100，可通过 size 参数自由缩放
// ─────────────────────────────────────────────────────────────────────────────

class AppLogo extends StatefulWidget {
  /// logo 尺寸（正方形宽高）
  final double size;

  /// 是否播放呼吸动画
  final bool animate;

  /// 强制使用的主色（为 null 时使用橙金默认色）
  final Color? primaryColor;

  /// 强制使用的高亮色
  final Color? lightColor;

  const AppLogo({
    super.key,
    this.size = 100,
    this.animate = true,
    this.primaryColor,
    this.lightColor,
  });

  @override
  State<AppLogo> createState() => _AppLogoState();
}

class _AppLogoState extends State<AppLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _breatheAnim;
  late Animation<double> _rotateAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    _breatheAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.06)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.06, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
    ]).animate(_controller);

    _rotateAnim = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );

    if (widget.animate) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = widget.primaryColor ?? const Color(0xFFE07818);
    final light = widget.lightColor ?? const Color(0xFFF5973A);

    if (!widget.animate) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: _LogoPainter(
            primary: primary,
            light: light,
            breatheScale: 1.0,
            rayRotation: 0.0,
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _LogoPainter(
              primary: primary,
              light: light,
              breatheScale: _breatheAnim.value,
              rayRotation: _rotateAnim.value * 0.03, // 慢速微旋转，更有生命感
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _LogoPainter —— 实际绘制逻辑
// ─────────────────────────────────────────────────────────────────────────────

class _LogoPainter extends CustomPainter {
  final Color primary;
  final Color light;
  final double breatheScale;
  final double rayRotation;

  const _LogoPainter({
    required this.primary,
    required this.light,
    required this.breatheScale,
    required this.rayRotation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(breatheScale);
    canvas.translate(-center.dx, -center.dy);

    // ── 1. 外发光晕 ──────────────────────────────────────────────────────────
    final glowPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18)
      ..shader = RadialGradient(
        colors: [
          primary.withValues(alpha: 0.45),
          primary.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(center: center, radius: radius * 1.2),
      );
    canvas.drawCircle(center, radius * 1.15, glowPaint);

    // ── 2. 主圆背景（渐变圆盘）────────────────────────────────────────────────
    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.4),
        radius: 1.0,
        colors: [
          light,
          primary,
          Color.lerp(primary, const Color(0xFFB85E08), 0.6)!,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(
        Rect.fromCircle(center: center, radius: radius),
      );
    canvas.drawCircle(center, radius * 0.88, bgPaint);

    // ── 3. 圆盘内边高光弧 ─────────────────────────────────────────────────────
    final innerHighlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.025
      ..shader = SweepGradient(
        startAngle: -math.pi * 0.7,
        endAngle: math.pi * 0.3,
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.55),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(center: center, radius: radius * 0.82),
      );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.82),
      -math.pi * 0.7,
      math.pi,
      false,
      innerHighlightPaint,
    );

    // ── 4. 放射光芒 ───────────────────────────────────────────────────────────
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rayRotation);
    canvas.translate(-center.dx, -center.dy);

    _drawRays(canvas, center, radius);

    canvas.restore();

    // ── 5. 中心装饰圆（内圆）──────────────────────────────────────────────────
    final innerCirclePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.25),
          Colors.white.withValues(alpha: 0.05),
        ],
      ).createShader(
        Rect.fromCircle(center: center, radius: radius * 0.38),
      );
    canvas.drawCircle(center, radius * 0.38, innerCirclePaint);

    // ── 6. 羽毛笔图标 ─────────────────────────────────────────────────────────
    _drawPen(canvas, center, radius);

    // ── 7. 顶部小光点（点睛之笔）─────────────────────────────────────────────
    _drawSparkles(canvas, center, radius);

    canvas.restore();
  }

  /// 绘制 8 条放射光芒（长短交替，细腻优雅）
  void _drawRays(Canvas canvas, Offset center, double radius) {
    const rayCount = 16;
    const angleStep = 2 * math.pi / rayCount;

    for (int i = 0; i < rayCount; i++) {
      final angle = i * angleStep - math.pi / 2;
      final isLong = i % 2 == 0;

      final innerR = radius * 0.92; // 从圆盘边缘往外延伸
      final outerR = isLong ? radius * 1.25 : radius * 1.12;
      final strokeW = isLong ? radius * 0.028 : radius * 0.018;

      final start = Offset(
        center.dx + math.cos(angle) * innerR,
        center.dy + math.sin(angle) * innerR,
      );
      final end = Offset(
        center.dx + math.cos(angle) * outerR,
        center.dy + math.sin(angle) * outerR,
      );

      // 光芒颜色：中段亮、末端透明
      final rayPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeW
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: isLong ? 0.9 : 0.65),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(
          Rect.fromPoints(start, end),
        );

      canvas.drawLine(start, end, rayPaint);
    }
  }

  /// 绘制中心羽毛笔（代表记录与书写）
  void _drawPen(Canvas canvas, Offset center, double radius) {
    final s = radius * 0.38; // 笔的半尺寸
    final penColor = Colors.white;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    // 笔稍微倾斜，更自然
    canvas.rotate(-math.pi / 6);

    final penPaint = Paint()
      ..color = penColor.withValues(alpha: 0.95)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = penColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.015;

    // ── 笔杆（圆角矩形）
    final barRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(0, -s * 0.05),
        width: s * 0.26,
        height: s * 1.3,
      ),
      Radius.circular(s * 0.13),
    );
    canvas.drawRRect(barRect, penPaint);
    canvas.drawRRect(barRect, strokePaint);

    // ── 笔尖（三角形）
    final tipPath = Path();
    final tipTop = Offset(0, s * 0.6);
    tipPath.moveTo(-s * 0.13, s * 0.5);
    tipPath.lineTo(s * 0.13, s * 0.5);
    tipPath.lineTo(tipTop.dx, tipTop.dy + s * 0.28);
    tipPath.close();

    final tipPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    canvas.drawPath(tipPath, tipPaint);

    // ── 笔夹（细条）
    final clipPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.018
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(s * 0.13, -s * 0.52),
      Offset(s * 0.13, s * 0.22),
      clipPaint,
    );

    // ── 笔帽分割线
    final capPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.022;
    canvas.drawLine(
      Offset(-s * 0.13, -s * 0.35),
      Offset(s * 0.13, -s * 0.35),
      capPaint,
    );

    // ── 笔帽顶部高光点
    final capTopPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(0, -s * 0.62), s * 0.07, capTopPaint);

    // ── 笔尖光点（书写的墨水珠）
    final inkPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(0, tipTop.dy + s * 0.28), s * 0.055, inkPaint);

    canvas.restore();
  }

  /// 绘制三颗散落的星光点（活跃感）
  void _drawSparkles(Canvas canvas, Offset center, double radius) {
    final sparkPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    // 三颗大小不一的光点，散落在圆盘右上区域
    final sparkles = [
      (Offset(radius * 0.42, -radius * 0.56), radius * 0.055),
      (Offset(radius * 0.60, -radius * 0.30), radius * 0.035),
      (Offset(radius * 0.24, -radius * 0.70), radius * 0.028),
    ];

    for (final (pos, r) in sparkles) {
      _drawStar4(canvas, center + pos, r, sparkPaint);
    }
  }

  /// 绘制四瓣星形（+ 形）
  void _drawStar4(Canvas canvas, Offset pos, double r, Paint paint) {
    final path = Path();
    const arms = 4;
    for (int i = 0; i < arms; i++) {
      final angle = i * math.pi / 2 - math.pi / 4;
      final tipAngle = angle + math.pi / arms;
      path.lineTo(
        pos.dx + math.cos(angle) * r,
        pos.dy + math.sin(angle) * r,
      );
      path.lineTo(
        pos.dx + math.cos(tipAngle) * r * 0.35,
        pos.dy + math.sin(tipAngle) * r * 0.35,
      );
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_LogoPainter oldDelegate) {
    return oldDelegate.breatheScale != breatheScale ||
        oldDelegate.rayRotation != rayRotation ||
        oldDelegate.primary != primary ||
        oldDelegate.light != light;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  AppLogoSmall —— 小尺寸静态版（用于 AppBar / 列表等）
// ─────────────────────────────────────────────────────────────────────────────

class AppLogoSmall extends StatelessWidget {
  final double size;
  final Color? primaryColor;
  final Color? lightColor;

  const AppLogoSmall({
    super.key,
    this.size = 36,
    this.primaryColor,
    this.lightColor,
  });

  @override
  Widget build(BuildContext context) {
    return AppLogo(
      size: size,
      animate: false,
      primaryColor: primaryColor,
      lightColor: lightColor,
    );
  }
}
