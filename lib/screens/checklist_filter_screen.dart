import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/checklist.dart';
import '../models/checklist_template.dart';
import '../data/template_data.dart';
import '../providers/checklist_provider.dart';
import '../theme/app_theme.dart';
import 'checklist_detail_screen.dart';
import 'checklist_discover_screen.dart';

// ─────────────────────────────────────────────────────────────────
//  ChecklistFilterScreen —— 全维度筛选页
//
//  【筛选维度】
//  1. 按清单性质（最核心）— ChecklistNature 10分类
//  2. 按我的角色            — LifeRole 枚举
//  3. 按生活场景            — LifeScene 枚举
//  4. 按时间属性            — TimeFilter
//  5. 按重复周期            — RepeatType
//  6. 按完成状态            — ChecklistStatus
//  7. 按我的标签            — 动态 userTags
//
//  【结果页】
//  · 上方：过滤后的已有清单列表
//  · 下方：「这个场景下你可能还需要」— 推荐模板区
// ─────────────────────────────────────────────────────────────────

// ── 清单性质枚举（核心维度）──────────────────────────────────────
enum ChecklistNature {
  dailyRoutine(
      'daily_routine', '日常惯例', '⚡', '每天/每周重复的仪式与习惯', Color(0xFFFF8C42)),
  majorEvent(
      'major_event', '重大事件', '🎯', '婚礼、搬家、入职等人生节点', Color(0xFF5C7CFA)),
  periodicMaintenance('periodic_maintenance', '周期维护', '🔄',
      '每月/每季定期才做的重要事项', Color(0xFF20C997)),
  emergencyKit(
      'emergency_kit', '应急备忘', '🛡️', '平时封存，突发时一键调用', Color(0xFFE03131)),
  shoppingList(
      'shopping_list', '采购备货', '🛒', '要去买、要备齐的物品清单', Color(0xFFFAB005)),
  growthLearning('growth_learning', '成长学习', '🌱', '技能目标、学习计划、职业发展',
      Color(0xFF2A9D6E)),
  inspirationCollection('inspiration_collection', '灵感收藏', '✨',
      '书单影单、愿望清单、灵感备忘', Color(0xFFCC5DE8)),
  emotionalRestore('emotional_restore', '情绪修复', '🧠',
      '不为完成任务，只为恢复精神能量', Color(0xFF339AF0)),
  notToDoList('not_to_do', '减法边界', '🚫', '不做什么清单、时间与精力边界',
      Color(0xFF868E96)),
  socialRelations('social_relations', '人际温度', '👥', '保持社交温度、管理重要关系',
      Color(0xFFD44470));

  const ChecklistNature(
      this.value, this.label, this.emoji, this.description, this.color);
  final String value;
  final String label;
  final String emoji;
  final String description;
  final Color color;
}

// ── 我的角色枚举 ───────────────────────────────────────────────────
enum LifeRole {
  officeWorker('office_worker', '职场人', '👔'),
  student('student', '学生', '📚'),
  parent('parent', '父母', '👶'),
  entrepreneur('entrepreneur', '创业者', '🚀'),
  freelancer('freelancer', '独立工作者', '🧑‍💻'),
  caregiver('caregiver', '照护者', '🤝'),
  petOwner('pet_owner', '宠主', '🐾'),
  propertyOwner('property_owner', '置业者', '🏡'),
  traveler('traveler', '旅行者', '✈️'),
  creator('creator', '创作者', '🎨');

  const LifeRole(this.value, this.label, this.emoji);
  final String value;
  final String label;
  final String emoji;
}

// ── 生活场景枚举 ───────────────────────────────────────────────────
enum LifeScene {
  travel('travel', '出行旅游', '✈️'),
  work('work', '工作办公', '💼'),
  home('home', '居家生活', '🏠'),
  health('health', '健康就医', '🏥'),
  shopping('shopping', '消费采购', '🛒'),
  finance('finance', '财务理财', '💰'),
  social('social', '社交活动', '🎉'),
  study('study', '学习成长', '📖'),
  career('career', '职业发展', '🎯'),
  startup('startup', '创业经营', '🚀'),
  baby('baby', '育儿教育', '👶'),
  property('property', '置业装修', '🏡'),
  mind('mind', '心理情绪', '🧠'),
  digital('digital', '数字生活', '💻'),
  pet('pet', '宠物护理', '🐾');

  const LifeScene(this.value, this.label, this.emoji);
  final String value;
  final String label;
  final String emoji;
}

// ── 时间属性枚举 ───────────────────────────────────────────────────
enum TimeFilter {
  today('today', '今日'),
  thisWeek('this_week', '本周'),
  overdue('overdue', '已逾期'),
  dueSoon('due_soon', '即将到期'),
  noDate('no_date', '无日期');

  const TimeFilter(this.value, this.label);
  final String value;
  final String label;
}

