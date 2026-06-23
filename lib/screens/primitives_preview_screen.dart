import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────
//  DimensionType —— 认知原语类型枚举（预览专用）
// ─────────────────────────────────────────────────────────────────

enum DimensionType {
  noteFlow,
  todoList,
  collectBoard,
  structuredLog,
  aiChat,
  timeline,
  qaExploration,
  tensionBoard,
  relationMap,
  freeform,
}

// ─────────────────────────────────────────────────────────────────
//  PrimitivesPreviewScreen —— 原语组件 Debug 预览页
//
//  【设计目标】
//  一页览尽所有原语的真实 UI 形态，使用 Mock 数据渲染，
//  不依赖数据库，开发者可以在这里直观感受每种原语的交互体验。
//
//  涵盖：
//    内置原语：note_flow / todo_list / collect_board / structured_log / ai_chat
//    扩展原语：timeline / qa_exploration / tension_board / relation_map
//    自由原语：freeform
// ─────────────────────────────────────────────────────────────────

class PrimitivesPreviewScreen extends StatefulWidget {
  const PrimitivesPreviewScreen({super.key});

  @override
  State<PrimitivesPreviewScreen> createState() =>
      _PrimitivesPreviewScreenState();
}

class _PrimitivesPreviewScreenState extends State<PrimitivesPreviewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 所有原语定义
  static const _primitives = [
    _PrimitiveMeta(
      type: DimensionType.noteFlow,
      name: 'note_flow',
      label: '「观察」原语',
      desc: '自由文本流 · 笔记/感悟/日志/灵感碎片',
      layer: '内置',
      color: Color(0xFF5C6BC0),
    ),
    _PrimitiveMeta(
      type: DimensionType.todoList,
      name: 'todo_list',
      label: '「行动」原语',
      desc: '可勾选清单 · 任务/待办/行动项',
      layer: '内置',
      color: Color(0xFF26A69A),
    ),
    _PrimitiveMeta(
      type: DimensionType.collectBoard,
      name: 'collect_board',
      label: '「收集」原语',
      desc: '外部内容看板 · 链接/图片/资料',
      layer: '内置',
      color: Color(0xFFEF5350),
    ),
    _PrimitiveMeta(
      type: DimensionType.structuredLog,
      name: 'structured_log',
      label: '「测量」原语',
      desc: '结构化追踪 · 数字/文字/选项字段',
      layer: '内置',
      color: Color(0xFFFF7043),
    ),
    _PrimitiveMeta(
      type: DimensionType.aiChat,
      name: 'ai_chat',
      label: '「对话」原语',
      desc: '专项 AI 对话频道 · 主题上下文持续探索',
      layer: '内置',
      color: Color(0xFF7C5CBF),
    ),
    _PrimitiveMeta(
      type: DimensionType.timeline,
      name: 'timeline',
      label: '「演进」原语',
      desc: '事件时间线 · 成长历程/项目里程碑',
      layer: '扩展',
      color: Color(0xFF29B6F6),
    ),
    _PrimitiveMeta(
      type: DimensionType.qaExploration,
      name: 'qa_exploration',
      label: '「追问」原语',
      desc: '问题树 · 苏格拉底式自我深挖',
      layer: '扩展',
      color: Color(0xFF66BB6A),
    ),
    _PrimitiveMeta(
      type: DimensionType.tensionBoard,
      name: 'tension_board',
      label: '「对立」原语',
      desc: '两极并置 · 决策权衡/正反论证',
      layer: '扩展',
      color: Color(0xFFAB47BC),
    ),
    _PrimitiveMeta(
      type: DimensionType.relationMap,
      name: 'relation_map',
      label: '「关联」原语',
      desc: '语义网络 · 知识图谱/概念连接',
      layer: '扩展',
      color: Color(0xFFF06292),
    ),
    _PrimitiveMeta(
      type: DimensionType.freeform,
      name: 'freeform',
      label: '「自由创作」原语',
      desc: 'AI 完全自定义 · 任何认知形态',
      layer: '自由',
      color: Color(0xFFFFCA28),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _primitives.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          _buildHeader(isDark),
          _buildTabBar(isDark),
        ],
        body: TabBarView(
          controller: _tabController,
          children: _primitives
              .map((p) => _PrimitivePreviewPanel(meta: p, isDark: isDark))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return SliverAppBar(
      expandedHeight: 140,
      pinned: true,
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      elevation: 0,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_rounded,
          color: isDark ? Colors.white : const Color(0xFF1A1A2E),
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary.withValues(alpha: 0.15),
                AppColors.primaryLight.withValues(alpha: 0.05),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text('🧩',
                            style: TextStyle(fontSize: 20)),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '原语组件预览',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1A1A2E),
                            ),
                          ),
                          Text(
                            '10 种认知原语 · 完整 UI 形态展示',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          'DEBUG',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                            letterSpacing: 1,
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
      ),
    );
  }

  Widget _buildTabBar(bool isDark) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _StickyTabBarDelegate(
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          unselectedLabelStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
          indicatorWeight: 2,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: _primitives.map((p) {
            return Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _LayerDot(layer: p.layer, color: p.color),
                  const SizedBox(width: 5),
                  Text(p.type.emoji),
                  const SizedBox(width: 4),
                  Text(p.type.defaultLabel),
                ],
              ),
            );
          }).toList(),
          labelColor: isDark ? Colors.white : const Color(0xFF1A1A2E),
          unselectedLabelColor:
              isDark ? DarkPalette.textSecondary : const Color(0xFF999BBB),
          indicatorColor: AppColors.primary,
        ),
        isDark: isDark,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  每种原语的完整预览面板
