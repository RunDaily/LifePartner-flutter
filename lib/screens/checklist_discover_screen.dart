import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../data/template_data.dart';
import '../models/checklist.dart';
import '../models/checklist_template.dart';
import '../models/user_profile.dart';
import '../providers/checklist_provider.dart';
import '../providers/user_profile_provider.dart';
import '../services/ai_service.dart';
import '../theme/app_theme.dart';
import 'checklist_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────
//  ChecklistDiscoverScreen —— AI 发现页（v1）
//
//  入口：清单首页顶部搜索 Banner 点击后进入
//
//  【布局结构】
//
//  ┌─────────────────────────────────────────────────────┐
//  │  ← 返回    🔍 [想做什么清单？__________]            │  吸顶搜索栏
//  ├─────────────────────────────────────────────────────┤
//  │  [旅行打包][周工作计划][健身训练][备考冲刺] ···       │  热门词气泡
//  ├─────────────────────────────────────────────────────┤
//  │  ✨ 为你推荐   基于你的画像                          │  个性化推荐标题
//  │  ┌──────────┐ ┌──────────┐ ┌──────────┐           │  横向卡片（可滑）
//  │  │💼 周复盘  │ │📊 项目跟 │ │📚 学习计 │           │
//  │  └──────────┘ └──────────┘ └──────────┘           │
//  ├─────────────────────────────────────────────────────┤
//  │  📋 模板库                                          │  Section 标题
//  │  [工作效率] [旅行] [健康] [学习] ···                │  分类 Tab
//  │  ┌───────┐ ┌───────┐ ┌───────┐                    │  模板卡片网格
//  │  └───────┘ └───────┘ └───────┘                    │
//  └─────────────────────────────────────────────────────┘
//
//  交互：
//  - 点击推荐词/热门词气泡 → 直接触发 AI 生成（弹出生成面板）
//  - 点击搜索框输入 → 同上
//  - 点击推荐卡片 → 触发 AI 生成（用卡片标题作为 prompt）
//  - 点击模板卡片 → 底部弹窗预览 → 「用这个模板」
// ─────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────
//  画像驱动的推荐数据
//
//  每个 PersonaArchetype 对应一组「推荐清单」，
//  用户在 Onboarding 选择后即可看到个性化推荐
// ─────────────────────────────────────────────────────────────────

class _RecommendCard {
  final String emoji;
  final String title;
  final String subtitle;
  final String colorHex;
  final String aiPrompt; // 点击时传给 AI 的 prompt

  const _RecommendCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.colorHex,
    required this.aiPrompt,
  });
}