// ─────────────────────────────────────────────────────────────────
//  筛选状态模型
// ─────────────────────────────────────────────────────────────────
class ChecklistFilterState {
  final Set<ChecklistNature> natures;
  final Set<LifeRole> roles;
  final Set<LifeScene> scenes;
  final Set<TimeFilter> timeFilters;
  final Set<RepeatType> repeatTypes;
  final Set<ChecklistStatus> statuses;
  final Set<String> userTags;

  const ChecklistFilterState({
    this.natures = const {},
    this.roles = const {},
    this.scenes = const {},
    this.timeFilters = const {},
    this.repeatTypes = const {},
    this.statuses = const {},
    this.userTags = const {},
  });

  bool get isEmpty =>
      natures.isEmpty &&
      roles.isEmpty &&
      scenes.isEmpty &&
      timeFilters.isEmpty &&
      repeatTypes.isEmpty &&
      statuses.isEmpty &&
      userTags.isEmpty;

  int get activeCount =>
      natures.length +
      roles.length +
      scenes.length +
      timeFilters.length +
      repeatTypes.length +
      statuses.length +
      userTags.length;

  ChecklistFilterState copyWith({
    Set<ChecklistNature>? natures,
    Set<LifeRole>? roles,
    Set<LifeScene>? scenes,
    Set<TimeFilter>? timeFilters,
    Set<RepeatType>? repeatTypes,
    Set<ChecklistStatus>? statuses,
    Set<String>? userTags,
  }) {
    return ChecklistFilterState(
      natures: natures ?? this.natures,
      roles: roles ?? this.roles,
      scenes: scenes ?? this.scenes,
      timeFilters: timeFilters ?? this.timeFilters,
      repeatTypes: repeatTypes ?? this.repeatTypes,
      statuses: statuses ?? this.statuses,
      userTags: userTags ?? this.userTags,
    );
  }

  ChecklistFilterState clear() => const ChecklistFilterState();
}

// ─────────────────────────────────────────────────────────────────
//  过滤逻辑
// ─────────────────────────────────────────────────────────────────
List<Checklist> applyChecklistFilter(
    List<Checklist> all, ChecklistFilterState filter) {
  if (filter.isEmpty) return all;
  return all.where((c) {
    // 按时间属性
    if (filter.timeFilters.isNotEmpty) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final matched = filter.timeFilters.any((tf) {
        switch (tf) {
          case TimeFilter.today:
            return c.isToday;
          case TimeFilter.thisWeek:
            if (c.scheduledDate == null) return false;
            final sd = DateTime(c.scheduledDate!.year,
                c.scheduledDate!.month, c.scheduledDate!.day);
            return !sd.isBefore(today) &&
                sd.isBefore(today.add(const Duration(days: 7)));
          case TimeFilter.overdue:
            return c.isOverdue;
          case TimeFilter.dueSoon:
            final days = c.daysUntilDue;
            return days != null && days >= 0 && days <= 7;
          case TimeFilter.noDate:
            return c.scheduledDate == null && c.dueDate == null;
        }
      });
      if (!matched) return false;
    }
    // 按重复周期
    if (filter.repeatTypes.isNotEmpty) {
      if (!filter.repeatTypes.contains(c.repeatType)) return false;
    }
    // 按完成状态
    if (filter.statuses.isNotEmpty) {
      if (!filter.statuses.contains(c.status)) return false;
    }
    // 按用户标签
    if (filter.userTags.isNotEmpty) {
      final cLabels = c.allTagLabels.toSet();
      if (!filter.userTags.any((t) => cLabels.contains(t))) return false;
    }
    // 按生活场景
    if (filter.scenes.isNotEmpty) {
      final tagLabels =
          c.allTagLabels.map((t) => t.toLowerCase()).toSet();
      final matched = filter.scenes.any((scene) {
        final sceneMatch = switch (scene) {
          LifeScene.work => c.scene == ChecklistScene.work,
          LifeScene.study => c.scene == ChecklistScene.study,
          LifeScene.shopping => c.scene == ChecklistScene.shopping,
          _ => c.scene == ChecklistScene.life ||
              c.scene == ChecklistScene.general,
        };
        if (sceneMatch) return true;
        return _sceneTagKeywords(scene)
            .any((kw) => tagLabels.any((tl) => tl.contains(kw)));
      });
      if (!matched) return false;
    }
    // 按我的角色
    if (filter.roles.isNotEmpty) {
      final tagLabels =
          c.allTagLabels.map((t) => t.toLowerCase()).toSet();
      final matched = filter.roles.any((role) => _roleTagKeywords(role)
          .any((kw) => tagLabels.any((tl) => tl.contains(kw))));
      if (!matched) return false;
    }
    // 按清单性质
    if (filter.natures.isNotEmpty) {
      final tagLabels =
          c.allTagLabels.map((t) => t.toLowerCase()).toSet();
      final matched =
          filter.natures.any((n) => _natureMatches(c, n, tagLabels));
      if (!matched) return false;
    }
    return true;
  }).toList();
}