// ─────────────────────────────────────────────────────────────────

class _PrimitivePreviewPanel extends StatelessWidget {
  final _PrimitiveMeta meta;
  final bool isDark;

  const _PrimitivePreviewPanel(
      {required this.meta, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return switch (meta.type) {
      DimensionType.noteFlow => _NoteFlowPreview(meta: meta, isDark: isDark),
      DimensionType.todoList => _TodoListPreview(meta: meta, isDark: isDark),
      DimensionType.collectBoard =>
        _CollectBoardPreview(meta: meta, isDark: isDark),
      DimensionType.structuredLog =>
        _StructuredLogPreview(meta: meta, isDark: isDark),
      DimensionType.aiChat => _AiChatPreview(meta: meta, isDark: isDark),
      DimensionType.timeline => _TimelinePreview(meta: meta, isDark: isDark),
      DimensionType.qaExploration =>
        _QaExplorationPreview(meta: meta, isDark: isDark),
      DimensionType.tensionBoard =>
        _TensionBoardPreview(meta: meta, isDark: isDark),
      DimensionType.relationMap =>
        _RelationMapPreview(meta: meta, isDark: isDark),
      DimensionType.freeform =>
        _FreeformPreview(meta: meta, isDark: isDark),
    };
  }
}

// ═══════════════════════════════════════════════════════════════
//  内置原语预览
// ═══════════════════════════════════════════════════════════════

// ── note_flow 预览 ───────────────────────────────────────────────

class _NoteFlowPreview extends StatelessWidget {
  final _PrimitiveMeta meta;
  final bool isDark;
  const _NoteFlowPreview({required this.meta, required this.isDark});

  static final _mockNotes = [
    _MockNote(
      '今天的感悟',
      '跑完步，坐在公园的长椅上，忽然想通了一件事：我一直在追求「确定性」，但生命本身就是流动的。也许我该学会和不确定性共处。',
      '刚刚',
      comment: '这句话值得你写下来，贴在能看见的地方。',
    ),
    _MockNote(
      '关于边界感',
      '边界感不是冷漠，而是尊重。对自己的边界有清晰认知，才能真正地去爱别人。',
      '昨天',
      comment: '边界与亲密并不矛盾，这是很成熟的洞察。',
    ),
    _MockNote(
      null,
      '灵感：把「极简主义」用在人际关系上——只保留真正重要的人。',
      '3天前',
      comment: null,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final color = meta.color;
    final cardBg = isDark ? DarkPalette.card : Colors.white;
    final textPrimary =
        isDark ? DarkPalette.textPrimary : const Color(0xFF1A1A2E);
    final textSecondary =
        isDark ? DarkPalette.textSecondary : const Color(0xFF666688);
    final textTertiary =
        isDark ? DarkPalette.textTertiary : const Color(0xFF999BBB);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _PrimitiveInfoCard(meta: meta, isDark: isDark),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _ConfigChips(
              chips: const [
                'sort: newest',
                'show_ai_comment: true',
                'template: 空',
              ],
              color: color,
              isDark: isDark,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                final note = _mockNotes[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.04),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: isDark ? 0.15 : 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('✍️',
                                      style: TextStyle(fontSize: 10)),
                                  const SizedBox(width: 3),
                                  Text('笔记',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: color,
                                          fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                            const Spacer(),
                            Text(note.time,
                                style: TextStyle(
                                    fontSize: 11, color: textTertiary)),
                          ],
                        ),
                        if (note.title != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            note.title!,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          note.content,
                          style: TextStyle(
                            fontSize: 14,
                            color: textSecondary,
                            height: 1.55,
                          ),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (note.comment != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.auto_awesome_rounded,
                                    size: 12, color: color),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    note.comment!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: textSecondary,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
              childCount: _mockNotes.length,
            ),
          ),
        ),
      ],
    );
  }
}

// ── todo_list 预览 ───────────────────────────────────────────────

class _TodoListPreview extends StatefulWidget {
  final _PrimitiveMeta meta;
  final bool isDark;
  const _TodoListPreview({required this.meta, required this.isDark});

  @override
  State<_TodoListPreview> createState() => _TodoListPreviewState();
}

class _TodoListPreviewState extends State<_TodoListPreview> {
  final _items = [
    _MockTodo('制定本周训练计划', false, '🔴', null),
    _MockTodo('购买跑步护膝', true, '🟡', '5/28'),
    _MockTodo('完成一次5km慢跑', false, '🔴', '5/30'),
    _MockTodo('记录跑步感受', false, '🟢', null),
    _MockTodo('和教练预约第二次课', true, '🟡', '6/1'),
  ];

