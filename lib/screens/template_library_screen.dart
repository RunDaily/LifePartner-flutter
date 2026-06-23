import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../data/template_data.dart';
import '../models/checklist.dart' show ChecklistStyle;
import '../models/checklist_template.dart';
import '../models/user_profile.dart';
import '../providers/checklist_provider.dart';
import '../providers/user_profile_provider.dart';
import '../services/ai_service.dart';
import '../theme/app_theme.dart';
import 'checklist_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────
//  TemplateLibraryScreen —— 清单模板库主页
//
//  【布局结构】
//
//  ┌─────────────────────────────────────────────────────┐
//  │  ←  模板库                                          │  AppBar
//  ├─────────────────────────────────────────────────────┤
//  │ [全部] [旅行✈️] [工作💼] [生活🏠] [健康💊] ... →   │  分类筛选栏
//  ├─────────────────────────────────────────────────────┤
//  │  ✨ 精选推荐（仅全部页显示）                          │  精选区
//  │  ┌──────────────┐  ┌──────────────┐               │  横向大卡片
//  │  │ 🧳旅行打包    │  │ ☀️晨间Routine │               │
//  │  └──────────────┘  └──────────────┘               │
//  ├─────────────────────────────────────────────────────┤
//  │  旅行 · 4 个模板                                    │  Section 标题
//  │  ┌──────┐  ┌──────┐  ┌──────┐                     │  2列网格卡片
//  │  │ 🧳   │  │ 💼   │  │ ⛺   │                     │
//  │  └──────┘  └──────┘  └──────┘                     │
//  ├─────────────────────────────────────────────────────┤
//  │  🤖 没找到合适的模板？让 AI 帮你生成                 │  AI 生成入口
//  └─────────────────────────────────────────────────────┘
//
//  点击模板卡片 → 弹出 _TemplatePreviewSheet（底部弹窗）
//    → 「用这个模板」→ createFromTemplate → 跳转详情页
//  点击 AI 入口 → 弹出 _AiGenerateSheet
//    → 输入意图 → 流式生成条目 → 预览 → 使用
// ─────────────────────────────────────────────────────────────────

class TemplateLibraryScreen extends StatefulWidget {
  const TemplateLibraryScreen({super.key});

  @override
  State<TemplateLibraryScreen> createState() => _TemplateLibraryScreenState();
}

class _TemplateLibraryScreenState extends State<TemplateLibraryScreen> {
  TemplateCategory _selectedCategory = TemplateCategory.all;

  List<ChecklistTemplate> get _displayedTemplates =>
      TemplateData.byCategory(_selectedCategory);

  bool get _showFeatured => _selectedCategory == TemplateCategory.all;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = WeeklyTheme.getLightPalette();
    final primary = isDark ? AppColors.darkPrimary : palette.primary;
    final bg = isDark ? AppColors.backgroundDark : palette.background;