bool _natureMatches(
    Checklist c, ChecklistNature nature, Set<String> tagLabels) {
  switch (nature) {
    case ChecklistNature.dailyRoutine:
      return c.repeatType != RepeatType.none ||
          tagLabels.any((t) =>
              t.contains('习惯') ||
              t.contains('晨间') ||
              t.contains('日常') ||
              t.contains('routine'));
    case ChecklistNature.majorEvent:
      return tagLabels.any((t) =>
          t.contains('旅行') ||
          t.contains('婚礼') ||
          t.contains('搬家') ||
          t.contains('入职') ||
          t.contains('活动'));
    case ChecklistNature.periodicMaintenance:
      return tagLabels.any((t) =>
          t.contains('维护') ||
          t.contains('保养') ||
          t.contains('定期') ||
          t.contains('月度') ||
          t.contains('季度'));
    case ChecklistNature.emergencyKit:
      return tagLabels.any((t) =>
          t.contains('应急') ||
          t.contains('急救') ||
          t.contains('紧急') ||
          t.contains('备用'));
    case ChecklistNature.shoppingList:
      return c.function == ChecklistFunction.purchase ||
          c.scene == ChecklistScene.shopping ||
          tagLabels.any((t) =>
              t.contains('购物') || t.contains('采购') || t.contains('买'));
    case ChecklistNature.growthLearning:
      return c.scene == ChecklistScene.study ||
          tagLabels.any((t) =>
              t.contains('学习') ||
              t.contains('成长') ||
              t.contains('技能') ||
              t.contains('职业'));
    case ChecklistNature.inspirationCollection:
      return tagLabels.any((t) =>
          t.contains('书单') ||
          t.contains('影单') ||
          t.contains('愿望') ||
          t.contains('灵感') ||
          t.contains('收藏') ||
          t.contains('bucket'));
    case ChecklistNature.emotionalRestore:
      return tagLabels.any((t) =>
          t.contains('情绪') ||
          t.contains('心理') ||
          t.contains('减压') ||
          t.contains('感恩') ||
          t.contains('冥想'));
    case ChecklistNature.notToDoList:
      return tagLabels.any((t) =>
          t.contains('不做') ||
          t.contains('边界') ||
          t.contains('减法') ||
          t.contains('戒断'));
    case ChecklistNature.socialRelations:
      return tagLabels.any((t) =>
          t.contains('人际') ||
          t.contains('社交') ||
          t.contains('礼物') ||
          t.contains('联络') ||
          t.contains('朋友'));
  }
}

List<String> _sceneTagKeywords(LifeScene scene) {
  return switch (scene) {
    LifeScene.travel => ['旅行', '出行', '出差', '露营', '旅游'],
    LifeScene.work => ['工作', '会议', '项目', '职场', '办公'],
    LifeScene.home => ['家居', '家务', '居家', '生活', '清洁'],
    LifeScene.health => ['健康', '就医', '医疗', '健身', '运动'],
    LifeScene.shopping => ['购物', '采购', '消费', '买'],
    LifeScene.finance => ['财务', '理财', '记账', '账单', '投资'],
    LifeScene.social => ['社交', '聚会', '活动', '派对'],
    LifeScene.study => ['学习', '读书', '备考', '课程'],
    LifeScene.career => ['职业', '求职', '简历', '面试', '晋升'],
    LifeScene.startup => ['创业', '创始', '融资', '产品'],
    LifeScene.baby => ['育儿', '宝宝', '孕产', '儿童'],
    LifeScene.property => ['置业', '装修', '租房', '买房', '搬家'],
    LifeScene.mind => ['心理', '情绪', '减压', '冥想', '正念'],
    LifeScene.digital => ['数字', '数据', 'app', '科技', '备份'],
    LifeScene.pet => ['宠物', '猫', '狗', '养宠'],
  };
}

List<String> _roleTagKeywords(LifeRole role) {
  return switch (role) {
    LifeRole.officeWorker => ['工作', '职场', '上班', '会议', '同事'],
    LifeRole.student => ['学习', '学生', '备考', '作业', '考试'],
    LifeRole.parent => ['育儿', '宝宝', '孩子', '家长', '父母'],
    LifeRole.entrepreneur => ['创业', '融资', '产品', '团队', '市场'],
    LifeRole.freelancer => ['自由', '接单', '独立', '远程', '客户'],
    LifeRole.caregiver => ['照护', '老人', '陪护', '就医', '康复'],
    LifeRole.petOwner => ['宠物', '猫', '狗', '喂食', '遛狗'],
    LifeRole.propertyOwner => ['置业', '装修', '买房', '物业', '维修'],
    LifeRole.traveler => ['旅行', '旅游', '出行', '机票', '签证'],
    LifeRole.creator => ['创作', '写作', '拍摄', '设计', '内容'],
  };
}