  @override
  Widget build(BuildContext context) {
    final color = widget.meta.color;
    final cardBg = widget.isDark ? DarkPalette.card : Colors.white;
    final textPrimary = widget.isDark
        ? DarkPalette.textPrimary
        : const Color(0xFF1A1A2E);
    final textSecondary = widget.isDark
        ? DarkPalette.textSecondary
        : const Color(0xFF666688);
    final textTertiary = widget.isDark
        ? DarkPalette.textTertiary
        : const Color(0xFF999BBB);

    final pending = _items.where((t) => !t.done).toList();
    final completed = _items.where((t) => t.done).toList();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
            child: _PrimitiveInfoCard(meta: widget.meta, isDark: widget.isDark)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _ConfigChips(
              chips: const [
                'has_priority: true',
                'has_due_date: true',
                'group_by: priority',
              ],
              color: color,
              isDark: widget.isDark,
            ),
          ),
        ),
        // 待完成
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text('待完成 (${pending.length})',
                style: TextStyle(
                    fontSize: 12,
                    color: textTertiary,
                    fontWeight: FontWeight.w600)),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => _buildTodoItem(
                  pending[i], color, cardBg, textPrimary, textSecondary,
                  textTertiary),
              childCount: pending.length,
            ),
          ),
        ),
        // 已完成
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text('已完成 (${completed.length})',
                style: TextStyle(
                    fontSize: 12,
                    color: textTertiary,
                    fontWeight: FontWeight.w600)),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => _buildTodoItem(
                  completed[i], color, cardBg, textPrimary, textSecondary,
                  textTertiary),
              childCount: completed.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTodoItem(_MockTodo todo, Color color, Color cardBg,
      Color textPrimary, Color textSecondary, Color textTertiary) {
    return GestureDetector(
      onTap: () => setState(() => todo.done = !todo.done),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.04),
          ),
        ),
        child: Row(
          children: [
            Icon(
              todo.done
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: todo.done ? color : textTertiary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                todo.title,
                style: TextStyle(
                  fontSize: 14,
                  color: todo.done ? textTertiary : textPrimary,
                  decoration:
                      todo.done ? TextDecoration.lineThrough : null,
                  decorationColor: textTertiary,
                ),
              ),
            ),
            if (todo.priority != null) ...[
              Text(todo.priority!, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
            ],
            if (todo.dueDate != null) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(todo.dueDate!,
                    style: TextStyle(fontSize: 10, color: color)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── collect_board 预览 ─────────────────────────────────────────

class _CollectBoardPreview extends StatelessWidget {
  final _PrimitiveMeta meta;
  final bool isDark;
  const _CollectBoardPreview({required this.meta, required this.isDark});

  static final _mockCollects = [
    _MockCollect(
      '极简主义的实践指南',
      'https://example.com/minimalism',
      '每个物品都有它存在的理由，如果没有，那它就不该存在。',
      '文章',
    ),
    _MockCollect(
      '斯多葛哲学入门',
      'https://example.com/stoic',
      '关注你能控制的，接受你不能控制的。这是斯多葛智慧的核心。',
      '链接',
    ),
    _MockCollect(
      '写作的本质',
      null,
      '写作是思维的镜子，你写的清晰度反映了你思考的清晰度。',
      '引用',
    ),
    _MockCollect(
      '费曼学习法',
      'https://example.com/feynman',
      '如果你不能用简单的语言解释一个概念，说明你还没真正理解它。',
      '视频',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final color = meta.color;
    final cardBg = isDark ? DarkPalette.card : Colors.white;
    final textPrimary =
        isDark ? DarkPalette.textPrimary : const Color(0xFF1A1A2E);
    final textSecondary =
        isDark ? DarkPalette.textSecondary : const Color(0xFF666688);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
            child: _PrimitiveInfoCard(meta: meta, isDark: isDark)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _ConfigChips(
              chips: const [
                'layout: card',
                'show_preview: true',
              ],
              color: color,
              isDark: isDark,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.85,
            ),
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                final item = _mockCollects[i];
                return Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.04),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: isDark ? 0.12 : 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 类型 Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('💎',
                                  style: TextStyle(fontSize: 10)),
                              const SizedBox(width: 3),
                              Text(
                                item.type,
                                style: TextStyle(
                                    fontSize: 10,
                                    color: color,
                                    fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: Text(
                            item.excerpt,
                            style: TextStyle(
                              fontSize: 11,
                              color: textSecondary,
                              height: 1.5,
                            ),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (item.url != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.link_rounded,
                                  size: 11,
                                  color: color.withValues(alpha: 0.6)),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  item.url!
                                      .replaceAll('https://', '')
                                      .replaceAll('example.com/', ''),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: color.withValues(alpha: 0.7),
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
                );
              },
              childCount: _mockCollects.length,
            ),
          ),
        ),
      ],
    );
  }
}

// ── structured_log 预览 ──────────────────────────────────────────

class _StructuredLogPreview extends StatelessWidget {
  final _PrimitiveMeta meta;
  final bool isDark;
  const _StructuredLogPreview({required this.meta, required this.isDark});

  static final _mockLogs = [
    {'date': '今天', 'weight': '68.2', 'mood': '很好', 'sleep': '7.5', 'note': '晨跑后测量'},
    {'date': '昨天', 'weight': '68.5', 'mood': '一般', 'sleep': '6.0', 'note': '有点累'},
    {'date': '2天前', 'weight': '69.0', 'mood': '好', 'sleep': '7.0', 'note': null},
    {'date': '3天前', 'weight': '68.8', 'mood': '很好', 'sleep': '8.0', 'note': '休息日'},
  ];

