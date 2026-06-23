import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/checklist.dart';
import '../models/user_profile.dart';
import '../providers/checklist_provider.dart';
import '../providers/user_profile_provider.dart';
import '../services/ai_service.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────
//  ChecklistDetailScreen —— 清单详情页
//
//  功能：
//  • 展示并勾选/取消条目（动画）
//  • 添加/编辑/删除单个条目
//  • 顶部进度条
//  • AI 一键生成条目（浮动 AI 按钮）
//  • 长按条目弹出操作菜单
//  • 右上角菜单：重置/清空已完成/归档
// ─────────────────────────────────────────────────────────────────

class ChecklistDetailScreen extends StatefulWidget {
  final String checklistId;

  const ChecklistDetailScreen({super.key, required this.checklistId});

  @override
  State<ChecklistDetailScreen> createState() => _ChecklistDetailScreenState();
}

class _ChecklistDetailScreenState extends State<ChecklistDetailScreen>
    with TickerProviderStateMixin {
  bool _isAiGenerating = false;
  final TextEditingController _quickAddCtrl = TextEditingController();
  // grouped 风格下的分组名输入
  final TextEditingController _quickGroupCtrl = TextEditingController();
  final FocusNode _quickAddFocus = FocusNode();
  bool _showQuickAdd = false;

  @override
  void dispose() {
    _quickAddCtrl.dispose();
    _quickGroupCtrl.dispose();
    _quickAddFocus.dispose();
    super.dispose();
  }

  Color _accentColor(Checklist checklist) {
    try {
      final hex = checklist.colorHex.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF5C7CFA);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<ChecklistProvider>(
      builder: (context, provider, _) {
        final checklist = provider.findById(widget.checklistId);
        if (checklist == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('清单')),
            body: const Center(child: Text('清单不存在')),
          );
        }

        final accent = _accentColor(checklist);
        final bgColor =
            isDark ? AppColors.backgroundDark : const Color(0xFFF8F8F8);

        return Scaffold(
          backgroundColor: bgColor,
          body: CustomScrollView(
            slivers: [
              // ── 应用栏 ──────────────────────────────────────────────
              _buildAppBar(context, checklist, accent, isDark),
              // ── 进度区 ──────────────────────────────────────────────
              SliverToBoxAdapter(
                child: _ProgressHeader(
                    checklist: checklist, accent: accent, isDark: isDark),
              ),
              // ── 智能模式纠错 Banner ──────────────────────────────────
              SliverToBoxAdapter(
                child: _ModeMismatchBanner(
                    checklist: checklist, accent: accent, isDark: isDark),
              ),
              // ── 条目列表 ─────────────────────────────────────────────
              _buildItemList(context, checklist, accent, isDark),
              // ── 快速添加栏（sticky 底部前预留空间）────────────────────
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
          // ── 底部操作栏 ───────────────────────────────────────────────
          bottomNavigationBar: _BottomBar(
            checklist: checklist,
            accent: accent,
            isDark: isDark,
            isAiGenerating: _isAiGenerating,
            showQuickAdd: _showQuickAdd,
            quickAddCtrl: _quickAddCtrl,
            quickGroupCtrl: _quickGroupCtrl,
            quickAddFocus: _quickAddFocus,
            onToggleQuickAdd: () {
              setState(() {
                _showQuickAdd = !_showQuickAdd;
                if (_showQuickAdd) {
                  Future.delayed(const Duration(milliseconds: 100), () {
                    _quickAddFocus.requestFocus();
                  });
                }
              });
            },
            onQuickAddSubmit: () => _quickAddItem(context, checklist),
            onAiGenerate: () => _generateWithAi(context, checklist),
            onOpenSettings: () => _showAdvancedSettings(context, checklist),
          ),
        );
      },
    );
  }

  // ── 应用栏 ───────────────────────────────────────────────────────

  SliverAppBar _buildAppBar(
      BuildContext context, Checklist checklist, Color accent, bool isDark) {
    final bgColor = isDark ? AppColors.backgroundDark : const Color(0xFFF8F8F8);
    return SliverAppBar(
      pinned: true,
      backgroundColor: bgColor,
      elevation: 0,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 20,
          color: isDark ? Colors.white70 : const Color(0xFF444444),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Text(checklist.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              checklist.title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1A1410),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        // 时态型：全部完成时显示「完成归档」快捷按钮
        if (checklist.checklistType == ChecklistType.temporal &&
            checklist.isAllDone)
          GestureDetector(
            onTap: () {
              context
                  .read<ChecklistProvider>()
                  .completeAndArchiveTemporal(checklist.id);
              Navigator.pop(context);
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text(
                    '完成归档',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        PopupMenuButton<String>(
          icon: Icon(
            Icons.more_horiz_rounded,
            color: isDark ? Colors.white70 : const Color(0xFF666666),
          ),
          color: isDark ? AppColors.surfaceDark : Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          onSelected: (v) => _handleMenuAction(context, v, checklist),
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'reset',
              child: Row(children: [
                Icon(Icons.refresh_rounded, size: 18),
                SizedBox(width: 10),
                Text('重置所有'),
              ]),
            ),
            const PopupMenuItem(
              value: 'clearChecked',
              child: Row(children: [
                Icon(Icons.clear_all_rounded, size: 18),
                SizedBox(width: 10),
                Text('清空已完成'),
              ]),
            ),
            const PopupMenuDivider(),
            // 时态型：显示「完成并归档」
            if (checklist.checklistType == ChecklistType.temporal)
              PopupMenuItem(
                value: 'completeArchive',
                child: Row(children: [
                  const Icon(Icons.check_circle_outline_rounded,
                      size: 18, color: Colors.green),
                  const SizedBox(width: 10),
                  Text('完成并归档',
                      style: TextStyle(
                          color: isDark ? Colors.white70 : const Color(0xFF444444))),
                ]),
              ),
            PopupMenuItem(
              value: 'archive',
              child: Row(children: [
                Icon(Icons.archive_outlined,
                    size: 18,
                    color: isDark ? Colors.white54 : const Color(0xFF888888)),
                const SizedBox(width: 10),
                Text('归档清单',
                    style: TextStyle(
                        color: isDark ? Colors.white54 : const Color(0xFF888888))),
              ]),
            ),
          ],
        ),
      ],
    );
  }

  // ── 条目列表（根据 interactionMode 分叉）────────────────────────
  //
  // ┌─────────────────────────────────────────────────────────────┐
  // │  style × interactionMode 协同规则                           │
  // │                                                             │
  // │  style 决定「布局骨架」：                                    │
  // │    grouped  → 带分组折叠头的布局；组内条目由 interactionMode  │
  // │               通过 _ItemTile._resolvedMode 选择控件          │
  // │    numbered → 严格按 sortOrder 排列，左侧显示序号气泡         │
  // │    simple   → 已完成下沉，未完成上置                         │
  // │                                                             │
  // │  interactionMode 决定「条目级控件」：                        │
  // │    execution → checkbox（默认）                             │
  // │    reference → _ReferenceItemTile（星评 + 只读）；           │
  // │                grouped 时降级为 _ItemTile(infoOnly)          │
  // │    review    → _ReviewItemTile（inline noteEntry）；         │
  // │                grouped 时复用 _ItemTile(noteEntry)           │
  // │    process   → _ProcessItemTile（带锁定/序号）；             │
  // │                grouped 时复用 _ItemTile(statusCycle)         │
  // │                                                             │
  // │  结论：grouped 风格「始终优先」走 _buildGroupedList，          │
  // │        分组内条目由 _ItemTile._resolvedMode 处理多态控件。     │
  // └─────────────────────────────────────────────────────────────┘

  Widget _buildItemList(
      BuildContext context, Checklist checklist, Color accent, bool isDark) {
    // grouped 风格：始终优先走分组布局，组内由 _resolvedMode 处理控件
    // 这样 grouped + any interactionMode 都能正确显示分组头
    if (checklist.style == ChecklistStyle.grouped) {
      return checklist.items.isEmpty
          ? _buildEmptyByMode(context, checklist, accent, isDark)
          : _buildGroupedList(context, checklist, accent, isDark);
    }

    // 非 grouped 风格：按 interactionMode 走专用 builder
    switch (checklist.interactionMode) {
      case ChecklistInteractionMode.reference:
        return _buildReferenceList(context, checklist, accent, isDark);
      case ChecklistInteractionMode.review:
        return _buildReviewList(context, checklist, accent, isDark);
      case ChecklistInteractionMode.process:
        return _buildProcessList(context, checklist, accent, isDark);
      case ChecklistInteractionMode.execution:
        break; // 走默认路径
    }

    if (checklist.items.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 60),
          child: Column(
            children: [
              Text('📋', style: const TextStyle(fontSize: 48)),
              const SizedBox(height: 14),
              Text(
                '清单还是空的',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : const Color(0xFF444444),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  '你可以手动添加，\n或者让 AI 帮你起草一份初稿，再自己调整',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : const Color(0xFFBBBBBB),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // 空状态直接触发 AI 起草
              GestureDetector(
                onTap: () => _generateWithAi(context, checklist),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('✨', style: TextStyle(fontSize: 15)),
                      SizedBox(width: 6),
                      Text(
                        'AI 帮我起草初稿',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'AI 生成的是草稿，你可以随时增删修改',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : const Color(0xFFCCCCCC),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 分组逻辑
    if (checklist.style == ChecklistStyle.grouped) {
      return _buildGroupedList(context, checklist, accent, isDark);
    }

    final isNumbered = checklist.style == ChecklistStyle.numbered;

    // 普通列表
    final items = List<ChecklistItem>.from(checklist.items);
    if (isNumbered) {
      // numbered 模式：严格按 sortOrder 顺序排列，保持步骤语义
      items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    } else {
      // simple 模式：未完成的排前面
      items.sort((a, b) {
        if (a.isChecked == b.isChecked) return a.sortOrder.compareTo(b.sortOrder);
        return a.isChecked ? 1 : -1;
      });
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (ctx, idx) => _ItemTile(
          item: items[idx],
          checklistId: checklist.id,
          checklistInteractionMode: checklist.interactionMode,
          accent: accent,
          isDark: isDark,
          // numbered 风格传入序号；simple 风格不传（null）
          index: isNumbered ? idx : null,
          onTap: () {
            HapticFeedback.lightImpact();
            context
                .read<ChecklistProvider>()
                .toggleItem(checklist.id, items[idx].id);
          },
          onLongPress: () =>
              _showItemMenu(context, checklist, items[idx], accent, isDark),
          onItemUpdated: (updated) =>
              context.read<ChecklistProvider>().updateItem(checklist.id, updated),
        ),
        childCount: items.length,
      ),
    );
  }

  Widget _buildGroupedList(
      BuildContext context, Checklist checklist, Color accent, bool isDark) {
    // 按 groupLabel 分组，保留插入顺序
    final groups = <String, List<ChecklistItem>>{};
    for (final item in checklist.items) {
      final key = item.groupLabel ?? '其他';
      groups.putIfAbsent(key, () => []).add(item);
    }

    final children = <Widget>[];
    groups.forEach((group, groupItems) {
      final checked = groupItems.where((i) => i.isChecked).length;
      final total = groupItems.length;

      // ── 分组标题行 ─────────────────────────────────────────────────
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Row(
            children: [
              // 左侧色条
              Container(
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              // 组名
              Text(
                group,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : const Color(0xFF444444),
                ),
              ),
              const SizedBox(width: 8),
              // 完成比例徽章
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: checked == total && total > 0
                      ? Colors.green.withValues(alpha: 0.15)
                      : accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$checked/$total',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: checked == total && total > 0
                        ? Colors.green
                        : accent,
                  ),
                ),
              ),
              const Spacer(),
              // 「+」快速添加到此组
              GestureDetector(
                onTap: () => _quickAddToGroup(context, checklist, group),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, size: 14, color: accent),
                      const SizedBox(width: 2),
                      Text('添加',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: accent)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      // ── 该组的条目 ──────────────────────────────────────────────────
      for (final item in groupItems) {
        children.add(
          _ItemTile(
            item: item,
            checklistId: checklist.id,
            checklistInteractionMode: checklist.interactionMode,
            accent: accent,
            isDark: isDark,
            onTap: () {
              HapticFeedback.lightImpact();
              context
                  .read<ChecklistProvider>()
                  .toggleItem(checklist.id, item.id);
            },
            onLongPress: () =>
                _showItemMenu(context, checklist, item, accent, isDark),
            onItemUpdated: (updated) =>
                context.read<ChecklistProvider>().updateItem(checklist.id, updated),
          ),
        );
      }
    });

    return SliverList(
      delegate: SliverChildListDelegate(children),
    );
  }

  // ── 快速添加 ─────────────────────────────────────────────────────

  Future<void> _quickAddItem(
      BuildContext context, Checklist checklist) async {
    final text = _quickAddCtrl.text.trim();
    if (text.isEmpty) {
      setState(() => _showQuickAdd = false);
      return;
    }
    final groupLabel = checklist.style == ChecklistStyle.grouped
        ? (_quickGroupCtrl.text.trim().isEmpty
            ? null
            : _quickGroupCtrl.text.trim())
        : null;
    await context
        .read<ChecklistProvider>()
        .addItem(checklist.id, title: text, groupLabel: groupLabel);
    _quickAddCtrl.clear();
    if (mounted) _quickAddFocus.requestFocus();
  }

  /// grouped 风格下：点击分组标题旁的「+」，快速向该组添加条目
  Future<void> _quickAddToGroup(
      BuildContext context, Checklist checklist, String groupName) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = _accentColor(checklist);
    final ctrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      groupName,
                      style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: accent),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('添加条目',
                    style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1A1410),
                    )),
                ]),
                const SizedBox(height: 14),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? Colors.white : const Color(0xFF1A1410)),
                  decoration: InputDecoration(
                    hintText: '输入条目名称…',
                    hintStyle: TextStyle(
                      color: isDark ? AppColors.textTertiaryDark : const Color(0xFFBBBBBB)),
                    filled: true,
                    fillColor: isDark ? AppColors.inputFillDark : const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  onSubmitted: (v) {
                    if (v.trim().isNotEmpty) {
                      context.read<ChecklistProvider>().addItem(
                          checklist.id, title: v.trim(), groupLabel: groupName);
                    }
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: () {
                      final t = ctrl.text.trim();
                      if (t.isNotEmpty) {
                        context.read<ChecklistProvider>().addItem(
                            checklist.id, title: t, groupLabel: groupName);
                      }
                      Navigator.pop(context);
                    },
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text('添加',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── AI 生成 ──────────────────────────────────────────────────────

  Future<void> _generateWithAi(
      BuildContext context, Checklist checklist) async {
    if (_isAiGenerating) return;
    HapticFeedback.mediumImpact();

    // 在任何 await 之前提前获取 context 相关引用
    final provider = context.read<ChecklistProvider>();
    final userProfileProvider = context.read<UserProfileProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final isDarkSheet = Theme.of(context).brightness == Brightness.dark;

    // 弹出 AI 输入对话框
    final prompt = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AiGenerateSheet(
        checklist: checklist,
        accent: _accentColor(checklist),
        isDark: isDarkSheet,
      ),
    );

    if (prompt == null || prompt.isEmpty) return;
    if (!mounted) return;

    setState(() => _isAiGenerating = true);

    try {
      final aiService = AiService();
      final sceneLabel = checklist.scene.label;
      final styleLabel = checklist.style.label;
      final isGrouped = checklist.style == ChecklistStyle.grouped;
      final isShopping = checklist.scene == ChecklistScene.shopping;

      // 根据 interactionMode 动态构建 system prompt
      final modeHint = _buildAiModeHint(checklist.interactionMode, isGrouped, isShopping);

      // ── 三层用户画像注入 ──────────────────────────────────────────
      // 获取用户所有清单标题，供第三层行为推断使用
      final allChecklistTitles = provider.checklists
          .map((c) => c.title)
          .toList();
      final UserProfile userProfile = userProfileProvider.profile;
      final personaCtx = userProfile.buildAiPersonaContext(
        checklistTitles: allChecklistTitles,
      );
      // 仅当用户有画像时才追加（避免空内容污染 prompt）
      final systemWithPersona = personaCtx.isNotEmpty
          ? '$modeHint\n\n---\n【关于这个用户】\n$personaCtx'
          : modeHint;

      final response = await aiService.chatCompletion(
        messages: [
          {
            'role': 'system',
            'content': systemWithPersona,
          },
          {
            'role': 'user',
            'content': '场景：$sceneLabel；风格：$styleLabel。\n$prompt',
          },
        ],
        maxTokens: 1200,
        temperature: 0.7,
      );

      // 解析 JSON
      String jsonStr = response.trim();
      if (jsonStr.startsWith('```')) {
        final lines = jsonStr.split('\n');
        jsonStr = lines
            .where((l) => !l.startsWith('```'))
            .join('\n')
            .trim();
      }

      final rawList = jsonDecode(jsonStr) as List<dynamic>;
      final newItems = rawList.map((raw) {
        final map = raw as Map<String, dynamic>;
        // 根据 interactionMode 映射 itemMode
        final itemModeStr = map['itemMode'] as String?;
        final itemMode = itemModeStr != null
            ? ChecklistItemMode.fromValue(itemModeStr)
            : ChecklistItemMode.inherit;
        return ChecklistItem(
          id: const Uuid().v4(),
          title: map['title'] as String? ?? '条目',
          note: map['note'] as String?,
          groupLabel: map['groupLabel'] as String?,
          quantity: map['quantity'] as String?,
          itemMode: itemMode,
          sortOrder: 0,
          createdAt: DateTime.now(),
        );
      }).toList();

      await provider.addItems(checklist.id, newItems);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('AI 已起草 ${newItems.length} 个条目，可随时调整 ✏️'),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('AI 生成失败: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAiGenerating = false);
    }
  }

  // ── AI Prompt 构建（根据 interactionMode 动态调整）─────────────────

  /// 根据 interactionMode 生成对应的 system prompt。
  ///
  /// 四种范式的生成策略：
  ///   execution → 动作清单：短标题 + 可选分组/数量
  ///   reference → 知识清单：条目标题为知识点，note 作为说明/释义
  ///   review    → 复盘清单：条目为问题，AI 不填写答案（留给用户）
  ///   process   → 流程清单：条目为步骤，可带 statusCycle itemMode
  static String _buildAiModeHint(
    ChecklistInteractionMode mode,
    bool isGrouped,
    bool isShopping,
  ) {
    final groupHint = isGrouped ? '\n- 如果适合分类，请在 groupLabel 字段填写所属分组名称。' : '';
    final qtyHint = isShopping ? '\n- 如果是购物场景，可在 quantity 字段填写数量（如：2个、500g）。' : '';

    switch (mode) {
      case ChecklistInteractionMode.execution:
        // 执行/勾选 范式：简洁动作条目
        return '''你是一个专业的清单助手，帮助用户创建「执行清单」。
执行清单用于任务勾选，每个条目是一个具体的待办事项或动作。

请根据用户描述，生成一组清单条目，严格以 JSON 数组格式返回，不要添加任何额外文字。
JSON 格式：
[
  {"title": "条目标题（动词开头，如：检查、购买、完成）", "note": "可选备注", "groupLabel": "分组名（可选）", "quantity": "数量（可选）"}
]

要求：
- 条目数量 5~15 个
- 标题以动词开头，简洁明确（8字以内为佳）
- note 为可选补充说明$groupHint$qtyHint
- 只返回 JSON 数组，不要任何其他内容''';

      case ChecklistInteractionMode.reference:
        // 参考/知识 范式：条目是知识点，note 是说明
        return '''你是一个专业的清单助手，帮助用户创建「参考清单」。
参考清单作为知识库或速查表，每个条目是一个知识点、规则或参考项，note 字段包含简要说明。

请根据用户描述，生成一组清单条目，严格以 JSON 数组格式返回，不要添加任何额外文字。
JSON 格式：
[
  {"title": "知识点名称（简洁）", "note": "简要说明或释义（20字以内）", "groupLabel": "分类（可选）"}
]

要求：
- 条目数量 6~12 个
- title 为知识点/术语/规则的名称，note 为简要解释
- itemMode 字段可选填 "info_only" 表示仅供参考$groupHint
- 只返回 JSON 数组，不要任何其他内容''';

      case ChecklistInteractionMode.review:
        // 复盘/反思 范式：条目是问题，留给用户回答
        return '''你是一个专业的清单助手，帮助用户创建「复盘清单」。
复盘清单包含一系列反思性问题，用户需要逐一填写自己的想法和答案。

请根据用户描述，生成一组反思性问题条目，严格以 JSON 数组格式返回，不要添加任何额外文字。
JSON 格式：
[
  {"title": "反思问题（以疑问句或开放性问题的形式）", "note": "提示说明（可选，帮助用户理解如何回答）", "itemMode": "note_entry", "groupLabel": "分类（可选）"}
]

要求：
- 条目数量 5~10 个
- title 是开放性问题，鼓励深入思考（不超过20字）
- note 是简短的回答提示（可选）
- 每个条目的 itemMode 字段填 "note_entry"$groupHint
- 只返回 JSON 数组，不要任何其他内容''';

      case ChecklistInteractionMode.process:
        // 流程/SOP 范式：条目是流程步骤，可带状态
        return '''你是一个专业的清单助手，帮助用户创建「流程清单（SOP）」。
流程清单按步骤顺序组织任务，每个条目是一个具体的执行步骤，可追踪当前状态。

请根据用户描述，生成一组流程步骤条目，严格以 JSON 数组格式返回，不要添加任何额外文字。
JSON 格式：
[
  {"title": "步骤名称（如：第一步：收集资料）", "note": "步骤说明（可选）", "itemMode": "status_cycle", "groupLabel": "阶段（可选）"}
]

要求：
- 条目数量 5~12 个
- title 是流程步骤名称，按执行顺序排列
- 每个条目的 itemMode 字段填 "status_cycle"（支持未开始/进行中/已完成三态切换）
- note 为可选的步骤说明$groupHint
- 只返回 JSON 数组，不要任何其他内容''';
    }
  }

  // ── 条目长按菜单 ─────────────────────────────────────────────────

  void _showItemMenu(BuildContext context, Checklist checklist,
      ChecklistItem item, Color accent, bool isDark) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ItemContextMenu(
        item: item,
        accent: accent,
        isDark: isDark,
        onEdit: () {
          Navigator.pop(context);
          _editItem(context, checklist, item, isDark);
        },
        onDelete: () {
          Navigator.pop(context);
          context
              .read<ChecklistProvider>()
              .removeItem(checklist.id, item.id);
        },
      ),
    );
  }

  void _editItem(BuildContext context, Checklist checklist, ChecklistItem item,
      bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditItemSheet(
        item: item,
        checklist: checklist,
        accent: _accentColor(checklist),
        isDark: isDark,
        onSave: (updated) {
          context.read<ChecklistProvider>().updateItem(checklist.id, updated);
        },
      ),
    );
  }

  // \u2500\u2500 \u9876\u90e8\u83dc\u5355\u64cd\u4f5c \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500

  void _handleMenuAction(
      BuildContext context, String action, Checklist checklist) {
    final provider = context.read<ChecklistProvider>();
    switch (action) {
      case 'reset':
        provider.resetAll(checklist.id);
      case 'clearChecked':
        provider.clearCheckedItems(checklist.id);
      case 'completeArchive':
        provider.completeAndArchiveTemporal(checklist.id);
        Navigator.pop(context);
      case 'archive':
        provider.archiveChecklist(checklist.id);
        Navigator.pop(context);
      case 'switchMode':
        _showSwitchModeSheet(context, checklist);
    }
  }

  /// 进阶设置底部弹窗（布局风格 + 交互范式 + 危险操作）
  void _showAdvancedSettings(BuildContext context, Checklist checklist) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = _accentColor(checklist);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AdvancedSettingsSheet(
        checklist: checklist,
        accent: accent,
        isDark: isDark,
        onClose: () => Navigator.pop(context),
      ),
    );
  }

  /// 切换交互模式的底部弹窗
  void _showSwitchModeSheet(
      BuildContext context, Checklist checklist) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = _accentColor(checklist);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36, height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '切换交互模式',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1A1410),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '不同模式决定了如何与这张清单互动',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : const Color(0xFF888888),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...ChecklistInteractionMode.values.map((mode) {
                    final isActive = checklist.interactionMode == mode;
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        if (!isActive) {
                          context.read<ChecklistProvider>().updateChecklist(
                                checklist.copyWith(interactionMode: mode),
                              );
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isActive
                              ? accent.withValues(
                                  alpha: isDark ? 0.16 : 0.1)
                              : (isDark
                                  ? const Color(0xFF2A2A2A)
                                  : const Color(0xFFF8F8F8)),
                          borderRadius: BorderRadius.circular(14),
                          border: isActive
                              ? Border.all(
                                  color: accent.withValues(alpha: 0.5),
                                  width: 1.5)
                              : Border.all(
                                  color: isDark
                                      ? Colors.white10
                                      : Colors.black
                                          .withValues(alpha: 0.05),
                                  width: 0.5),
                        ),
                        child: Row(
                          children: [
                            Text(mode.emoji,
                                style: const TextStyle(fontSize: 22)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    mode.label,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: isActive
                                          ? accent
                                          : (isDark
                                              ? Colors.white
                                              : const Color(0xFF1A1410)),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _modeDescription(mode),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? AppColors.textTertiaryDark
                                          : const Color(0xFF888888),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isActive)
                              Icon(Icons.check_circle_rounded,
                                  size: 20, color: accent),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _modeDescription(ChecklistInteractionMode mode) {
    switch (mode) {
      case ChecklistInteractionMode.execution:
        return '勾选完成，追踪进度。适合打包、购物、待办';
      case ChecklistInteractionMode.reference:
        return '无需勾选，可评分收藏。适合书单、愿望清单';
      case ChecklistInteractionMode.review:
        return '每条是问题，展开填写回应。适合复盘、反思';
      case ChecklistInteractionMode.process:
        return '严格顺序，逐步解锁。适合上线流程、手术规程';
    }
  }

  // ── 参考范式条目列表 ──────────────────────────────────────────────
  // 浏览为主，无勾选，右侧可评分；按 sortOrder 排列

  Widget _buildReferenceList(
      BuildContext context, Checklist checklist, Color accent, bool isDark) {
    if (checklist.items.isEmpty) {
      return _buildEmptyState(context, checklist, isDark,
          emoji: '📖',
          title: '还没有参考条目',
          subtitle: '添加想看的书、想去的地方、\n想学的技能…随时翻阅');
    }
    final items = List<ChecklistItem>.from(checklist.items)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (ctx, idx) => _ReferenceItemTile(
          item: items[idx],
          accent: accent,
          isDark: isDark,
          onRatingChanged: (r) {
            context.read<ChecklistProvider>().updateItem(
                  checklist.id,
                  items[idx].copyWith(ratingValue: r),
                );
          },
          onLongPress: () =>
              _showItemMenu(context, checklist, items[idx], accent, isDark),
        ),
        childCount: items.length,
      ),
    );
  }

  // ── 回顾范式条目列表 ──────────────────────────────────────────────
  // 每条是一道问题，点击展开文字输入区；勾选 = 已回答

  Widget _buildReviewList(
      BuildContext context, Checklist checklist, Color accent, bool isDark) {
    if (checklist.items.isEmpty) {
      return _buildEmptyState(context, checklist, isDark,
          emoji: '🔍',
          title: '还没有回顾问题',
          subtitle: 'AI 可以帮你生成一份复盘问卷，\n逐题填写，把思考沉淀下来');
    }
    final items = List<ChecklistItem>.from(checklist.items)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (ctx, idx) => _ReviewItemTile(
          item: items[idx],
          index: idx,
          accent: accent,
          isDark: isDark,
          onToggle: () {
            HapticFeedback.lightImpact();
            context.read<ChecklistProvider>()
                .toggleItem(checklist.id, items[idx].id);
          },
          onResponseChanged: (response) {
            context.read<ChecklistProvider>().updateItem(
                  checklist.id,
                  items[idx].copyWith(noteResponse: response),
                );
          },
          onLongPress: () =>
              _showItemMenu(context, checklist, items[idx], accent, isDark),
        ),
        childCount: items.length,
      ),
    );
  }

  // ── 流程范式条目列表 ──────────────────────────────────────────────
  // 严格顺序：前一步未完成则锁定后续步骤

  Widget _buildProcessList(
      BuildContext context, Checklist checklist, Color accent, bool isDark) {
    if (checklist.items.isEmpty) {
      return _buildEmptyState(context, checklist, isDark,
          emoji: '🔢',
          title: '还没有流程步骤',
          subtitle: '按严格顺序逐步推进，\n上一步完成才能进行下一步');
    }
    final items = List<ChecklistItem>.from(checklist.items)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (ctx, idx) {
          // 第一步始终可操作；后续步骤须前一步已完成才能激活
          final isLocked = idx > 0 && !items[idx - 1].isChecked;
          return _ProcessItemTile(
            item: items[idx],
            index: idx,
            isLocked: isLocked,
            accent: accent,
            isDark: isDark,
            onTap: isLocked
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    context.read<ChecklistProvider>()
                        .toggleItem(checklist.id, items[idx].id);
                  },
            onLongPress: isLocked
                ? null
                : () => _showItemMenu(
                    context, checklist, items[idx], accent, isDark),
          );
        },
        childCount: items.length,
      ),
    );
  }

  // ── 通用空状态 ────────────────────────────────────────────────────

  /// grouped + interactionMode 组合时的空状态：
  /// 根据 interactionMode 选择对应的文案
  Widget _buildEmptyByMode(
      BuildContext context, Checklist checklist, Color accent, bool isDark) {
    switch (checklist.interactionMode) {
      case ChecklistInteractionMode.reference:
        return _buildEmptyState(context, checklist, isDark,
            emoji: '📖',
            title: '还没有参考条目',
            subtitle: '添加想看的书、想去的地方、\n想学的技能…随时翻阅');
      case ChecklistInteractionMode.review:
        return _buildEmptyState(context, checklist, isDark,
            emoji: '🔍',
            title: '还没有回顾问题',
            subtitle: 'AI 可以帮你生成一份复盘问卷，\n逐题填写，把思考沉淀下来');
      case ChecklistInteractionMode.process:
        return _buildEmptyState(context, checklist, isDark,
            emoji: '🔢',
            title: '还没有流程步骤',
            subtitle: '按分组组织 SOP 步骤，\n分组内条目支持状态追踪');
      case ChecklistInteractionMode.execution:
        return _buildEmptyState(context, checklist, isDark,
            emoji: '📋',
            title: '清单还是空的',
            subtitle: '你可以手动添加，\n或者让 AI 帮你起草一份初稿，再自己调整');
    }
  }

  Widget _buildEmptyState(
    BuildContext context,
    Checklist checklist,
    bool isDark, {
    required String emoji,
    required String title,
    required String subtitle,
  }) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : const Color(0xFF444444),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : const Color(0xFFBBBBBB),
                ),
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => _generateWithAi(context, checklist),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('✨', style: TextStyle(fontSize: 15)),
                    SizedBox(width: 6),
                    Text(
                      'AI 帮我起草初稿',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 进度顶部区 ────────────────────────────────────────────────────

// ── 智能模式纠错 Banner ───────────────────────────────────────────
// 当清单的 function 与 interactionMode 不匹配时（通常是历史数据），
// 提示用户一键切换到正确的交互范式。
class _ModeMismatchBanner extends StatelessWidget {
  final Checklist checklist;
  final Color accent;
  final bool isDark;

  const _ModeMismatchBanner(
      {required this.checklist, required this.accent, required this.isDark});

  /// 计算「推荐的」interactionMode（基于 function）
  ChecklistInteractionMode? get _recommendedMode {
    final expected =
        ChecklistInteractionMode.fromFunction(checklist.function);
    // 已经匹配，不需要提示
    if (checklist.interactionMode == expected) return null;
    // execution 是万能兜底，只在 function 明确需要特殊 mode 时才提示
    if (expected == ChecklistInteractionMode.execution) return null;
    return expected;
  }

  String _modeLabel(ChecklistInteractionMode mode) => switch (mode) {
        ChecklistInteractionMode.review => '复盘模式',
        ChecklistInteractionMode.process => '流程模式',
        ChecklistInteractionMode.reference => '参考模式',
        ChecklistInteractionMode.execution => '执行模式',
      };

  String _modeDesc(ChecklistInteractionMode mode) => switch (mode) {
        ChecklistInteractionMode.review => '每题下方可写文字回应，逐题填写思考',
        ChecklistInteractionMode.process => '步骤严格顺序，前一步完成才能进行下一步',
        ChecklistInteractionMode.reference => '浏览为主，无需打勾',
        ChecklistInteractionMode.execution => '经典勾选模式，有完成进度',
      };

  IconData _modeIcon(ChecklistInteractionMode mode) => switch (mode) {
        ChecklistInteractionMode.review => Icons.edit_note_rounded,
        ChecklistInteractionMode.process => Icons.account_tree_rounded,
        ChecklistInteractionMode.reference => Icons.menu_book_rounded,
        ChecklistInteractionMode.execution => Icons.check_box_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final recommended = _recommendedMode;
    if (recommended == null) return const SizedBox.shrink();

    final bannerBg = isDark
        ? accent.withValues(alpha: 0.12)
        : accent.withValues(alpha: 0.07);
    final borderColor = accent.withValues(alpha: isDark ? 0.3 : 0.2);
    final textColor =
        isDark ? Colors.white : const Color(0xFF1A1410);
    final subColor = isDark
        ? AppColors.textSecondaryDark
        : const Color(0xFF888888);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: bannerBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 0.8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 图标
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_modeIcon(recommended),
                  size: 18, color: accent),
            ),
            const SizedBox(width: 12),
            // 文字
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '切换到「${_modeLabel(recommended)}」效果更好',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _modeDesc(recommended),
                    style: TextStyle(
                        fontSize: 12, color: subColor, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 切换按钮
            GestureDetector(
              onTap: () {
                context.read<ChecklistProvider>().updateChecklist(
                      checklist.copyWith(interactionMode: recommended),
                    );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Text(
                  '立即切换',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
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

class _ProgressHeader extends StatelessWidget {
  final Checklist checklist;
  final Color accent;
  final bool isDark;

  const _ProgressHeader(
      {required this.checklist, required this.accent, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final total = checklist.totalCount;
    final checked = checklist.checkedCount;
    final progress = checklist.progress;
    final mode = checklist.interactionMode;

    // 功能层 badge：结构型 + 非默认 checklist 时展示
    final fn = checklist.function;
    final showFunction = checklist.checklistType == ChecklistType.structural &&
        fn != ChecklistFunction.checklist;

    // 参考范式：不显示进度条
    final showProgressBar = mode != ChecklistInteractionMode.reference && total > 0;

    // 右侧进度文字：因范式不同而不同
    final String progressText;
    final String? progressSubtext;
    if (total == 0) {
      progressText = '暂无条目';
      progressSubtext = null;
    } else if (mode == ChecklistInteractionMode.reference) {
      progressText = '$total 个条目';
      progressSubtext = null;
    } else if (mode == ChecklistInteractionMode.review) {
      progressText = '$checked / $total';
      progressSubtext = checked == total ? '全部回答完毕 🎉' : '已回答 $checked 题';
    } else {
      progressText = '$checked / $total';
      progressSubtext = null;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 第一行：左侧语义标签 + 右侧进度数字 ──────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左侧：时态型显示日期；结构型显示场景+功能+模式 badge
              Expanded(
                child: checklist.checklistType == ChecklistType.temporal &&
                        checklist.scheduledDate != null
                    ? _TemporalDateBadge(
                        date: checklist.scheduledDate!,
                        accent: accent,
                        repeatType: checklist.repeatType)
                    : Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          // 场景 badge
                          _HeaderBadge(
                            label:
                                '${checklist.scene.emoji} ${checklist.scene.label}',
                            color: accent,
                            isDark: isDark,
                          ),
                          // 功能层 badge（有非默认功能时才显示）
                          if (showFunction)
                            _HeaderBadge(
                              label: '${fn.emoji} ${fn.label}',
                              color: accent,
                              isDark: isDark,
                              filled: true,
                            ),
                          // 交互范式 badge（非默认执行范式时显示）
                          if (mode != ChecklistInteractionMode.execution)
                            _HeaderBadge(
                              label: '${mode.emoji} ${mode.label}',
                              color: accent,
                              isDark: isDark,
                              filled: true,
                            ),
                        ],
                      ),
              ),
              const SizedBox(width: 12),
              // 右侧：进度信息（因 interactionMode 而异）
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    progressText,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: checklist.isAllDone
                          ? Colors.green
                          : (isDark
                              ? Colors.white70
                              : const Color(0xFF444444)),
                    ),
                  ),
                  if (progressSubtext != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        progressSubtext,
                        style: TextStyle(
                          fontSize: 11,
                          color: checklist.isAllDone
                              ? Colors.green
                              : (isDark
                                  ? AppColors.textTertiaryDark
                                  : const Color(0xFFAAAAAA)),
                        ),
                      ),
                    )
                  else if (checklist.isAllDone &&
                      mode != ChecklistInteractionMode.reference)
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Text('🎉', style: TextStyle(fontSize: 14)),
                    ),
                ],
              ),
            ],
          ),
          // ── 进度条（reference 模式不显示）──────────────────────
          if (showProgressBar) ...[            
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: accent.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(
                  checklist.isAllDone ? Colors.green : accent,
                ),
                minHeight: 6,
              ),
            ),
          ],
          // ── 描述 ────────────────────────────────────────────────
          if (checklist.description.isNotEmpty) ...[            
            const SizedBox(height: 10),
            Text(
              checklist.description,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : const Color(0xFF888888),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── 详情页头部小徽章 ──────────────────────────────────────────────
class _HeaderBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool isDark;
  final bool filled;

  const _HeaderBadge({
    required this.label,
    required this.color,
    required this.isDark,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: filled
            ? color.withValues(alpha: isDark ? 0.22 : 0.14)
            : color.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(6),
        border: filled
            ? Border.all(color: color.withValues(alpha: 0.3), width: 0.8)
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: filled ? FontWeight.w700 : FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}

// ── 条目 Tile ─────────────────────────────────────────────────────
//
// 支持条目级多态控件（itemMode），根据 item.itemMode（或清单级 interactionMode
// 作为 inherit 的回退）渲染不同的右侧交互控件：
//   checkbox    → 传统勾选框（execution 默认）
//   counter     → +/- 数字计数器（counterValue）
//   statusCycle → 多状态循环 badge（counterValue 作状态索引；状态文字从 note 读取，
//                 格式：「状态A,状态B,状态C」；默认「未开始,进行中,已完成」）
//   noteEntry   → 展开 inline 文字输入区（noteResponse）
//   infoOnly    → 仅展示，无交互（reference 模式默认）
//   rating      → 1-5 星评分（ratingValue）—— reference 模式专用，已在 _ReferenceItemTile 实现

class _ItemTile extends StatefulWidget {
  final ChecklistItem item;
  final String checklistId;
  final ChecklistInteractionMode checklistInteractionMode;
  final Color accent;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final ValueChanged<ChecklistItem> onItemUpdated;

  /// numbered 风格下显示序号；null = simple/grouped 模式
  final int? index;

  const _ItemTile({
    required this.item,
    required this.checklistId,
    required this.checklistInteractionMode,
    required this.accent,
    required this.isDark,
    required this.onTap,
    required this.onLongPress,
    required this.onItemUpdated,
    this.index,
  });

  @override
  State<_ItemTile> createState() => _ItemTileState();
}

class _ItemTileState extends State<_ItemTile> {
  bool _noteExpanded = false;
  late TextEditingController _noteCtrl;

  /// 解析条目级实际模式：
  /// - item.itemMode == inherit → 用清单级 interactionMode 的默认控件
  /// - 否则直接用 item.itemMode
  ChecklistItemMode get _resolvedMode {
    if (widget.item.itemMode == ChecklistItemMode.inherit) {
      // 清单级范式 → 条目默认控件映射
      return switch (widget.checklistInteractionMode) {
        ChecklistInteractionMode.reference => ChecklistItemMode.infoOnly,
        ChecklistInteractionMode.review => ChecklistItemMode.noteEntry,
        ChecklistInteractionMode.process => ChecklistItemMode.checkbox,
        ChecklistInteractionMode.execution => ChecklistItemMode.checkbox,
      };
    }
    return widget.item.itemMode;
  }

  /// statusCycle 的状态标签列表
  /// 从 item.note 读取（逗号分隔），若为空则使用默认三态
  List<String> get _statusLabels {
    final note = widget.item.note ?? '';
    if (note.contains(',')) {
      final parts = note.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      if (parts.length >= 2) return parts;
    }
    return ['未开始', '进行中', '已完成'];
  }

  @override
  void initState() {
    super.initState();
    _noteCtrl = TextEditingController(text: widget.item.noteResponse);
    // 已有回应时默认展开
    _noteExpanded = widget.item.noteResponse.isNotEmpty;
  }

  @override
  void didUpdateWidget(covariant _ItemTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.noteResponse != widget.item.noteResponse &&
        _noteCtrl.text != widget.item.noteResponse) {
      _noteCtrl.text = widget.item.noteResponse;
    }
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  // ── 左侧指示器（勾选框 / 序号气泡）─────────────────────────────

  Widget _buildLeading() {
    final mode = _resolvedMode;
    // counter / statusCycle / infoOnly / noteEntry：左侧用彩色圆点
    if (mode == ChecklistItemMode.counter ||
        mode == ChecklistItemMode.statusCycle ||
        mode == ChecklistItemMode.infoOnly) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: widget.accent.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 14),
        ],
      );
    }
    // noteEntry：左侧用序号小圆角方块（已回答变勾）
    if (mode == ChecklistItemMode.noteEntry) {
      final answered = widget.item.isChecked;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: answered ? widget.accent : widget.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Center(
                child: answered
                    ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                    : Text(
                        widget.index != null ? '${widget.index! + 1}' : '✏',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: widget.accent,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
      );
    }
    // checkbox / process（默认）
    if (widget.index != null) {
      // numbered 风格：序号气泡
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: widget.item.isChecked ? widget.accent : widget.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: widget.item.isChecked
                    ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                    : Text(
                        '${widget.index! + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: widget.accent,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
      );
    }
    // simple / grouped：普通勾选框
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 22, height: 22,
          decoration: BoxDecoration(
            color: widget.item.isChecked ? widget.accent : Colors.transparent,
            border: Border.all(
              color: widget.item.isChecked
                  ? widget.accent
                  : (widget.isDark ? Colors.white30 : const Color(0xFFCCCCCC)),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: widget.item.isChecked
              ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
              : null,
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  // ── 右侧多态控件 ──────────────────────────────────────────────────

  Widget? _buildTrailing() {
    final mode = _resolvedMode;
    switch (mode) {
      case ChecklistItemMode.counter:
        return _CounterControl(
          value: widget.item.counterValue,
          accent: widget.accent,
          isDark: widget.isDark,
          onChanged: (v) => widget.onItemUpdated(
            widget.item.copyWith(
              counterValue: v,
              // counterValue > 0 视为「有数值」，isChecked = (v > 0)
              isChecked: v > 0,
            ),
          ),
        );
      case ChecklistItemMode.statusCycle:
        return _StatusCycleControl(
          labels: _statusLabels,
          currentIndex: widget.item.counterValue.clamp(0, _statusLabels.length - 1),
          accent: widget.accent,
          isDark: widget.isDark,
          onTap: () {
            final next = (widget.item.counterValue + 1) % _statusLabels.length;
            widget.onItemUpdated(
              widget.item.copyWith(
                counterValue: next,
                isChecked: next == _statusLabels.length - 1,
              ),
            );
          },
        );
      case ChecklistItemMode.infoOnly:
        // 参考模式：右侧仅展示 quantity（若有），无交互
        if (widget.item.quantity != null && widget.item.quantity!.isNotEmpty) {
          return Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: widget.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              widget.item.quantity!,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: widget.accent,
              ),
            ),
          );
        }
        return null;
      default:
        // checkbox / noteEntry / rating → 右侧展示 quantity（若有）
        if (widget.item.quantity != null && widget.item.quantity!.isNotEmpty) {
          return Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: widget.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              widget.item.quantity!,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: widget.accent,
              ),
            ),
          );
        }
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDark ? AppColors.cardDark : Colors.white;
    final textColor = widget.isDark ? Colors.white : const Color(0xFF1A1410);
    final subtextColor = widget.isDark ? AppColors.textTertiaryDark : const Color(0xFFAAAAAA);
    final mode = _resolvedMode;

    final isCheckedStyle = widget.item.isChecked &&
        mode != ChecklistItemMode.counter &&
        mode != ChecklistItemMode.statusCycle;

    final trailing = _buildTrailing();

    return GestureDetector(
      onTap: mode == ChecklistItemMode.counter ||
              mode == ChecklistItemMode.statusCycle ||
              mode == ChecklistItemMode.infoOnly
          ? null
          : mode == ChecklistItemMode.noteEntry
              ? () => setState(() => _noteExpanded = !_noteExpanded)
              : widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        decoration: BoxDecoration(
          color: isCheckedStyle
              ? (widget.isDark
                  ? widget.accent.withValues(alpha: 0.06)
                  : widget.accent.withValues(alpha: 0.04))
              : bgColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isCheckedStyle
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: widget.isDark ? 0.2 : 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 主行 ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // 左侧指示器
                  _buildLeading(),
                  // 标题 + 备注
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: isCheckedStyle
                                ? (widget.isDark ? Colors.white38 : const Color(0xFFBBBBBB))
                                : textColor,
                            decoration: isCheckedStyle ? TextDecoration.lineThrough : null,
                            decorationColor: widget.isDark ? Colors.white38 : const Color(0xFFBBBBBB),
                          ),
                        ),
                        // counter/statusCycle：note 存的是状态标签配置，不显示为备注
                        if (widget.item.note != null &&
                            widget.item.note!.isNotEmpty &&
                            mode != ChecklistItemMode.statusCycle)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              widget.item.note!,
                              style: TextStyle(fontSize: 12, color: subtextColor),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        // noteEntry 折叠时展示回应摘要
                        if (mode == ChecklistItemMode.noteEntry &&
                            !_noteExpanded &&
                            widget.item.noteResponse.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              widget.item.noteResponse,
                              style: TextStyle(
                                fontSize: 12,
                                color: widget.isDark
                                    ? AppColors.textSecondaryDark
                                    : const Color(0xFF888888),
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // 右侧控件
                  ?trailing,
                  // noteEntry：展开/收起箭头
                  if (mode == ChecklistItemMode.noteEntry)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Icon(
                        _noteExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: widget.isDark ? Colors.white38 : const Color(0xFFCCCCCC),
                      ),
                    ),
                ],
              ),
            ),
            // ── noteEntry 展开区 ─────────────────────────────────────
            if (mode == ChecklistItemMode.noteEntry)
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                child: _noteExpanded
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Divider(
                              height: 1,
                              color: widget.isDark
                                  ? Colors.white10
                                  : Colors.black.withValues(alpha: 0.06),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _noteCtrl,
                              maxLines: null,
                              minLines: 2,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.6,
                                color: widget.isDark ? Colors.white : const Color(0xFF1A1410),
                              ),
                              decoration: InputDecoration(
                                hintText: '写下你的想法…',
                                hintStyle: TextStyle(
                                  fontSize: 13,
                                  color: widget.isDark
                                      ? AppColors.textTertiaryDark
                                      : const Color(0xFFBBBBBB),
                                ),
                                filled: true,
                                fillColor: widget.isDark
                                    ? widget.accent.withValues(alpha: 0.06)
                                    : widget.accent.withValues(alpha: 0.04),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                              ),
                              onChanged: (v) => widget.onItemUpdated(
                                widget.item.copyWith(noteResponse: v),
                              ),
                            ),
                            if (!widget.item.isChecked && _noteCtrl.text.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  widget.onTap();
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: widget.accent.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: widget.accent.withValues(alpha: 0.3), width: 0.8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_circle_outline_rounded,
                                          size: 14, color: widget.accent),
                                      const SizedBox(width: 4),
                                      Text(
                                        '标记为已完成',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: widget.accent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  条目编辑 BottomSheet（_EditItemSheet）
//  支持：标题 / 备注 / 数量 / 分组标签 / 条目级 itemMode 选择
//  当 itemMode == statusCycle 时，显示状态标签编辑行
// ─────────────────────────────────────────────────────────────────

class _EditItemSheet extends StatefulWidget {
  final ChecklistItem item;
  final Checklist checklist;
  final Color accent;
  final bool isDark;
  final ValueChanged<ChecklistItem> onSave;

  const _EditItemSheet({
    required this.item,
    required this.checklist,
    required this.accent,
    required this.isDark,
    required this.onSave,
  });

  @override
  State<_EditItemSheet> createState() => _EditItemSheetState();
}

class _EditItemSheetState extends State<_EditItemSheet> {
  late TextEditingController _titleCtrl;
  late TextEditingController _noteCtrl;
  late TextEditingController _qtyCtrl;
  late TextEditingController _groupCtrl;
  late TextEditingController _statusLabelsCtrl;
  late ChecklistItemMode _selectedMode;

  // itemMode 选项：inherit 用「跟随清单」表示
  static const _modeOptions = [
    (ChecklistItemMode.inherit, '跟随清单', Icons.auto_awesome_rounded),
    (ChecklistItemMode.checkbox, '勾选框', Icons.check_box_outlined),
    (ChecklistItemMode.counter, '计数器', Icons.add_box_outlined),
    (ChecklistItemMode.statusCycle, '状态循环', Icons.swap_horiz_rounded),
    (ChecklistItemMode.noteEntry, '填写回应', Icons.edit_note_rounded),
    (ChecklistItemMode.infoOnly, '仅展示', Icons.info_outline_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.item.title);
    _selectedMode = widget.item.itemMode;

    // statusCycle：note 存状态标签；其他模式：note 作为普通备注
    final note = widget.item.note ?? '';
    if (_selectedMode == ChecklistItemMode.statusCycle) {
      _noteCtrl = TextEditingController();
      _statusLabelsCtrl = TextEditingController(text: note);
    } else {
      _noteCtrl = TextEditingController(text: note);
      _statusLabelsCtrl = TextEditingController();
    }
    _qtyCtrl = TextEditingController(text: widget.item.quantity ?? '');
    _groupCtrl = TextEditingController(text: widget.item.groupLabel ?? '');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    _qtyCtrl.dispose();
    _groupCtrl.dispose();
    _statusLabelsCtrl.dispose();
    super.dispose();
  }

  Widget _field(TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      style: TextStyle(
        fontSize: 15,
        color: widget.isDark ? Colors.white : const Color(0xFF1A1410),
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 14,
          color: widget.isDark ? Colors.white38 : const Color(0xFFBBBBBB),
        ),
        filled: true,
        fillColor: widget.isDark
            ? Colors.white.withValues(alpha: 0.06)
            : const Color(0xFFF5F5F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isGrouped = widget.checklist.style == ChecklistStyle.grouped;
    final isShopping = widget.checklist.scene == ChecklistScene.shopping;
    final isStatusCycle = _selectedMode == ChecklistItemMode.statusCycle;
    final textColor = widget.isDark ? Colors.white : const Color(0xFF1A1410);
    final subtextColor = widget.isDark ? Colors.white54 : const Color(0xFF888888);

    return Container(
      decoration: BoxDecoration(
        color: widget.isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 拖动条
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: widget.isDark
                        ? Colors.white24
                        : Colors.black.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text('编辑条目',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: textColor)),
              const SizedBox(height: 14),
              // 标题
              _field(_titleCtrl, '条目标题'),
              // 条目模式选择器
              const SizedBox(height: 14),
              Text('交互控件',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: subtextColor)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: _modeOptions.map((opt) {
                  final (mode, label, icon) = opt;
                  final selected = _selectedMode == mode;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedMode = mode),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected
                            ? widget.accent.withValues(alpha: 0.15)
                            : (widget.isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : const Color(0xFFF0F0F0)),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected
                              ? widget.accent.withValues(alpha: 0.5)
                              : Colors.transparent,
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon,
                              size: 14,
                              color: selected
                                  ? widget.accent
                                  : (widget.isDark
                                      ? Colors.white54
                                      : const Color(0xFF888888))),
                          const SizedBox(width: 5),
                          Text(label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                color: selected
                                    ? widget.accent
                                    : (widget.isDark
                                        ? Colors.white70
                                        : const Color(0xFF555555)),
                              )),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              // statusCycle：状态标签配置行
              if (isStatusCycle) ...[
                const SizedBox(height: 12),
                Text('状态标签（逗号分隔，如：待处理,进行中,已完成）',
                    style: TextStyle(fontSize: 12, color: subtextColor)),
                const SizedBox(height: 6),
                _field(_statusLabelsCtrl, '未开始,进行中,已完成'),
              ] else ...[
                // 普通备注
                const SizedBox(height: 10),
                _field(_noteCtrl, '备注（可选）'),
              ],
              if (isGrouped) ...[
                const SizedBox(height: 10),
                _field(_groupCtrl, '所属分组（如：衣物、证件…）'),
              ],
              if (isShopping) ...[
                const SizedBox(height: 10),
                _field(_qtyCtrl, '数量（如：2个、500g）'),
              ],
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: widget.isDark
                            ? const Color(0xFF2A2A2A)
                            : const Color(0xFFF0F0F0),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text('取消',
                            style: TextStyle(
                                color: widget.isDark
                                    ? Colors.white54
                                    : const Color(0xFF888888))),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: () {
                      // 根据 isStatusCycle，note 字段用途不同
                      final noteValue = isStatusCycle
                          ? (_statusLabelsCtrl.text.trim().isEmpty
                              ? null
                              : _statusLabelsCtrl.text.trim())
                          : (_noteCtrl.text.trim().isEmpty
                              ? null
                              : _noteCtrl.text.trim());

                      final updated = widget.item.copyWith(
                        title: _titleCtrl.text.trim().isEmpty
                            ? widget.item.title
                            : _titleCtrl.text.trim(),
                        note: noteValue,
                        quantity: _qtyCtrl.text.trim().isEmpty
                            ? null
                            : _qtyCtrl.text.trim(),
                        groupLabel: isGrouped
                            ? (_groupCtrl.text.trim().isEmpty
                                ? null
                                : _groupCtrl.text.trim())
                            : widget.item.groupLabel,
                        itemMode: _selectedMode,
                        // 切换到非 counter/statusCycle 时重置 counterValue
                        counterValue: (_selectedMode == ChecklistItemMode.counter ||
                                _selectedMode == ChecklistItemMode.statusCycle)
                            ? widget.item.counterValue
                            : 0,
                      );
                      widget.onSave(updated);
                      Navigator.pop(context);
                    },
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: widget.accent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text('保存',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  计数器控件（counter 模式）
//  +/- 按钮修改 counterValue；中间显示当前数值
//  value == 0 时显示灰色「0」，> 0 时显示主色
// ─────────────────────────────────────────────────────────────────

class _CounterControl extends StatelessWidget {
  final int value;
  final Color accent;
  final bool isDark;
  final ValueChanged<int> onChanged;

  const _CounterControl({
    required this.value,
    required this.accent,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value > 0;
    final textColor = hasValue ? accent : (isDark ? Colors.white38 : const Color(0xFFCCCCCC));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 减号按钮
        GestureDetector(
          onTap: value > 0
              ? () {
                  HapticFeedback.selectionClick();
                  onChanged(value - 1);
                }
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: value > 0
                  ? accent.withValues(alpha: isDark ? 0.18 : 0.12)
                  : (isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF0F0F0)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.remove_rounded,
              size: 16,
              color: value > 0 ? accent : (isDark ? Colors.white24 : const Color(0xFFCCCCCC)),
            ),
          ),
        ),
        // 数值
        Container(
          width: 40,
          alignment: Alignment.center,
          child: Text(
            '$value',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ),
        // 加号按钮
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(value + 1);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isDark ? 0.18 : 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.add_rounded, size: 16, color: accent),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  多状态循环控件（statusCycle 模式）
//  点击后循环切换到下一个状态；当前状态以彩色 badge 展示
//  状态颜色方案：
//    第 0 个 → 灰色（未开始）
//    中间态  → 主色（进行中）
//    最后态  → 绿色（已完成）
// ─────────────────────────────────────────────────────────────────

class _StatusCycleControl extends StatelessWidget {
  final List<String> labels;
  final int currentIndex;
  final Color accent;
  final bool isDark;
  final VoidCallback onTap;

  const _StatusCycleControl({
    required this.labels,
    required this.currentIndex,
    required this.accent,
    required this.isDark,
    required this.onTap,
  });

  Color get _badgeColor {
    if (currentIndex == 0) return isDark ? Colors.white38 : const Color(0xFFBBBBBB);
    if (currentIndex == labels.length - 1) return Colors.green;
    return accent;
  }

  @override
  Widget build(BuildContext context) {
    final label = labels[currentIndex];
    final color = _badgeColor;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.18 : 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.swap_horiz_rounded, size: 12, color: color.withValues(alpha: 0.7)),
          ],
        ),
      ),
    );
  }
}

// ── 底部操作栏 ────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final Checklist checklist;
  final Color accent;
  final bool isDark;
  final bool isAiGenerating;
  final bool showQuickAdd;
  final TextEditingController quickAddCtrl;
  final TextEditingController quickGroupCtrl;
  final FocusNode quickAddFocus;
  final VoidCallback onToggleQuickAdd;
  final VoidCallback onQuickAddSubmit;
  final VoidCallback onAiGenerate;
  final VoidCallback onOpenSettings;

  const _BottomBar({
    required this.checklist,
    required this.accent,
    required this.isDark,
    required this.isAiGenerating,
    required this.showQuickAdd,
    required this.quickAddCtrl,
    required this.quickGroupCtrl,
    required this.quickAddFocus,
    required this.onToggleQuickAdd,
    required this.onQuickAddSubmit,
    required this.onAiGenerate,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? AppColors.surfaceDark : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── 快速添加输入框（展开时显示）────────────────────────────
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: showQuickAdd
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // grouped 风格：先输入分组名
                          if (checklist.style == ChecklistStyle.grouped) ..._buildGroupInput(context),
                          // 条目名 + 发送
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: quickAddCtrl,
                                  focusNode: quickAddFocus,
                                  onSubmitted: (_) => onQuickAddSubmit(),
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF1A1410),
                                  ),
                                  decoration: InputDecoration(
                                    hintText: checklist.style == ChecklistStyle.grouped
                                        ? '条目名称，回车添加…'
                                        : '输入条目，回车添加…',
                                    hintStyle: TextStyle(
                                      color: isDark
                                          ? AppColors.textTertiaryDark
                                          : const Color(0xFFBBBBBB),
                                    ),
                                    filled: true,
                                    fillColor: isDark
                                        ? AppColors.inputFillDark
                                        : const Color(0xFFF5F5F5),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 10),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: onQuickAddSubmit,
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: accent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.send_rounded,
                                      color: Colors.white, size: 18),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            // ── 主按钮行 ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  // AI 生成按钮
                  GestureDetector(
                    onTap: onAiGenerate,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 11),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isAiGenerating
                              ? [Colors.grey, Colors.grey.shade400]
                              : [
                                  const Color(0xFF7C3AED),
                                  const Color(0xFF5B21B6),
                                ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isAiGenerating)
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          else
                            const Text('✨',
                                style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                           Text(
                             isAiGenerating ? 'AI 起草中…' : 'AI 起草初稿',
                             style: const TextStyle(
                               color: Colors.white,
                               fontSize: 14,
                               fontWeight: FontWeight.w700,
                             ),
                           ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  // 进阶设置按钮
                  GestureDetector(
                    onTap: onOpenSettings,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF2A2A2A)
                            : const Color(0xFFF0F0F0),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.tune_rounded,
                        color: isDark
                            ? Colors.white54
                            : const Color(0xFF888888),
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 手动添加按钮
                  GestureDetector(
                    onTap: onToggleQuickAdd,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: showQuickAdd
                            ? accent
                            : (isDark
                                ? const Color(0xFF2A2A2A)
                                : const Color(0xFFF0F0F0)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        showQuickAdd
                            ? Icons.close_rounded
                            : Icons.add_rounded,
                        color: showQuickAdd
                            ? Colors.white
                            : (isDark
                                ? Colors.white70
                                : const Color(0xFF666666)),
                        size: 22,
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

  /// grouped 风格下的「分组名」输入行
  /// 返回 List[Widget]，用 spread 插入到 Column 里
  List<Widget> _buildGroupInput(BuildContext context) {
    return [
      Row(
        children: [
          // 分组图标
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.folder_outlined, size: 16, color: accent),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: quickGroupCtrl,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white : const Color(0xFF1A1410),
              ),
              decoration: InputDecoration(
                hintText: '分组名（如：衣物、证件…）',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : const Color(0xFFBBBBBB),
                ),
                filled: true,
                fillColor: isDark
                    ? accent.withValues(alpha: 0.06)
                    : accent.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: accent.withValues(alpha: 0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: accent.withValues(alpha: 0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: accent, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
    ];
  }
}

// ── 条目上下文菜单 ────────────────────────────────────────────────

class _ItemContextMenu extends StatelessWidget {
  final ChecklistItem item;
  final Color accent;
  final bool isDark;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ItemContextMenu({
    required this.item,
    required this.accent,
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Row(
              children: [
                Icon(
                  item.isChecked
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: item.isChecked
                      ? Colors.green
                      : (isDark ? Colors.white30 : Colors.black26),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color:
                          isDark ? Colors.white : const Color(0xFF1A1410),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(
              height: 1,
              color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
          InkWell(
            onTap: onEdit,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(children: [
                Icon(Icons.edit_outlined,
                    size: 18,
                    color: isDark
                        ? Colors.white70
                        : const Color(0xFF444444)),
                const SizedBox(width: 14),
                Text('编辑',
                    style: TextStyle(
                        fontSize: 15,
                        color: isDark
                            ? Colors.white70
                            : const Color(0xFF444444))),
              ]),
            ),
          ),
          InkWell(
            onTap: onDelete,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(children: [
                const Icon(Icons.delete_outline_rounded,
                    size: 18, color: Colors.red),
                const SizedBox(width: 14),
                const Text('删除',
                    style: TextStyle(fontSize: 15, color: Colors.red)),
              ]),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── AI 生成输入面板 ───────────────────────────────────────────────

class _AiGenerateSheet extends StatefulWidget {
  final Checklist checklist;
  final Color accent;
  final bool isDark;

  const _AiGenerateSheet({
    required this.checklist,
    required this.accent,
    required this.isDark,
  });

  @override
  State<_AiGenerateSheet> createState() => _AiGenerateSheetState();
}

class _AiGenerateSheetState extends State<_AiGenerateSheet> {
  final _ctrl = TextEditingController();

  // 快速选择的场景提示词——优先基于清单标题关键词匹配，fallback 到场景词库
  List<String> get _quickPrompts {
    final title = widget.checklist.title.toLowerCase();

    // ── 标题关键词 → 定制提示词映射表 ──────────────────────────────
    const Map<List<String>, List<String>> _titleKeywordMap = {
      // 简历 / 求职
      ['简历', '求职', '面试', '投递', 'resume', 'cv']: [
        '基本信息与联系方式',
        '工作经历与项目经验',
        '教育背景与证书',
        '技能与亮点总结',
      ],
      // 旅行 / 出行
      ['旅行', '出行', '旅游', '出发', '行程', '度假', '背包', '打包']: [
        '行李打包清单',
        '出发前必办事项',
        '住宿 & 交通预订',
        '旅途应急准备',
      ],
      // 购物 / 采购
      ['购物', '采购', '买', '超市', '年货', '礼品', '礼物']: [
        '日常食材采购',
        '节日年货清单',
        '办公室用品补货',
        '礼品挑选清单',
      ],
      // 项目 / 上线 / 发布
      ['项目', '上线', '发布', '发版', '迭代', '需求', '产品']: [
        '项目启动检查清单',
        '产品上线前必检项',
        '版本发布流程 SOP',
        '需求评审准备清单',
      ],
      // 会议 / 周会 / 汇报
      ['会议', '周会', '汇报', '晨会', '月会', '复盘会', '站会']: [
        '会前议程准备',
        '会中记录要点',
        '会后行动项跟进',
        '汇报材料清单',
      ],
      // 学习 / 复习 / 备考
      ['学习', '复习', '备考', '考研', '考试', '课程', '读书', '书单']: [
        '每日学习任务清单',
        '期末复习重点梳理',
        '考研备考计划清单',
        '技能提升学习路径',
      ],
      // 健康 / 运动 / 健身
      ['健康', '运动', '健身', '锻炼', '减肥', '瘦身', '跑步', '打卡']: [
        '每日健身训练计划',
        '饮食控制打卡清单',
        '运动装备采购清单',
        '健康习惯养成清单',
      ],
      // 搬家 / 装修 / 家居
      ['搬家', '装修', '家居', '租房', '新家', '布置']: [
        '搬家物品打包清单',
        '新居置办用品清单',
        '装修验收检查清单',
        '水电网开通办理清单',
      ],
      // 计划 / 目标 / 年度
      ['计划', '目标', '年度', '季度', '月度', '规划', '里程碑']: [
        '年度核心目标清单',
        '季度 OKR 拆解清单',
        '每周重点任务计划',
        '月度复盘 & 展望',
      ],
      // 婚礼 / 婚庆
      ['婚礼', '婚庆', '婚宴', '结婚', '喜宴']: [
        '婚礼策划流程清单',
        '婚宴宾客邀请清单',
        '婚礼当天必备物品',
        '蜜月出行准备清单',
      ],
      // 开学 / 新生
      ['开学', '新生', '入学', '军训', '宿舍']: [
        '开学行李准备清单',
        '宿舍必备用品清单',
        '入学手续办理清单',
        '大学新生适应计划',
      ],
    };

    // 遍历关键词表，找到第一个命中的分组
    for (final entry in _titleKeywordMap.entries) {
      if (entry.key.any((kw) => title.contains(kw))) {
        return entry.value;
      }
    }

    // ── Fallback：基于 scene 返回通用提示词 ──────────────────────
    switch (widget.checklist.scene) {
      case ChecklistScene.shopping:
        return ['周末超市采购清单', '年货购物清单', '办公室用品采购', '健身补剂购物清单'];
      case ChecklistScene.work:
        return ['项目启动检查清单', '周会准备清单', '产品上线清单', '职场新人必备'];
      case ChecklistScene.study:
        return ['期末复习计划清单', '每日学习任务', '考研备考清单', '技能提升计划'];
      case ChecklistScene.life:
        return ['旅行行李打包清单', '周末大扫除清单', '健康习惯清单', '搬家准备清单'];
      case ChecklistScene.general:
        return ['日常任务清单', '待办事项', '今日目标清单', '本周计划清单'];
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDark ? AppColors.surfaceDark : Colors.white;
    final textColor =
        widget.isDark ? Colors.white : const Color(0xFF1A1410);
    final hintColor =
        widget.isDark ? AppColors.textTertiaryDark : const Color(0xFFBBBBBB);

    return Container(
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
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 拖拽手柄
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: widget.isDark
                        ? Colors.white24
                        : Colors.black.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // 标题
              Row(
                children: [
                  const Text('✨', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text('AI 帮我起草初稿',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: textColor)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'AI 会生成一份草稿初稿，你可以随时增删修改',
                style: TextStyle(fontSize: 13, color: hintColor),
              ),
              const SizedBox(height: 14),
              // 快速选择提示词
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _quickPrompts.map((p) {
                  return GestureDetector(
                    onTap: () => setState(() => _ctrl.text = p),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: widget.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: widget.accent.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        p,
                        style: TextStyle(
                          fontSize: 12,
                          color: widget.accent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              // 自定义输入
              TextField(
                controller: _ctrl,
                autofocus: true,
                maxLines: 3,
                style: TextStyle(fontSize: 15, color: textColor),
                decoration: InputDecoration(
                  hintText: '或者输入自定义描述…\n例如：春节送长辈礼品清单',
                  hintStyle: TextStyle(color: hintColor, fontSize: 14),
                  filled: true,
                  fillColor: widget.isDark
                      ? AppColors.inputFillDark
                      : const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              // 生成按钮
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () {
                    final text = _ctrl.text.trim();
                    if (text.isNotEmpty) {
                      Navigator.pop(context, text);
                    }
                  },
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('✨', style: TextStyle(fontSize: 16)),
                          SizedBox(width: 8),
                          Text(
                            '生成初稿',
                             style: TextStyle(
                               color: Colors.white,
                               fontSize: 16,
                               fontWeight: FontWeight.w700,
                             ),
                          ),
                        ],
                      ),
                    ),
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
//  _TemporalDateBadge —— 时态清单详情页顶部日期标签
//  替代结构型的「场景标签」，醒目展示归属日期和重复属性
// ─────────────────────────────────────────────────────────────────

class _TemporalDateBadge extends StatelessWidget {
  final DateTime date;
  final Color accent;
  final RepeatType repeatType;

  const _TemporalDateBadge({
    required this.date,
    required this.accent,
    required this.repeatType,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final d = DateTime(date.year, date.month, date.day);

    String dateLabel;
    bool isOverdue = false;
    if (d == today) {
      dateLabel = '📅 今天';
    } else if (d == tomorrow) {
      dateLabel = '📅 明天';
    } else if (d.isBefore(today)) {
      final diff = today.difference(d).inDays;
      dateLabel = '⚠️ ${diff == 1 ? "昨天" : "$diff 天前"}';
      isOverdue = true;
    } else {
      dateLabel = '📅 ${date.month}月${date.day}日';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isOverdue
                ? const Color(0xFFFF6B6B).withValues(alpha: 0.12)
                : accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            dateLabel,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isOverdue ? const Color(0xFFE05555) : accent,
            ),
          ),
        ),
        if (repeatType != RepeatType.none) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF20C997).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.refresh_rounded,
                    size: 11, color: Color(0xFF20C997)),
                const SizedBox(width: 3),
                Text(
                  repeatType.label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF20C997),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  参考范式条目 Tile
//  • 无勾选框，左侧彩色圆点指示
//  • 默认不显示评分（浏览优先）
//  • 已评分的条目：直接在右侧紧凑展示星星
//  • 未评分 + 点击条目：展开评分行（轻量交互）
//  • 长按弹出编辑/删除菜单
// ─────────────────────────────────────────────────────────────────

class _ReferenceItemTile extends StatefulWidget {
  final ChecklistItem item;
  final Color accent;
  final bool isDark;
  final ValueChanged<int> onRatingChanged;
  final VoidCallback onLongPress;

  const _ReferenceItemTile({
    required this.item,
    required this.accent,
    required this.isDark,
    required this.onRatingChanged,
    required this.onLongPress,
  });

  @override
  State<_ReferenceItemTile> createState() => _ReferenceItemTileState();
}

class _ReferenceItemTileState extends State<_ReferenceItemTile> {
  // 只有点击条目后才展开评分行（已有评分则始终展示）
  bool _showRating = false;

  @override
  void initState() {
    super.initState();
    // 已有评分时默认展示
    _showRating = widget.item.ratingValue > 0;
  }

  @override
  void didUpdateWidget(covariant _ReferenceItemTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item.ratingValue != oldWidget.item.ratingValue) {
      _showRating = widget.item.ratingValue > 0 || _showRating;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDark ? AppColors.cardDark : Colors.white;
    final textColor = widget.isDark ? Colors.white : const Color(0xFF1A1410);
    final subtextColor =
        widget.isDark ? AppColors.textTertiaryDark : const Color(0xFFAAAAAA);
    final hasRating = widget.item.ratingValue > 0;

    return GestureDetector(
      onTap: () {
        // 点击展开/收起评分行（已有评分的条目不可收起）
        if (!hasRating) {
          setState(() => _showRating = !_showRating);
        }
      },
      onLongPress: widget.onLongPress,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: hasRating
              ? Border.all(
                  color: const Color(0xFFFAB005).withValues(alpha: 0.25),
                  width: 0.8)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: widget.isDark ? 0.2 : 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 主行 ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // 左侧彩色圆点
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: widget.accent.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 标题 + 备注
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: textColor,
                          ),
                        ),
                        if (widget.item.note != null &&
                            widget.item.note!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              widget.item.note!,
                              style:
                                  TextStyle(fontSize: 12, color: subtextColor),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 右侧：已有评分则紧凑展示，否则展示「评分」小按钮
                  if (hasRating)
                    // 紧凑评分展示（可点击修改）
                    GestureDetector(
                      onTap: () => setState(() => _showRating = !_showRating),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded,
                              size: 14, color: Color(0xFFFAB005)),
                          const SizedBox(width: 2),
                          Text(
                            '${widget.item.ratingValue}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFD4900A),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (!_showRating)
                    // 未评分且收起状态：轻量「+ 评分」提示
                    GestureDetector(
                      onTap: () => setState(() => _showRating = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: widget.isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '评分',
                          style: TextStyle(
                            fontSize: 11,
                            color: subtextColor,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // ── 展开的评分行 ──────────────────────────────────────
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: _showRating
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Divider(
                            height: 1,
                            color: widget.isDark
                                ? Colors.white10
                                : Colors.black.withValues(alpha: 0.06),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Text(
                                '你的评分',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: subtextColor,
                                ),
                              ),
                              const SizedBox(width: 10),
                              _StarRating(
                                value: widget.item.ratingValue,
                                accent: widget.accent,
                                isDark: widget.isDark,
                                onChanged: widget.onRatingChanged,
                              ),
                              const Spacer(),
                              // 收起按钮（仅未评分时可收起）
                              if (!hasRating)
                                GestureDetector(
                                  onTap: () =>
                                      setState(() => _showRating = false),
                                  child: Icon(
                                    Icons.keyboard_arrow_up_rounded,
                                    size: 16,
                                    color: subtextColor,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  星级评分控件（1-5星，0=未评分）
// ─────────────────────────────────────────────────────────────────

class _StarRating extends StatelessWidget {
  final int value; // 0~5
  final Color accent;
  final bool isDark;
  final ValueChanged<int> onChanged;

  const _StarRating({
    required this.value,
    required this.accent,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < value;
        return GestureDetector(
          onTap: () {
            // 点同一颗星 → 取消评分；否则设置评分
            onChanged(filled && i == value - 1 ? 0 : i + 1);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(
              filled ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 18,
              color: filled
                  ? const Color(0xFFFAB005)
                  : (isDark ? Colors.white24 : const Color(0xFFDDDDDD)),
            ),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  回顾范式条目 Tile
//  • 序号气泡 + 问题标题
//  • 点击展开/折叠多行文字输入区（记录回应）
//  • 勾选图标 = 「已回答这道题」
//  • 已回答的问题折叠时显示回应摘要
// ─────────────────────────────────────────────────────────────────

class _ReviewItemTile extends StatefulWidget {
  final ChecklistItem item;
  final int index;
  final Color accent;
  final bool isDark;
  final VoidCallback onToggle;
  final ValueChanged<String> onResponseChanged;
  final VoidCallback onLongPress;

  const _ReviewItemTile({
    required this.item,
    required this.index,
    required this.accent,
    required this.isDark,
    required this.onToggle,
    required this.onResponseChanged,
    required this.onLongPress,
  });

  @override
  State<_ReviewItemTile> createState() => _ReviewItemTileState();
}

class _ReviewItemTileState extends State<_ReviewItemTile> {
  bool _expanded = false;
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.item.noteResponse);
    // 如果已有回应，默认展开
    _expanded = widget.item.noteResponse.isNotEmpty;
  }

  @override
  void didUpdateWidget(covariant _ReviewItemTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 外部更新回应时同步文本框
    if (oldWidget.item.noteResponse != widget.item.noteResponse &&
        _ctrl.text != widget.item.noteResponse) {
      _ctrl.text = widget.item.noteResponse;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDark ? AppColors.cardDark : Colors.white;
    final textColor = widget.isDark ? Colors.white : const Color(0xFF1A1410);
    final answered = widget.item.isChecked;

    return GestureDetector(
      onLongPress: widget.onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        decoration: BoxDecoration(
          color: answered
              ? widget.accent.withValues(alpha: widget.isDark ? 0.08 : 0.05)
              : bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: answered
                ? widget.accent.withValues(alpha: 0.25)
                : (widget.isDark
                    ? Colors.white10
                    : Colors.black.withValues(alpha: 0.06)),
            width: answered ? 1.2 : 0.8,
          ),
          boxShadow: answered
              ? []
              : [
                  BoxShadow(
                    color: Colors.black
                        .withValues(alpha: widget.isDark ? 0.18 : 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 问题行 ────────────────────────────────────────────
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 序号气泡
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: answered
                            ? widget.accent
                            : widget.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: answered
                            ? const Icon(Icons.check_rounded,
                                size: 14, color: Colors.white)
                            : Text(
                                '${widget.index + 1}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: widget.accent,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // 问题标题 + 折叠时的回应摘要
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.item.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: answered
                                  ? textColor.withValues(alpha: 0.7)
                                  : textColor,
                              height: 1.4,
                            ),
                          ),
                          // 已回答时折叠态显示摘要
                          if (!_expanded &&
                              widget.item.noteResponse.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              widget.item.noteResponse,
                              style: TextStyle(
                                fontSize: 12,
                                color: widget.isDark
                                    ? AppColors.textSecondaryDark
                                    : const Color(0xFF888888),
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 右侧：展开/收起 + 勾选
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _expanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: widget.isDark
                              ? Colors.white38
                              : const Color(0xFFCCCCCC),
                        ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            widget.onToggle();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: answered
                                  ? widget.accent
                                  : Colors.transparent,
                              border: Border.all(
                                color: answered
                                    ? widget.accent
                                    : (widget.isDark
                                        ? Colors.white30
                                        : const Color(0xFFCCCCCC)),
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: answered
                                ? const Icon(Icons.check_rounded,
                                    size: 13, color: Colors.white)
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // ── 展开：文字输入区 ───────────────────────────────────
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              child: _expanded
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Divider(
                            height: 1,
                            color: widget.isDark
                                ? Colors.white10
                                : Colors.black.withValues(alpha: 0.06),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _ctrl,
                            maxLines: null,
                            minLines: 3,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.6,
                              color: widget.isDark
                                  ? Colors.white
                                  : const Color(0xFF1A1410),
                            ),
                            decoration: InputDecoration(
                              hintText: '写下你的思考与回应…',
                              hintStyle: TextStyle(
                                fontSize: 13,
                                color: widget.isDark
                                    ? AppColors.textTertiaryDark
                                    : const Color(0xFFBBBBBB),
                              ),
                              filled: true,
                              fillColor: widget.isDark
                                  ? widget.accent.withValues(alpha: 0.06)
                                  : widget.accent.withValues(alpha: 0.04),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                            ),
                            onChanged: widget.onResponseChanged,
                          ),
                          // 有内容且未标记时显示「标记已回答」按钮
                          if (!answered && _ctrl.text.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                widget.onToggle();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: widget.accent
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: widget.accent
                                          .withValues(alpha: 0.3),
                                      width: 0.8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                        Icons.check_circle_outline_rounded,
                                        size: 14,
                                        color: widget.accent),
                                    const SizedBox(width: 4),
                                    Text(
                                      '标记为已回答',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: widget.accent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  流程范式条目 Tile
//  • 严格顺序：竖线连接每个步骤
//  • 已锁定步骤：灰色+锁图标，无法操作
//  • 当前可执行步骤：高亮边框，突出显示「当前步骤」标签
//  • 已完成步骤：绿色勾，淡化显示
// ─────────────────────────────────────────────────────────────────

class _ProcessItemTile extends StatelessWidget {
  final ChecklistItem item;
  final int index;
  final bool isLocked;
  final Color accent;
  final bool isDark;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _ProcessItemTile({
    required this.item,
    required this.index,
    required this.isLocked,
    required this.accent,
    required this.isDark,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? AppColors.cardDark : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1410);
    final subtextColor =
        isDark ? AppColors.textTertiaryDark : const Color(0xFFAAAAAA);

    final stepColor = isLocked
        ? (isDark ? Colors.white24 : const Color(0xFFCCCCCC))
        : item.isChecked
            ? Colors.green
            : accent;

    // 当前可执行步骤（未锁定且未完成）
    final isCurrent = !isLocked && !item.isChecked;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 左侧：步骤圆圈 + 连接线 ──────────────────────────────
          SizedBox(
            width: 36,
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isLocked
                        ? Colors.transparent
                        : item.isChecked
                            ? Colors.green
                            : isCurrent
                                ? accent
                                : accent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: stepColor, width: isCurrent ? 2 : 1.5),
                  ),
                  child: Center(
                    child: isLocked
                        ? Icon(Icons.lock_outline_rounded,
                            size: 14,
                            color: isDark
                                ? Colors.white24
                                : const Color(0xFFCCCCCC))
                        : item.isChecked
                            ? const Icon(Icons.check_rounded,
                                size: 16, color: Colors.white)
                            : Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isCurrent ? Colors.white : accent,
                                ),
                              ),
                  ),
                ),
                // 连接线
                Container(
                  width: 2,
                  height: 22,
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  decoration: BoxDecoration(
                    color: item.isChecked
                        ? Colors.green.withValues(alpha: 0.35)
                        : (isDark
                            ? Colors.white12
                            : Colors.black.withValues(alpha: 0.08)),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // ── 右侧：条目内容卡片 ──────────────────────────────────
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              onLongPress: onLongPress,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isLocked
                      ? (isDark
                          ? bgColor.withValues(alpha: 0.5)
                          : const Color(0xFFFAFAFA))
                      : item.isChecked
                          ? (isDark
                              ? Colors.green.withValues(alpha: 0.06)
                              : Colors.green.withValues(alpha: 0.04))
                          : isCurrent
                              ? (isDark
                                  ? accent.withValues(alpha: 0.1)
                                  : accent.withValues(alpha: 0.06))
                              : bgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: isCurrent
                      ? Border.all(
                          color: accent.withValues(alpha: 0.4), width: 1.2)
                      : item.isChecked
                          ? Border.all(
                              color: Colors.green.withValues(alpha: 0.2),
                              width: 0.8)
                          : Border.all(
                              color: isDark
                                  ? Colors.white10
                                  : Colors.black.withValues(alpha: 0.05),
                              width: 0.5),
                  boxShadow: isCurrent
                      ? [
                          BoxShadow(
                            color: accent.withValues(
                                alpha: isDark ? 0.12 : 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : [],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            isCurrent ? FontWeight.w600 : FontWeight.w500,
                        color: isLocked
                            ? (isDark
                                ? Colors.white38
                                : const Color(0xFFCCCCCC))
                            : item.isChecked
                                ? (isDark
                                    ? Colors.white38
                                    : const Color(0xFFBBBBBB))
                                : textColor,
                        decoration: item.isChecked
                            ? TextDecoration.lineThrough
                            : null,
                        decorationColor:
                            isDark ? Colors.white38 : const Color(0xFFBBBBBB),
                      ),
                    ),
                    if (item.note != null && item.note!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          item.note!,
                          style:
                              TextStyle(fontSize: 12, color: subtextColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    // 当前步骤标签
                    if (isCurrent) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '👉 当前步骤',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
                        ),
                      ),
                    ],
                    // 锁定提示
                    if (isLocked) ...[
                      const SizedBox(height: 4),
                      Text(
                        '🔒 请先完成上一步',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? Colors.white24
                              : const Color(0xFFCCCCCC),
                        ),
                      ),
                    ],
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

// ─────────────────────────────────────────────────────────────────
//  进阶配置 Sheet（_AdvancedSettingsSheet）
//
//  功能分区：
//   1. 交互范式（进阶配置 · AI 决定，可手动覆盖）
//   2. 布局风格（simple / numbered / grouped）
//   3. 危险操作（重置 / 清空已完成 / 归档）
//
//  设计原则：
//   • 交互范式置于「进阶配置」分区，有明确的 AI 决定说明
//   • 普通用户只会偶尔触碰，不在主路径上
//   • 危险操作在底部，视觉上用红色区分
// ─────────────────────────────────────────────────────────────────

class _AdvancedSettingsSheet extends StatelessWidget {
  final Checklist checklist;
  final Color accent;
  final bool isDark;
  final VoidCallback onClose;

  const _AdvancedSettingsSheet({
    required this.checklist,
    required this.accent,
    required this.isDark,
    required this.onClose,
  });

  // 布局风格选项
  static const _styleOptions = [
    (ChecklistStyle.simple, '标准', Icons.list_rounded),
    (ChecklistStyle.numbered, '序号', Icons.format_list_numbered_rounded),
    (ChecklistStyle.grouped, '分组', Icons.folder_outlined),
  ];

  // 交互范式选项
  static const _modeOptions = [
    (ChecklistInteractionMode.execution, '执行', Icons.check_box_outline_blank_rounded),
    (ChecklistInteractionMode.reference, '参考', Icons.menu_book_rounded),
    (ChecklistInteractionMode.review, '复盘', Icons.psychology_outlined),
    (ChecklistInteractionMode.process, '流程', Icons.account_tree_outlined),
  ];

  String _modeDescription(ChecklistInteractionMode mode) {
    switch (mode) {
      case ChecklistInteractionMode.execution:
        return '勾选完成，追踪进度';
      case ChecklistInteractionMode.reference:
        return '浏览为主，可评分';
      case ChecklistInteractionMode.review:
        return '逐题填写，复盘反思';
      case ChecklistInteractionMode.process:
        return '严格顺序，步骤解锁';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? AppColors.surfaceDark : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1410);
    final subtextColor = isDark ? Colors.white54 : const Color(0xFF888888);
    final dividerColor = isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 拖动条
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white24
                        : Colors.black.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.tune_rounded, size: 18, color: accent),
                  const SizedBox(width: 8),
                  Text('清单设置',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      )),
                ],
              ),
              const SizedBox(height: 20),

              // ── 分区 1：布局风格 ──────────────────────────────────
              Text('布局风格',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: subtextColor)),
              const SizedBox(height: 10),
              Row(
                children: _styleOptions.map((opt) {
                  final (style, label, icon) = opt;
                  final selected = checklist.style == style;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          if (!selected) {
                            context.read<ChecklistProvider>().updateChecklist(
                                  checklist.copyWith(style: style),
                                );
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: selected
                                ? accent.withValues(alpha: isDark ? 0.18 : 0.12)
                                : (isDark
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : const Color(0xFFF5F5F5)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected
                                  ? accent.withValues(alpha: 0.5)
                                  : Colors.transparent,
                              width: 1.2,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(icon,
                                  size: 20,
                                  color: selected
                                      ? accent
                                      : (isDark ? Colors.white54 : const Color(0xFF888888))),
                              const SizedBox(height: 5),
                              Text(label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                    color: selected
                                        ? accent
                                        : (isDark ? Colors.white70 : const Color(0xFF666666)),
                                  )),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),
              Divider(height: 1, color: dividerColor),
              const SizedBox(height: 20),

              // ── 分区 2：交互范式（进阶配置区）────────────────────
              Row(
                children: [
                  Text('交互范式',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: subtextColor)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9775FA).withValues(alpha: isDark ? 0.2 : 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('进阶配置',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF9775FA),
                        )),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // 说明文字
              Text(
                'AI 会根据清单的场景和内容自动推断合适的范式。\n通常你不需要手动调整。',
                style: TextStyle(fontSize: 12, height: 1.5, color: subtextColor),
              ),
              const SizedBox(height: 12),
              // 范式选项网格
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.8,
                children: _modeOptions.map((opt) {
                  final (mode, label, icon) = opt;
                  final selected = checklist.interactionMode == mode;
                  return GestureDetector(
                    onTap: () {
                      if (!selected) {
                        context.read<ChecklistProvider>().updateChecklist(
                              checklist.copyWith(interactionMode: mode),
                            );
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF9775FA).withValues(alpha: isDark ? 0.18 : 0.1)
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : const Color(0xFFF5F5F5)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF9775FA).withValues(alpha: 0.5)
                              : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(icon,
                              size: 16,
                              color: selected
                                  ? const Color(0xFF9775FA)
                                  : (isDark ? Colors.white54 : const Color(0xFF888888))),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(label,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                      color: selected
                                          ? const Color(0xFF9775FA)
                                          : (isDark ? Colors.white : const Color(0xFF1A1410)),
                                    )),
                                Text(_modeDescription(mode),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDark ? Colors.white38 : const Color(0xFFAAAAAA),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          if (selected)
                            const Icon(Icons.check_circle_rounded,
                                size: 14, color: Color(0xFF9775FA)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),
              Divider(height: 1, color: dividerColor),
              const SizedBox(height: 16),

              // ── 分区 3：常规操作 ──────────────────────────────────
              Text('操作',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: subtextColor)),
              const SizedBox(height: 10),
              // 重置所有
              _ActionRow(
                icon: Icons.refresh_rounded,
                label: '重置所有条目',
                description: '将全部条目标记为未完成',
                isDark: isDark,
                onTap: () {
                  Navigator.pop(context);
                  context.read<ChecklistProvider>().resetAll(checklist.id);
                },
              ),
              const SizedBox(height: 8),
              // 清空已完成
              _ActionRow(
                icon: Icons.clear_all_rounded,
                label: '清空已完成条目',
                description: '从列表中删除所有已勾选的条目',
                isDark: isDark,
                onTap: () {
                  Navigator.pop(context);
                  context.read<ChecklistProvider>().clearCheckedItems(checklist.id);
                },
              ),
              // 时态型：完成并归档
              if (checklist.checklistType == ChecklistType.temporal) ...[
                const SizedBox(height: 8),
                _ActionRow(
                  icon: Icons.check_circle_outline_rounded,
                  label: '完成并归档',
                  description: '标记为完成，移入归档',
                  isDark: isDark,
                  iconColor: Colors.green,
                  onTap: () {
                    Navigator.pop(context);
                    context.read<ChecklistProvider>()
                        .completeAndArchiveTemporal(checklist.id);
                    Navigator.pop(context);
                  },
                ),
              ],
              const SizedBox(height: 16),
              Divider(height: 1, color: dividerColor),
              const SizedBox(height: 12),
              // 归档（危险操作）
              _ActionRow(
                icon: Icons.archive_outlined,
                label: '归档清单',
                description: '隐藏清单，可在归档列表中恢复',
                isDark: isDark,
                iconColor: Colors.orange,
                labelColor: Colors.orange,
                onTap: () {
                  Navigator.pop(context);
                  context.read<ChecklistProvider>().archiveChecklist(checklist.id);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 设置 Sheet 中的操作行 ────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final bool isDark;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? labelColor;

  const _ActionRow({
    required this.icon,
    required this.label,
    required this.description,
    required this.isDark,
    required this.onTap,
    this.iconColor,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    final ic = iconColor ?? (isDark ? Colors.white70 : const Color(0xFF555555));
    final lc = labelColor ?? (isDark ? Colors.white : const Color(0xFF1A1410));
    final sc = isDark ? Colors.white38 : const Color(0xFFAAAAAA);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: ic.withValues(alpha: isDark ? 0.15 : 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: ic),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: lc,
                      )),
                  Text(description,
                      style: TextStyle(fontSize: 11, color: sc)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 18,
                color: isDark ? Colors.white24 : const Color(0xFFCCCCCC)),
          ],
        ),
      ),
    );
  }
}
