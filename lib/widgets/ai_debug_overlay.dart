import 'dart:ui' show lerpDouble;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/ai_service.dart';
import '../services/ai_debug_log_service.dart';

// ─────────────────────────────────────────────────────────────────
//  AI 调试浮层
//
//  仅在 kDebugMode == true 时渲染（Release 版本零开销）
//
//  展示内容（四个 Tab）：
//  1. 📤 Prompt：发送给 AI 的完整 Prompt（System Prompt + 用户问题）
//  2. 💬 AI 回复：AI 的完整回复内容
//  3. 📊 Token：本次对话的 Token 消耗
//  4. 📁 历史日志：从本地日志文件读取的所有历史对话记录
// ─────────────────────────────────────────────────────────────────

/// 调试浮层入口组件（包裹在 child 之上）
class AiDebugOverlayWrapper extends StatefulWidget {
  final Widget child;
  const AiDebugOverlayWrapper({super.key, required this.child});

  @override
  State<AiDebugOverlayWrapper> createState() => _AiDebugOverlayWrapperState();
}

class _AiDebugOverlayWrapperState extends State<AiDebugOverlayWrapper> {
  bool _panelOpen = false;

  void _togglePanel() => setState(() => _panelOpen = !_panelOpen);
  void _closePanel() => setState(() => _panelOpen = false);

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return widget.child;

    return Stack(
      children: [
        widget.child,

        if (_panelOpen)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _DebugPanel(onClose: _closePanel),
          ),

        // 右上角后台任务 Token 胶囊（独立于主 debug 面板）
        const Positioned(
          top: 0,
          right: 0,
          child: _BgTaskCapsule(),
        ),

        _AiDebugFab(
          panelOpen: _panelOpen,
          onToggle: _togglePanel,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  右上角后台任务 Token 胶囊
//  仅在 debug 模式，当后台有 silent 任务运行/完成时显示
// ─────────────────────────────────────────────────────────────────

class _BgTaskCapsule extends StatefulWidget {
  const _BgTaskCapsule();

  @override
  State<_BgTaskCapsule> createState() => _BgTaskCapsuleState();
}

class _BgTaskCapsuleState extends State<_BgTaskCapsule>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    AiDebugNotifier.instance.addListener(_onUpdate);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    AiDebugNotifier.instance.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (!mounted) return;
    final bg = AiDebugNotifier.instance.bgTask;
    if (bg != null) {
      _fadeCtrl.forward();
    } else {
      _fadeCtrl.reverse();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bg = AiDebugNotifier.instance.bgTask;
    if (bg == null && _fadeCtrl.value == 0) return const SizedBox.shrink();

    final isRunning = bg != null && !bg.isCompleted;
    final isDone = bg != null && bg.isCompleted;

    // 颜色：运行中橙色，完成绿色
    final color = isRunning
        ? const Color(0xFFFF9500)
        : const Color(0xFF32D74B);

    final label = isRunning
        ? '⚡ ${bg.label}  ~${bg.estimatedInputTokens} tk'
        : isDone
            ? '✓ ${bg.label}  ${bg.actualTotalTokens != null ? "${bg.actualTotalTokens} tk" : "完成"}'
            : '';

    return FadeTransition(
      opacity: _fadeAnim,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 8, right: 10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E).withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.7), width: 1),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isRunning)
                  Padding(
                    padding: const EdgeInsets.only(right: 5),
                    child: SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: color,
                      ),
                    ),
                  ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                    fontFamily: 'monospace',
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  可拖拽悬浮按钮
// ─────────────────────────────────────────────────────────────────

class _AiDebugFab extends StatefulWidget {
  final bool panelOpen;
  final VoidCallback onToggle;

  const _AiDebugFab({required this.panelOpen, required this.onToggle});

  @override
  State<_AiDebugFab> createState() => _AiDebugFabState();
}