// ─────────────────────────────────────────────────────────────────
//  推荐引擎
// ─────────────────────────────────────────────────────────────────
List<ChecklistTemplate> buildRecommendations(ChecklistFilterState filter) {
  final all = TemplateData.all;

  Set<TemplateCategory> cats = {};

  for (final n in filter.natures) {
    cats.addAll(_natureToCats(n));
  }
  for (final s in filter.scenes) {
    cats.addAll(_sceneToCats(s));
  }
  for (final r in filter.roles) {
    cats.addAll(_roleToCats(r));
  }

  if (cats.isEmpty) {
    return all.where((t) => t.isFeatured).take(6).toList();
  }

  final result = <ChecklistTemplate>[];
  final seen = <String>{};
  for (final t in all) {
    if (cats.contains(t.category) && seen.add(t.id)) {
      result.add(t);
      if (result.length >= 6) break;
    }
  }
  return result;
}

List<TemplateCategory> _natureToCats(ChecklistNature n) => switch (n) {
      ChecklistNature.dailyRoutine => [
          TemplateCategory.life,
          TemplateCategory.health
        ],
      ChecklistNature.majorEvent => [
          TemplateCategory.travel,
          TemplateCategory.event,
          TemplateCategory.property
        ],
      ChecklistNature.periodicMaintenance => [
          TemplateCategory.life,
          TemplateCategory.finance,
          TemplateCategory.health
        ],
      ChecklistNature.emergencyKit => [
          TemplateCategory.health,
          TemplateCategory.life
        ],
      ChecklistNature.shoppingList => [
          TemplateCategory.shopping,
          TemplateCategory.travel
        ],
      ChecklistNature.growthLearning => [
          TemplateCategory.study,
          TemplateCategory.career,
          TemplateCategory.startup
        ],
      ChecklistNature.inspirationCollection => [
          TemplateCategory.study,
          TemplateCategory.travel,
          TemplateCategory.mind
        ],
      ChecklistNature.emotionalRestore => [
          TemplateCategory.mind,
          TemplateCategory.health,
          TemplateCategory.life
        ],
      ChecklistNature.notToDoList => [
          TemplateCategory.mind,
          TemplateCategory.work
        ],
      ChecklistNature.socialRelations => [
          TemplateCategory.event,
          TemplateCategory.life
        ],
    };

List<TemplateCategory> _sceneToCats(LifeScene s) => switch (s) {
      LifeScene.travel => [TemplateCategory.travel],
      LifeScene.work => [TemplateCategory.work],
      LifeScene.home => [TemplateCategory.life, TemplateCategory.property],
      LifeScene.health => [TemplateCategory.health],
      LifeScene.shopping => [TemplateCategory.shopping],
      LifeScene.finance => [TemplateCategory.finance],
      LifeScene.social => [TemplateCategory.event],
      LifeScene.study => [TemplateCategory.study],
      LifeScene.career => [TemplateCategory.career],
      LifeScene.startup => [TemplateCategory.startup],
      LifeScene.baby => [TemplateCategory.baby],
      LifeScene.property => [TemplateCategory.property],
      LifeScene.mind => [TemplateCategory.mind],
      LifeScene.digital => [TemplateCategory.life],
      LifeScene.pet => [TemplateCategory.pet],
    };

List<TemplateCategory> _roleToCats(LifeRole r) => switch (r) {
      LifeRole.officeWorker => [TemplateCategory.work, TemplateCategory.career],
      LifeRole.student => [TemplateCategory.study, TemplateCategory.career],
      LifeRole.parent => [TemplateCategory.baby, TemplateCategory.life],
      LifeRole.entrepreneur => [
          TemplateCategory.startup,
          TemplateCategory.work
        ],
      LifeRole.freelancer => [TemplateCategory.work, TemplateCategory.career],
      LifeRole.caregiver => [TemplateCategory.health, TemplateCategory.life],
      LifeRole.petOwner => [TemplateCategory.pet],
      LifeRole.propertyOwner => [
          TemplateCategory.property,
          TemplateCategory.life
        ],
      LifeRole.traveler => [TemplateCategory.travel],
      LifeRole.creator => [TemplateCategory.startup, TemplateCategory.career],
    };

// ─────────────────────────────────────────────────────────────────
//  ChecklistFilterScreen —— 筛选主屏
// ─────────────────────────────────────────────────────────────────

class ChecklistFilterScreen extends StatefulWidget {
  final ChecklistFilterState? initialFilter;

  const ChecklistFilterScreen({super.key, this.initialFilter});

  @override
  State<ChecklistFilterScreen> createState() =>
      _ChecklistFilterScreenState();
}

