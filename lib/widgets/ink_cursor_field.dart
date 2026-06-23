import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../providers/cursor_style_provider.dart';

/// 仿「纯纯手写」的自定义光标 TextField
///
/// 支持三种光标风格（通过 [cursorStyle] 切换）：
/// - [CursorStyle.inkDrop]  墨滴：呼吸发光 + 粒子拖尾 + 点击涟漪
/// - [CursorStyle.neon]     霓虹：渐变强发光竖线，无粒子
/// - [CursorStyle.minimal]  极简：纯细线，无任何特效
class InkCursorField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final int? maxLines;
  final int? minLines;
  final TextStyle? style;
  final InputDecoration? decoration;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final Color cursorColor;
  final CursorStyle cursorStyle;

  const InkCursorField({
    super.key,
    required this.controller,
    required this.focusNode,
    this.maxLines,
    this.minLines,
    this.style,
    this.decoration,
    this.keyboardType,
    this.onChanged,
    this.cursorColor = const Color(0xFF7C5CBF),
    this.cursorStyle = CursorStyle.inkDrop,
  });

  @override
  State<InkCursorField> createState() => _InkCursorFieldState();
}

class _InkCursorFieldState extends State<InkCursorField>
    with TickerProviderStateMixin {
  // ── 呼吸发光脉冲（周期 900ms，inkDrop / neon 用） ──
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  // ── 涟漪动画（inkDrop 用，400ms 单次） ──
  late final AnimationController _rippleCtrl;
  late final Animation<double> _rippleAnim;

  // ── 光标位置缓动（360ms easeOutCubic） ──
  late final AnimationController _moveCtrl;
  late final CurvedAnimation _moveAnim;
  Offset _cursorFrom = Offset.zero;
  Offset _cursorTo   = Offset.zero;

  // ── 墨水粒子（inkDrop 用） ──
  final List<_InkParticle> _particles = [];

  Offset _rippleOffset = Offset.zero;
  int _lastTextLength = 0;

  // ── 打字速度检测 ──
  // 记录最近 5 次按键时间戳，用于计算打字频率
  final List<int> _keyTimestamps = [];
  static const _maxTimestamps = 5;

  /// 计算当前打字节奏（毫秒/字，越小代表越快）
  /// 返回 0 ~ 1000+，超过 800 视为缓慢/停顿
  double get _msPerChar {
    if (_keyTimestamps.length < 2) return 800;
    // 取最近几次间隔的均值
    double total = 0;
    for (int i = 1; i < _keyTimestamps.length; i++) {
      total += _keyTimestamps[i] - _keyTimestamps[i - 1];
    }
    return total / (_keyTimestamps.length - 1);
  }

  /// 根据打字速度计算粒子参数
  /// 返回 (count, radiusScale, speedScale)
  ({int count, double radiusScale, double speedScale}) get _inkIntensity {
    final ms = _msPerChar;
    if (ms < 150) {
      // 极快：连续快敲，较多粒子
      return (count: 3, radiusScale: 1.0, speedScale: 1.0);
    } else if (ms < 350) {
      // 正常节奏
      return (count: 2, radiusScale: 0.75, speedScale: 0.8);
    } else if (ms < 700) {
      // 慢速：偶尔一字
      return (count: 1, radiusScale: 0.55, speedScale: 0.6);
    } else {
      // 停顿后第一个字：极少墨水
      return (count: 1, radiusScale: 0.4, speedScale: 0.5);
    }
  }

  final _fieldKey = GlobalKey();

  Offset get _cursorOffset => Offset.lerp(_cursorFrom, _cursorTo, _moveAnim.value)!;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);
    // 粒子由 pulse 帧驱动
    _pulseCtrl.addListener(_tickParticles);

    _rippleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _rippleAnim = CurvedAnimation(parent: _rippleCtrl, curve: Curves.easeOut);

    _moveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _moveAnim = CurvedAnimation(parent: _moveCtrl, curve: Curves.easeOutCubic);

    widget.controller.addListener(_onTextChanged);
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _rippleCtrl.dispose();
    _moveCtrl.dispose();
    _moveAnim.dispose();
    widget.controller.removeListener(_onTextChanged);
    widget.focusNode.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final newLen = widget.controller.text.length;
    final isTyping = newLen > _lastTextLength;
    _lastTextLength = newLen;

    if (isTyping && widget.cursorStyle == CursorStyle.inkDrop) {
      // 记录按键时间戳，超过 800ms 间隔视为新一轮输入，重置历史
      final now = DateTime.now().millisecondsSinceEpoch;
      if (_keyTimestamps.isNotEmpty && now - _keyTimestamps.last > 800) {
        _keyTimestamps.clear();
      }
      _keyTimestamps.add(now);
      if (_keyTimestamps.length > _maxTimestamps) {
        _keyTimestamps.removeAt(0);
      }
    }

    // 先更新光标位置，回调完成后再撒粒子（确保位置已经更新）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateCursorPosition();
      if (isTyping && widget.cursorStyle == CursorStyle.inkDrop) {
        final ink = _inkIntensity;
        _spawnInkParticles(
          _cursorTo,
          count: ink.count,
          radiusScale: ink.radiusScale,
          speedScale: ink.speedScale,
          burst: false,
        );
      }
    });
  }

  void _onFocusChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateCursorPosition());
    setState(() {});
  }

  void _updateCursorPosition() {
    if (!mounted) return;
    final selection = widget.controller.selection;
    if (selection.baseOffset < 0) return;

    final fieldBox = _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (fieldBox == null) return;

    RenderEditable? editable;
    void findEditable(RenderObject obj) {
      if (editable != null) return;
      if (obj is RenderEditable) { editable = obj; return; }
      obj.visitChildren(findEditable);
    }
    findEditable(fieldBox);
    if (editable == null) return;

    final caretRect = editable!.getLocalRectForCaret(
      TextPosition(offset: selection.baseOffset.clamp(0, widget.controller.text.length)),
    );
    final editableBox = editable! as RenderBox;
    final caretGlobal = editableBox.localToGlobal(Offset(caretRect.left, caretRect.center.dy));
    final newTarget = fieldBox.globalToLocal(caretGlobal);

    _moveCursorTo(newTarget);
  }

  void _moveCursorTo(Offset target) {
    if (!mounted) return;
    final dist = (target - _cursorTo).distance;
    if (dist < 0.5) return;

    if (widget.cursorStyle == CursorStyle.inkDrop) {
      if (dist > 20) {
        // 光标跳远：涟漪 + 爆散粒子
        _rippleOffset = target;
        _rippleCtrl.forward(from: 0);
        _spawnInkParticles(target, count: 5, burst: true);
      } else if (dist > 4) {
        // 普通移动（点击同行不同位置）：少量粒子
        _spawnInkParticles(target, count: 2, burst: false);
      }
    }

    _cursorFrom = _cursorOffset;
    _cursorTo   = target;
    _moveCtrl.forward(from: 0);
  }

  /// 在 [origin] 处喷射墨水粒子
  /// [count]       粒子数量
  /// [radiusScale] 半径倍率（由打字速度决定，0.4~1.0）
  /// [speedScale]  速度倍率（由打字速度决定，0.5~1.0）
  /// [burst]       true = 四面八方爆开（光标跳远时用），false = 向右侧/右上扇形（打字时用）
  void _spawnInkParticles(
    Offset origin, {
    int count = 2,
    double radiusScale = 0.6,
    double speedScale = 0.7,
    bool burst = false,
  }) {
    if (!mounted) return;
    // 保持粒子总数上限，避免积压
    if (_particles.length > 10) {
      _particles.removeRange(0, _particles.length - 6);
    }
    final rng = math.Random();
    for (int i = 0; i < count; i++) {
      final double angle;
      if (burst) {
        // 爆散：360° 随机
        angle = rng.nextDouble() * math.pi * 2;
      } else {
        // 打字：向右为主，扇形 ±60°，同时略偏上（-π/6）
        angle = -math.pi / 6 + (rng.nextDouble() - 0.5) * math.pi * (2 / 3);
      }
      _particles.add(_InkParticle(
        origin: origin,
        angle: angle,
        // 基础速度 30~70 px/s，乘以速度倍率
        speed: (30 + rng.nextDouble() * 40) * speedScale,
        // 基础半径 1.5~3.0 px，乘以半径倍率
        radius: (1.5 + rng.nextDouble() * 1.5) * radiusScale,
        life: 1.0,
        color: widget.cursorColor,
      ));
    }
  }

  void _tickParticles() {
    if (_particles.isEmpty) return;
    const dt = 0.016;
    for (final p in _particles) {
      p.life -= dt * 2.2; // 约 0.45s 消散（比之前更慢，看得更清楚）
      p.origin = Offset(
        p.origin.dx + math.cos(p.angle) * p.speed * dt,
        p.origin.dy + math.sin(p.angle) * p.speed * dt,
      );
    }
    _particles.removeWhere((p) => p.life <= 0);
  }

  @override
  Widget build(BuildContext context) {
    final lineHeight = (widget.style?.fontSize ?? 16) * (widget.style?.height ?? 1.7);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        TextField(
          key: _fieldKey,
          controller: widget.controller,
          focusNode: widget.focusNode,
          maxLines: widget.maxLines,
          minLines: widget.minLines,
          keyboardType: widget.keyboardType,
          style: widget.style,
          decoration: widget.decoration,
          onChanged: (v) => widget.onChanged?.call(v),
          onTap: () => WidgetsBinding.instance
              .addPostFrameCallback((_) => _updateCursorPosition()),
          cursorColor: Colors.transparent,
          cursorWidth: 0,
        ),

        if (widget.focusNode.hasFocus)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: Listenable.merge([_pulseAnim, _rippleAnim, _moveCtrl]),
                builder: (context, child) => CustomPaint(
                  painter: _InkCursorPainter(
                    cursorOffset: _cursorOffset,
                    rippleOffset: _rippleOffset,
                    rippleProgress: _rippleAnim.value,
                    pulseValue: _pulseAnim.value,
                    particles: List.unmodifiable(_particles),
                    color: widget.cursorColor,
                    lineHeight: lineHeight,
                    style: widget.cursorStyle,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  墨水粒子数据模型
// ─────────────────────────────────────────────────────────────────

class _InkParticle {
  Offset origin;
  double angle;
  double speed;
  double radius;
  double life;
  Color color;

  _InkParticle({
    required this.origin,
    required this.angle,
    required this.speed,
    required this.radius,
    required this.life,
    required this.color,
  });
}

// ─────────────────────────────────────────────────────────────────
//  CustomPainter：三种风格分支绘制
// ─────────────────────────────────────────────────────────────────

class _InkCursorPainter extends CustomPainter {
  final Offset cursorOffset;
  final Offset rippleOffset;
  final double rippleProgress;
  final double pulseValue;
  final List<_InkParticle> particles;
  final Color color;
  final double lineHeight;
  final CursorStyle style;

  const _InkCursorPainter({
    required this.cursorOffset,
    required this.rippleOffset,
    required this.rippleProgress,
    required this.pulseValue,
    required this.particles,
    required this.color,
    required this.lineHeight,
    required this.style,
  });

  @override
  void paint(Canvas canvas, Size size) {
    switch (style) {
      case CursorStyle.inkDrop:
        _paintInkDrop(canvas);
      case CursorStyle.neon:
        _paintNeon(canvas);
      case CursorStyle.minimal:
        _paintMinimal(canvas);
    }
  }

  // ── 风格①：墨滴（原有效果） ──────────────────────────────────

  void _paintInkDrop(Canvas canvas) {
    // 涟漪
    if (rippleProgress > 0 && rippleProgress < 1) {
      canvas.drawCircle(
        rippleOffset, rippleProgress * 26,
        Paint()
          ..color = color.withValues(alpha: (1 - rippleProgress) * 0.30)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      if (rippleProgress < 0.55) {
        canvas.drawCircle(
          rippleOffset, rippleProgress * 11,
          Paint()
            ..color = color.withValues(alpha: (0.55 - rippleProgress) * 0.40)
            ..style = PaintingStyle.fill,
        );
      }
    }

    // 粒子拖尾
    for (final p in particles) {
      final op = (p.life * 0.9).clamp(0.0, 0.9);
      final r = p.radius * p.life;

      // 外层软晕（模糊扩散，模拟墨水晕染）
      canvas.drawCircle(p.origin, r * 3.0,
          Paint()
            ..color = p.color.withValues(alpha: op * 0.18)
            ..style = PaintingStyle.fill
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 1.5));

      // 中层晕
      canvas.drawCircle(p.origin, r * 1.6,
          Paint()
            ..color = p.color.withValues(alpha: op * 0.35)
            ..style = PaintingStyle.fill);

      // 核心实心圆点
      canvas.drawCircle(p.origin, r,
          Paint()
            ..color = p.color.withValues(alpha: op)
            ..style = PaintingStyle.fill);
    }

    // 光标线
    final halfH = lineHeight / 2 - 1;
    final top    = Offset(cursorOffset.dx, cursorOffset.dy - halfH);
    final bottom = Offset(cursorOffset.dx, cursorOffset.dy + halfH);

    // 外发光
    final glowR = 3.0 + pulseValue * 4;
    canvas.drawLine(top, bottom,
        Paint()
          ..color = color.withValues(alpha: 0.10 + pulseValue * 0.18)
          ..strokeWidth = glowR
          ..strokeCap = StrokeCap.round
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowR / 2));

    // 主线
    final mainOp = 0.75 + pulseValue * 0.25;
    canvas.drawLine(top, bottom,
        Paint()
          ..color = color.withValues(alpha: mainOp)
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round);

    // 笔尖圆点
    canvas.drawCircle(top, 2.5,
        Paint()..color = color.withValues(alpha: mainOp)..style = PaintingStyle.fill);
  }

  // ── 风格②：霓虹 ─────────────────────────────────────────────

  void _paintNeon(Canvas canvas) {
    final halfH = lineHeight / 2 - 1;
    final top    = Offset(cursorOffset.dx, cursorOffset.dy - halfH);
    final bottom = Offset(cursorOffset.dx, cursorOffset.dy + halfH);

    // 最外层大光晕（随呼吸膨胀）
    final outerGlow = 8.0 + pulseValue * 10;
    canvas.drawLine(top, bottom,
        Paint()
          ..color = color.withValues(alpha: 0.06 + pulseValue * 0.10)
          ..strokeWidth = outerGlow
          ..strokeCap = StrokeCap.round
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, outerGlow * 0.7));

    // 中层光晕
    final midGlow = 4.0 + pulseValue * 4;
    canvas.drawLine(top, bottom,
        Paint()
          ..color = color.withValues(alpha: 0.20 + pulseValue * 0.20)
          ..strokeWidth = midGlow
          ..strokeCap = StrokeCap.round
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, midGlow * 0.4));

    // 渐变主线（用 shader）
    final grad = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        color.withValues(alpha: 0.6 + pulseValue * 0.4),
        HSLColor.fromColor(color).withLightness(
          (HSLColor.fromColor(color).lightness + 0.2).clamp(0.0, 1.0),
        ).toColor().withValues(alpha: 0.9 + pulseValue * 0.1),
        color.withValues(alpha: 0.6 + pulseValue * 0.4),
      ],
    );
    final rect = Rect.fromPoints(top, bottom);
    canvas.drawLine(top, bottom,
        Paint()
          ..shader = grad.createShader(rect)
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round);

    // 顶部亮点
    canvas.drawCircle(top, 2.0 + pulseValue * 1.5,
        Paint()..color = Colors.white.withValues(alpha: 0.7 + pulseValue * 0.3)..style = PaintingStyle.fill);
    // 底部小亮点
    canvas.drawCircle(bottom, 1.5,
        Paint()..color = color.withValues(alpha: 0.5 + pulseValue * 0.3)..style = PaintingStyle.fill);
  }

  // ── 风格③：极简 ─────────────────────────────────────────────

  void _paintMinimal(Canvas canvas) {
    final halfH = lineHeight / 2 - 2;
    final top    = Offset(cursorOffset.dx, cursorOffset.dy - halfH);
    final bottom = Offset(cursorOffset.dx, cursorOffset.dy + halfH);

    // 只画一条 1.5px 细线，透明度随呼吸微微变化（0.55~0.75）
    canvas.drawLine(top, bottom,
        Paint()
          ..color = color.withValues(alpha: 0.55 + pulseValue * 0.20)
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_InkCursorPainter old) =>
      old.cursorOffset != cursorOffset ||
      old.rippleProgress != rippleProgress ||
      old.pulseValue != pulseValue ||
      old.particles.length != particles.length ||
      old.style != style;
}