class _AiDebugFabState extends State<_AiDebugFab>
    with TickerProviderStateMixin {
  double _xPos = -1;
  double _yPos = -1;

  // 脉冲动画（AI 工作中使用）
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  // 显隐淡入淡出动画（静止 ↔ 激活状态切换）
  late AnimationController _appearController;
  late Animation<double> _appearAnim;

  bool _wasGenerating = false;

  @override
  void initState() {
    super.initState();

    // 脉冲：AI 工作时循环呼吸
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.88, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // 浮现/消隐：0.0 = 极隐蔽  1.0 = 完全浮现
    _appearController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _appearAnim = CurvedAnimation(
      parent: _appearController,
      curve: Curves.easeOutCubic,
    );

    AiDebugNotifier.instance.addListener(_onDebugUpdate);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _appearController.dispose();
    AiDebugNotifier.instance.removeListener(_onDebugUpdate);
    super.dispose();
  }

  void _onDebugUpdate() {
    if (!mounted) return;
    final current = AiDebugNotifier.instance.current;
    final isGenerating = current != null && !current.isCompleted;

    // 状态变化时触发浮现/消隐动画
    if (isGenerating && !_wasGenerating) {
      _appearController.forward();
    } else if (!isGenerating && _wasGenerating && !widget.panelOpen) {
      // AI 完成后停留 2 秒再隐蔽（除非面板已打开）
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && !widget.panelOpen) {
          _appearController.reverse();
        }
      });
    }
    _wasGenerating = isGenerating;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    if (_xPos < 0) {
      _xPos = size.width - 64;
      _yPos = size.height * 0.65;
    }

    final current = AiDebugNotifier.instance.current;
    final isGenerating = current != null && !current.isCompleted;
    // 面板打开时也完全显示
    final isActive = isGenerating || widget.panelOpen;

    // 面板打开时强制保持完全浮现
    if (widget.panelOpen && _appearController.value < 1.0) {
      _appearController.forward();
    }

    return Positioned(
      left: _xPos,
      top: _yPos,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _xPos = (_xPos + details.delta.dx).clamp(0.0, size.width - 52);
            _yPos = (_yPos + details.delta.dy).clamp(0.0, size.height - 52);
          });
        },
        onTap: () {
          // 点击时先浮现，再打开面板
          _appearController.forward();
          widget.onToggle();
        },
        child: AnimatedBuilder(
          animation: Listenable.merge([_pulseAnim, _appearAnim]),
          builder: (_, child) {
            // t: 0 = 隐蔽状态，1 = 激活状态
            final t = _appearAnim.value;
            // 隐蔽时：极小尺寸（10px）+ 极低透明度（0.15）
            // 激活时：正常尺寸（48px）+ 完全不透明
            final fabSize = lerpDouble(10.0, 48.0, t)!;
            final opacity = lerpDouble(0.18, 1.0, t)!;
            final scale = isGenerating ? _pulseAnim.value : 1.0;

            return Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  // 保持点击区域不变（即使视觉上很小也能点到）
                  child: Center(
                    child: Container(
                      width: fabSize,
                      height: fabSize,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: widget.panelOpen
                              ? [const Color(0xFF388BFD), const Color(0xFF2563EB)]
                              : isGenerating
                                  ? [const Color(0xFF00C896), const Color(0xFF00A878)]
                                  : [const Color(0xFF2A2A3E), const Color(0xFF1A1A2E)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: isGenerating
                                      ? const Color(0xFF00C896).withValues(alpha: 0.6)
                                      : const Color(0xFF388BFD).withValues(alpha: 0.5),
                                  blurRadius: isGenerating ? 20 : 12,
                                  spreadRadius: isGenerating ? 3 : 1,
                                ),
                              ]
                            : [],
                        border: Border.all(
                          color: isActive
                              ? (isGenerating
                                  ? const Color(0xFF00FF99).withValues(alpha: 0.5)
                                  : const Color(0xFF58A6FF).withValues(alpha: 0.4))
                              : Colors.white.withValues(alpha: 0.08),
                          width: 1.0,
                        ),
                      ),
                      child: fabSize >= 28
                          ? Center(
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Text(
                                    widget.panelOpen ? '✕' : '🔬',
                                    style: TextStyle(
                                      fontSize: widget.panelOpen ? 14 : 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                  // AI 工作中：右上角绿色小点
                                  if (isGenerating && !widget.panelOpen)
                                    Positioned(
                                      right: 2,
                                      top: 2,
                                      child: Container(
                                        width: 7,
                                        height: 7,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF00FF99),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF00FF99)
                                                  .withValues(alpha: 0.8),
                                              blurRadius: 6,
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  调试面板（从底部弹出）
//  四个 Tab：Prompt / AI 回复 / Token 消耗 / 历史日志
// ─────────────────────────────────────────────────────────────────

class _DebugPanel extends StatefulWidget {
  final VoidCallback onClose;
  const _DebugPanel({required this.onClose});

  @override
  State<_DebugPanel> createState() => _DebugPanelState();
}

class _DebugPanelState extends State<_DebugPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnim;

  // 0 = Prompt, 1 = AI 回复, 2 = Token 消耗, 3 = 历史日志
  int _selectedTab = 0;
  // 内存中的历史 session 选中的索引（-1 = 最新/当前）
  int _historyIndex = -1;

  // ── 历史日志 Tab 的状态 ──
  List<AiDebugLogEntry> _logEntries = [];
  bool _logLoading = false;
  String _logFilePath = '';
  int _logFileSizeBytes = 0;
  // 当前展开查看详情的日志条目索引（-1 = 未展开）
  int _logDetailIndex = -1;
  // 日志详情内部 Tab（0=Prompt, 1=回复, 2=Token）
  int _logDetailTab = 0;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );
    _slideController.forward();
    AiDebugNotifier.instance.addListener(_onUpdate);
  }

  @override
  void dispose() {
    _slideController.dispose();
    AiDebugNotifier.instance.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  /// 当前要展示的内存 session（-1 = 最新，否则取历史列表对应项）
  AiDebugTokenInfo? get _activeSession {
    final notifier = AiDebugNotifier.instance;
    if (_historyIndex == -1) return notifier.current;
    final history = notifier.history;
    if (_historyIndex < history.length) return history[_historyIndex];
    return notifier.current;
  }

  // ── 加载历史日志文件 ────────────────────────────────────────

  Future<void> _loadLogs() async {
    if (_logLoading) return;
    setState(() => _logLoading = true);
    try {
      final entries = await AiDebugLogService.instance.readLogs();
      final path = await AiDebugLogService.instance.getLogFilePath();
      final size = await AiDebugLogService.instance.getLogFileSizeBytes();
      if (mounted) {
        setState(() {
          _logEntries = entries;
          _logFilePath = path;
          _logFileSizeBytes = size;
          _logDetailIndex = -1;
          _logLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _logLoading = false);
    }
  }

  Future<void> _clearLogs() async {
    await AiDebugLogService.instance.clearLogs();
    await _loadLogs();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final notifier = AiDebugNotifier.instance;

    return SlideTransition(
      position: _slideAnim,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: screenHeight * 0.75),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF0D1117),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(
                top: BorderSide(color: Color(0xFF30363D), width: 1),
                left: BorderSide(color: Color(0xFF30363D), width: 1),
                right: BorderSide(color: Color(0xFF30363D), width: 1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 30,
                  offset: Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 拖拽指示条
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF30363D),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // 标题栏
                _buildTitleBar(notifier),
                // 内存会话切换条（有多条时显示，且不在历史日志 Tab）
                if (_selectedTab != 3 && notifier.history.length > 1)
                  _buildSessionPicker(notifier),
                // Tab 栏
                _buildTabBar(),
                const Divider(height: 1, color: Color(0xFF30363D)),
                // 内容区
                Flexible(
                  child: _selectedTab == 3
                      ? _buildLogTabScaffold()
                      : SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 36),
                          child: _buildTabContent(),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── 标题栏 ──────────────────────────────────────────────────────

  Widget _buildTitleBar(AiDebugNotifier notifier) {
    final session = _activeSession;
    final isGenerating = session != null && !session.isCompleted;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 6),
      child: Row(
        children: [
          const Text('🔬', style: TextStyle(fontSize: 15)),
          const SizedBox(width: 8),
          const Text(
            'AI Debug',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF58A6FF),
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 8),
          // 状态徽章
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: isGenerating
                  ? const Color(0xFF1B3A1B)
                  : const Color(0xFF1B2830),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isGenerating
                    ? const Color(0xFF3FB950)
                    : const Color(0xFF30363D),
              ),
            ),
            child: Text(
              isGenerating ? '生成中...' : (session != null ? '已完成' : '等待对话'),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isGenerating
                    ? const Color(0xFF3FB950)
                    : const Color(0xFF8B949E),
                fontFamily: 'monospace',
              ),
            ),
          ),
          const Spacer(),
          if (_selectedTab != 3 && notifier.history.isNotEmpty)
            GestureDetector(
              onTap: () {
                notifier.clearHistory();
                setState(() => _historyIndex = -1);
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  '清空',
                  style: TextStyle(fontSize: 12, color: Color(0xFF8B949E)),
                ),
              ),
            ),
          GestureDetector(
            onTap: widget.onClose,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFF21262D),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 16,
                color: Color(0xFF8B949E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 内存会话选择条 ───────────────────────────────────────────────

  Widget _buildSessionPicker(AiDebugNotifier notifier) {
    final history = notifier.history;
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: history.length,
        separatorBuilder: (context, index) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final isSelected = _historyIndex == i ||
              (_historyIndex == -1 && i == 0);
          final info = history[i];
          final timeStr =
              '${info.startTime.hour.toString().padLeft(2, '0')}:'
              '${info.startTime.minute.toString().padLeft(2, '0')}:'
              '${info.startTime.second.toString().padLeft(2, '0')}';
          return GestureDetector(
            onTap: () => setState(() => _historyIndex = i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF21262D)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF58A6FF)
                      : const Color(0xFF30363D),
                ),
              ),
              child: Text(
                '#${i + 1}  $timeStr',
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected
                      ? const Color(0xFF58A6FF)
                      : const Color(0xFF8B949E),
                  fontFamily: 'monospace',
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Tab 栏 ──────────────────────────────────────────────────────

  Widget _buildTabBar() {
    const tabs = ['📤 Prompt', '💬 AI 回复', '📊 Token', '📁 日志'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          for (int i = 0; i < tabs.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            _buildTab(i, tabs[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildTab(int index, String label) {
    final isActive = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedTab = index);
        // 切换到日志 Tab 时自动加载
        if (index == 3 && _logEntries.isEmpty && !_logLoading) {
          _loadLogs();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF21262D) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive
                ? const Color(0xFF30363D)
                : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            color: isActive
                ? const Color(0xFFE6EDF3)
                : const Color(0xFF8B949E),
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }

  // ── 内容区分发（Tab 0/1/2）────────────────────────────────────

  Widget _buildTabContent() {
    final session = _activeSession;

    if (session == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(
            '等待对话开始…\n发送一条消息后即可在这里查看',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF8B949E),
              fontFamily: 'monospace',
              height: 1.8,
            ),
          ),
        ),
      );
    }

    return switch (_selectedTab) {
      0 => _buildPromptTab(session),
      1 => _buildReplyTab(session),
      _ => _buildTokenTab(session),
    };
  }

  // ── Tab 0：Prompt ───────────────────────────────────────────────

  Widget _buildPromptTab(AiDebugTokenInfo info) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBlockHeader(
          '❓ 用户提问',
          '${info.userQuestionTokens} tokens',
          const Color(0xFF3FB950),
        ),
        const SizedBox(height: 8),
        _buildTextBox(
          info.userQuestion.isEmpty ? '（暂无）' : info.userQuestion,
          maxHeight: 120,
          borderColor: const Color(0xFF2EA043).withValues(alpha: 0.4),
        ),
        const SizedBox(height: 16),
        _buildBlockHeader(
          '🤖 System Prompt',
          '${info.systemPromptTokens} tokens',
          const Color(0xFF388BFD),
        ),
        const SizedBox(height: 8),
        _buildTextBox(
          info.systemPromptContent.isEmpty ? '（暂无）' : info.systemPromptContent,
          maxHeight: 300,
          borderColor: const Color(0xFF388BFD).withValues(alpha: 0.4),
        ),
      ],
    );
  }

  // ── Tab 1：AI 回复 ───────────────────────────────────────────────

  Widget _buildReplyTab(AiDebugTokenInfo info) {
    final isGenerating = !info.isCompleted;
    final content = info.responseContent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBlockHeader(
          isGenerating ? '💬 AI 回复（生成中…）' : '💬 AI 回复',
          isGenerating
              ? '已生成 ${info.outputTokens} tokens'
              : (info.apiCompletionTokens != null
                  ? '${info.apiCompletionTokens} tokens'
                  : '~${info.outputTokens} tokens'),
          isGenerating ? const Color(0xFF3FB950) : const Color(0xFF58A6FF),
        ),
        const SizedBox(height: 8),
        _buildTextBox(
          content.isEmpty ? '（等待生成…）' : content,
          maxHeight: 400,
          borderColor: const Color(0xFF388BFD).withValues(alpha: 0.3),
        ),
      ],
    );
  }

  // ── Tab 2：Token 消耗 ─────────────────────────────────────────────

  Widget _buildTokenTab(AiDebugTokenInfo info) {
    final elapsed = info.elapsedMs;
    final elapsedStr = elapsed < 1000
        ? '${elapsed}ms'
        : '${(elapsed / 1000).toStringAsFixed(1)}s';

    final inputTok = info.apiPromptTokens ?? info.totalInputTokens;
    final outputTok = info.apiCompletionTokens ?? info.outputTokens;
    final totalTok = info.apiTotalTokens ?? (inputTok + outputTok);
    final isActual = info.apiTotalTokens != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isActual
                ? const Color(0xFF0D2137)
                : const Color(0xFF1B1B0D),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isActual
                  ? const Color(0xFF1F4580).withValues(alpha: 0.6)
                  : const Color(0xFFD29922).withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              Text(
                isActual ? '🎯 API 实际值（精确）' : '⚠️ 本地估算值（生成中）',
                style: TextStyle(
                  fontSize: 10,
                  color: isActual
                      ? const Color(0xFF58A6FF)
                      : const Color(0xFFD29922),
                  fontFamily: 'monospace',
                ),
              ),
              const Spacer(),
              Text(
                '⏱ $elapsedStr',
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF8B949E),
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildTokenCard('输入 Tokens', inputTok, '📥', const Color(0xFF388BFD)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildTokenCard('输出 Tokens', outputTok, '📤', const Color(0xFF3FB950)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildTokenCard('合计 Tokens', totalTok, '💰', const Color(0xFFE6EDF3)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF30363D)),
          ),
          child: Column(
            children: [
              _buildRow('System Prompt', '~${info.systemPromptTokens} tok'),
              const SizedBox(height: 6),
              _buildRow('历史对话', '~${info.historyTokens} tok'),
              const SizedBox(height: 6),
              _buildRow('用户问题', '~${info.userQuestionTokens} tok'),
              const Divider(height: 16, color: Color(0xFF30363D)),
              _buildRow('输入合计（估算）', '~${info.totalInputTokens} tok', highlight: true),
              if (isActual && info.apiPromptTokens != null) ...[
                const SizedBox(height: 6),
                _buildRow(
                  '估算误差',
                  '${(info.totalInputTokens - info.apiPromptTokens!).abs()} tok'
                  ' (${((info.totalInputTokens - info.apiPromptTokens!).abs() / info.apiPromptTokens! * 100).toStringAsFixed(1)}%)',
                  valueColor: const Color(0xFF8B949E),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── Tab 3：历史日志 ──────────────────────────────────────────────

  Widget _buildLogTabScaffold() {
    // 如果正在查看某条日志详情，显示详情页
    if (_logDetailIndex >= 0 && _logDetailIndex < _logEntries.length) {
      return _buildLogDetail(_logEntries[_logDetailIndex]);
    }
    // 否则显示日志列表
    return _buildLogList();
  }

  Widget _buildLogList() {
    return Column(
      children: [
        // 工具栏：文件信息 + 刷新 + 清空
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 文件路径
              if (_logFilePath.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF30363D)),
                  ),
                  child: SelectableText(
                    _logFilePath,
                    style: const TextStyle(
                      fontSize: 9,
                      color: Color(0xFF8B949E),
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  // 条数 + 文件大小
                  Text(
                    '共 ${_logEntries.length} 条  •  ${_formatBytes(_logFileSizeBytes)}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF8B949E),
                      fontFamily: 'monospace',
                    ),
                  ),
                  const Spacer(),
                  // 刷新按钮
                  GestureDetector(
                    onTap: _logLoading ? null : _loadLogs,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF21262D),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: const Color(0xFF30363D)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_logLoading)
                            const SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: Color(0xFF58A6FF),
                              ),
                            )
                          else
                            const Text('↺', style: TextStyle(fontSize: 12, color: Color(0xFF58A6FF))),
                          const SizedBox(width: 4),
                          const Text(
                            '刷新',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF58A6FF),
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 清空按钮
                  GestureDetector(
                    onTap: _logEntries.isEmpty
                        ? null
                        : () async {
                            await _clearLogs();
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF21262D),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: const Color(0xFF30363D)),
                      ),
                      child: const Text(
                        '🗑 清空日志',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFFD29922),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFF21262D)),
        // 日志条目列表
        Flexible(
          child: _logLoading && _logEntries.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF58A6FF),
                    ),
                  ),
                )
              : _logEntries.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Text(
                          '暂无历史日志\n完成一次 AI 对话后自动保存',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8B949E),
                            fontFamily: 'monospace',
                            height: 1.8,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 36),
                      itemCount: _logEntries.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 6),
                      itemBuilder: (context, i) => _buildLogListItem(_logEntries[i], i),
                    ),
        ),
      ],
    );
  }

  Widget _buildLogListItem(AiDebugLogEntry entry, int index) {
    final isActual = entry.hasApiTokens;
    return GestureDetector(
      onTap: () => setState(() {
        _logDetailIndex = index;
        _logDetailTab = 0;
      }),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF30363D)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部：时间 + 耗时 + Token
            Row(
              children: [
                Text(
                  entry.timeLabel,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF58A6FF),
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '⏱ ${entry.elapsedLabel}',
                  style: const TextStyle(
                    fontSize: 9,
                    color: Color(0xFF8B949E),
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: isActual
                        ? const Color(0xFF0D2137)
                        : const Color(0xFF1B1B0D),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: isActual
                          ? const Color(0xFF388BFD).withValues(alpha: 0.5)
                          : const Color(0xFFD29922).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    '${entry.totalTokens} tok',
                    style: TextStyle(
                      fontSize: 9,
                      color: isActual
                          ? const Color(0xFF58A6FF)
                          : const Color(0xFFD29922),
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // 用户问题摘要
            Text(
              entry.userQuestion.isEmpty
                  ? '（无问题内容）'
                  : entry.userQuestion.length > 60
                      ? '${entry.userQuestion.substring(0, 60)}…'
                      : entry.userQuestion,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFFE6EDF3),
                fontFamily: 'monospace',
                height: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            // Token 小摘要
            Row(
              children: [
                _buildMiniTokenBadge('📥 ${entry.inputTokens}', const Color(0xFF388BFD)),
                const SizedBox(width: 4),
                _buildMiniTokenBadge('📤 ${entry.outputTokensFinal}', const Color(0xFF3FB950)),
                const SizedBox(width: 4),
                _buildMiniTokenBadge('日记: ${entry.injectedMomentCount}/${entry.totalMomentCount}条', const Color(0xFF8B949E)),
                const Spacer(),
                const Text(
                  '查看详情 →',
                  style: TextStyle(
                    fontSize: 9,
                    color: Color(0xFF58A6FF),
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniTokenBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          color: color,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  // ── 日志详情页 ───────────────────────────────────────────────────

  Widget _buildLogDetail(AiDebugLogEntry entry) {
    return Column(
      children: [
        // 返回按钮 + 时间
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _logDetailIndex = -1),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF21262D),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF30363D)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('←', style: TextStyle(fontSize: 12, color: Color(0xFF58A6FF))),
                      SizedBox(width: 4),
                      Text(
                        '返回列表',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF58A6FF),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  entry.timeLabel,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF8B949E),
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '⏱ ${entry.elapsedLabel}',
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF8B949E),
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
        // 详情内部 Tab
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              _buildDetailTab(0, '📤 Prompt'),
              const SizedBox(width: 6),
              _buildDetailTab(1, '💬 回复'),
              const SizedBox(width: 6),
              _buildDetailTab(2, '📊 Token'),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFF30363D)),
        // 内容
        Flexible(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
            child: _buildLogDetailContent(entry),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailTab(int index, String label) {
    final isActive = _logDetailTab == index;
    return GestureDetector(
      onTap: () => setState(() => _logDetailTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF21262D) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive ? const Color(0xFF30363D) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            color: isActive ? const Color(0xFFE6EDF3) : const Color(0xFF8B949E),
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }

  Widget _buildLogDetailContent(AiDebugLogEntry entry) {
    return switch (_logDetailTab) {
      0 => _buildLogPromptTab(entry),
      1 => _buildLogReplyTab(entry),
      _ => _buildLogTokenTab(entry),
    };
  }

  Widget _buildLogPromptTab(AiDebugLogEntry entry) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBlockHeader(
          '❓ 用户提问',
          '~${entry.userQuestionTokens} tokens',
          const Color(0xFF3FB950),
        ),
        const SizedBox(height: 8),
        _buildTextBox(
          entry.userQuestion.isEmpty ? '（暂无）' : entry.userQuestion,
          maxHeight: 120,
          borderColor: const Color(0xFF2EA043).withValues(alpha: 0.4),
        ),
        const SizedBox(height: 16),
        _buildBlockHeader(
          '🤖 System Prompt',
          '~${entry.systemPromptTokens} tokens',
          const Color(0xFF388BFD),
        ),
        const SizedBox(height: 8),
        _buildTextBox(
          entry.systemPromptContent.isEmpty ? '（暂无）' : entry.systemPromptContent,
          maxHeight: 300,
          borderColor: const Color(0xFF388BFD).withValues(alpha: 0.4),
        ),
      ],
    );
  }

  Widget _buildLogReplyTab(AiDebugLogEntry entry) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBlockHeader(
          '💬 AI 回复',
          entry.hasApiTokens
              ? '${entry.apiCompletionTokens} tokens'
              : '~${entry.outputTokens} tokens',
          const Color(0xFF58A6FF),
        ),
        const SizedBox(height: 8),
        _buildTextBox(
          entry.responseContent.isEmpty ? '（无回复内容）' : entry.responseContent,
          maxHeight: 420,
          borderColor: const Color(0xFF388BFD).withValues(alpha: 0.3),
        ),
      ],
    );
  }

  Widget _buildLogTokenTab(AiDebugLogEntry entry) {
    final isActual = entry.hasApiTokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isActual ? const Color(0xFF0D2137) : const Color(0xFF1B1B0D),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isActual
                  ? const Color(0xFF1F4580).withValues(alpha: 0.6)
                  : const Color(0xFFD29922).withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              Text(
                isActual ? '🎯 API 实际值（精确）' : '⚠️ 本地估算值',
                style: TextStyle(
                  fontSize: 10,
                  color: isActual ? const Color(0xFF58A6FF) : const Color(0xFFD29922),
                  fontFamily: 'monospace',
                ),
              ),
              const Spacer(),
              Text(
                '⏱ ${entry.elapsedLabel}',
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF8B949E),
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildTokenCard('输入', entry.inputTokens, '📥', const Color(0xFF388BFD))),
            const SizedBox(width: 10),
            Expanded(child: _buildTokenCard('输出', entry.outputTokensFinal, '📤', const Color(0xFF3FB950))),
            const SizedBox(width: 10),
            Expanded(child: _buildTokenCard('合计', entry.totalTokens, '💰', const Color(0xFFE6EDF3))),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF30363D)),
          ),
          child: Column(
            children: [
              _buildRow('System Prompt', '~${entry.systemPromptTokens} tok'),
              const SizedBox(height: 6),
              _buildRow('历史对话', '~${entry.historyTokens} tok'),
              const SizedBox(height: 6),
              _buildRow('用户问题', '~${entry.userQuestionTokens} tok'),
              const Divider(height: 16, color: Color(0xFF30363D)),
              _buildRow('输入合计（估算）', '~${entry.totalInputTokens} tok', highlight: true),
              const SizedBox(height: 6),
              _buildRow('日记注入模式', entry.diaryContextMode),
              const SizedBox(height: 6),
              _buildRow('注入日记条数', '${entry.injectedMomentCount}/${entry.totalMomentCount} 条'),
              if (isActual && entry.apiPromptTokens != null) ...[
                const Divider(height: 16, color: Color(0xFF30363D)),
                _buildRow('API 输入 Token', '${entry.apiPromptTokens} tok', highlight: true),
                const SizedBox(height: 6),
                _buildRow(
                  '估算误差',
                  '${(entry.totalInputTokens - entry.apiPromptTokens!).abs()} tok'
                  ' (${((entry.totalInputTokens - entry.apiPromptTokens!).abs() / entry.apiPromptTokens! * 100).toStringAsFixed(1)}%)',
                  valueColor: const Color(0xFF8B949E),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── 通用小组件 ──────────────────────────────────────────────────

  Widget _buildBlockHeader(String title, String badge, Color badgeColor) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF8B949E),
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFF30363D)),
          ),
          child: Text(
            badge,
            style: TextStyle(
              fontSize: 9,
              color: badgeColor,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextBox(
    String text, {
    double maxHeight = 200,
    Color? borderColor,
  }) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(maxHeight: maxHeight),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: borderColor ?? const Color(0xFF30363D),
        ),
      ),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: SelectableText(
          text,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFFE6EDF3),
            fontFamily: 'monospace',
            height: 1.65,
          ),
        ),
      ),
    );
  }

  Widget _buildTokenCard(String label, int value, String emoji, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 6),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              color: Color(0xFF8B949E),
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(
    String label,
    String value, {
    bool highlight = false,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF8B949E),
              fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: highlight ? FontWeight.w700 : FontWeight.normal,
            color: valueColor ??
                (highlight
                    ? const Color(0xFFE6EDF3)
                    : const Color(0xFFADB5BD)),
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  // ── 工具方法 ─────────────────────────────────────────────────────

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)}MB';
  }
}