    return Scaffold(
      backgroundColor: bg,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildAppBar(context, primary, isDark, innerBoxIsScrolled),
        ],
        body: CustomScrollView(
          slivers: [
            // 分类筛选栏
            SliverToBoxAdapter(
              child: _CategoryFilterBar(
                selected: _selectedCategory,
                primary: primary,
                isDark: isDark,
                onSelect: (cat) => setState(() => _selectedCategory = cat),
              ),
            ),

            // 精选推荐区
            if (_showFeatured) ...[
              SliverToBoxAdapter(
                child: _SectionHeader(
                  label: '✨ 精选推荐',
                  isDark: isDark,
                  trailing: null,
                ),
              ),
              SliverToBoxAdapter(
                child: _FeaturedRow(
                  templates: TemplateData.featured,
                  primary: primary,
                  isDark: isDark,
                  onTap: (t) => _openPreview(context, t, primary, isDark),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
            ],

            // 全部分类分组展示
            if (_selectedCategory == TemplateCategory.all) ...[
              for (final cat in TemplateCategory.values.skip(1)) ...[
                if (TemplateData.byCategory(cat).isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: _SectionHeader(
                      label: '${cat.emoji} ${cat.label}',
                      isDark: isDark,
                      trailing: '${TemplateData.byCategory(cat).length} 个',
                    ),
                  ),
                  _buildTemplateGrid(
                    TemplateData.byCategory(cat),
                    primary,
                    isDark,
                    context,
                  ),
                ],
              ],
            ] else ...[
              SliverToBoxAdapter(
                child: _SectionHeader(
                  label:
                      '${_selectedCategory.emoji} ${_selectedCategory.label}',
                  isDark: isDark,
                  trailing: '${_displayedTemplates.length} 个',
                ),
              ),
              _buildTemplateGrid(
                _displayedTemplates,
                primary,
                isDark,
                context,
              ),
            ],

            // ── AI 生成入口卡片 ──
            SliverToBoxAdapter(
              child: _AiGenerateBanner(
                isDark: isDark,
                primary: primary,
                onTap: () => _openAiGenerate(context, primary, isDark),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  SliverAppBar _buildAppBar(
    BuildContext context,
    Color primary,
    bool isDark,
    bool innerBoxIsScrolled,
  ) {
    final bgColor = isDark
        ? AppColors.backgroundDark
        : WeeklyTheme.getLightPalette().background;

    return SliverAppBar(
      pinned: true,
      floating: true,
      backgroundColor: bgColor,
      surfaceTintColor: Colors.transparent,
      elevation: innerBoxIsScrolled ? 1 : 0,
      shadowColor: Colors.black12,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 18,
          color: isDark ? Colors.white : const Color(0xFF1A1410),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        '模板库',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : const Color(0xFF1A1410),
        ),
      ),
    );
  }

  SliverPadding _buildTemplateGrid(
    List<ChecklistTemplate> templates,
    Color primary,
    bool isDark,
    BuildContext context,
  ) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.05,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _TemplateCard(
            template: templates[index],
            primary: primary,
            isDark: isDark,
            onTap: () =>
                _openPreview(context, templates[index], primary, isDark),
          ),
          childCount: templates.length,
        ),
      ),
    );
  }

  void _openPreview(
    BuildContext context,
    ChecklistTemplate template,
    Color primary,
    bool isDark,
  ) {
    HapticFeedback.lightImpact();
    final provider = context.read<ChecklistProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TemplatePreviewSheet(
        template: template,
        primary: primary,
        isDark: isDark,
        provider: provider,
      ),
    );
  }

  void _openAiGenerate(
    BuildContext context,
    Color primary,
    bool isDark,
  ) {
    HapticFeedback.lightImpact();
    final provider = context.read<ChecklistProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AiGenerateSheet(
        primary: primary,
        isDark: isDark,
        provider: provider,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  AI 生成入口横幅
// ─────────────────────────────────────────────────────────────────

class _AiGenerateBanner extends StatelessWidget {
  final bool isDark;
  final Color primary;
  final VoidCallback onTap;

  const _AiGenerateBanner({
    required this.isDark,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primary.withValues(alpha: isDark ? 0.22 : 0.10),
                primary.withValues(alpha: isDark ? 0.10 : 0.04),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: primary.withValues(alpha: isDark ? 0.35 : 0.20),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: isDark ? 0.25 : 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Text('🤖', style: TextStyle(fontSize: 24)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '没找到合适的模板？',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1A1410),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '描述你的需求，让 AI 为你生成专属清单',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : const Color(0xFF888888),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: primary.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  AI 生成底部弹窗
// ─────────────────────────────────────────────────────────────────

/// 生成阶段状态机
enum _GenPhase {
  input,      // 初始输入阶段
  generating, // AI 流式生成中
  preview,    // 生成完毕，展示预览
  error,      // 发生错误
}

class _AiGenerateSheet extends StatefulWidget {
  final Color primary;
  final bool isDark;
  final ChecklistProvider provider;

  const _AiGenerateSheet({
    required this.primary,
    required this.isDark,
    required this.provider,
  });

  @override
  State<_AiGenerateSheet> createState() => _AiGenerateSheetState();
}

class _AiGenerateSheetState extends State<_AiGenerateSheet> {
  final TextEditingController _intentCtrl = TextEditingController();
  final FocusNode _intentFocus = FocusNode();
  final ScrollController _listScroll = ScrollController();

  _GenPhase _phase = _GenPhase.input;
  String _errorMsg = '';

  String _generatedTitle = '';
  String _generatedEmoji = '📋';
  final List<String> _generatedItems = [];
  String _streamingCurrentItem = '';
  bool _isUsing = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(
      const Duration(milliseconds: 100),
      () => _intentFocus.requestFocus(),
    );
  }

  @override
  void dispose() {
    _intentCtrl.dispose();
    _intentFocus.dispose();
    _listScroll.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final intent = _intentCtrl.text.trim();
    if (intent.isEmpty) return;

    HapticFeedback.mediumImpact();
    _intentFocus.unfocus();

    setState(() {
      _phase = _GenPhase.generating;
      _generatedTitle = '';
      _generatedEmoji = '📋';
      _generatedItems.clear();
      _streamingCurrentItem = '';
      _errorMsg = '';
    });

    // ── 三层用户画像注入 ─────────────────────────────────────────
    final checklistProvider = context.read<ChecklistProvider>();
    final userProfileProvider = context.read<UserProfileProvider>();
    final allChecklistTitles = checklistProvider.checklists
        .map((c) => c.title)
        .toList();
    final UserProfile userProfile = userProfileProvider.profile;
    final personaCtx = userProfile.buildAiPersonaContext(
      checklistTitles: allChecklistTitles,
    );

    final baseSystemPrompt = '''你是一个清单生成专家。用户描述一个场景或需求，你输出一份实用的清单。

输出格式（严格按此格式，不要输出其他内容）：
第一行：emoji空格标题（例如：🧳 西藏自驾游清单）
后续每行：一个条目（直接写条目文本，不加序号、不加-、不加•）

要求：
- 条目数量 10-20 个，实用不冗余
- 每个条目一行，简洁具体
- 不要分组，不要标题行，不要空行
- 不要解释说明''';

    final systemPrompt = personaCtx.isNotEmpty
        ? '$baseSystemPrompt\n\n---\n【关于这个用户】\n$personaCtx'
        : baseSystemPrompt;

    final userMsg = '帮我生成一份清单：$intent';
    final buffer = StringBuffer();

    try {
      final stream = AiService.instance.chatStream(
        systemPrompt: systemPrompt,
        userMessage: userMsg,
        history: const [],
      );

      await for (final chunk in stream) {
        if (!mounted) return;
        buffer.write(chunk);

        final raw = buffer.toString();
        final lines = raw.split('\n');

        String newTitle = _generatedTitle;
        String newEmoji = _generatedEmoji;
        final newItems = <String>[];
        String newStreaming = '';

        for (int i = 0; i < lines.length; i++) {
          final line = lines[i];
          final isLast = i == lines.length - 1;

          if (i == 0) {
            final trimmed = line.trim();
            if (trimmed.isNotEmpty) {
              final firstRune = trimmed.runes.first;
              if (firstRune > 0x2000) {
                final spaceIdx = trimmed.indexOf(' ');
                if (spaceIdx > 0) {
                  newEmoji = trimmed.substring(0, spaceIdx).trim();
                  newTitle = trimmed.substring(spaceIdx).trim();
                } else {
                  newTitle = trimmed;
                }
              } else {
                newTitle = trimmed;
              }
            }
          } else {
            final trimmed = line.trim();
            if (trimmed.isEmpty) continue;
            if (isLast) {
              newStreaming = trimmed;
            } else {
              newItems.add(trimmed);
            }
          }
        }

        setState(() {
          _generatedTitle = newTitle;
          _generatedEmoji = newEmoji;
          _generatedItems
            ..clear()
            ..addAll(newItems);
          _streamingCurrentItem = newStreaming;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_listScroll.hasClients) {
            _listScroll.animateTo(
              _listScroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
            );
          }
        });
      }

      // 流结束：把 streaming 行并入正式 items
      if (_streamingCurrentItem.isNotEmpty) {
        _generatedItems.add(_streamingCurrentItem);
        _streamingCurrentItem = '';
      }

      setState(() => _phase = _GenPhase.preview);
      HapticFeedback.lightImpact();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _GenPhase.error;
        _errorMsg = e.toString();
      });
    }
  }

  Future<void> _useGenerated(BuildContext ctx) async {
    if (_isUsing || _generatedItems.isEmpty) return;
    setState(() => _isUsing = true);
    HapticFeedback.mediumImpact();

    final navigator = Navigator.of(ctx);
    final title =
        _generatedTitle.isNotEmpty ? _generatedTitle : '我的 AI 清单';
    final template = ChecklistTemplate(
      id: 'ai_generated_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      description: 'AI 根据你的需求生成',
      emoji: _generatedEmoji,
      colorHex: '5C7CFA',
      category: TemplateCategory.all,
      items: _generatedItems.map((text) => TemplateItem(text: text)).toList(),
    );

    try {
      final checklist = await widget.provider.createFromTemplate(template);
      if (!ctx.mounted) return;
      navigator.pop();
      navigator.push(
        MaterialPageRoute(
          builder: (_) => ChecklistDetailScreen(checklistId: checklist.id),
        ),
      );
    } catch (e) {
      if (!ctx.mounted) return;
      setState(() => _isUsing = false);
      ScaffoldMessenger.of(ctx)
          .showSnackBar(SnackBar(content: Text('创建失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final primary = widget.primary;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final maxH = MediaQuery.of(context).size.height * 0.90;
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxH),
        padding: EdgeInsets.only(bottom: bottomPad),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖拽手柄
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 弹窗标题行
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color:
                          primary.withValues(alpha: isDark ? 0.20 : 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Text('🤖', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI 生成专属清单',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1A1410),
                        ),
                      ),
                      Text(
                        '描述你的场景，AI 帮你列好每一项',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.textTertiaryDark
                              : const Color(0xFFAAAAAA),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            Divider(
              height: 1,
              color: isDark
                  ? Colors.white10
                  : Colors.black.withValues(alpha: 0.07),
            ),
            const SizedBox(height: 16),

            // 意图输入框（始终显示）
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _IntentInputBox(
                controller: _intentCtrl,
                focusNode: _intentFocus,
                isDark: isDark,
                primary: primary,
                enabled: _phase == _GenPhase.input ||
                    _phase == _GenPhase.error,
                onSubmit: _generate,
              ),
            ),

            const SizedBox(height: 12),

            // 各阶段主体内容
            Flexible(child: _buildPhaseContent(context, isDark, primary)),

            // 底部按钮
            _buildBottomBar(context, isDark, primary),
          ],
        ),
      ),
    );
  }

  Widget _buildPhaseContent(
      BuildContext context, bool isDark, Color primary) {
    switch (_phase) {
      case _GenPhase.input:
        return _buildInputHints(isDark, primary);
      case _GenPhase.generating:
        return _buildGeneratingView(isDark, primary);
      case _GenPhase.preview:
        return _buildPreviewView(isDark, primary);
      case _GenPhase.error:
        return _buildErrorView(isDark);
    }
  }

  // ── 输入阶段：示例提示 ────────────────────────────────────────
  Widget _buildInputHints(bool isDark, Color primary) {
    final hints = [
      ('🏕️', '我要去云南自驾游'),
      ('📚', '准备考研复试'),
      ('🐶', '第一次养狗'),
      ('💼', '明天有重要面试'),
      ('🏠', '准备装修新房'),
      ('✈️', '出差去上海两天'),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      children: [
        Text(
          '你可以这样描述',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark
                ? AppColors.textTertiaryDark
                : const Color(0xFFAAAAAA),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: hints.map((h) {
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                _intentCtrl.text = h.$2;
                _intentCtrl.selection = TextSelection.fromPosition(
                  TextPosition(offset: h.$2.length),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF2A2A2A)
                      : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                ),
                child: Text(
                  '${h.$1} ${h.$2}',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : const Color(0xFF555555),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── 生成中：流式条目列表 ──────────────────────────────────────
  Widget _buildGeneratingView(bool isDark, Color primary) {
    final allItems = [
      ..._generatedItems,
      if (_streamingCurrentItem.isNotEmpty) _streamingCurrentItem,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(
            children: [
              if (_generatedEmoji.isNotEmpty)
                Text(_generatedEmoji,
                    style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _generatedTitle.isNotEmpty
                      ? _generatedTitle
                      : '正在生成…',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color:
                        isDark ? Colors.white : const Color(0xFF1A1410),
                  ),
                ),
              ),
              _PulsingDot(color: primary),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: _listScroll,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            itemCount: allItems.length,
            itemBuilder: (context, index) {
              final isStreaming = index == allItems.length - 1 &&
                  _streamingCurrentItem.isNotEmpty;
              return _StreamItem(
                text: allItems[index],
                index: index + 1,
                isDark: isDark,
                primary: primary,
                isStreaming: isStreaming,
              );
            },
          ),
        ),
      ],
    );
  }

  // ── 预览阶段：最终结果 ────────────────────────────────────────
  Widget _buildPreviewView(bool isDark, Color primary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(
            children: [
              Text(_generatedEmoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _generatedTitle,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color:
                        isDark ? Colors.white : const Color(0xFF1A1410),
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: isDark ? 0.18 : 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_generatedItems.length} 条',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: _listScroll,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            itemCount: _generatedItems.length,
            itemBuilder: (context, index) => _StreamItem(
              text: _generatedItems[index],
              index: index + 1,
              isDark: isDark,
              primary: primary,
              isStreaming: false,
            ),
          ),
        ),
      ],
    );
  }

  // ── 错误状态 ──────────────────────────────────────────────────
  Widget _buildErrorView(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('😓', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(
              '生成失败，请重试',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1A1410),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMsg,
              style: TextStyle(
                fontSize: 11,
                color: isDark
                    ? AppColors.textTertiaryDark
                    : const Color(0xFFBBBBBB),
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ── 底部按钮区（根据阶段变化）────────────────────────────────
  Widget _buildBottomBar(BuildContext context, bool isDark, Color primary) {
    if (_phase == _GenPhase.input || _phase == _GenPhase.error) {
      // 生成按钮
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed:
                  _intentCtrl.text.trim().isEmpty ? null : _generate,
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: isDark
                    ? const Color(0xFF2A2A2A)
                    : const Color(0xFFE8E8E8),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('✨', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 6),
                  Text(
                    'AI 帮我生成',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_phase == _GenPhase.generating) {
      // 加载中按钮（禁用）
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: null,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark
                    ? const Color(0xFF2A2A2A)
                    : const Color(0xFFEEEEEE),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'AI 正在生成…',
                    style: TextStyle(
                      fontSize: 15,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : const Color(0xFF888888),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // preview 阶段：重新生成 + 使用清单
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 50,
                child: OutlinedButton(
                  onPressed: _isUsing
                      ? null
                      : () => setState(() {
                            _phase = _GenPhase.input;
                            _generatedItems.clear();
                            _generatedTitle = '';
                            _generatedEmoji = '📋';
                          }),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark
                        ? AppColors.textSecondaryDark
                        : const Color(0xFF555555),
                    side: BorderSide(
                      color: isDark ? Colors.white24 : Colors.black12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    '重新生成',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed:
                      _isUsing ? null : () => _useGenerated(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isUsing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_circle_outline_rounded,
                                size: 16),
                            SizedBox(width: 6),
                            Text(
                              '使用这份清单',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
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

// ─────────────────────────────────────────────────────────────────
//  意图输入框
// ─────────────────────────────────────────────────────────────────

class _IntentInputBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isDark;
  final Color primary;
  final bool enabled;
  final VoidCallback onSubmit;

  const _IntentInputBox({
    required this.controller,
    required this.focusNode,
    required this.isDark,
    required this.primary,
    required this.enabled,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
        ),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        maxLines: 2,
        minLines: 1,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => onSubmit(),
        style: TextStyle(
          fontSize: 15,
          color: isDark ? Colors.white : const Color(0xFF1A1410),
        ),
        decoration: InputDecoration(
          hintText: '例如：我要去西藏自驾游、准备考研复试…',
          hintStyle: TextStyle(
            fontSize: 14,
            color: isDark
                ? AppColors.textTertiaryDark
                : const Color(0xFFBBBBBB),
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  流式条目行
// ─────────────────────────────────────────────────────────────────

class _StreamItem extends StatelessWidget {
  final String text;
  final int index;
  final bool isDark;
  final Color primary;
  final bool isStreaming;

  const _StreamItem({
    required this.text,
    required this.index,
    required this.isDark,
    required this.primary,
    required this.isStreaming,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: isStreaming ? 0.08 : 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$index',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: primary.withValues(
                      alpha: isStreaming ? 0.5 : 1.0),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: isStreaming
                    ? (isDark
                        ? AppColors.textTertiaryDark
                        : const Color(0xFFAAAAAA))
                    : (isDark
                        ? AppColors.textSecondaryDark
                        : const Color(0xFF333333)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  流式脉冲点动画
// ─────────────────────────────────────────────────────────────────

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color.withValues(
                alpha: ((_anim.value + i * 0.3) % 1.0).clamp(0.2, 1.0),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  分类筛选栏
// ─────────────────────────────────────────────────────────────────

class _CategoryFilterBar extends StatelessWidget {
  final TemplateCategory selected;
  final Color primary;
  final bool isDark;
  final ValueChanged<TemplateCategory> onSelect;

  const _CategoryFilterBar({
    required this.selected,
    required this.primary,
    required this.isDark,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: TemplateCategory.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = TemplateCategory.values[index];
          final isActive = cat == selected;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onSelect(cat);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isActive
                    ? primary
                    : (isDark
                        ? const Color(0xFF2A2A2A)
                        : Colors.white),
                borderRadius: BorderRadius.circular(20),
                border: isActive
                    ? null
                    : Border.all(
                        color: isDark
                            ? Colors.white12
                            : Colors.black.withValues(alpha: 0.08),
                      ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: primary.withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(cat.emoji,
                      style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 4),
                  Text(
                    cat.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.w500,
                      color: isActive
                          ? Colors.white
                          : (isDark
                              ? AppColors.textSecondaryDark
                              : const Color(0xFF555555)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Section 标题
// ─────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final bool isDark;
  final String? trailing;

  const _SectionHeader({
    required this.label,
    required this.isDark,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1A1410),
              ),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppColors.textTertiaryDark
                    : const Color(0xFFAAAAAA),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  精选横向大卡片行
// ─────────────────────────────────────────────────────────────────

class _FeaturedRow extends StatelessWidget {
  final List<ChecklistTemplate> templates;
  final Color primary;
  final bool isDark;
  final ValueChanged<ChecklistTemplate> onTap;

  const _FeaturedRow({
    required this.templates,
    required this.primary,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: templates.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final t = templates[index];
          final accent = _hexToColor(t.colorHex);
          return GestureDetector(
            onTap: () => onTap(t),
            child: Container(
              width: 180,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent.withValues(alpha: isDark ? 0.25 : 0.12),
                    accent.withValues(alpha: isDark ? 0.10 : 0.04),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: accent.withValues(alpha: isDark ? 0.30 : 0.18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(t.emoji,
                          style: const TextStyle(fontSize: 22)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '精选',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? Colors.white
                          : const Color(0xFF1A1410),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${t.itemCount} 个条目',
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
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  模板网格卡片
// ─────────────────────────────────────────────────────────────────

class _TemplateCard extends StatelessWidget {
  final ChecklistTemplate template;
  final Color primary;
  final bool isDark;
  final VoidCallback onTap;

  const _TemplateCard({
    required this.template,
    required this.primary,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _hexToColor(template.colorHex);
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
          ),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
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
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: isDark ? 0.20 : 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      template.emoji,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color:
                        accent.withValues(alpha: isDark ? 0.18 : 0.10),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    template.function.label,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              template.title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1A1410),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Row(
              children: [
                Icon(
                  Icons.format_list_bulleted_rounded,
                  size: 11,
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : const Color(0xFFAAAAAA),
                ),
                const SizedBox(width: 4),
                Text(
                  '${template.itemCount} 个条目',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : const Color(0xFFAAAAAA),
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
//  模板预览底部弹窗
// ─────────────────────────────────────────────────────────────────

class _TemplatePreviewSheet extends StatefulWidget {
  final ChecklistTemplate template;
  final Color primary;
  final bool isDark;
  final ChecklistProvider provider;

  const _TemplatePreviewSheet({
    required this.template,
    required this.primary,
    required this.isDark,
    required this.provider,
  });

  @override
  State<_TemplatePreviewSheet> createState() =>
      _TemplatePreviewSheetState();
}

class _TemplatePreviewSheetState extends State<_TemplatePreviewSheet> {
  bool _isCreating = false;

  Color get accent => _hexToColor(widget.template.colorHex);

  Future<void> _useTemplate(BuildContext context) async {
    if (_isCreating) return;
    setState(() => _isCreating = true);
    HapticFeedback.mediumImpact();

    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final checklist =
          await widget.provider.createFromTemplate(widget.template);
      if (!context.mounted) return;
      navigator.pop();
      navigator.push(
        MaterialPageRoute(
          builder: (_) =>
              ChecklistDetailScreen(checklistId: checklist.id),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      setState(() => _isCreating = false);
      scaffoldMessenger
          .showSnackBar(SnackBar(content: Text('创建失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.template;
    final isDark = widget.isDark;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final maxH = MediaQuery.of(context).size.height * 0.82;

    final List<Widget> itemWidgets = _buildItemWidgets(t, isDark);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxH),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 头部信息
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: accent
                          .withValues(alpha: isDark ? 0.20 : 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        t.emoji,
                        style: const TextStyle(fontSize: 26),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1A1410),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.textTertiaryDark
                                : const Color(0xFFAAAAAA),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _InfoBadge(
                              label: t.category.label,
                              color: accent,
                              isDark: isDark,
                            ),
                            _InfoBadge(
                              label: t.function.label,
                              color: accent,
                              isDark: isDark,
                            ),
                            _InfoBadge(
                              label: '${t.itemCount} 个条目',
                              color: accent,
                              isDark: isDark,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),
            Divider(
              height: 1,
              color: isDark
                  ? Colors.white10
                  : Colors.black.withValues(alpha: 0.07),
            ),

            Flexible(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                children: itemWidgets,
              ),
            ),

            Divider(
              height: 1,
              color: isDark
                  ? Colors.white10
                  : Colors.black.withValues(alpha: 0.07),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isCreating
                        ? null
                        : () => _useTemplate(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isCreating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_circle_outline_rounded,
                                  size: 18),
                              SizedBox(width: 8),
                              Text(
                                '用这个模板',
                                style: TextStyle(
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
    );
  }

  List<Widget> _buildItemWidgets(ChecklistTemplate t, bool isDark) {
    if (t.style == ChecklistStyle.grouped) {
      final groups = <String, List<TemplateItem>>{};
      final noGroup = <TemplateItem>[];
      for (final item in t.items) {
        if (item.group != null) {
          groups.putIfAbsent(item.group!, () => []).add(item);
        } else {
          noGroup.add(item);
        }
      }
      final widgets = <Widget>[];
      for (final entry in groups.entries) {
        widgets.add(
            _GroupHeader(label: entry.key, isDark: isDark, accent: accent));
        for (final item in entry.value) {
          widgets.add(_PreviewItem(
            item: item,
            style: t.style,
            index: null,
            isDark: isDark,
            accent: accent,
          ));
        }
        widgets.add(const SizedBox(height: 6));
      }
      for (final item in noGroup) {
        widgets.add(_PreviewItem(
          item: item,
          style: t.style,
          index: null,
          isDark: isDark,
          accent: accent,
        ));
      }
      return widgets;
    } else if (t.style == ChecklistStyle.numbered) {
      return t.items.asMap().entries.map((entry) {
        return _PreviewItem(
          item: entry.value,
          style: t.style,
          index: entry.key + 1,
          isDark: isDark,
          accent: accent,
        );
      }).toList();
    } else {
      return t.items.map((item) {
        return _PreviewItem(
          item: item,
          style: t.style,
          index: null,
          isDark: isDark,
          accent: accent,
        );
      }).toList();
    }
  }
}

// ─────────────────────────────────────────────────────────────────
//  预览列表子组件
// ─────────────────────────────────────────────────────────────────

class _GroupHeader extends StatelessWidget {
  final String label;
  final bool isDark;
  final Color accent;

  const _GroupHeader(
      {required this.label, required this.isDark, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 13,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : const Color(0xFF666666),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewItem extends StatelessWidget {
  final TemplateItem item;
  final ChecklistStyle style;
  final int? index;
  final bool isDark;
  final Color accent;

  const _PreviewItem({
    required this.item,
    required this.style,
    required this.index,
    required this.isDark,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            child: style == ChecklistStyle.numbered && index != null
                ? Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$index',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
                    ),
                  )
                : Container(
                    width: 16,
                    height: 16,
                    margin: const EdgeInsets.only(top: 1),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark
                            ? Colors.white30
                            : Colors.black.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item.quantity != null
                  ? '${item.text}（${item.quantity}）'
                  : item.text,
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : const Color(0xFF333333),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool isDark;

  const _InfoBadge(
      {required this.label, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  工具函数
// ─────────────────────────────────────────────────────────────────

Color _hexToColor(String hex) {
  try {
    final clean = hex.replaceAll('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  } catch (_) {
    return const Color(0xFF5C7CFA);
  }
}