  @override
  Widget build(BuildContext context) {
    final color = meta.color;
    final cardBg = isDark ? DarkPalette.card : Colors.white;
    final textPrimary =
        isDark ? DarkPalette.textPrimary : const Color(0xFF1A1A2E);
    final textSecondary =
        isDark ? DarkPalette.textSecondary : const Color(0xFF666688);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _PrimitiveInfoCard(meta: meta, isDark: isDark)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _ConfigChips(
              chips: const [
                'fields: weight/mood/sleep',
                'chart_type: line',
                'show_stats: true',
              ],
              color: color,
              isDark: isDark,
            ),
          ),
        ),
        // 统计卡片
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.insights_rounded, size: 13, color: color),
                      const SizedBox(width: 6),
                      Text('数据概览',
                          style: TextStyle(
                              fontSize: 12,
                              color: color,
                              fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text('共 ${_mockLogs.length} 条',
                          style: TextStyle(
                              fontSize: 11, color: textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _StatCell(
                          label: '体重',
                          value: '68.2',
                          unit: 'kg',
                          diff: -0.3,
                          color: color,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary),
                      _StatCell(
                          label: '睡眠',
                          value: '7.5',
                          unit: 'h',
                          diff: 1.5,
                          color: color,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary),
                      _StatCell(
                          label: '心情',
                          value: '很好',
                          unit: null,
                          diff: null,
                          color: color,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        // 记录列表
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                final log = _mockLogs[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.04),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('📊',
                                    style: TextStyle(fontSize: 10)),
                                const SizedBox(width: 3),
                                Text('体重记录',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: color,
                                        fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Text(log['date']!,
                              style: TextStyle(
                                  fontSize: 11, color: textSecondary)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _buildFieldChip(
                              '体重', '${log['weight']} kg', color,
                              isNum: true, isDark: isDark),
                          _buildFieldChip(
                              '心情', log['mood']!, color,
                              isDark: isDark),
                          _buildFieldChip(
                              '睡眠', '${log['sleep']} h', color,
                              isNum: true, isDark: isDark),
                        ],
                      ),
                      if (log['note'] != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          log['note']!,
                          style: TextStyle(
                              fontSize: 12,
                              color: textSecondary,
                              fontStyle: FontStyle.italic),
                        ),
                      ],
                    ],
                  ),
                );
              },
              childCount: _mockLogs.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFieldChip(String label, String value, Color color,
      {bool isNum = false, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: isNum
            ? color.withValues(alpha: isDark ? 0.15 : 0.08)
            : (isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04)),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isNum
              ? color.withValues(alpha: 0.25)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label ',
            style: TextStyle(
                fontSize: 11,
                color: isDark
                    ? DarkPalette.textSecondary
                    : const Color(0xFF666688)),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isNum ? 14 : 12,
              fontWeight: isNum ? FontWeight.w700 : FontWeight.w500,
              color: isNum
                  ? color
                  : (isDark ? Colors.white : const Color(0xFF1A1A2E)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── ai_chat 预览 ─────────────────────────────────────────────────

class _AiChatPreview extends StatelessWidget {
  final _PrimitiveMeta meta;
  final bool isDark;
  const _AiChatPreview({required this.meta, required this.isDark});

  static final _mockMessages = [
    _MockChatMsg(isAi: true,
        text: '你已经在极简主义这条路上走了三周了。我注意到你上周的记录里有一条——「清了三箱子东西，但心里反而更空了」。这种「空」，你怎么看它？是失落，还是某种解脱？'),
    _MockChatMsg(isAi: false,
        text: '有点两者都有。扔掉东西的时候有点难受，但扔完之后房间变干净，人好像也轻了。不知道该怎么描述。'),
    _MockChatMsg(isAi: true,
        text: '「人好像也轻了」——这是个很重要的信号。极简主义不是关于物品数量，而是关于你和物品的关系。那些让你难受的，是什么类型的东西？'),
    _MockChatMsg(isAi: false, text: '大多是以前买但从来没用的，还有一些「以防万一」留着的。'),
    _MockChatMsg(isAi: true,
        text: '「以防万一」的东西——背后藏着的是焦虑，而不是真实的需要。这很有意思。你觉得这种焦虑，在你生活的其他方面也存在吗？'),
  ];

  @override
  Widget build(BuildContext context) {
    final color = meta.color;
    final cardBg = isDark ? const Color(0xFF252525) : Colors.white;
    final textPrimary =
        isDark ? DarkPalette.textPrimary : const Color(0xFF1A1A2E);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _PrimitiveInfoCard(meta: meta, isDark: isDark)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _ConfigChips(
              chips: const ['archetype: space', '流式输出', 'Hero 动画'],
              color: color,
              isDark: isDark,
            ),
          ),
        ),
        // 模拟对话列表
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                final msg = _mockMessages[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: msg.isAi
                        ? MainAxisAlignment.start
                        : MainAxisAlignment.end,
                    children: [
                      if (msg.isAi) ...[
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [color, color.withValues(alpha: 0.7)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Text('🧩',
                                style: TextStyle(fontSize: 14)),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 11),
                          decoration: BoxDecoration(
                            color: msg.isAi ? cardBg : color,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(18),
                              topRight: const Radius.circular(18),
                              bottomLeft:
                                  Radius.circular(msg.isAi ? 4 : 18),
                              bottomRight:
                                  Radius.circular(msg.isAi ? 18 : 4),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                    alpha: isDark ? 0.18 : 0.055),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            msg.text,
                            style: TextStyle(
                              color: msg.isAi
                                  ? textPrimary
                                  : Colors.white,
                              fontSize: 13,
                              height: 1.55,
                            ),
                          ),
                        ),
                      ),
                      if (!msg.isAi) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.person_rounded,
                              size: 16, color: color),
                        ),
                      ],
                    ],
                  ),
                );
              },
              childCount: _mockMessages.length,
            ),
          ),
        ),
        // 输入框 mock
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.07),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '有什么新想法或疑问…',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? const Color(0xFF555555)
                            : const Color(0xFFBBB0D0),
                      ),
                    ),
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2A2A2A)
                          : const Color(0xFFEEEEEE),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_upward_rounded,
                      color: isDark
                          ? const Color(0xFF555555)
                          : const Color(0xFFAAAAAA),
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  扩展原语预览
// ═══════════════════════════════════════════════════════════════

