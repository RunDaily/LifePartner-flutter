import 'dart:convert';

// ─────────────────────────────────────────────────────────────────
//  ActivityDefinition —— 活动定义（用户活动集里的一种活动类型）
//
//  【生活五环】设计哲学：
//  人的所有活动归属于五个生命支柱，缺失任何一环都会让生活失衡。
//  五环既是数据分类，也是核心视觉语言——在 UI 上以五边形呈现，
//  让用户直观感受到"我的生活哪个维度在发光，哪个维度在凹陷"。
//
//  🏃 身体力行 Body   —— 运动、健身、照顾身体
//  ❤️ 关系连接 People —— 亲情、爱情、友情、社交
//  🎨 创造表达 Create —— 创作、手工、烹饪、一切输出
//  🌱 心智成长 Grow   —— 学习、阅读、冥想、自我认知
//  🎯 心流专注 Flow   —— 深度工作、副业、职业发展
//
//  持久化：整个活动集以 JSON List 存储在 KV Store。
// ─────────────────────────────────────────────────────────────────

/// 活动分类（生活五环）
enum ActivityCategory {
  body('body', '身体力行', '🏃', ['#FF6B35', '#FF9A56']),
  people('people', '关系连接', '❤️', ['#E8507A', '#F48FB1']),
  create('create', '创造表达', '🎨', ['#7C4DFF', '#B39DDB']),
  grow('grow', '心智成长', '🌱', ['#2E7D32', '#81C784']),
  flow('flow', '心流专注', '🎯', ['#1565C0', '#64B5F6']);

  const ActivityCategory(
      this.value, this.label, this.emoji, this.defaultGradient);
  final String value;
  final String label;
  final String emoji;

  /// 该维度的默认渐变色
  final List<String> defaultGradient;

  /// 主色（渐变起点）
  String get primaryHex => defaultGradient.first;

  static ActivityCategory fromValue(String v) =>
      ActivityCategory.values.firstWhere(
        (e) => e.value == v,
        orElse: () => ActivityCategory.body,
      );
}

/// 单个活动定义
class ActivityDefinition {
  final String id;

  /// 活动名称（如：跑步、爬山）
  final String name;

  /// Emoji 图标
  final String emoji;

  /// 分类（五环之一）
  final ActivityCategory category;

  /// 渐变色（两个 hex 字符串，如 ['#FF9A56', '#FF6B35']）
  final List<String> gradientHex;

  /// 简短描述（AI 生成或用户自填）
  final String description;

  /// 是否为内置预置活动（false = 用户自建）
  final bool isPreset;

  /// 创建时间
  final DateTime createdAt;

  /// AI 生成的专属一句话文案（首次打卡后后台异步生成，本地缓存）
  /// null = 尚未生成，UI 降级到本地插值文案
  final String? mottoLine;