/// 每个人物原型对应的推荐清单
const Map<String, List<_RecommendCard>> _personaRecommends = {
  // ── 职场打工人 ──────────────────────────────────────────────────
  'office_worker': [
    _RecommendCard(emoji: '📅', title: '下周工作计划', subtitle: '提前规划，高效推进', colorHex: '339AF0', aiPrompt: '下周工作计划清单，包含重点任务、会议安排和截止日期追踪'),
    _RecommendCard(emoji: '📊', title: '项目进度追踪', subtitle: '里程碑·交付物·风险', colorHex: '20C997', aiPrompt: '项目进度追踪清单，包含里程碑、交付物和风险记录'),
    _RecommendCard(emoji: '💡', title: '会议准备清单', subtitle: '议程·材料·跟进事项', colorHex: 'FAB005', aiPrompt: '会议准备清单，包含议程整理、材料准备和会后行动项'),
    _RecommendCard(emoji: '🔁', title: '周工作复盘', subtitle: '完成了什么·下周聚焦', colorHex: 'CC5DE8', aiPrompt: '周工作复盘清单，包含本周完成事项、遇到的问题和下周计划'),
    _RecommendCard(emoji: '📧', title: '职场沟通清单', subtitle: '邮件·汇报·跨部门', colorHex: 'FF6B6B', aiPrompt: '职场沟通效率清单，包含邮件规范、汇报要点和跨部门协作'),
  ],

  // ── 独当一面者 ──────────────────────────────────────────────────
  'self_employed': [
    _RecommendCard(emoji: '🚀', title: '产品 MVP 清单', subtitle: '最小可行版本验证', colorHex: 'FF6348', aiPrompt: '产品MVP验证清单，包含核心功能、用户测试和迭代计划'),
    _RecommendCard(emoji: '💰', title: '客户开发流程', subtitle: '线索·跟进·成单', colorHex: '20C997', aiPrompt: '客户开发清单，包含线索收集、跟进节奏和成单流程'),
    _RecommendCard(emoji: '📋', title: '每日独立工作', subtitle: '专注工作·避免拖延', colorHex: '339AF0', aiPrompt: '独立工作者每日清单，包含专注任务、休息节奏和产出记录'),
    _RecommendCard(emoji: '🧾', title: '接单流程 SOP', subtitle: '从谈单到交付', colorHex: 'FAB005', aiPrompt: '接单流程SOP，从客户谈判到项目交付的完整步骤'),
    _RecommendCard(emoji: '📈', title: '月度收入规划', subtitle: '目标·实际·差距分析', colorHex: 'CC5DE8', aiPrompt: '月度收入规划清单，包含收入目标、实际记录和差距分析'),
  ],

  // ── 学生党 ──────────────────────────────────────────────────────
  'student': [
    _RecommendCard(emoji: '📚', title: '期末备考计划', subtitle: '科目·重点·冲刺安排', colorHex: '339AF0', aiPrompt: '期末备考计划清单，按科目整理重点和复习节奏'),
    _RecommendCard(emoji: '✍️', title: '论文写作清单', subtitle: '选题·文献·初稿·答辩', colorHex: '20C997', aiPrompt: '论文写作清单，从选题到答辩的完整步骤'),
    _RecommendCard(emoji: '🗓️', title: '每日学习计划', subtitle: '时间块·打卡·复习', colorHex: 'FAB005', aiPrompt: '学生每日学习计划清单，包含时间块安排和打卡习惯'),
    _RecommendCard(emoji: '🎓', title: '实习求职准备', subtitle: '简历·投递·面试', colorHex: 'CC5DE8', aiPrompt: '实习求职准备清单，包含简历优化、投递追踪和面试准备'),
    _RecommendCard(emoji: '📖', title: '读书笔记模板', subtitle: '摘录·思考·总结', colorHex: 'FF6B6B', aiPrompt: '读书笔记清单，包含重要摘录、个人思考和读后总结'),
  ],

  // ── 家庭掌舵人 ──────────────────────────────────────────────────
  'family_manager': [
    _RecommendCard(emoji: '🛒', title: '家庭购物清单', subtitle: '食材·日用·按周采购', colorHex: '20C997', aiPrompt: '家庭周采购清单，包含食材、日用品和分类整理'),
    _RecommendCard(emoji: '🏠', title: '家务安排清单', subtitle: '日常·每周·每月', colorHex: '339AF0', aiPrompt: '家务安排清单，按日常、每周、每月分类整理'),
    _RecommendCard(emoji: '💳', title: '家庭账单管理', subtitle: '固定支出·还款·年费', colorHex: 'FAB005', aiPrompt: '家庭账单管理清单，包含固定支出提醒和还款节点'),
    _RecommendCard(emoji: '📅', title: '家庭日历事项', subtitle: '纪念日·就医·报名', colorHex: 'CC5DE8', aiPrompt: '家庭重要日历事项清单，包含纪念日、就医提醒和报名截止'),
    _RecommendCard(emoji: '🔧', title: '家居维护清单', subtitle: '水电·家电·季节检查', colorHex: 'FF6B6B', aiPrompt: '家居维护清单，包含水电检查、家电维保和季节性保养'),
  ],

  // ── 新手爸妈 ──────────────────────────────────────────────────────
  'new_parent': [
    _RecommendCard(emoji: '👶', title: '宝宝生长记录', subtitle: '体重·身高·发育里程碑', colorHex: 'FF6B6B', aiPrompt: '宝宝生长记录清单，包含体重身高、发育里程碑和喂养记录'),
    _RecommendCard(emoji: '💉', title: '疫苗接种计划', subtitle: '时间·地点·注意事项', colorHex: '339AF0', aiPrompt: '宝宝疫苗接种清单，包含接种时间、地点和注意事项'),
    _RecommendCard(emoji: '🍼', title: '月子待办清单', subtitle: '月子期重要事项', colorHex: '20C997', aiPrompt: '月子期待办清单，包含宝宝护理、产后恢复和证件办理'),
    _RecommendCard(emoji: '🎒', title: '入园准备清单', subtitle: '物品·心理·入园流程', colorHex: 'FAB005', aiPrompt: '幼儿园入园准备清单，包含物品准备、心理建设和入园流程'),
    _RecommendCard(emoji: '🌟', title: '早教活动清单', subtitle: '每周亲子活动安排', colorHex: 'CC5DE8', aiPrompt: '每周早教亲子活动清单，适合0-3岁宝宝的互动活动'),
  ],

  // ── 运动爱好者 ──────────────────────────────────────────────────
  'fitness_fan': [
    _RecommendCard(emoji: '💪', title: '健身训练计划', subtitle: '分化·组数·重量记录', colorHex: 'FF6348', aiPrompt: '健身训练计划清单，包含分化训练、组数安排和重量记录'),
    _RecommendCard(emoji: '🏃', title: '跑步打卡计划', subtitle: '里程·配速·周目标', colorHex: '20C997', aiPrompt: '跑步打卡计划清单，包含每周里程目标、配速记录和进步追踪'),
    _RecommendCard(emoji: '🥗', title: '饮食管理清单', subtitle: '蛋白质·碳水·热量', colorHex: 'FAB005', aiPrompt: '健身饮食管理清单，包含蛋白质目标、饮食搭配和餐前准备'),
    _RecommendCard(emoji: '🏆', title: '赛事备战清单', subtitle: '训练·装备·比赛准备', colorHex: '339AF0', aiPrompt: '赛事备战清单，包含赛前训练计划、装备准备和比赛当天安排'),
    _RecommendCard(emoji: '😴', title: '恢复与休息', subtitle: '睡眠·拉伸·放松', colorHex: 'CC5DE8', aiPrompt: '运动恢复清单，包含睡眠质量、拉伸放松和营养补充'),
  ],

  // ── 生活探索者 ──────────────────────────────────────────────────
  'life_explorer': [
    _RecommendCard(emoji: '✈️', title: '旅行打包清单', subtitle: '证件·衣物·电子设备', colorHex: '339AF0', aiPrompt: '出行旅行打包清单，包含证件、衣物、洗漱和电子设备'),
    _RecommendCard(emoji: '🗺️', title: '行程规划清单', subtitle: '景点·住宿·交通安排', colorHex: '20C997', aiPrompt: '旅行行程规划清单，包含景点优先级、住宿安排和交通连接'),
    _RecommendCard(emoji: '🍜', title: '探店打卡记录', subtitle: '心愿·探访·推荐', colorHex: 'FAB005', aiPrompt: '探店打卡清单，记录想去的餐厅、已探访评价和推荐理由'),
    _RecommendCard(emoji: '🌟', title: '年度心愿清单', subtitle: '想做的100件事', colorHex: 'CC5DE8', aiPrompt: '年度心愿清单，列出今年想体验、想完成的有趣事情'),
    _RecommendCard(emoji: '📷', title: '摄影取景清单', subtitle: '地点·时机·构图思路', colorHex: 'FF6B6B', aiPrompt: '摄影取景清单，包含想去的地点、最佳时机和构图想法'),
  ],

  // ── 慢生活践行者 ─────────────────────────────────────────────────
  'slow_liver': [
    _RecommendCard(emoji: '🌅', title: '晨间例程清单', subtitle: '唤醒·冥想·开始一天', colorHex: 'FAB005', aiPrompt: '晨间例程清单，包含起床唤醒、冥想练习和一天好的开始'),
    _RecommendCard(emoji: '🌿', title: '断舍离计划', subtitle: '物品整理·清空·留存', colorHex: '20C997', aiPrompt: '断舍离整理清单，按区域梳理物品，决定留存或丢弃'),
    _RecommendCard(emoji: '🕯️', title: '每日仪式感', subtitle: '小事·用心·品质感', colorHex: 'CC5DE8', aiPrompt: '每日仪式感清单，记录让生活更有品质感的小事'),
    _RecommendCard(emoji: '📒', title: '感恩日记提示', subtitle: '今天值得感谢的事', colorHex: '339AF0', aiPrompt: '感恩日记清单，每天记录值得感谢的三件事和小确幸'),
    _RecommendCard(emoji: '🌙', title: '睡前放松清单', subtitle: '手机断开·放松·入眠', colorHex: 'FF6B6B', aiPrompt: '睡前放松清单，包含数字断联、放松练习和助眠习惯'),
  ],

  // ── 知识成长派 ──────────────────────────────────────────────────
  'knowledge_seeker': [
    _RecommendCard(emoji: '📖', title: '读书计划清单', subtitle: '书单·进度·笔记', colorHex: '339AF0', aiPrompt: '读书计划清单，包含待读书单、阅读进度和核心笔记'),
    _RecommendCard(emoji: '🧠', title: '技能学习路径', subtitle: '目标技能·资源·练习', colorHex: '20C997', aiPrompt: '技能学习路径清单，包含目标技能拆解、学习资源和练习计划'),
    _RecommendCard(emoji: '🎧', title: '播客收听清单', subtitle: '节目·话题·整理摘要', colorHex: 'FAB005', aiPrompt: '播客收听清单，记录想听的节目、精彩片段和内容摘要'),
    _RecommendCard(emoji: '💡', title: '想法收集箱', subtitle: '灵感·文章·待深入', colorHex: 'CC5DE8', aiPrompt: '想法收集清单，记录灵感、待深入研究的主题和参考资料'),
    _RecommendCard(emoji: '🔬', title: '年度学习目标', subtitle: 'OKR · 关键结果', colorHex: 'FF6B6B', aiPrompt: '年度学习目标清单，用OKR格式整理学习目标和关键结果'),
  ],

  // ── 健康管理者 ──────────────────────────────────────────────────
  'health_conscious': [
    _RecommendCard(emoji: '💊', title: '用药记录清单', subtitle: '药名·剂量·时间·备注', colorHex: 'FF6B6B', aiPrompt: '用药记录清单，包含药品名称、剂量、服药时间和特殊备注'),
    _RecommendCard(emoji: '🏥', title: '复查就医清单', subtitle: '时间·科室·检查项目', colorHex: '339AF0', aiPrompt: '复查就医准备清单，包含预约时间、携带资料和检查项目'),
    _RecommendCard(emoji: '🥗', title: '健康饮食管理', subtitle: '忌口·营养·膳食安排', colorHex: '20C997', aiPrompt: '健康饮食管理清单，包含饮食禁忌、营养目标和每日膳食'),
    _RecommendCard(emoji: '😴', title: '睡眠质量追踪', subtitle: '入睡时间·质量评分', colorHex: 'CC5DE8', aiPrompt: '睡眠质量追踪清单，记录入睡时间、起床时间和睡眠质量评分'),
    _RecommendCard(emoji: '📊', title: '健康指标记录', subtitle: '血压·血糖·体重趋势', colorHex: 'FAB005', aiPrompt: '健康指标记录清单，追踪血压、血糖、体重等关键健康数据'),
  ],
};