// ── timeline 预览 ────────────────────────────────────────────────

class _TimelinePreview extends StatelessWidget {
  final _PrimitiveMeta meta;
  final bool isDark;
  const _TimelinePreview({required this.meta, required this.isDark});

  static final _mockEvents = [
    _MockTimelineEvent('2024/01', '开始跑步', '第一次5km，用了42分钟，跑完几乎走不了路。', true),
    _MockTimelineEvent('2024/03', '突破10km', '训练三个月后，完成了第一次10km，用时68分钟。', true),
    _MockTimelineEvent('2024/05', '第一次半马', '21km，用时2小时22分。终点前500米泪目了。', true),
    _MockTimelineEvent('2024/08', '目标：全马', '报名了12月的马拉松，开始系统备战。', false),
  ];

  @override
  Widget build(BuildContext context) {
    final color = meta.color;
    final cardBg = isDark ? DarkPalette.card : Colors.white;
    final textPrimary =
        isDark ? DarkPalette.textPrimary : const Color(0xFF1A1A2E);
    final textSecondary =
        isDark ? DarkPalette.textSecondary : const Color(0xFF666688);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _PrimitiveInfoCard(meta: meta, isDark: isDark)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _ConfigChips(
              chips: const [
                'direction: forward',
                'show_date: true',
                'phases: 探索期/成长期/冲刺期',
              ],
              color: color,
              isDark: isDark,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                final ev = _mockEvents[i];
                final isLast = i == _mockEvents.length - 1;
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 时间轴
                      SizedBox(
                        width: 52,
                        child: Column(
                          children: [
                            Container(
                              width: ev.isCompleted ? 14 : 12,
                              height: ev.isCompleted ? 14 : 12,
                              margin: const EdgeInsets.only(top: 4),
                              decoration: BoxDecoration(
                                color: ev.isCompleted
                                    ? color
                                    : color.withValues(alpha: 0.3),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: isDark
                                        ? AppColors.backgroundDark
                                        : AppColors.backgroundLight,
                                    width: 2),
                                boxShadow: ev.isCompleted
                                    ? [
                                        BoxShadow(
                                          color:
                                              color.withValues(alpha: 0.4),
                                          blurRadius: 6,
                                        )
                                      ]
                                    : null,
                              ),
                            ),
                            if (!isLast)
                              Expanded(
                                child: Container(
                                  width: 2,
                                  margin: const EdgeInsets.only(top: 4),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        color.withValues(alpha: 0.5),
                                        color.withValues(alpha: 0.1),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // 内容卡片
                      Expanded(
                        child: Container(
                          margin:
                              EdgeInsets.only(bottom: isLast ? 0 : 16),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: ev.isCompleted
                                  ? color.withValues(alpha: 0.25)
                                  : (isDark
                                      ? Colors.white
                                          .withValues(alpha: 0.06)
                                      : Colors.black
                                          .withValues(alpha: 0.04)),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                    alpha: isDark ? 0.14 : 0.04),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color:
                                          color.withValues(alpha: 0.1),
                                      borderRadius:
                                          BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      ev.date,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: color,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  if (!ev.isCompleted)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.orange
                                            .withValues(alpha: 0.1),
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '目标',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.orange[700],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                ev.title,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                ev.desc,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: textSecondary,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              childCount: _mockEvents.length,
            ),
          ),
        ),
      ],
    );
  }
}

// ── qa_exploration 预览 ──────────────────────────────────────────

class _QaExplorationPreview extends StatelessWidget {
  final _PrimitiveMeta meta;
  final bool isDark;
  const _QaExplorationPreview({required this.meta, required this.isDark});

  static final _mockQa = [
    _MockQaNode(0, '我真正想要的是什么样的工作？', null, 0),
    _MockQaNode(1, '能让我有「意义感」的工作', '答案', 1),
    _MockQaNode(2, '「意义感」对你来说意味着什么？', '追问', 2),
    _MockQaNode(3, '做的事情能影响到别人', '答案', 3),
    _MockQaNode(4, '是什么让你觉得现在的工作缺乏这个？', '追问', 4),
    _MockQaNode(5, '重复性太强，看不到自己的贡献', '答案', 3),
  ];