  const ActivityDefinition({
    required this.id,
    required this.name,
    required this.emoji,
    required this.category,
    required this.gradientHex,
    this.description = '',
    this.isPreset = false,
    required this.createdAt,
    this.mottoLine,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'category': category.value,
        'gradientHex': gradientHex,
        'description': description,
        'isPreset': isPreset,
        'createdAt': createdAt.millisecondsSinceEpoch,
        if (mottoLine != null) 'mottoLine': mottoLine,
      };

  factory ActivityDefinition.fromMap(Map<String, dynamic> map) =>
      ActivityDefinition(
        id: map['id'] as String,
        name: map['name'] as String? ?? '',
        emoji: map['emoji'] as String? ?? '🎯',
        category:
            ActivityCategory.fromValue(map['category'] as String? ?? 'body'),
        gradientHex:
            (map['gradientHex'] as List<dynamic>? ?? ['#FF9A56', '#FF6B35'])
                .map((e) => e.toString())
                .toList(),
        description: map['description'] as String? ?? '',
        isPreset: map['isPreset'] as bool? ?? false,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            map['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch),
        mottoLine: map['mottoLine'] as String?,
      );

  /// 返回一份修改了 mottoLine 的副本
  ActivityDefinition withMotto(String motto) => ActivityDefinition(
        id: id,
        name: name,
        emoji: emoji,
        category: category,
        gradientHex: gradientHex,
        description: description,
        isPreset: isPreset,
        createdAt: createdAt,
        mottoLine: motto,
      );

  String toJson() => jsonEncode(toMap());
}

// ─────────────────────────────────────────────────────────────────
//  内置活动预置库（引导选择时展示）
//  按五环分类，覆盖用户日常高频活动场景
// ─────────────────────────────────────────────────────────────────

class ActivityPresets {
  static final List<ActivityDefinition> all = [
    // ══════════════════════════════════════
    //  🏃 身体力行 Body
    //  覆盖：运动、锻炼、照顾身体的一切
    // ══════════════════════════════════════
    ActivityDefinition(
      id: 'preset_run',
      name: '跑步',
      emoji: '🏃',
      category: ActivityCategory.body,
      gradientHex: ['#FF6B35', '#FF9A56'],
      description: '迈开双腿，感受身体在节奏中苏醒',
      isPreset: true,
      createdAt: DateTime(2024),
    ),
    ActivityDefinition(
      id: 'preset_swim',
      name: '游泳',
      emoji: '🏊',
      category: ActivityCategory.body,
      gradientHex: ['#0288D1', '#4FC3F7'],
      description: '在水中找到专属的宁静与力量',
      isPreset: true,
      createdAt: DateTime(2024),
    ),
    ActivityDefinition(
      id: 'preset_gym',
      name: '健身',
      emoji: '💪',
      category: ActivityCategory.body,
      gradientHex: ['#C62828', '#EF5350'],
      description: '每一次挥汗，都是对自己的承诺',
      isPreset: true,
      createdAt: DateTime(2024),
    ),
    ActivityDefinition(
      id: 'preset_cycling',
      name: '骑行',
      emoji: '🚴',
      category: ActivityCategory.body,
      gradientHex: ['#2E7D32', '#66BB6A'],
      description: '踩着风，把城市的每条路变成风景',
      isPreset: true,
      createdAt: DateTime(2024),
    ),
    ActivityDefinition(
      id: 'preset_yoga',
      name: '瑜伽',
      emoji: '🧘',
      category: ActivityCategory.body,
      gradientHex: ['#6A1B9A', '#CE93D8'],
      description: '在呼吸里找到平静与力量',
      isPreset: true,
      createdAt: DateTime(2024),
    ),
    ActivityDefinition(
      id: 'preset_walk',
      name: '散步',
      emoji: '🚶',
      category: ActivityCategory.body,
      gradientHex: ['#00838F', '#80DEEA'],
      description: '放慢脚步，把生活细节收进眼底',
      isPreset: true,
      createdAt: DateTime(2024),
    ),
    ActivityDefinition(
      id: 'preset_badminton',
      name: '羽毛球',
      emoji: '🏸',
      category: ActivityCategory.body,
      gradientHex: ['#E65100', '#FFA726'],
      description: '一来一往，球场是最好的社交场',
      isPreset: true,
      createdAt: DateTime(2024),
    ),
    ActivityDefinition(
      id: 'preset_basketball',
      name: '篮球',
      emoji: '🏀',
      category: ActivityCategory.body,
      gradientHex: ['#BF360C', '#FF7043'],
      description: '投篮那一刻，时间静止',
      isPreset: true,
      createdAt: DateTime(2024),
    ),
    ActivityDefinition(
      id: 'preset_sleep',
      name: '好好睡觉',
      emoji: '😴',
      category: ActivityCategory.body,
      gradientHex: ['#283593', '#7986CB'],
      description: '高质量的睡眠，是最好的恢复',
      isPreset: true,
      createdAt: DateTime(2024),
    ),
    ActivityDefinition(
      id: 'preset_spa',
      name: 'SPA / 按摩',
      emoji: '💆',
      category: ActivityCategory.body,
      gradientHex: ['#2E7D32', '#A5D6A7'],
      description: '好好犒劳一下自己的身体',
      isPreset: true,
      createdAt: DateTime(2024),
    ),

    // ══════════════════════════════════════
    //  ❤️ 关系连接 People
    //  覆盖：亲情、爱情、友情、所有与人的联结
    // ══════════════════════════════════════
    ActivityDefinition(
      id: 'preset_date',
      name: '约会',
      emoji: '💑',
      category: ActivityCategory.people,
      gradientHex: ['#C62828', '#EF9A9A'],
      description: '每一次相遇都值得被好好记录',
      isPreset: true,
      createdAt: DateTime(2024),
    ),
    ActivityDefinition(
      id: 'preset_family',
      name: '陪伴家人',
      emoji: '🏠',
      category: ActivityCategory.people,
      gradientHex: ['#E65100', '#FFB74D'],
      description: '家人在哪里，心就在哪里',
      isPreset: true,
      createdAt: DateTime(2024),
    ),
    ActivityDefinition(
      id: 'preset_child',
      name: '陪孩子',
      emoji: '👨‍👩‍👧',
      category: ActivityCategory.people,
      gradientHex: ['#F57F17', '#FFD54F'],
      description: '陪伴，是给孩子最好的礼物',
      isPreset: true,
      createdAt: DateTime(2024),
    ),
    ActivityDefinition(
      id: 'preset_friends',
      name: '朋友聚会',
      emoji: '🥂',
      category: ActivityCategory.people,
      gradientHex: ['#AD1457', '#F06292'],
      description: '好朋友在一起，时间过得飞快',
      isPreset: true,
      createdAt: DateTime(2024),
    ),
    ActivityDefinition(
      id: 'preset_call',
      name: '打电话/聊天',
      emoji: '📞',
      category: ActivityCategory.people,
      gradientHex: ['#00695C', '#80CBC4'],
      description: '一通电话，拉近了千里之外的距离',
      isPreset: true,
      createdAt: DateTime(2024),
    ),
    ActivityDefinition(
      id: 'preset_parents',
      name: '陪父母',
      emoji: '👴',
      category: ActivityCategory.people,
      gradientHex: ['#4E342E', '#A1887F'],
      description: '时间是最珍贵的礼物，给爸妈多一点',
      isPreset: true,
      createdAt: DateTime(2024),
    ),
    ActivityDefinition(
      id: 'preset_volunteer',
      name: '公益志愿',
      emoji: '🤝',
      category: ActivityCategory.people,
      gradientHex: ['#00695C', '#4DB6AC'],
      description: '付出让世界更温暖',
      isPreset: true,
      createdAt: DateTime(2024),
    ),
    ActivityDefinition(
      id: 'preset_social',
      name: '社交活动',
      emoji: '🎉',
      category: ActivityCategory.people,
      gradientHex: ['#E8507A', '#F48FB1'],
      description: '走出去，遇见更多有趣的人',
      isPreset: true,
      createdAt: DateTime(2024),
    ),

    // ══════════════════════════════════════
    //  🎨 创造表达 Create
    //  覆盖：所有创作、手工、烹饪、一切"从无到有"
    // ══════════════════════════════════════
    ActivityDefinition(
      id: 'preset_writing',
      name: '写作',
      emoji: '✍️',
      category: ActivityCategory.create,
      gradientHex: ['#4527A0', '#9575CD'],
      description: '文字是时光最好的容器',
      isPreset: true,
      createdAt: DateTime(2024),
    ),
    ActivityDefinition(
      id: 'preset_painting',
      name: '绘画',
      emoji: '🎨',
      category: ActivityCategory.create,
      gradientHex: ['#7B1FA2', '#CE93D8'],
      description: '笔触之间，世界有了新的颜色',
      isPreset: true,
      createdAt: DateTime(2024),
    ),
    ActivityDefinition(
      id: 'preset_instrument',
      name: '弹奏乐器',
      emoji: '🎸',
      category: ActivityCategory.create,
      gradientHex: ['#E65100', '#FFB74D'],
      description: '每一次练习，都是与音乐更近一步',
      isPreset: true,
      createdAt: DateTime(2024),
    ),
    ActivityDefinition(
      id: 'preset_singing',
      name: '唱歌',
      emoji: '🎵',
      category: ActivityCategory.create,
      gradientHex: ['#880E4F', '#F48FB1'],
      description: '用声音记录最真实的情绪',
      isPreset: true,
      createdAt: DateTime(2024),
    ),
    ActivityDefinition(
      id: 'preset_photography',
      name: '摄影',
      emoji: '📷',
      category: ActivityCategory.create,
      gradientHex: ['#263238', '#78909C'],
      description: '按下快门，定格最美的瞬间',
      isPreset: true,
      createdAt: DateTime(2024),
    ),
    ActivityDefinition(
      id: 'preset_cooking',
      name: '下厨',
      emoji: '🍳',
      category: ActivityCategory.create,
      gradientHex: ['#BF360C', '#FF8A65'],
      description: '一道亲手做的菜，是最暖心的仪式感',
      isPreset: true,
      createdAt: DateTime(2024),
    ),
    ActivityDefinition(
      id: 'preset_coding',
      name: '写代码',
      emoji: '💻',
      category: ActivityCategory.create,
      gradientHex: ['#1A237E', '#5C6BC0'],
      description: '把想法变成现实，是最酷的创造',
      isPreset: true,
      createdAt: DateTime(2024),
    ),
    ActivityDefinition(
      id: 'preset_crafts',
      name: '手工/DIY',
      emoji: '🧶',
      category: ActivityCategory.create,
      gradientHex: ['#880E4F', '#F06292'],
      description: '用双手创造独一无二的东西',
      isPreset: true,
      createdAt: DateTime(2024),
    ),
    ActivityDefinition(
      id: 'preset_vlog',
      name: '拍视频/剪辑',
      emoji: '🎬',
      category: ActivityCategory.create,
      gradientHex: ['#311B92', '#7E57C2'],
      description: '把生活剪成一部属于自己的电影',
      isPreset: true,
      createdAt: DateTime(2024),
    ),

    // ══════════════════════════════════════
    //  🌱 心智成长 Grow
    //  覆盖：学习、阅读、冥想、反思、自我认知
    // ══════════════════════════════════════
    ActivityDefinition(
      id: 'preset_reading',
      name: '阅读',
      emoji: '📚',
      category: ActivityCategory.grow,
      gradientHex: ['#1B5E20', '#66BB6A'],
      description: '好书是最长情的陪伴',
      isPreset: true,
      createdAt: DateTime(2024),
    ),
    ActivityDefinition(
      id: 'preset_meditation',
      name: '冥想',
      emoji: '🌙',
      category: ActivityCategory.grow,
      gradientHex: ['#1A237E', '#5C6BC0'],
      description: '清空思绪，让内心重归宁静',
      isPreset: true,
      createdAt: DateTime(2024),
    ),
    ActivityDefinition(
      id: 'preset_journal',
      name: '写日记/复盘',
      emoji: '📔',
      category: ActivityCategory.grow,
      gradientHex: ['#33691E', '#AED581'],
      description: '把每天的感悟留下来，与未来的自己对话',
      isPreset: true,
      createdAt: DateTime(2024),
    ),
    ActivityDefinition(
      id: 'preset_course',
      name: '上课/网课',
      emoji: '🎓',
      category: ActivityCategory.grow,
      gradientHex: ['#006064', '#80DEEA'],
      description: '每天进步一点点，积累成大改变',
      isPreset: true,
      createdAt: DateTime(2024),
    ),
    ActivityDefinition(
      id: 'preset_podcast',
      name: '听播客/音频',
      emoji: '🎙️',
      category: ActivityCategory.grow,
      gradientHex: ['#37474F', '#90A4AE'],
      description: '在碎片时间里，让思维跑起来',
      isPreset: true,
      createdAt: DateTime(2024),
    ),
    ActivityDefinition(
      id: 'preset_therapy',
      name: '心理咨询',
      emoji: '🫶',
      category: ActivityCategory.grow,
      gradientHex: ['#4A148C', '#AB47BC'],
      description: '照顾内心，是最重要的成长',
      isPreset: true,
      createdAt: DateTime(2024),
    ),
    ActivityDefinition(
      id: 'preset_hiking',
      name: '独处思考',
      emoji: '🌿',
      category: ActivityCategory.grow,
      gradientHex: ['#2E7D32', '#A5D6A7'],
      description: '给自己一段安静的时间，和内心对话',
      isPreset: true,
      createdAt: DateTime(2024),
    ),
    ActivityDefinition(
      id: 'preset_language',
      name: '学语言',
      emoji: '🗣️',
      category: ActivityCategory.grow,
      gradientHex: ['#00695C', '#4DB6AC'],
      description: '多一门语言，多一个看世界的窗口',
      isPreset: true,
      createdAt: DateTime(2024),
    ),

    // ══════════════════════════════════════
    //  🎯 心流专注 Flow
    //  覆盖：深度工作、副业、专注投入的事
    // ══════════════════════════════════════
    ActivityDefinition(
      id: 'preset_deepwork',
      name: '深度工作',
      emoji: '🎯',
      category: ActivityCategory.flow,
      gradientHex: ['#0D47A1', '#42A5F5'],
      description: '全力以赴投入，进入心流状态',
      isPreset: true,
      createdAt: DateTime(2024),
    ),
    ActivityDefinition(
      id: 'preset_sidejob',
      name: '副业/接单',
      emoji: '💼',
      category: ActivityCategory.flow,
      gradientHex: ['#1565C0', '#64B5F6'],
      description: '为自己多开一条路',
      isPreset: true,
      createdAt: DateTime(2024),
    ),
    ActivityDefinition(
      id: 'preset_project',
      name: '推进项目',
      emoji: '🚀',
      category: ActivityCategory.flow,
      gradientHex: ['#311B92', '#7986CB'],
      description: '每一步都算数，每一次推进都值得记录',
      isPreset: true,
      createdAt: DateTime(2024),
    ),
    ActivityDefinition(
      id: 'preset_meeting',
      name: '重要会议',
      emoji: '📋',
      category: ActivityCategory.flow,
      gradientHex: ['#004D40', '#4DB6AC'],
      description: '把每次关键会议当作里程碑',
      isPreset: true,
      createdAt: DateTime(2024),
    ),
    ActivityDefinition(
      id: 'preset_networking',
      name: '拓展人脉',
      emoji: '🌐',
      category: ActivityCategory.flow,
      gradientHex: ['#01579B', '#29B6F6'],
      description: '认识对的人，打开新的可能',
      isPreset: true,
      createdAt: DateTime(2024),
    ),
    ActivityDefinition(
      id: 'preset_planning',
      name: '规划/策略',
      emoji: '🗺️',
      category: ActivityCategory.flow,
      gradientHex: ['#263238', '#607D8B'],
      description: '想清楚方向，才能走得更稳',
      isPreset: true,
      createdAt: DateTime(2024),
    ),
    ActivityDefinition(
      id: 'preset_travel',
      name: '出差/旅行',
      emoji: '✈️',
      category: ActivityCategory.flow,
      gradientHex: ['#006064', '#4DD0E1'],
      description: '每一次出发，都带回新的视角',
      isPreset: true,
      createdAt: DateTime(2024),
    ),
  ];

  /// 按分类分组
  static Map<ActivityCategory, List<ActivityDefinition>> get byCategory {
    final map = <ActivityCategory, List<ActivityDefinition>>{};
    for (final cat in ActivityCategory.values) {
      map[cat] = [];
    }
    for (final a in all) {
      map[a.category]!.add(a);
    }
    return map;
  }
}

// ─────────────────────────────────────────────────────────────────
//  ActivityMottoFallback —— 本地插值文案系统
//
//  在以下场景作为最终兜底展示：
//  1. 活动尚无 AI 生成文案（mottoLine == null）
//  2. 无网络，AI 调用未触发
//  3. AI 调用失败
//
//  【设计原则】
//  - 先精确匹配活动名称（高频活动有专属文案）
//  - 再按维度返回动态插值文案（插入活动名/emoji）
//  - 任意情况下都有有温度的文字，不出现空白或通用占位符
// ─────────────────────────────────────────────────────────────────

class ActivityMottoFallback {
  ActivityMottoFallback._();

  // ── 高频活动精确匹配表 ───────────────────────────────────────
  // 活动名 → 专属文案（精心手写，全部唯一）
  static const Map<String, String> _exactMap = {
    // 🏃 身体
    '跑步':     '脚步一起，思绪跟着变清晰',
    '游泳':     '在水里，浮力把疲惫都托住了',
    '健身':     '和昨天的自己较劲，才叫进步',
    '骑行':     '换一种速度，看不一样的城市',
    '瑜伽':     '每一次呼气，都是放下一点什么',
    '散步':     '慢下来走，才能看见平时错过的',
    '羽毛球':   '球网两侧，是我最喜欢的快乐距离',
    '篮球':     '出手的瞬间，全身心都在场',
    '好好睡觉': '今天把睡眠还给自己，明天更能还给生活',
    'SPA / 按摩': '身体也需要被好好对待',
    // ❤️ 关系
    '约会':     '两个人在一起，时间总是过得太快',
    '陪伴家人': '家人在的地方，是最简单的幸福',
    '陪孩子':   '他们长得太快，这一刻值得好好记',
    '朋友聚会': '好朋友聊起来，总感觉没有废话',
    '打电话/聊天': '声音穿过屏幕，距离就近了一点',
    '陪父母':   '陪着他们，是我现在能做的最重要的事',
    '公益志愿': '付出这件事，会悄悄改变自己',
    '社交活动': '走出去，总会遇到有意思的人',
    // 🎨 创造
    '写作':     '写下来的，才真的属于自己',
    '绘画':     '线条和颜色，是另一种语言',
    '弹奏乐器': '手指记住的，是比文字更深的感受',
    '唱歌':     '用嗓子说出嘴说不出的话',
    '摄影':     '一次按下快门，就保住了一个瞬间',
    '下厨':     '为自己做顿饭，是最真实的善待',
    '写代码':   '键盘声里，想法一点点变成现实',
    '手工/DIY': '双手做的东西，有机器造不出来的温度',
    '拍视频/剪辑': '把生活剪成故事，留给未来的自己看',
    // 🌱 成长
    '阅读':     '读进去一页，世界就多开了一扇窗',
    '冥想':     '安静几分钟，内心就清楚很多',
    '写日记/复盘': '把今天写下来，明天才走得更稳',
    '上课/网课': '花时间学的东西，早晚都会用上',
    '听播客/音频': '耳机里的世界，比想象中大得多',
    '心理咨询': '了解自己，是最难也最值得的功课',
    '独处思考': '安静的时候，才是真正在想清楚',
    '学语言':   '每多一门语言，就多一种理解世界的方式',
    // 🎯 专注
    '深度工作': '进入状态的时候，连时间都不记得了',
    '副业/接单': '多走一步，就多一种可能性',
    '推进项目': '每次推进，离那个目标就近一点',
    '重要会议': '这次对话，可能是个转折点',
    '拓展人脉': '认识一个对的人，胜过走很多弯路',
    '规划/策略': '想清楚方向，比埋头跑更重要',
    '出差/旅行': '在不熟悉的地方，反而想清楚了一些事',
  };

  // ── 维度动态插值模板（按维度随机取一条，插入活动名）─────────
  static const Map<ActivityCategory, List<String>> _categoryTemplates = {
    ActivityCategory.body: [
      '每次{name}，都是给身体的一次礼物',
      '{name}之后，感觉整个人状态不一样',
      '坚持{name}，身体会记住这份积累',
      '动起来就是对自己最好的善待',
    ],
    ActivityCategory.people: [
      '和重要的人在一起，总是值得记下来的',
      '这次{name}，是今天最有温度的时刻',
      '关系需要花时间，{name}就是在投资它',
      '有人在，生活就有了锚',
    ],
    ActivityCategory.create: [
      '{name}的过程，就是在给世界留下痕迹',
      '做出来的东西，比什么都真实',
      '每次{name}，都在离自己想要的样子近一点',
      '创造这件事，练的是全力以赴',
    ],
    ActivityCategory.grow: [
      '今天{name}，是在给未来的自己打基础',
      '慢慢学、慢慢悟，总比不动强',
      '{name}这件事，时间会告诉你值得',
      '成长不是一下子的事，{name}就是积累',
    ],
    ActivityCategory.flow: [
      '专注的时候，是最接近自己的时候',
      '{name}的每一分钟，都算数',
      '进入心流，时间就是另一种感觉',
      '把{name}做到位，其他事情自然跟上',
    ],
  };

  /// 获取活动的本地 fallback 文案
  ///
  /// 优先顺序：
  /// 1. 精确匹配活动名
  /// 2. 按维度模板插值（用活动名替换 {name}）
  static String get(ActivityDefinition activity) {
    // 精确匹配
    final exact = _exactMap[activity.name];
    if (exact != null) return exact;

    // 维度模板插值
    final templates = _categoryTemplates[activity.category] ?? [];
    if (templates.isEmpty) return activity.description.isNotEmpty
        ? activity.description
        : '${activity.emoji} 记录每一次，见证自己的积累';

    // 用活动名的哈希选择模板，确保同一活动每次取同一条（稳定性）
    final idx = activity.name.hashCode.abs() % templates.length;
    final template = templates[idx];
    return template.replaceAll('{name}', activity.name);
  }

  /// 获取活动当前展示的最佳文案
  ///
  /// 有 AI 文案优先用 AI 文案，否则降级到本地 fallback
  static String best(ActivityDefinition activity) {
    if (activity.mottoLine != null && activity.mottoLine!.isNotEmpty) {
      return activity.mottoLine!;
    }
    return get(activity);
  }
}