/// 无画像时的默认推荐（通用热门）
const List<_RecommendCard> _defaultRecommends = [
  _RecommendCard(emoji: '✈️', title: '旅行打包清单', subtitle: '出发前必备 · 证件衣物', colorHex: '339AF0', aiPrompt: '旅行打包清单，包含证件、衣物、洗漱和电子设备'),
  _RecommendCard(emoji: '📅', title: '下周工作计划', subtitle: '任务 · 会议 · 优先级', colorHex: '20C997', aiPrompt: '下周工作计划清单，包含重点任务、会议安排和优先级排序'),
  _RecommendCard(emoji: '🛒', title: '家庭采购清单', subtitle: '食材 · 日用 · 按类整理', colorHex: 'FAB005', aiPrompt: '家庭采购清单，包含食材、日用品按类别整理'),
  _RecommendCard(emoji: '💪', title: '健身训练计划', subtitle: '动作 · 组数 · 打卡', colorHex: 'FF6348', aiPrompt: '健身训练计划清单，包含训练动作、组数安排和打卡记录'),
  _RecommendCard(emoji: '📖', title: '读书笔记模板', subtitle: '摘录 · 思考 · 总结', colorHex: 'CC5DE8', aiPrompt: '读书笔记清单，包含重要摘录、个人思考和读后总结'),
  _RecommendCard(emoji: '🌅', title: '晨间例程清单', subtitle: '唤醒 · 运动 · 好的开始', colorHex: 'FAB005', aiPrompt: '晨间例程清单，包含起床、运动和开启美好一天的步骤'),
];