  @override
  Widget build(BuildContext context) {
    final color = meta.color;
    final cardBg = isDark ? DarkPalette.card : Colors.white;
    final textPrimary =
        isDark ? DarkPalette.textPrimary : const Color(0xFF1A1A2E);
    final textSecondary =
        isDark ? DarkPalette.textSecondary : const Color(0xFF666688);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _PrimitiveInfoCard(meta: meta, isDark: isDark)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _ConfigChips(
              chips: const [
                'depth_limit: 5',
                'ai_follow_up: true',
                'seed_question: 自定义',
              ],
              color: color,
              isDark: isDark,
            ),
          ),
        ),
        // 种子问题展示
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.12 : 0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome_rounded,
                      size: 14, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AI 入口问题：我真正想要的是什么样的工作？',
                      style: TextStyle(
                        fontSize: 13,
                        color: textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                final node = _mockQa[i];
                final isRoot = node.depth == 0;
                final isQuestion = node.type == null || node.type == '追问';
                return Container(
                  margin: EdgeInsets.only(
                    bottom: 8,
                    left: (node.depth * 18.0).clamp(0.0, 72.0),
                  ),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isQuestion
                        ? color.withValues(alpha: isDark ? 0.1 : 0.06)
                        : cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isRoot
                          ? color.withValues(alpha: 0.35)
                          : isQuestion
                              ? color.withValues(alpha: 0.2)
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : Colors.black.withValues(alpha: 0.04)),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (node.type != null) ...[
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isQuestion
                                    ? color.withValues(alpha: 0.12)
                                    : Colors.green
                                        .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                isQuestion ? '🔍 追问' : '💬 回答',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isQuestion ? color : Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],
                      Text(
                        isRoot ? '❓ ${node.text}' : node.text,
                        style: TextStyle(
                          fontSize: isRoot ? 14 : 13,
                          fontWeight: isRoot
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isQuestion
                              ? (isRoot ? color : textPrimary)
                              : textSecondary,
                          height: 1.5,
                        ),
                      ),
                      if (!isRoot) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.subdirectory_arrow_right_rounded,
                              size: 11,
                              color: color.withValues(alpha: 0.5),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '继续追问',
                              style: TextStyle(
                                fontSize: 10,
                                color: color.withValues(alpha: 0.65),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
              childCount: _mockQa.length,
            ),
          ),
        ),
      ],
    );
  }
}

// ── tension_board 预览 ────────────────────────────────────────────

class _TensionBoardPreview extends StatelessWidget {
  final _PrimitiveMeta meta;
  final bool isDark;
  const _TensionBoardPreview({required this.meta, required this.isDark});

  static final _leftItems = [
    '完全自主，可以按自己的节奏工作',
    '没有无聊的汇报，专注做事',
    '收入上限更高，成功了可以实现财务自由',
    '打造属于自己的东西，有成就感',
  ];

  static final _rightItems = [
    '收入不稳定，前期可能入不敷出',
    '一个人扛所有压力，很孤独',
    '需要处理大量非技术性事务',
    '失败风险高，可能浪费多年时间',
  ];

  @override
  Widget build(BuildContext context) {
    final color = meta.color;
    final leftColor = const Color(0xFF27AE60);
    final rightColor = const Color(0xFFE74C3C);
    final cardBg = isDark ? DarkPalette.card : Colors.white;
    final textPrimary =
        isDark ? DarkPalette.textPrimary : const Color(0xFF1A1A2E);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _PrimitiveInfoCard(meta: meta, isDark: isDark)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _ConfigChips(
              chips: const [
                'left_label: 创业的理由',
                'right_label: 创业的代价',
              ],
              color: color,
              isDark: isDark,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: _buildSideHeader('✅ 创业的理由', leftColor, isDark),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSideHeader('❌ 创业的代价', rightColor, isDark),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: _leftItems
                          .map((t) => _buildCard(t, leftColor, cardBg,
                              textPrimary, isDark))
                          .toList(),
                    ),
                  ),
                  Container(
                    width: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.07)
                        : Colors.black.withValues(alpha: 0.05),
                  ),
                  Expanded(
                    child: Column(
                      children: _rightItems
                          .map((t) => _buildCard(t, rightColor, cardBg,
                              textPrimary, isDark))
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSideHeader(String label, Color sideColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: sideColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: sideColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildCard(String text, Color sideColor, Color cardBg,
      Color textPrimary, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: sideColor.withValues(alpha: isDark ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: sideColor.withValues(alpha: 0.15)),
      ),
      child: Text(
        text,
        style: TextStyle(
            fontSize: 12, color: textPrimary, height: 1.4),
      ),
    );
  }
}

// ── relation_map 预览 ─────────────────────────────────────────────

class _RelationMapPreview extends StatelessWidget {
  final _PrimitiveMeta meta;
  final bool isDark;
  const _RelationMapPreview({required this.meta, required this.isDark});

  static final _mockNodes = [
    _MockRelationNode('极简主义', '核心', '作为生活方式框架的切入点'),
    _MockRelationNode('断舍离', '方法论', '极简主义的实践技法，源自日本'),
    _MockRelationNode('正念冥想', '相关概念', '与极简主义同属「去噪」范式'),
    _MockRelationNode('斯多葛主义', '哲学根源', '极简主义的哲学底座之一'),
    _MockRelationNode('消费主义', '对立面', '极简主义所对抗的文化力量'),
    _MockRelationNode('心理空间', '效果维度', '极简主义带来的内在清净感'),
  ];