class _ChecklistFilterScreenState extends State<ChecklistFilterScreen> {
  late ChecklistFilterState _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter ?? const ChecklistFilterState();
  }

  void _toggle<T>(T item, Set<T> set, void Function(Set<T>) update) {
    final next = Set<T>.from(set);
    if (next.contains(item)) {
      next.remove(item);
    } else {
      next.add(item);
    }
    setState(() => update(next));
  }

  void _showResults(BuildContext context) {
    if (_filter.isEmpty) return;
    HapticFeedback.mediumImpact();
    final provider = context.read<ChecklistProvider>();
    final all = provider.checklists
        .where((c) => c.status != ChecklistStatus.archived)
        .toList();
    final filtered = applyChecklistFilter(all, _filter);
    final recommended = buildRecommendations(_filter);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChecklistFilterResultScreen(
          filter: _filter,
          results: filtered,
          recommended: recommended,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = WeeklyTheme.getLightPalette();
    final primary = isDark ? AppColors.darkPrimary : palette.primary;
    final bg =
        isDark ? AppColors.backgroundDark : const Color(0xFFF8F6F3);
    final provider = context.read<ChecklistProvider>();

    // 动态用户标签
    final allUserTags = <String>{};
    for (final c in provider.checklists) {
      allUserTags.addAll(c.userTags.map((t) => t.label));
    }

    // 命中数量
    final all = provider.checklists
        .where((c) => c.status != ChecklistStatus.archived)
        .toList();
    final hitCount = applyChecklistFilter(all, _filter).length;

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          // ── 顶部导航栏 ────────────────────────────────────────
          _FilterAppBar(
            isDark: isDark,
            primary: primary,
            activeCount: _filter.activeCount,
            onClear: () => setState(() => _filter = _filter.clear()),
          ),

          // ── 筛选面板滚动内容 ──────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              children: [
                const SizedBox(height: 8),

                // 1. 按清单性质（最核心）
                _FilterSection(
                  title: '按清单性质',
                  subtitle: '这张清单，在你的生活里扮演什么角色？',
                  isDark: isDark,
                  child: _NatureGrid(
                    selected: _filter.natures,
                    isDark: isDark,
                    onToggle: (n) => _toggle(n, _filter.natures,
                        (s) => _filter = _filter.copyWith(natures: s)),
                  ),
                ),

                // 2. 按我的角色
                _FilterSection(
                  title: '按我的角色',
                  subtitle: '你现在主要以哪种身份在使用清单？',
                  isDark: isDark,
                  child: _UniformChipGrid(
                    cols: 3,
                    items: LifeRole.values
                        .map((r) => _FilterChip(
                              label: '${r.emoji} ${r.label}',
                              isSelected: _filter.roles.contains(r),
                              activeColor: primary,
                              isDark: isDark,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                _toggle(r, _filter.roles, (s) =>
                                    _filter = _filter.copyWith(roles: s));
                              },
                            ))
                        .toList(),
                  ),
                ),

                // 3. 按生活场景
                _FilterSection(
                  title: '按生活场景',
                  subtitle: '你现在处于哪个生活情境中？',
                  isDark: isDark,
                  child: _UniformChipGrid(
                    cols: 3,
                    items: LifeScene.values
                        .map((s) => _FilterChip(
                              label: '${s.emoji} ${s.label}',
                              isSelected: _filter.scenes.contains(s),
                              activeColor: primary,
                              isDark: isDark,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                _toggle(s, _filter.scenes, (set) =>
                                    _filter = _filter.copyWith(scenes: set));
                              },
                            ))
                        .toList(),
                  ),
                ),

                // 4~6. 时间 + 重复 + 状态 合并为一个 section，减少滚动量
                _FilterSection(
                  title: '按时间 · 周期 · 状态',
                  subtitle: '细化时间范围、重复节奏和当前进展',
                  isDark: isDark,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SubSectionLabel(label: '时间属性', isDark: isDark),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: TimeFilter.values
                            .map((tf) => _FilterChip(
                                  label: tf.label,
                                  isSelected: _filter.timeFilters.contains(tf),
                                  activeColor: primary,
                                  isDark: isDark,
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    _toggle(tf, _filter.timeFilters, (set) =>
                                        _filter = _filter.copyWith(timeFilters: set));
                                  },
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 12),
                      _SubSectionLabel(label: '重复周期', isDark: isDark),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: RepeatType.values
                            .map((rt) => _FilterChip(
                                  label: rt.label,
                                  isSelected: _filter.repeatTypes.contains(rt),
                                  activeColor: primary,
                                  isDark: isDark,
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    _toggle(rt, _filter.repeatTypes, (set) =>
                                        _filter = _filter.copyWith(repeatTypes: set));
                                  },
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 12),
                      _SubSectionLabel(label: '完成状态', isDark: isDark),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ChecklistStatus.values
                            .map((s) => _FilterChip(
                                  label: s.label,
                                  isSelected: _filter.statuses.contains(s),
                                  activeColor: primary,
                                  isDark: isDark,
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    _toggle(s, _filter.statuses, (set) =>
                                        _filter = _filter.copyWith(statuses: set));
                                  },
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),

                // 7. 按我的标签（动态）
                if (allUserTags.isNotEmpty)
                  _FilterSection(
                    title: '按我的标签',
                    subtitle: '你手动打过的标签',
                    isDark: isDark,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: allUserTags
                          .toList()
                          .map((tag) => _FilterChip(
                                label: tag,
                                isSelected: _filter.userTags.contains(tag),
                                activeColor: primary,
                                isDark: isDark,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  _toggle(tag, _filter.userTags, (set) =>
                                      _filter = _filter.copyWith(userTags: set));
                                },
                              ))
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),

          // ── 底部确认按钮 ──────────────────────────────────────
          _FilterBottomBar(
            hitCount: hitCount,
            isFilterEmpty: _filter.isEmpty,
            primary: primary,
            isDark: isDark,
            onConfirm: () => _showResults(context),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  顶部导航栏
// ─────────────────────────────────────────────────────────────────
class _FilterAppBar extends StatelessWidget {
  final bool isDark;
  final Color primary;
  final int activeCount;
  final VoidCallback onClear;

  const _FilterAppBar({
    required this.isDark,
    required this.primary,
    required this.activeCount,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        isDark ? Colors.white : const Color(0xFF1A1410);
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : const Color(0xFF888888);

    return Container(
      color: isDark
          ? const Color(0xFF141414)
          : const Color(0xFFF8F6F3),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 14,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  size: 16, color: textSecondary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '筛选清单',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                ),
                if (activeCount > 0)
                  Text(
                    '已选 $activeCount 个条件',
                    style: TextStyle(
                      fontSize: 12,
                      color: primary,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                else
                  Text(
                    '从多个维度精准找到你需要的清单',
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
              ],
            ),
          ),
          if (activeCount > 0)
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onClear();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '重置',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
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
//  筛选分区容器
// ─────────────────────────────────────────────────────────────────
class _FilterSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isDark;
  final Widget child;

  const _FilterSection({
    required this.title,
    required this.subtitle,
    required this.isDark,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        isDark ? Colors.white : const Color(0xFF1A1410);
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : const Color(0xFF888888);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  清单性质网格（2列，竖排卡片，描述完整显示）
// ─────────────────────────────────────────────────────────────────
class _NatureGrid extends StatelessWidget {
  final Set<ChecklistNature> selected;
  final ValueChanged<ChecklistNature> onToggle;
  final bool isDark;

  const _NatureGrid({
    required this.selected,
    required this.onToggle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final natures = ChecklistNature.values;
    // 手动构建2列，确保高度由内容决定而非 GridView 固定比例
    final rows = <Widget>[];
    for (int i = 0; i < natures.length; i += 2) {
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _NatureCard(nature: natures[i], isSelected: selected.contains(natures[i]), isDark: isDark, onTap: () { HapticFeedback.selectionClick(); onToggle(natures[i]); })),
            const SizedBox(width: 8),
            if (i + 1 < natures.length)
              Expanded(child: _NatureCard(nature: natures[i + 1], isSelected: selected.contains(natures[i + 1]), isDark: isDark, onTap: () { HapticFeedback.selectionClick(); onToggle(natures[i + 1]); }))
            else
              const Expanded(child: SizedBox()),
          ],
        ),
      );
      if (i + 2 < natures.length) rows.add(const SizedBox(height: 8));
    }
    return Column(children: rows);
  }
}

class _NatureCard extends StatelessWidget {
  final ChecklistNature nature;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _NatureCard({
    required this.nature,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = nature.color;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: isDark ? 0.2 : 0.09)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : const Color(0xFFF7F7F7)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? color.withValues(alpha: 0.55)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.07)
                    : Colors.transparent),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // emoji 背景圆圈
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.18 : 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(nature.emoji,
                    style: const TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 8),
            // 标题
            Text(
              nature.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? color
                    : (isDark ? Colors.white : const Color(0xFF1A1410)),
              ),
            ),
            const SizedBox(height: 3),
            // 描述（不截断，完整展示）
            Text(
              nature.description,
              style: TextStyle(
                fontSize: 11,
                height: 1.45,
                color: isSelected
                    ? color.withValues(alpha: 0.75)
                    : (isDark
                        ? AppColors.textTertiaryDark
                        : const Color(0xFFAAAAAA)),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            // 选中时底部小勾
            if (isSelected) ...[const SizedBox(height: 6), Align(alignment: Alignment.centerRight, child: Icon(Icons.check_circle_rounded, size: 14, color: color))],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  通用筛选胶囊 Chip（固定高度，统一视觉）
// ─────────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color activeColor;
  final bool isDark;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.activeColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: isDark ? 0.2 : 0.1)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : const Color(0xFFF5F5F5)),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? activeColor.withValues(alpha: 0.6)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.transparent),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[Icon(Icons.check_rounded, size: 12, color: activeColor), const SizedBox(width: 4)],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? activeColor
                    : (isDark
                        ? AppColors.textSecondaryDark
                        : const Color(0xFF555555)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  统一列数网格（角色/场景用，3列整齐排列）
// ─────────────────────────────────────────────────────────────────
class _UniformChipGrid extends StatelessWidget {
  final int cols;
  final List<Widget> items;

  const _UniformChipGrid({required this.cols, required this.items});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (int i = 0; i < items.length; i += cols) {
      final rowItems = items.sublist(i, (i + cols).clamp(0, items.length));
      rows.add(
        Row(
          children: [
            for (int j = 0; j < rowItems.length; j++) ...[  
              Expanded(child: rowItems[j]),
              if (j < rowItems.length - 1) const SizedBox(width: 8),
            ],
            // 如果最后一行不满，补空占位
            for (int k = rowItems.length; k < cols; k++) ...[  
              const SizedBox(width: 8),
              const Expanded(child: SizedBox()),
            ],
          ],
        ),
      );
      if (i + cols < items.length) rows.add(const SizedBox(height: 8));
    }
    return Column(children: rows);
  }
}

// ─────────────────────────────────────────────────────────────────
//  分区内小标题
// ─────────────────────────────────────────────────────────────────
class _SubSectionLabel extends StatelessWidget {
  final String label;
  final bool isDark;

  const _SubSectionLabel({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: isDark
            ? AppColors.textTertiaryDark
            : const Color(0xFF999999),
        letterSpacing: 0.3,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  底部确认栏
// ─────────────────────────────────────────────────────────────────
class _FilterBottomBar extends StatelessWidget {
  final int hitCount;
  final bool isFilterEmpty;
  final Color primary;
  final bool isDark;
  final VoidCallback onConfirm;

  const _FilterBottomBar({
    required this.hitCount,
    required this.isFilterEmpty,
    required this.primary,
    required this.isDark,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPad),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: GestureDetector(
        onTap: isFilterEmpty ? null : onConfirm,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 52,
          decoration: BoxDecoration(
            color: isFilterEmpty
                ? (isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0xFFE8E8E8))
                : primary,
            borderRadius: BorderRadius.circular(14),
            boxShadow: isFilterEmpty
                ? null
                : [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isFilterEmpty
                    ? '请选择筛选条件'
                    : '查看 $hitCount 个清单',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isFilterEmpty
                      ? (isDark
                          ? AppColors.textTertiaryDark
                          : const Color(0xFFAAAAAA))
                      : Colors.white,
                ),
              ),
              if (!isFilterEmpty) ...[
                const SizedBox(width: 6),
                const Icon(Icons.arrow_forward_rounded,
                    size: 18, color: Colors.white),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  筛选结果页 —— ChecklistFilterResultScreen
// ─────────────────────────────────────────────────────────────────

class ChecklistFilterResultScreen extends StatelessWidget {
  final ChecklistFilterState filter;
  final List<Checklist> results;
  final List<ChecklistTemplate> recommended;

  const ChecklistFilterResultScreen({
    super.key,
    required this.filter,
    required this.results,
    required this.recommended,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = WeeklyTheme.getLightPalette();
    final primary = isDark ? AppColors.darkPrimary : palette.primary;
    final bg =
        isDark ? AppColors.backgroundDark : const Color(0xFFF8F6F3);

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          // ── AppBar ──────────────────────────────────────────
          _ResultAppBar(
            filter: filter,
            isDark: isDark,
            primary: primary,
            resultCount: results.length,
          ),

          // ── 已有清单 ─────────────────────────────────────────
          if (results.isEmpty)
            SliverToBoxAdapter(
              child: _EmptyResults(isDark: isDark, primary: primary),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _ChecklistResultCard(
                    checklist: results[i],
                    isDark: isDark,
                    primary: primary,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChecklistDetailScreen(
                            checklistId: results[i].id),
                      ),
                    ),
                  ),
                  childCount: results.length,
                ),
              ),
            ),

          // ── 推荐区分隔 ────────────────────────────────────────
          if (recommended.isNotEmpty)
            SliverToBoxAdapter(
              child: _RecommendDivider(
                  isDark: isDark, primary: primary),
            ),

          // ── 推荐模板 ──────────────────────────────────────────
          if (recommended.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _RecommendTemplateCard(
                    template: recommended[i],
                    isDark: isDark,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ChecklistDiscoverScreen(),
                      ),
                    ),
                  ),
                  childCount: recommended.length,
                ),
              ),
            ),

          SliverToBoxAdapter(
            child: SizedBox(
              height: MediaQuery.of(context).padding.bottom + 32,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  结果页 AppBar（带已选标签摘要）
// ─────────────────────────────────────────────────────────────────
class _ResultAppBar extends StatelessWidget {
  final ChecklistFilterState filter;
  final bool isDark;
  final Color primary;
  final int resultCount;

  const _ResultAppBar({
    required this.filter,
    required this.isDark,
    required this.primary,
    required this.resultCount,
  });

  List<String> get _chips {
    final chips = <String>[];
    for (final n in filter.natures) {
      chips.add('${n.emoji} ${n.label}');
    }
    for (final r in filter.roles) {
      chips.add('${r.emoji} ${r.label}');
    }
    for (final s in filter.scenes) {
      chips.add('${s.emoji} ${s.label}');
    }
    for (final t in filter.timeFilters) {
      chips.add(t.label);
    }
    for (final rt in filter.repeatTypes) {
      chips.add(rt.label);
    }
    for (final st in filter.statuses) {
      chips.add(st.label);
    }
    for (final tag in filter.userTags) {
      chips.add(tag);
    }
    return chips;
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        isDark ? Colors.white : const Color(0xFF1A1410);
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : const Color(0xFF888888);
    final chips = _chips;

    return SliverAppBar(
      floating: false,
      pinned: true,
      expandedHeight: 100,
      backgroundColor: isDark
          ? const Color(0xFF141414)
          : const Color(0xFFF8F6F3),
      elevation: 0,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.arrow_back_ios_new_rounded,
              size: 16, color: textSecondary),
        ),
      ),
      title: Text(
        '筛选结果',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: textPrimary,
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Padding(
          padding: const EdgeInsets.fromLTRB(16, 54, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '共找到 $resultCount 个清单',
                style: TextStyle(
                  fontSize: 12,
                  color: primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: chips
                      .take(8)
                      .map((chip) => Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: primary.withValues(
                                  alpha: isDark ? 0.15 : 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              chip,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: primary,
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  空结果提示
// ─────────────────────────────────────────────────────────────────
class _EmptyResults extends StatelessWidget {
  final bool isDark;
  final Color primary;

  const _EmptyResults({required this.isDark, required this.primary});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        children: [
          const Text('🔍', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 16),
          Text(
            '没有找到匹配的清单',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1A1410),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '但下方有一些这个场景下\n你可能还没有创建的推荐清单',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : const Color(0xFF888888),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  推荐区分隔标题
// ─────────────────────────────────────────────────────────────────
class _RecommendDivider extends StatelessWidget {
  final bool isDark;
  final Color primary;

  const _RecommendDivider({required this.isDark, required this.primary});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: isDark ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome_rounded,
                    size: 13, color: primary),
                const SizedBox(width: 5),
                Text(
                  '这个场景下，你可能还需要',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Divider(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  已有清单结果卡片
// ─────────────────────────────────────────────────────────────────
class _ChecklistResultCard extends StatelessWidget {
  final Checklist checklist;
  final bool isDark;
  final Color primary;
  final VoidCallback onTap;

  const _ChecklistResultCard({
    required this.checklist,
    required this.isDark,
    required this.primary,
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
    final progress = checklist.progress;
    final isDone = checklist.isAllDone;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          children: [
            // emoji 图标
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color:
                    accent.withValues(alpha: isDark ? 0.18 : 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(checklist.emoji,
                    style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    checklist.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? Colors.white
                          : const Color(0xFF1A1410),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  if (checklist.totalCount > 0)
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.black.withValues(alpha: 0.06),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isDone
                                    ? const Color(0xFF20C997)
                                    : accent,
                              ),
                              minHeight: 4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isDone
                              ? '完成 ✅'
                              : '${checklist.checkedCount}/${checklist.totalCount}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDone
                                ? const Color(0xFF20C997)
                                : (isDark
                                    ? AppColors.textSecondaryDark
                                    : const Color(0xFF888888)),
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      '暂无事项',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textTertiaryDark
                            : const Color(0xFFBBBBBB),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded,
                size: 18,
                color: isDark
                    ? AppColors.textTertiaryDark
                    : const Color(0xFFCCCCCC)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  推荐模板卡片
// ─────────────────────────────────────────────────────────────────
class _RecommendTemplateCard extends StatelessWidget {
  final ChecklistTemplate template;
  final bool isDark;
  final VoidCallback onTap;

  const _RecommendTemplateCard({
    required this.template,
    required this.isDark,
    required this.onTap,
  });

  Color get _accent {
    try {
      return Color(
          int.parse('FF${template.colorHex.replaceAll('#', '')}',
              radix: 16));
    } catch (_) {
      return const Color(0xFF5C7CFA);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark
              ? accent.withValues(alpha: 0.08)
              : accent.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: accent.withValues(alpha: isDark ? 0.2 : 0.12),
          ),
        ),
        child: Row(
          children: [
            // emoji
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color:
                    accent.withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(template.emoji,
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
                      Expanded(
                        child: Text(
                          template.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1A1410),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '模板',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    template.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : const Color(0xFF888888),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.add_circle_outline_rounded,
                size: 20, color: accent.withValues(alpha: 0.7)),
          ],
        ),
      ),
    );
  }
}
