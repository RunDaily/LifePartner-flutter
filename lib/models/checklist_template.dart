// ─────────────────────────────────────────────────────────────────
//  ChecklistTemplate —— 清单模板模型
//
//  【设计思路】
//  模板是「可复用的清单骨架」，是纯值对象（Value Object），不入数据库。
//  用户选择模板后，生成一份独立的 Checklist 实例（structural 型），
//  两者完全解耦，实例修改不影响模板，模板更新不影响已创建的实例。
//
//  【数据来源】
//  v1：内置于 Dart 代码中（lib/data/template_data.dart）
//  未来：可扩展为远端 JSON CDN / Firebase Remote Config 热更新
//
//  【与 Checklist 模型的映射】
//  ChecklistTemplate.items → List<ChecklistItem>
//  ChecklistTemplate.function → ChecklistFunction
//  ChecklistTemplate.style → ChecklistStyle
//  ChecklistTemplate.sceneTags → List<ChecklistTag>（userTags）
// ─────────────────────────────────────────────────────────────────

import 'checklist.dart';

// ── 模板分类（展示用，与 ChecklistScene 正交）────────────────────
/// 模板库的展示维度，比 ChecklistScene 更丰富，面向用户心智
enum TemplateCategory {
  all('all', '全部', '📋'),
  travel('travel', '旅行', '✈️'),
  work('work', '工作', '💼'),
  life('life', '生活', '🏠'),
  health('health', '健康', '💊'),
  shopping('shopping', '购物', '🛒'),
  study('study', '学习', '📚'),
  event('event', '活动', '🎉'),
  finance('finance', '财务', '💰'),
  // ── 新增分类 ───────────────────────────────────────────────
  baby('baby', '育儿', '👶'),
  property('property', '置业', '🏡'),
  mind('mind', '心理', '🧠'),
  career('career', '职业', '🎯'),
  startup('startup', '创业', '🚀'),
  pet('pet', '宠物', '🐾');

  const TemplateCategory(this.value, this.label, this.emoji);
  final String value;
  final String label;
  final String emoji;

  /// 映射到兼容的 ChecklistScene（创建清单时使用）
  ChecklistScene get scene => switch (this) {
        TemplateCategory.work ||
        TemplateCategory.career ||
        TemplateCategory.startup =>
          ChecklistScene.work,
        TemplateCategory.study => ChecklistScene.study,
        TemplateCategory.shopping => ChecklistScene.shopping,
        TemplateCategory.travel ||
        TemplateCategory.health ||
        TemplateCategory.life ||
        TemplateCategory.event ||
        TemplateCategory.finance ||
        TemplateCategory.baby ||
        TemplateCategory.property ||
        TemplateCategory.mind ||
        TemplateCategory.pet =>
          ChecklistScene.life,
        _ => ChecklistScene.general,
      };
}

// ── 模板条目 ────────────────────────────────────────────────────
/// 轻量级条目结构（模板专用，不含 id / isChecked / 时间戳等运行时字段）
class TemplateItem {
  /// 条目文本
  final String text;

  /// 分组标签（grouped 风格下使用，如「证件类」「衣物类」）
  final String? group;

  /// 数量（purchase 风格下使用，如「3件」）
  final String? quantity;

  const TemplateItem({
    required this.text,
    this.group,
    this.quantity,
  });

  /// 转换为真实的 ChecklistItem（需传入 uuid 工厂）
  ChecklistItem toChecklistItem({
    required String id,
    required int sortOrder,
  }) {
    return ChecklistItem(
      id: id,
      title: text,
      groupLabel: group,
      quantity: quantity,
      sortOrder: sortOrder,
      createdAt: DateTime.now(),
    );
  }
}

// ── 清单模板 ─────────────────────────────────────────────────────
class ChecklistTemplate {
  /// 全局唯一标识（如 'travel_packing_v1'），用于去重和统计
  final String id;

  /// 模板标题
  final String title;

  /// 简短描述（展示在模板卡片副标题处）
  final String description;

  /// 代表性 emoji
  final String emoji;

  /// 清单颜色（HEX，不含 #，如 '5C7CFA'）
  final String colorHex;

  /// 模板所属分类（用于模板库筛选展示）
  final TemplateCategory category;

  /// 清单功能层（影响 AI 策略和展示风格）
  final ChecklistFunction function;

  /// 清单展示风格
  final ChecklistStyle style;

  /// 场景标签（创建清单时作为 userTags 写入）
  final List<String> sceneTags;

  /// 模板条目列表
  final List<TemplateItem> items;

  /// 是否展示在「精选推荐」区域
  final bool isFeatured;

  /// 使用次数（内置数据可预设，用于排序和展示热度）
  final int usageCount;

  const ChecklistTemplate({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
    required this.colorHex,
    required this.category,
    this.function = ChecklistFunction.checklist,
    this.style = ChecklistStyle.simple,
    this.sceneTags = const [],
    this.items = const [],
    this.isFeatured = false,
    this.usageCount = 0,
  });

  /// 条目总数
  int get itemCount => items.length;

  /// 含有分组的条目数（grouped 风格下）
  int get groupCount {
    final groups = items.map((i) => i.group).where((g) => g != null).toSet();
    return groups.length;
  }

  /// 副标题展示文本（如「32 个物品 · 5 个分组」）
  String get subtitleText {
    final countStr = '$itemCount 个$_itemUnit';
    if (style == ChecklistStyle.grouped && groupCount > 0) {
      return '$countStr · $groupCount 个分组';
    }
    if (style == ChecklistStyle.numbered) {
      return '$countStr步骤';
    }
    return countStr;
  }

  String get _itemUnit => switch (function) {
        ChecklistFunction.purchase => '物品',
        ChecklistFunction.sop => '',
        ChecklistFunction.plan => '事项',
        _ => '条目',
      };
}