  @override
  Widget build(BuildContext context) {
    final color = meta.color;
    final cardBg = isDark ? DarkPalette.card : Colors.white;
    final textPrimary =
        isDark ? DarkPalette.textPrimary : const Color(0xFF1A1A2E);
    final textSecondary =
        isDark ? DarkPalette.textSecondary : const Color(0xFF666688);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _PrimitiveInfoCard(meta: meta, isDark: isDark)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _ConfigChips(
              chips: const [
                'center_label: 极简主义',
                'node_types: 方法论/哲学根源/对立面',
              ],
              color: color,
              isDark: isDark,
            ),
          ),
        ),
        // 中心节点
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '◉ 极简主义',
                    style: TextStyle(
                      fontSize: 14,
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '的关联网络',
                  style: TextStyle(fontSize: 13, color: textSecondary),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                final node = _mockNodes[i];
                // 颜色按节点类型区分
                final nodeColors = {
                  '核心': color,
                  '方法论': const Color(0xFF26A69A),
                  '相关概念': const Color(0xFF5C6BC0),
                  '哲学根源': const Color(0xFF7E57C2),
                  '对立面': const Color(0xFFE74C3C),
                  '效果维度': const Color(0xFF66BB6A),
                };
                final nodeColor = nodeColors[node.type] ?? color;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: nodeColor.withValues(alpha: 0.18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: isDark ? 0.12 : 0.03),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: nodeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          node.type,
                          style: TextStyle(
                            fontSize: 11,
                            color: nodeColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              node.name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                            Text(
                              node.desc,
                              style: TextStyle(
                                fontSize: 11,
                                color: textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 11,
                        color: textSecondary.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                );
              },
              childCount: _mockNodes.length,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  自由原语预览
// ─────────────────────────────────────────────────────────────────

class _FreeformPreview extends StatelessWidget {
  final _PrimitiveMeta meta;
  final bool isDark;
  const _FreeformPreview({required this.meta, required this.isDark});

  static final _mockEntries = [
    {
      'time': '今天 10:32',
      'rating': '9/10',
      'highlight': '和老朋友聊了两个小时，久违的放松感',
      'lesson': '高质量的社交比孤独思考更能帮助我理清思路',
      'nextAction': '下周约晚饭',
    },
    {
      'time': '昨天 22:10',
      'rating': '7/10',
      'highlight': '完成了拖了三周的文章草稿',
      'lesson': '只要开始，拖延就会消失',
      'nextAction': '明天修改第二稿',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final color = meta.color;
    final cardBg = isDark ? DarkPalette.card : Colors.white;
    final textPrimary =
        isDark ? DarkPalette.textPrimary : const Color(0xFF1A1A2E);
    final textSecondary =
        isDark ? DarkPalette.textSecondary : const Color(0xFF666688);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _PrimitiveInfoCard(meta: meta, isDark: isDark)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _ConfigChips(
              chips: const [
                'render_hint: 每日复盘',
                'ai_role: 复盘导师',
                'fields: rating/highlight/lesson/next',
              ],
              color: color,
              isDark: isDark,
            ),
          ),
        ),
        // Freeform 头部信息
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.1 : 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('🌀', style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '每日复盘',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                            ),
                            Text(
                              'render_hint · 每日复盘',
                              style: TextStyle(
                                fontSize: 11,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome_rounded,
                                size: 10, color: color),
                            const SizedBox(width: 3),
                            Text(
                              'AI 自定义',
                              style: TextStyle(
                                fontSize: 10,
                                color: color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'AI 会以「复盘导师」的角色陪你回顾每一天，引导你提炼规律，发现盲区，持续成长。',
                    style: TextStyle(
                        fontSize: 13, color: textSecondary, height: 1.5),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.psychology_rounded,
                          size: 13, color: color),
                      const SizedBox(width: 5),
                      Text(
                        'AI 在此扮演：复盘导师',
                        style: TextStyle(
                          fontSize: 12,
                          color: color,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                final entry = _mockEntries[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.04),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: isDark ? 0.12 : 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            entry['time']!,
                            style: TextStyle(
                              fontSize: 11,
                              color: color,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '⭐ ${entry['rating']}',
                              style: TextStyle(
                                fontSize: 12,
                                color: color,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildFreeformField(
                          '亮点', entry['highlight']!,
                          color, textPrimary, textSecondary, isDark),
                      const SizedBox(height: 8),
                      _buildFreeformField(
                          '收获', entry['lesson']!,
                          const Color(0xFF66BB6A), textPrimary,
                          textSecondary, isDark),
                      const SizedBox(height: 8),
                      _buildFreeformField(
                          '下一步', entry['nextAction']!,
                          const Color(0xFF29B6F6), textPrimary,
                          textSecondary, isDark),
                    ],
                  ),
                );
              },
              childCount: _mockEntries.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFreeformField(String label, String value, Color fieldColor,
      Color textPrimary, Color textSecondary, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 46,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: fieldColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: textPrimary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  共用 UI 组件
// ═══════════════════════════════════════════════════════════════

/// 原语信息卡：顶部标识 + 语义说明 + 层次徽章
class _PrimitiveInfoCard extends StatelessWidget {
  final _PrimitiveMeta meta;
  final bool isDark;
  const _PrimitiveInfoCard({required this.meta, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        isDark ? DarkPalette.textPrimary : const Color(0xFF1A1A2E);
    final textSecondary =
        isDark ? DarkPalette.textSecondary : const Color(0xFF666688);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: meta.color.withValues(alpha: isDark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: meta.color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: meta.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(meta.type.emoji,
                      style: const TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          meta.label,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _LayerBadge(layer: meta.layer, color: meta.color),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      meta.desc,
                      style: TextStyle(
                        fontSize: 12,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              meta.name,
              style: TextStyle(
                fontSize: 11,
                color: meta.color,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Config 参数展示 chips
class _ConfigChips extends StatelessWidget {
  final List<String> chips;
  final Color color;
  final bool isDark;

  const _ConfigChips(
      {required this.chips, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.tune_rounded, size: 11, color: color.withValues(alpha: 0.7)),
            const SizedBox(width: 5),
            Text(
              'config 参数',
              style: TextStyle(
                fontSize: 11,
                color: color.withValues(alpha: 0.8),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 5,
          children: chips
              .map((chip) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Text(
                      chip,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark
                            ? DarkPalette.textSecondary
                            : const Color(0xFF666688),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

/// 层次徽章
class _LayerBadge extends StatelessWidget {
  final String layer;
  final Color color;
  const _LayerBadge({required this.layer, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        layer,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Tab 标题里的彩色小圆点（区分原语层次）
class _LayerDot extends StatelessWidget {
  final String layer;
  final Color color;
  const _LayerDot({required this.layer, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.8),
        shape: BoxShape.circle,
      ),
    );
  }
}

/// 统计单格（用于 structured_log 预览）
class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final double? diff;
  final Color color;
  final Color textPrimary;
  final Color textSecondary;

  const _StatCell({
    required this.label,
    required this.value,
    required this.unit,
    required this.diff,
    required this.color,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final diffColor = diff == null
        ? Colors.transparent
        : (diff! < 0 ? const Color(0xFF27AE60) : const Color(0xFFE74C3C));

    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: textSecondary),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 2),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    unit!,
                    style: TextStyle(fontSize: 11, color: textSecondary),
                  ),
                ),
              ],
            ],
          ),
          if (diff != null)
            Text(
              '${diff! >= 0 ? '+' : ''}${diff!.toStringAsFixed(1)}',
              style: TextStyle(fontSize: 11, color: diffColor),
            ),
        ],
      ),
    );
  }
}

/// StickyTabBarDelegate
class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final bool isDark;

  const _StickyTabBarDelegate(this.tabBar, {required this.isDark});

  @override
  double get minExtent => tabBar.preferredSize.height + 1;
  @override
  double get maxExtent => tabBar.preferredSize.height + 1;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      child: Column(
        children: [
          Container(
            height: 0.5,
            color: isDark
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.black.withValues(alpha: 0.05),
          ),
          tabBar,
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) =>
      tabBar != oldDelegate.tabBar || isDark != oldDelegate.isDark;
}

// ═══════════════════════════════════════════════════════════════
//  数据模型 (Mock)
// ═══════════════════════════════════════════════════════════════

class _PrimitiveMeta {
  final DimensionType type;
  final String name;
  final String label;
  final String desc;
  final String layer;
  final Color color;

  const _PrimitiveMeta({
    required this.type,
    required this.name,
    required this.label,
    required this.desc,
    required this.layer,
    required this.color,
  });
}

class _MockNote {
  final String? title;
  final String content;
  final String time;
  final String? comment;
  _MockNote(this.title, this.content, this.time, {this.comment});
}

class _MockTodo {
  final String title;
  bool done;
  final String? priority;
  final String? dueDate;
  _MockTodo(this.title, this.done, this.priority, this.dueDate);
}

class _MockCollect {
  final String title;
  final String? url;
  final String excerpt;
  final String type;
  _MockCollect(this.title, this.url, this.excerpt, this.type);
}

class _MockChatMsg {
  final bool isAi;
  final String text;
  _MockChatMsg({required this.isAi, required this.text});
}

class _MockTimelineEvent {
  final String date;
  final String title;
  final String desc;
  final bool isCompleted;
  _MockTimelineEvent(this.date, this.title, this.desc, this.isCompleted);
}

class _MockQaNode {
  final int id;
  final String text;
  final String? type;
  final int depth;
  _MockQaNode(this.id, this.text, this.type, this.depth);
}

class _MockRelationNode {
  final String name;
  final String type;
  final String desc;
  _MockRelationNode(this.name, this.type, this.desc);
}

// ─────────────────────────────────────────────────────────────────
//  DimensionType 扩展：emoji 和 defaultLabel
// ─────────────────────────────────────────────────────────────────

extension DimensionTypePreviewExt on DimensionType {
  String get emoji {
    switch (this) {
      case DimensionType.noteFlow:
        return '✍️';
      case DimensionType.todoList:
        return '✅';
      case DimensionType.collectBoard:
        return '💎';
      case DimensionType.structuredLog:
        return '📊';
      case DimensionType.aiChat:
        return '🤖';
      case DimensionType.timeline:
        return '🕰️';
      case DimensionType.qaExploration:
        return '🔍';
      case DimensionType.tensionBoard:
        return '⚖️';
      case DimensionType.relationMap:
        return '🕸️';
      case DimensionType.freeform:
        return '🌀';
    }
  }

  String get defaultLabel {
    switch (this) {
      case DimensionType.noteFlow:
        return '观察';
      case DimensionType.todoList:
        return '行动';
      case DimensionType.collectBoard:
        return '收集';
      case DimensionType.structuredLog:
        return '测量';
      case DimensionType.aiChat:
        return '对话';
      case DimensionType.timeline:
        return '演进';
      case DimensionType.qaExploration:
        return '追问';
      case DimensionType.tensionBoard:
        return '对立';
      case DimensionType.relationMap:
        return '关联';
      case DimensionType.freeform:
        return '自由';
    }
  }
}