/// 热门搜索词（固定，不依赖画像）
const List<String> _hotKeywords = [
  '旅行打包', '周工作计划', '健身训练', '备考冲刺',
  '宝宝成长', '家庭采购', '年度目标', '读书清单',
  '搬家整理', '婚礼筹备', '减脂饮食', '睡前放松',
];

// ─────────────────────────────────────────────────────────────────
//  ChecklistDiscoverScreen
// ─────────────────────────────────────────────────────────────────

class ChecklistDiscoverScreen extends StatefulWidget {
  const ChecklistDiscoverScreen({super.key});

  @override
  State<ChecklistDiscoverScreen> createState() =>
      _ChecklistDiscoverScreenState();
}

class _ChecklistDiscoverScreenState extends State<ChecklistDiscoverScreen> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  // 模板库当前选中的分类
  TemplateCategory _selectedCategory = TemplateCategory.all;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  /// 根据用户画像计算推荐列表（最多取前5个不同 persona 各2张）
  List<_RecommendCard> _buildRecommends(UserProfile profile) {
    final cards = <_RecommendCard>[];
    final personas = profile.personaValues;

    if (personas.isEmpty) return _defaultRecommends;

    for (final pv in personas) {
      final list = _personaRecommends[pv];
      if (list != null) {
        // 每个 persona 最多贡献前3张
        cards.addAll(list.take(3));
      }
      if (cards.length >= 9) break;
    }

    // 不够9张时补充默认推荐
    if (cards.length < 6) {
      for (final d in _defaultRecommends) {
        if (!cards.any((c) => c.title == d.title)) {
          cards.add(d);
        }
        if (cards.length >= 6) break;
      }
    }

    return cards;
  }

  // ── 触发 AI 生成 ──────────────────────────────────────────────────

  void _generateWithPrompt(String prompt) {
    if (prompt.trim().isEmpty) return;
    _searchCtrl.text = prompt;
    _searchFocus.unfocus();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AiDiscoverGenerateSheet(
        initialPrompt: prompt,
        onCreated: (checklist) {
          Navigator.pop(context); // 关闭底部弹窗
          // 跳转到新建清单详情
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChecklistDetailScreen(checklistId: checklist.id),
            ),
          );
        },
      ),
    );
  }

  // ── 模板点击预览 ──────────────────────────────────────────────────

  void _previewTemplate(ChecklistTemplate template) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TemplatePreviewSheet(
        template: template,
        onUse: () {
          Navigator.pop(context);
          _useTemplate(template);
        },
      ),
    );
  }

  Future<void> _useTemplate(ChecklistTemplate template) async {
    final provider = context.read<ChecklistProvider>();
    final items = template.items.map((ti) => ChecklistItem(
      id: const Uuid().v4(),
      title: ti.text,
      groupLabel: ti.group,
      sortOrder: template.items.indexOf(ti),
      createdAt: DateTime.now(),
    )).toList();
    final checklist = await provider.addChecklist(
      title: template.title,
      emoji: template.emoji,
      colorHex: template.colorHex,
      scene: template.category.scene,
      function: template.function,
      style: template.style,
      checklistType: ChecklistType.structural,
      items: items,
    );
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChecklistDetailScreen(checklistId: checklist.id),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  Build
  // ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? WeeklyTheme.getDarkPalette().primary : WeeklyTheme.getLightPalette().primary;
    final bg = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1A1410);
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : const Color(0xFF888888);

    final profile = context.watch<UserProfileProvider>().profile;
    final recommends = _buildRecommends(profile);

    // 当前分类的模板
    final templates = _selectedCategory == TemplateCategory.all
        ? TemplateData.all
        : TemplateData.all
            .where((t) => t.category == _selectedCategory)
            .toList();

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          // ── 吸顶搜索 AppBar ──────────────────────────────────────
          _buildSearchAppBar(isDark, primary, bg, textPrimary),

          // ── 热门词气泡 ────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _HotKeywords(
              keywords: _hotKeywords,
              primary: primary,
              isDark: isDark,
              onTap: _generateWithPrompt,
            ),
          ),

          // ── 个性化推荐卡片 ────────────────────────────────────────
          SliverToBoxAdapter(
            child: _RecommendSection(
              recommends: recommends,
              personas: profile.personaValues,
              primary: primary,
              isDark: isDark,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              onTap: (card) => _generateWithPrompt(card.aiPrompt),
            ),
          ),

          // ── 模板库 Section ────────────────────────────────────────
          SliverToBoxAdapter(
            child: _TemplateSectionHeader(
              isDark: isDark,
              textPrimary: textPrimary,
            ),
          ),

          // 模板分类 Tab
          SliverToBoxAdapter(
            child: _TemplateCategoryBar(
              selected: _selectedCategory,
              primary: primary,
              isDark: isDark,
              onChanged: (c) => setState(() => _selectedCategory = c),
            ),
          ),

          // 模板卡片网格
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.1,
              ),
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _TemplateGridCard(
                  template: templates[i],
                  primary: primary,
                  isDark: isDark,
                  onTap: () => _previewTemplate(templates[i]),
                ),
                childCount: templates.length,
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildSearchAppBar(
      bool isDark, Color primary, Color bg, Color textPrimary) {
    return SliverAppBar(
      pinned: true,
      floating: true,
      snap: false,
      backgroundColor: bg,
      elevation: 0,
      toolbarHeight: 66,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
        color: isDark ? Colors.white : const Color(0xFF1A1410),
        onPressed: () => Navigator.pop(context),
      ),
      title: GestureDetector(
        onTap: () {
          _searchFocus.requestFocus();
        },
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Icon(Icons.search_rounded,
                  size: 20,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : const Color(0xFF888888)),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  focusNode: _searchFocus,
                  style: TextStyle(
                    fontSize: 14.5,
                    color: isDark ? Colors.white : const Color(0xFF1A1410),
                  ),
                  decoration: InputDecoration(
                    hintText: '想做什么清单？',
                    hintStyle: TextStyle(
                      fontSize: 14.5,
                      color: isDark
                          ? const Color(0xFF666666)
                          : const Color(0xFFAAAAAA),
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                  onSubmitted: _generateWithPrompt,
                  textInputAction: TextInputAction.search,
                ),
              ),
              // 提交箭头（有内容时显示）
              AnimatedBuilder(
                animation: _searchCtrl,
                builder: (_, __) {
                  if (_searchCtrl.text.isEmpty) {
                    return const SizedBox(width: 12);
                  }
                  return GestureDetector(
                    onTap: () => _generateWithPrompt(_searchCtrl.text),
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.arrow_forward_rounded,
                          size: 16, color: Colors.white),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      titleSpacing: 0,
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  热门词气泡
// ─────────────────────────────────────────────────────────────────

class _HotKeywords extends StatelessWidget {
  final List<String> keywords;
  final Color primary;
  final bool isDark;
  final ValueChanged<String> onTap;

  const _HotKeywords({
    required this.keywords,
    required this.primary,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('🔥',
                  style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 5),
              Text(
                '热门',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? const Color(0xFF888888)
                      : const Color(0xFFAAAAAA),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: keywords.map((kw) {
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onTap(kw);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.07)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.07),
                      width: 0.7,
                    ),
                  ),
                  child: Text(
                    kw,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.8)
                          : const Color(0xFF444444),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  个性化推荐区
// ─────────────────────────────────────────────────────────────────

class _RecommendSection extends StatelessWidget {
  final List<_RecommendCard> recommends;
  final List<String> personas;
  final Color primary;
  final bool isDark;
  final Color textPrimary;
  final Color textSecondary;
  final ValueChanged<_RecommendCard> onTap;

  const _RecommendSection({
    required this.recommends,
    required this.personas,
    required this.primary,
    required this.isDark,
    required this.textPrimary,
    required this.textSecondary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section 标题
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text('✨', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 7),
              Text(
                '为你推荐',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              if (personas.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '基于你的画像',
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

        // 横向可滑卡片列表（右侧 peek）
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            physics: const BouncingScrollPhysics(),
            itemCount: recommends.length,
            itemBuilder: (_, i) {
              final card = recommends[i];
              Color accent;
              try {
                accent = Color(
                    int.parse('FF${card.colorHex}', radix: 16));
              } catch (_) {
                accent = primary;
              }
              return _RecommendCardWidget(
                card: card,
                accent: accent,
                isDark: isDark,
                onTap: () => onTap(card),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _RecommendCardWidget extends StatelessWidget {
  final _RecommendCard card;
  final Color accent;
  final bool isDark;
  final VoidCallback onTap;

  const _RecommendCardWidget({
    required this.card,
    required this.accent,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.surfaceDark : Colors.white;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 152,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.black.withValues(alpha: 0.06),
            width: 0.7,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // emoji 徽章
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: isDark ? 0.18 : 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child:
                    Text(card.emoji, style: const TextStyle(fontSize: 20)),
              ),
            ),
            const Spacer(),
            Text(
              card.title,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1A1410),
                height: 1.25,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              card.subtitle,
              style: TextStyle(
                fontSize: 11,
                color: isDark
                    ? AppColors.textTertiaryDark
                    : const Color(0xFFAAAAAA),
                height: 1.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  模板库 Section 标题
// ─────────────────────────────────────────────────────────────────

class _TemplateSectionHeader extends StatelessWidget {
  final bool isDark;
  final Color textPrimary;

  const _TemplateSectionHeader({
    required this.isDark,
    required this.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          const Text('📋', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 7),
          Text(
            '模板库',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${TemplateData.all.length} 个场景模板',
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
//  模板分类 Tab 横向滚动
// ─────────────────────────────────────────────────────────────────

class _TemplateCategoryBar extends StatelessWidget {
  final TemplateCategory selected;
  final Color primary;
  final bool isDark;
  final ValueChanged<TemplateCategory> onChanged;

  const _TemplateCategoryBar({
    required this.selected,
    required this.primary,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // 全部 + 有模板数据的分类
    final usedCategories = [TemplateCategory.all] +
        TemplateCategory.values
            .where((c) =>
                c != TemplateCategory.all &&
                TemplateData.all.any((t) => t.category == c))
            .toList();

    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: usedCategories.length,
        itemBuilder: (_, i) {
          final cat = usedCategories[i];
          final isActive = cat == selected;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onChanged(cat);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isActive
                    ? primary
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.07)
                        : Colors.black.withValues(alpha: 0.05)),
                borderRadius: BorderRadius.circular(20),
                border: isActive
                    ? null
                    : Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.07),
                        width: 0.7,
                      ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (cat != TemplateCategory.all) ...[
                    Text(cat.emoji, style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 5),
                  ],
                  Text(
                    cat.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isActive ? FontWeight.w700 : FontWeight.w500,
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
//  模板网格卡片
// ─────────────────────────────────────────────────────────────────

class _TemplateGridCard extends StatelessWidget {
  final ChecklistTemplate template;
  final Color primary;
  final bool isDark;
  final VoidCallback onTap;

  const _TemplateGridCard({
    required this.template,
    required this.primary,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color accent;
    try {
      accent = Color(
          int.parse('FF${template.colorHex}', radix: 16));
    } catch (_) {
      accent = primary;
    }
    final cardBg = isDark ? AppColors.surfaceDark : Colors.white;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.black.withValues(alpha: 0.05),
            width: 0.7,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // emoji 徽章
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: isDark ? 0.15 : 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(template.emoji,
                    style: const TextStyle(fontSize: 22)),
              ),
            ),
            const Spacer(),
            Text(
              template.title,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1A1410),
                height: 1.25,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              '${template.items.length} 个条目',
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
//  模板预览底部弹窗
// ─────────────────────────────────────────────────────────────────

class _TemplatePreviewSheet extends StatelessWidget {
  final ChecklistTemplate template;
  final VoidCallback onUse;

  const _TemplatePreviewSheet({
    required this.template,
    required this.onUse,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color accent;
    try {
      accent = Color(int.parse('FF${template.colorHex}', radix: 16));
    } catch (_) {
      accent = Theme.of(context).primaryColor;
    }
    final sheetBg =
        isDark ? const Color(0xFF1A1625) : Colors.white;

    return Container(
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖拽把手
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color:
                  isDark ? Colors.white24 : const Color(0xFFDDDDDD),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 标题行
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(template.emoji,
                        style: const TextStyle(fontSize: 24)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        template.title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1A1410),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        template.description,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : const Color(0xFF888888),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 条目预览列表
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: template.items.length,
              itemBuilder: (_, i) {
                final item = template.items[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark
                                ? Colors.white24
                                : const Color(0xFFCCCCCC),
                            width: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.text,
                          style: TextStyle(
                            fontSize: 13.5,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.85)
                                : const Color(0xFF333333),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // 使用按钮
          Padding(
            padding: EdgeInsets.fromLTRB(
                20, 12, 20, 20 + MediaQuery.of(context).padding.bottom),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: onUse,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text(
                  '用这个模板',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
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
//  AI 生成底部弹窗（带流式输出）
// ─────────────────────────────────────────────────────────────────

enum _GenPhase { idle, generating, done, error }

class _AiDiscoverGenerateSheet extends StatefulWidget {
  final String initialPrompt;
  final ValueChanged<Checklist> onCreated;

  const _AiDiscoverGenerateSheet({
    required this.initialPrompt,
    required this.onCreated,
  });

  @override
  State<_AiDiscoverGenerateSheet> createState() =>
      _AiDiscoverGenerateSheetState();
}

class _AiDiscoverGenerateSheetState
    extends State<_AiDiscoverGenerateSheet> {
  late TextEditingController _ctrl;
  _GenPhase _phase = _GenPhase.idle;
  String _generatedTitle = '';
  String _generatedEmoji = '📋';
  final List<String> _generatedItems = [];
  String _streamingCurrentItem = '';
  String _errorMsg = '';
  StreamSubscription<String>? _sub;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialPrompt);
    // 有初始词时自动触发生成
    if (widget.initialPrompt.isNotEmpty) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _generate());
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final intent = _ctrl.text.trim();
    if (intent.isEmpty) return;
    HapticFeedback.mediumImpact();

    // ── 三层用户画像注入 ──────────────────────────────────────────
    final checklistProvider = context.read<ChecklistProvider>();
    final userProfileProvider = context.read<UserProfileProvider>();
    final allTitles =
        checklistProvider.checklists.map((c) => c.title).toList();
    final UserProfile userProfile = userProfileProvider.profile;
    final personaCtx =
        userProfile.buildAiPersonaContext(checklistTitles: allTitles);

    final basePrompt = '''你是一个清单生成专家。用户描述一个场景或需求，你输出一份实用的清单。

输出格式（严格按此格式，不要输出其他内容）：
第一行：emoji空格标题（例如：🧳 西藏自驾游清单）
后续每行：一个条目（直接写条目文本，不加序号、不加-、不加•）

要求：
- 条目数量 10-20 个，实用不冗余
- 每个条目一行，简洁具体
- 不要分组，不要标题行，不要空行
- 不要解释说明''';

    final systemPrompt = personaCtx.isNotEmpty
        ? '$basePrompt\n\n---\n【关于这个用户】\n$personaCtx'
        : basePrompt;

    setState(() {
      _phase = _GenPhase.generating;
      _generatedTitle = '';
      _generatedEmoji = '📋';
      _generatedItems.clear();
      _streamingCurrentItem = '';
      _errorMsg = '';
    });

    final buffer = StringBuffer();

    try {
      final stream = AiService.instance.chatStream(
        systemPrompt: systemPrompt,
        userMessage: '帮我生成一份清单：$intent',
      );

      _sub = stream.listen(
        (chunk) {
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
                    newEmoji = trimmed.substring(0, spaceIdx);
                    newTitle = trimmed.substring(spaceIdx + 1);
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
        },
        onDone: () {
          if (!mounted) return;
          // 把最后一条流式词也 commit
          if (_streamingCurrentItem.isNotEmpty) {
            _generatedItems.add(_streamingCurrentItem);
          }
          setState(() {
            _phase = _GenPhase.done;
            _streamingCurrentItem = '';
          });
        },
        onError: (e) {
          if (!mounted) return;
          setState(() {
            _phase = _GenPhase.error;
            _errorMsg = e.toString();
          });
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _GenPhase.error;
        _errorMsg = e.toString();
      });
    }
  }

  Future<void> _useGenerated() async {
    if (_generatedItems.isEmpty) return;
    HapticFeedback.mediumImpact();
    final provider = context.read<ChecklistProvider>();
    final title = _generatedTitle.isNotEmpty ? _generatedTitle : _ctrl.text.trim();
    final items = _generatedItems
        .asMap()
        .entries
        .map((e) => ChecklistItem(
              id: const Uuid().v4(),
              title: e.value,
              sortOrder: e.key,
              createdAt: DateTime.now(),
            ))
        .toList();
    final checklist = await provider.addChecklist(
      title: title,
      emoji: _generatedEmoji,
      colorHex: '#339AF0',
      scene: ChecklistScene.life,
      function: ChecklistFunction.checklist,
      style: ChecklistStyle.simple,
      checklistType: ChecklistType.structural,
      items: items,
    );
    if (!mounted) return;
    widget.onCreated(checklist);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? WeeklyTheme.getDarkPalette().primary : WeeklyTheme.getLightPalette().primary;
    final sheetBg = isDark ? const Color(0xFF1A1625) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1A1410);
    final textSec = isDark ? AppColors.textSecondaryDark : const Color(0xFF888888);
    final isGenerating = _phase == _GenPhase.generating;
    final isDone = _phase == _GenPhase.done;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖拽把手
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : const Color(0xFFDDDDDD),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 标题
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                const Text('🤖', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(
                  'AI 生成清单',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
          ),
          // 搜索输入栏
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.07)
                          : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 12),
                        Icon(Icons.edit_note_rounded,
                            size: 18,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : const Color(0xFF888888)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _ctrl,
                            style: TextStyle(
                              fontSize: 14,
                              color: textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: '描述你想要的清单...',
                              hintStyle: TextStyle(
                                fontSize: 14,
                                color: isDark
                                    ? const Color(0xFF666666)
                                    : const Color(0xFFAAAAAA),
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              contentPadding: EdgeInsets.zero,
                              isDense: true,
                            ),
                            onSubmitted: (_) => _generate(),
                            textInputAction: TextInputAction.go,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: isGenerating ? null : _generate,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isGenerating
                          ? primary.withValues(alpha: 0.4)
                          : primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: isGenerating
                        ? const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : const Icon(Icons.auto_awesome_rounded,
                            size: 20, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // ── 结果区 ──────────────────────────────────────────────────
          Expanded(
            child: _buildResultArea(
                isDark, primary, textPrimary, textSec, isDone, isGenerating),
          ),
          // ── 底部按钮 ─────────────────────────────────────────────────
          if (isDone && _generatedItems.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(
                  16, 10, 16, 16 + MediaQuery.of(context).padding.bottom),
              child: Row(
                children: [
                  // 重新生成
                  Expanded(
                    flex: 1,
                    child: GestureDetector(
                      onTap: _generate,
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.07)
                              : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            '重新生成',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white70
                                  : const Color(0xFF555555),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 使用
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: _useGenerated,
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              primary,
                              primary.withValues(alpha: 0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: primary.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            '用这份清单',
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
            )
          else if (_phase == _GenPhase.idle)
            Padding(
              padding: EdgeInsets.fromLTRB(
                  16, 8, 16, 16 + MediaQuery.of(context).padding.bottom),
              child: const SizedBox.shrink(),
            )
          else
            SizedBox(height: 20 + MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildResultArea(bool isDark, Color primary, Color textPrimary,
      Color textSec, bool isDone, bool isGenerating) {
    if (_phase == _GenPhase.idle) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome_outlined,
                size: 36,
                color: isDark ? Colors.white24 : const Color(0xFFCCCCCC)),
            const SizedBox(height: 12),
            Text(
              '输入想法，AI 来帮你起草清单',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white38 : const Color(0xFFBBBBBB),
              ),
            ),
          ],
        ),
      );
    }

    if (_phase == _GenPhase.error) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('😅', style: TextStyle(fontSize: 32)),
            const SizedBox(height: 12),
            Text(
              '生成失败，请重试',
              style: TextStyle(fontSize: 14, color: textSec),
            ),
            if (_errorMsg.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
                child: Text(
                  _errorMsg,
                  style: TextStyle(fontSize: 11, color: textSec),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      );
    }

    // 生成中 or 完成 —— 显示结果列表
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      children: [
        // 清单标题
        if (_generatedTitle.isNotEmpty || isGenerating) ...[
          Row(
            children: [
              if (_generatedEmoji.isNotEmpty)
                Text(_generatedEmoji,
                    style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _generatedTitle.isNotEmpty
                      ? _generatedTitle
                      : '生成中...',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
        ],
        // 条目列表
        ..._generatedItems.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDone
                              ? primary.withValues(alpha: 0.5)
                              : (isDark
                                  ? Colors.white24
                                  : const Color(0xFFCCCCCC)),
                          width: 1.4,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.85)
                            : const Color(0xFF333333),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            )),
        // 正在流式输出的最后一条
        if (_streamingCurrentItem.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: primary.withValues(alpha: 0.4),
                      width: 1.4,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _streamingCurrentItem,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.5)
                          : const Color(0xFFAAAAAA),
                      height: 1.4,
                    ),
                  ),
                ),
                // 打字光标动效
                SizedBox(
                  width: 12,
                  child: Text(
                    '▌',
                    style: TextStyle(
                      fontSize: 14,
                      color: primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }
}
