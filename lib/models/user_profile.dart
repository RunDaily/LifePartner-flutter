// ─────────────────────────────────────────────────────────────────
//  用户画像模型 v3
//
//  【三层标签架构】
//
//  第一层：PersonaArchetype（人物原型）
//    - 10个大标签，覆盖所有主流用户人群
//    - Onboarding 时展示，30秒选完
//    - 每个标签信息密度极高（身份+生活方式+场景需求）
//
//  第二层：DetailTag（细分兴趣标签）
//    - 按8个子组，共80+个细分标签
//    - 在设置页「更多标签」区域展示
//    - 用户有兴趣才深入填写
//
//  第三层：InferredTag（行为推断标签）
//    - 根据用户创建的清单关键词，AI 自动推断
//    - 用户完全无感知，不在 UI 中展示
//    - 每次构建 System Prompt 时动态计算注入
//
//  AI 注入优先级：第一层 > 第三层（行为推断）> 第二层（细分兴趣）
//  因为第一层和第三层最能驱动清单推荐，第二层是补充
// ─────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────
//  旧字段保留（历史兼容，UI 不再展示）
// ─────────────────────────────────────────────────────────────────

@Deprecated('Use PersonaArchetype system instead')
enum UserIdentityType {
  general('general', '自由记录者', '📝', '记录生活中的每一个瞬间'),
  entrepreneur('entrepreneur', '创业者', '🚀', '追踪商业灵感与创业历程'),
  student('student', '学生', '📚', '管理学习计划与成长记录'),
  examPrep('exam_prep', '备考党', '✏️', '备考打卡、错题归纳、冲刺倒计时'),
  pregnantMom('pregnant_mom', '孕期宝妈', '🤰', '记录孕周变化与宝宝成长'),
  newMom('new_mom', '新手妈妈', '👶', '记录宝宝成长里程碑'),
  diabetic('diabetic', '糖尿病管理', '💉', '追踪血糖、饮食与用药记录'),
  fitness('fitness', '健身达人', '💪', '记录训练计划与身体数据'),
  traveler('traveler', '旅行者', '✈️', '记录旅途见闻与精彩瞬间'),
  custom('custom', '自定义', '✨', '用自己的方式定义记录');

  const UserIdentityType(this.value, this.label, this.emoji, this.description);
  final String value;
  final String label;
  final String emoji;
  final String description;
}

@Deprecated('Use tag system instead')
enum UserMotivation {
  habit('habit', '养成习惯', '💪', ''),
  goal('goal', '追踪目标', '🎯', ''),
  memory('memory', '记录生活', '📖', ''),
  emotion('emotion', '整理情绪', '😌', ''),
  unknown('unknown', '还没想好', '🤔', '');

  const UserMotivation(this.value, this.label, this.emoji, this.description);
  final String value;
  final String label;
  final String emoji;
  final String description;
}

@Deprecated('Use tag system instead')
enum UserBarrier {
  forgets('forgets', '总忘了记', '⏰', ''),
  noIdea('no_idea', '不知道写什么', '😐', ''),
  giveUp('give_up', '坚持几天就放弃', '😓', ''),
  noFeedback('no_feedback', '写了也不知道有没有用', '✍️', ''),
  firstTime('first_time', '第一次认真记录', '🆕', '');

  const UserBarrier(this.value, this.label, this.emoji, this.description);
  final String value;
  final String label;
  final String emoji;
  final String description;
}

// ─────────────────────────────────────────────────────────────────
//  第一层：人物原型大标签
// ─────────────────────────────────────────────────────────────────

/// 10个人物原型大标签
///
/// 设计原则：
/// - 每个标签让用户看到后有「对，这说的就是我」的认同感
/// - 覆盖中国互联网用户的主流人群
/// - 信息密度极高：一个标签 = 身份 + 生活方式 + 场景需求
/// - Onboarding 时展示，用户 30 秒选完（可多选）
enum PersonaArchetype {
  // ── 职业/角色类 ──────────────────────────────────────────────
  officeWorker(
    'office_worker',
    '职场打工人',
    '💼',
    '工作日节奏明显，推荐工作计划、会议准备、项目追踪、效率工具类清单。'
    '语气专业简洁，注重可执行性。时间提醒集中在工作日。',
  ),
  selfEmployed(
    'self_employed',
    '独当一面者',
    '🚀',
    '创业者/自由职业/斜杠青年，时间自管理，推荐商业计划、客户跟进、'
    '接单流程、收入规划类清单。语气直接，关注结果和里程碑。',
  ),
  student(
    'student',
    '学生党',
    '📚',
    '按学期/考试节点作息，推荐课程安排、考试备考、知识整理、'
    '社团活动类清单。关注截止日期和打卡。',
  ),
  familyManager(
    'family_manager',
    '家庭掌舵人',
    '🏠',
    '管理家庭事务，推荐家务安排、采购清单、家庭日程、账单管理类清单。'
    '时间碎片化，清单要简洁直接。',
  ),
  newParent(
    'new_parent',
    '新手爸妈',
    '👶',
    '有0-6岁孩子，时间极碎片化，推荐育儿清单、宝宝成长记录、'
    '早教活动、儿科就诊类清单。语气温暖，提醒要轻柔。',
  ),

  // ── 生活方式类 ──────────────────────────────────────────────
  fitnessFan(
    'fitness_fan',
    '运动爱好者',
    '💪',
    '有规律运动习惯，推荐训练计划、运动打卡、营养管理、'
    '赛事准备类清单。关注数据记录和进步追踪。',
  ),
  lifeExplorer(
    'life_explorer',
    '生活探索者',
    '✨',
    '爱旅行、爱尝试新事物、爱体验，推荐旅行攻略、探店打卡、'
    '心愿清单、新技能挑战类清单。语气轻松有趣。',
  ),
  slowLiver(
    'slow_liver',
    '慢生活践行者',
    '🌿',
    '极简主义/仪式感/佛系，推荐断舍离、日常例程、'
    '冥想打卡、生活品质类清单。语气温和，不催促，节奏舒缓。',
  ),
  knowledgeSeeeker(
    'knowledge_seeker',
    '知识成长派',
    '🧠',
    '爱读书爱学习，自我驱动，推荐书单管理、学习计划、'
    '读书笔记、技能提升类清单。语气鼓励，关注成长进度。',
  ),
  healthConscious(
    'health_conscious',
    '健康管理者',
    '💚',
    '有慢病/康复/强健康意识，推荐用药记录、复查提醒、'
    '饮食管理、睡眠追踪类清单。语气关怀，提醒重要事项请遵医嘱。',
  );

  const PersonaArchetype(
      this.value, this.label, this.emoji, this.aiHint);
  final String value;
  final String label;
  final String emoji;

  /// 注入给 AI 的语义提示（直接驱动推荐策略和语气）
  final String aiHint;
}

// ─────────────────────────────────────────────────────────────────
//  第二层：细分兴趣标签
// ─────────────────────────────────────────────────────────────────

/// 细分兴趣标签的子组
enum DetailTagGroup {
  sports('sports', '运动与身体', '🏃'),
  food('food', '美食与生活', '🍜'),
  lifestyle('lifestyle', '生活方式', '🌿'),
  learning('learning', '学习与成长', '📚'),
  travel('travel', '旅行与探索', '✈️'),
  family('family', '家庭与宠物', '🐾'),
  creative('creative', '创意与表达', '🎨'),
  lifeStage('life_stage', '人生节点', '🗺️'),
  finance('finance', '财务与规划', '💰');

  const DetailTagGroup(this.value, this.label, this.emoji);
  final String value;
  final String label;
  final String emoji;
}

/// 细分兴趣标签
class DetailTag {
  final String value;
  final String label;
  final String emoji;
  final DetailTagGroup group;
  final String aiHint;

  const DetailTag({
    required this.value,
    required this.label,
    required this.emoji,
    required this.group,
    required this.aiHint,
  });
}

/// 所有细分兴趣标签
class DetailTags {
  DetailTags._();

  static const List<DetailTag> all = [
    // ══════════════════════════════════════════════════════
    //  运动与身体
    // ══════════════════════════════════════════════════════
    DetailTag(
      value: 'gym_regular',
      label: '健身房常客',
      emoji: '🏋️',
      group: DetailTagGroup.sports,
      aiHint: '需要训练计划、动作记录、营养管理清单',
    ),
    DetailTag(
      value: 'runner',
      label: '跑步机器',
      emoji: '👟',
      group: DetailTagGroup.sports,
      aiHint: '关注配速和里程数据，需要训练周期和比赛备战清单',
    ),
    DetailTag(
      value: 'cyclist',
      label: '骑行侠',
      emoji: '🚴',
      group: DetailTagGroup.sports,
      aiHint: '需要路线规划、装备维护、长途骑行准备清单',
    ),
    DetailTag(
      value: 'yoga_fan',
      label: '瑜伽修行者',
      emoji: '🧘',
      group: DetailTagGroup.sports,
      aiHint: '重视身心平衡，需要冥想记录、练习打卡清单',
    ),
    DetailTag(
      value: 'hiker',
      label: '徒步党',
      emoji: '🥾',
      group: DetailTagGroup.sports,
      aiHint: '需要路线攻略、装备清单、安全准备清单',
    ),
    DetailTag(
      value: 'camper',
      label: '露营人',
      emoji: '⛺',
      group: DetailTagGroup.sports,
      aiHint: '需要装备打包清单、营地规划、食物准备清单',
    ),
    DetailTag(
      value: 'climber',
      label: '攀岩者',
      emoji: '🧗',
      group: DetailTagGroup.sports,
      aiHint: '需要装备安全检查、训练计划清单',
    ),
    DetailTag(
      value: 'swimmer',
      label: '游泳选手',
      emoji: '🏊',
      group: DetailTagGroup.sports,
      aiHint: '规律打卡，需要训练数据记录清单',
    ),
    DetailTag(
      value: 'losing_weight',
      label: '减脂进行时',
      emoji: '🔥',
      group: DetailTagGroup.sports,
      aiHint: '当下有明确目标，需要饮食记录+运动打卡双线管理清单',
    ),
    DetailTag(
      value: 'marathon_prep',
      label: '马拉松备战中',
      emoji: '🏅',
      group: DetailTagGroup.sports,
      aiHint: '训练周期明确，需要里程碑和赛前准备清单',
    ),

    // ══════════════════════════════════════════════════════
    //  美食与生活
    // ══════════════════════════════════════════════════════
    DetailTag(
      value: 'foodie',
      label: '美食鉴赏家',
      emoji: '🍽️',
      group: DetailTagGroup.food,
      aiHint: '需要餐厅收藏、探店记录、踩雷提醒清单',
    ),
    DetailTag(
      value: 'home_cook',
      label: '下厨实验家',
      emoji: '🍳',
      group: DetailTagGroup.food,
      aiHint: '需要食谱管理、食材采购、烹饪步骤清单',
    ),
    DetailTag(
      value: 'coffee_lover',
      label: '咖啡研究员',
      emoji: '☕',
      group: DetailTagGroup.food,
      aiHint: '有仪式感，需要咖啡豆收藏、冲泡记录清单',
    ),
    DetailTag(
      value: 'baker',
      label: '烘焙爱好者',
      emoji: '🧁',
      group: DetailTagGroup.food,
      aiHint: '需要精准材料清单、烘焙步骤、工具采购清单',
    ),
    DetailTag(
      value: 'vegan',
      label: '素食践行者',
      emoji: '🥗',
      group: DetailTagGroup.food,
      aiHint: '有饮食理念，需要营养搭配、食材替换、外出就餐清单',
    ),
    DetailTag(
      value: 'tea_lover',
      label: '茶道爱好者',
      emoji: '🍵',
      group: DetailTagGroup.food,
      aiHint: '需要茶叶收藏、茶具管理、泡茶记录清单',
    ),

    // ══════════════════════════════════════════════════════
    //  生活方式
    // ══════════════════════════════════════════════════════
    DetailTag(
      value: 'minimalist',
      label: '极简主义者',
      emoji: '🪴',
      group: DetailTagGroup.lifestyle,
      aiHint: '推荐断舍离清单、物品管理、反消费决策清单',
    ),
    DetailTag(
      value: 'ritual_master',
      label: '仪式感大师',
      emoji: '🕯️',
      group: DetailTagGroup.lifestyle,
      aiHint: '清单本身是享受，需要晨间例程、日常仪式、节日准备清单',
    ),
    DetailTag(
      value: 'early_riser',
      label: '早起俱乐部',
      emoji: '🌅',
      group: DetailTagGroup.lifestyle,
      aiHint: '需要晨间例程、早起打卡、习惯养成清单',
    ),
    DetailTag(
      value: 'organizer',
      label: '整理控',
      emoji: '🗂️',
      group: DetailTagGroup.lifestyle,
      aiHint: '需要整理收纳、物品归类、空间规划清单',
    ),
    DetailTag(
      value: 'eco_conscious',
      label: '环保主义者',
      emoji: '♻️',
      group: DetailTagGroup.lifestyle,
      aiHint: '需要绿色消费、减少浪费、可持续生活清单',
    ),
    DetailTag(
      value: 'meditator',
      label: '冥想爱好者',
      emoji: '🌸',
      group: DetailTagGroup.lifestyle,
      aiHint: '重视内心状态，需要冥想打卡、情绪记录清单',
    ),
    DetailTag(
      value: 'night_owl',
      label: '夜猫子',
      emoji: '🦉',
      group: DetailTagGroup.lifestyle,
      aiHint: '晚上效率高，提醒时间建议调整到深夜，注意作息改善建议',
    ),
    DetailTag(
      value: 'digital_detox',
      label: '数字戒断中',
      emoji: '📵',
      group: DetailTagGroup.lifestyle,
      aiHint: '有意识管理手机时间，需要屏幕时间记录、专注打卡清单',
    ),

    // ══════════════════════════════════════════════════════
    //  学习与成长
    // ══════════════════════════════════════════════════════
    DetailTag(
      value: 'bookworm',
      label: '书虫',
      emoji: '📖',
      group: DetailTagGroup.learning,
      aiHint: '需要书单管理、读书笔记、阅读打卡清单',
    ),
    DetailTag(
      value: 'podcast_addict',
      label: '播客成瘾者',
      emoji: '🎧',
      group: DetailTagGroup.learning,
      aiHint: '碎片化学习，需要收听清单、内容整理清单',
    ),
    DetailTag(
      value: 'language_learner',
      label: '语言学习者',
      emoji: '🗣️',
      group: DetailTagGroup.learning,
      aiHint: '每日打卡型，需要词汇记录、练习进度清单',
    ),
    DetailTag(
      value: 'exam_prep',
      label: '备考冲刺中',
      emoji: '✏️',
      group: DetailTagGroup.learning,
      aiHint: '有截止日期压力，需要备考打卡、知识点整理、模拟考复盘清单',
    ),
    DetailTag(
      value: 'side_hustler',
      label: '副业探索者',
      emoji: '💡',
      group: DetailTagGroup.learning,
      aiHint: '尝试新方向，需要技能学习、客户开发、收入记录清单',
    ),
    DetailTag(
      value: 'course_buyer',
      label: '知识付费用户',
      emoji: '🎓',
      group: DetailTagGroup.learning,
      aiHint: '买了很多课，需要课程进度追踪、笔记整理、学习打卡清单',
    ),

    // ══════════════════════════════════════════════════════
    //  旅行与探索
    // ══════════════════════════════════════════════════════
    DetailTag(
      value: 'traveler',
      label: '旅行家',
      emoji: '✈️',
      group: DetailTagGroup.travel,
      aiHint: '需要行程规划、打包清单、景点攻略、旅行预算清单',
    ),
    DetailTag(
      value: 'backpacker',
      label: '背包客',
      emoji: '🎒',
      group: DetailTagGroup.travel,
      aiHint: '极简出行，需要极简打包清单、预算管理、临时决策清单',
    ),
    DetailTag(
      value: 'city_wanderer',
      label: '城市漫游者',
      emoji: '🗺️',
      group: DetailTagGroup.travel,
      aiHint: '探索本地，需要探店打卡、隐藏地点、周边活动清单',
    ),
    DetailTag(
      value: 'road_tripper',
      label: '自驾游爱好者',
      emoji: '🚗',
      group: DetailTagGroup.travel,
      aiHint: '需要路线规划、车辆准备、沿途住宿清单',
    ),

    // ══════════════════════════════════════════════════════
    //  家庭与宠物
    // ══════════════════════════════════════════════════════
    DetailTag(
      value: 'cat_owner',
      label: '撸猫大师',
      emoji: '🐱',
      group: DetailTagGroup.family,
      aiHint: '需要宠物健康记录、疫苗提醒、用品采购、驱虫计划清单',
    ),
    DetailTag(
      value: 'dog_owner',
      label: '遛狗专家',
      emoji: '🐶',
      group: DetailTagGroup.family,
      aiHint: '需要日常遛狗打卡、宠物护理、医疗记录清单',
    ),
    DetailTag(
      value: 'plant_lover',
      label: '养花种菜',
      emoji: '🌱',
      group: DetailTagGroup.family,
      aiHint: '需要浇水周期提醒、施肥计划、植物健康记录清单',
    ),
    DetailTag(
      value: 'pregnant',
      label: '孕期记录者',
      emoji: '🤰',
      group: DetailTagGroup.family,
      aiHint: '需要孕周追踪、产检提醒、待产包、营养管理清单，语气温柔',
    ),
    DetailTag(
      value: 'caring_for_parents',
      label: '照顾父母',
      emoji: '👴',
      group: DetailTagGroup.family,
      aiHint: '需要用药提醒、复查安排、陪诊记录、紧急联系清单',
    ),
    DetailTag(
      value: 'aquarium_keeper',
      label: '鱼缸玩家',
      emoji: '🐠',
      group: DetailTagGroup.family,
      aiHint: '需要换水周期、喂食记录、水质检测、造景材料清单',
    ),

    // ══════════════════════════════════════════════════════
    //  创意与表达
    // ══════════════════════════════════════════════════════
    DetailTag(
      value: 'journaler',
      label: '手帐玩家',
      emoji: '📒',
      group: DetailTagGroup.creative,
      aiHint: '记录型用户，审美驱动，需要手帐素材、灵感收集清单',
    ),
    DetailTag(
      value: 'photographer',
      label: '摄影爱好者',
      emoji: '📷',
      group: DetailTagGroup.creative,
      aiHint: '需要拍摄清单、器材采购、外拍计划、后期流程清单',
    ),
    DetailTag(
      value: 'diy_crafter',
      label: 'DIY 手工客',
      emoji: '✂️',
      group: DetailTagGroup.creative,
      aiHint: '需要材料清单、制作步骤、工具采购清单',
    ),
    DetailTag(
      value: 'musician',
      label: '乐器练习生',
      emoji: '🎸',
      group: DetailTagGroup.creative,
      aiHint: '打卡型，需要练习计划、曲目清单、演出准备清单',
    ),
    DetailTag(
      value: 'writer',
      label: '写作爱好者',
      emoji: '✍️',
      group: DetailTagGroup.creative,
      aiHint: '需要写作计划、选题收集、投稿追踪清单',
    ),
    DetailTag(
      value: 'gamer',
      label: '游戏玩家',
      emoji: '🎮',
      group: DetailTagGroup.creative,
      aiHint: '需要游戏攻略、任务追踪、活动打卡、想玩清单',
    ),
    DetailTag(
      value: 'collector',
      label: '收藏爱好者',
      emoji: '🏆',
      group: DetailTagGroup.creative,
      aiHint: '需要收藏记录、心愿清单、价格追踪清单',
    ),

    // ══════════════════════════════════════════════════════
    //  人生节点（当下限时特征）
    // ══════════════════════════════════════════════════════
    DetailTag(
      value: 'job_hunting',
      label: '准备跳槽了',
      emoji: '🔍',
      group: DetailTagGroup.lifeStage,
      aiHint: '需要简历准备、投递追踪、面试复盘、offer对比清单',
    ),
    DetailTag(
      value: 'new_employee',
      label: '刚入职的新人',
      emoji: '🌱',
      group: DetailTagGroup.lifeStage,
      aiHint: '需要入职清单、熟悉流程、前90天目标清单',
    ),
    DetailTag(
      value: 'wedding_planning',
      label: '婚礼筹备中',
      emoji: '💍',
      group: DetailTagGroup.lifeStage,
      aiHint: '高密度清单需求，需要供应商管理、宾客名单、时间节点清单',
    ),
    DetailTag(
      value: 'moving',
      label: '刚搬新家',
      emoji: '📦',
      group: DetailTagGroup.lifeStage,
      aiHint: '需要装修验收、采购清单、手续办理、搬家打包清单',
    ),
    DetailTag(
      value: 'startup_early',
      label: '创业第一年',
      emoji: '💡',
      group: DetailTagGroup.lifeStage,
      aiHint: '需要MVP验证、种子用户、产品迭代、团队搭建清单',
    ),
    DetailTag(
      value: 'saving_money',
      label: '存钱大作战',
      emoji: '🐷',
      group: DetailTagGroup.lifeStage,
      aiHint: '需要预算管理、消费记录、目标倒计时清单',
    ),
    DetailTag(
      value: 'buying_house',
      label: '买房计划中',
      emoji: '🏡',
      group: DetailTagGroup.lifeStage,
      aiHint: '需要看房记录、贷款计算、选房对比、流程追踪清单',
    ),
    DetailTag(
      value: 'graduation',
      label: '毕业过渡期',
      emoji: '🎓',
      group: DetailTagGroup.lifeStage,
      aiHint: '人生转折，需要求职清单、入职准备、独立生活清单',
    ),

    // ══════════════════════════════════════════════════════
    //  财务与规划
    // ══════════════════════════════════════════════════════
    DetailTag(
      value: 'finance_newbie',
      label: '理财新手',
      emoji: '📊',
      group: DetailTagGroup.finance,
      aiHint: '需要入门学习、基金定投、理财目标清单',
    ),
    DetailTag(
      value: 'budget_tracker',
      label: '记账强迫症',
      emoji: '🔢',
      group: DetailTagGroup.finance,
      aiHint: '精细化财务管理，需要月度预算、分类记账清单',
    ),
    DetailTag(
      value: 'investor',
      label: '投资研究员',
      emoji: '📈',
      group: DetailTagGroup.finance,
      aiHint: '需要投资复盘、持仓管理、学习笔记清单',
    ),
  ];

  /// 按子组筛选
  static List<DetailTag> byGroup(DetailTagGroup group) =>
      all.where((t) => t.group == group).toList();

  /// 根据 value 查找（找不到返回 null）
  static DetailTag? fromValue(String value) {
    try {
      return all.firstWhere((t) => t.value == value);
    } catch (_) {
      return null;
    }
  }
}

// ─────────────────────────────────────────────────────────────────
//  第三层：行为推断标签（AI 自动推断，用户无感知）
// ─────────────────────────────────────────────────────────────────

/// 行为推断规则
///
/// 当用户的清单标题/事项包含某些关键词时，自动追加对应的 AI 画像提示
class InferredTagRule {
  /// 触发关键词列表（包含任意一个即触发）
  final List<String> keywords;

  /// 推断出的行为标签
  final String inferredLabel;

  /// 注入给 AI 的语义提示
  final String aiHint;

  const InferredTagRule({
    required this.keywords,
    required this.inferredLabel,
    required this.aiHint,
  });
}

/// 所有行为推断规则
class InferredTagRules {
  InferredTagRules._();

  static const List<InferredTagRule> all = [
    InferredTagRule(
      keywords: ['健身', '训练', '跑步', '骑行', '瑜伽', '游泳', '运动', '撸铁', '健身房'],
      inferredLabel: '活跃运动者',
      aiHint: '用户经常创建运动相关清单，推荐训练计划和健康管理类清单',
    ),
    InferredTagRule(
      keywords: ['旅行', '出发', '打包', '攻略', '景点', '酒店', '机票', '行程'],
      inferredLabel: '旅行爱好者',
      aiHint: '用户经常创建旅行相关清单，推荐旅行规划和行李打包类清单',
    ),
    InferredTagRule(
      keywords: ['宝宝', '孩子', '育儿', '幼儿园', '辅食', '疫苗', '早教'],
      inferredLabel: '育儿中的父母',
      aiHint: '用户有育儿相关清单，推荐亲子活动和成长记录类清单',
    ),
    InferredTagRule(
      keywords: ['读书', '书单', '笔记', '学习', '课程', '备考', '考试', '知识'],
      inferredLabel: '持续学习者',
      aiHint: '用户经常创建学习相关清单，推荐知识管理和技能提升类清单',
    ),
    InferredTagRule(
      keywords: ['减肥', '减脂', '体重', '饮食', '卡路里', '热量', '碳水'],
      inferredLabel: '健康饮食关注者',
      aiHint: '用户有健康饮食相关清单，推荐营养管理和体重追踪类清单',
    ),
    InferredTagRule(
      keywords: ['工作', '项目', '需求', '会议', '汇报', 'deadline', '任务', '上班'],
      inferredLabel: '高效工作者',
      aiHint: '用户有大量工作任务清单，推荐效率工具和项目管理类清单',
    ),
    InferredTagRule(
      keywords: ['购物', '采购', '买', '清单', '超市', '食材', '物品'],
      inferredLabel: '精细生活管理者',
      aiHint: '用户经常使用购物采购清单，推荐家庭管理类清单',
    ),
    InferredTagRule(
      keywords: ['药', '用药', '复查', '医院', '体检', '血糖', '血压', '康复'],
      inferredLabel: '健康管理需求强',
      aiHint: '用户有医疗健康类清单，推荐健康追踪和用药提醒类清单，提醒重要事项请遵医嘱',
    ),
    InferredTagRule(
      keywords: ['存钱', '理财', '预算', '记账', '支出', '收入', '投资'],
      inferredLabel: '财务规划关注者',
      aiHint: '用户有财务管理类清单，推荐记账和财务规划类清单',
    ),
    InferredTagRule(
      keywords: ['装修', '搬家', '家居', '布置', '收纳', '整理', '断舍离'],
      inferredLabel: '生活品质追求者',
      aiHint: '用户有家居整理类清单，推荐收纳整理和家居管理类清单',
    ),
  ];
}

// ─────────────────────────────────────────────────────────────────
//  UserProfile —— 用户个人档案
// ─────────────────────────────────────────────────────────────────

class UserProfile {
  /// 用户昵称
  final String nickname;

  /// AI 助手的称呼
  final String aiName;

  /// 用户自定义补充描述（自由文本）
  final String customDescription;

  // ── 第一层：人物原型大标签（Onboarding 时填写）────────────────
  /// 已选的人物原型 value 列表
  /// 例如：['office_worker', 'knowledge_seeker']
  final List<String> personaValues;

  // ── 第二层：细分兴趣标签（设置页可选）───────────────────────
  /// 已选的细分兴趣标签 value 列表
  /// 例如：['bookworm', 'cyclist', 'foodie']
  final List<String> detailTagValues;

  // ── 旧字段（历史兼容）───────────────────────────────────────
  // ignore: deprecated_member_use_from_same_package
  final UserIdentityType identityType;
  final String primaryGoal;
  // ignore: deprecated_member_use_from_same_package
  final UserMotivation? motivation;
  // ignore: deprecated_member_use_from_same_package
  final UserBarrier? mainBarrier;
  final bool hasCompletedPortrait;

  // 向后兼容别名（旧代码用 profileTagValues / lifestyleTagValues）
  List<String> get profileTagValues => personaValues;
  List<String> get lifestyleTagValues => personaValues;

  const UserProfile({
    this.nickname = '',
    this.aiName = '小瞬',
    this.customDescription = '',
    this.personaValues = const [],
    this.detailTagValues = const [],
    // 旧字段
    // ignore: deprecated_member_use_from_same_package
    this.identityType = UserIdentityType.general,
    this.primaryGoal = '',
    this.motivation,
    this.mainBarrier,
    this.hasCompletedPortrait = false,
  });

  // ── 查询方法 ─────────────────────────────────────────────────

  /// 获取已选的人物原型列表
  List<PersonaArchetype> get personas => personaValues
      .map((v) {
        try {
          return PersonaArchetype.values.firstWhere((e) => e.value == v);
        } catch (_) {
          return null;
        }
      })
      .whereType<PersonaArchetype>()
      .toList();

  /// 获取已选的细分标签列表
  List<DetailTag> get detailTags =>
      detailTagValues.map(DetailTags.fromValue).whereType<DetailTag>().toList();

  /// 是否已建立基本画像
  bool get hasProfile =>
      personaValues.isNotEmpty || nickname.isNotEmpty;

  /// 总标签数量
  int get totalTagCount => personaValues.length + detailTagValues.length;

  // ── copyWith ─────────────────────────────────────────────────

  UserProfile copyWith({
    String? nickname,
    String? aiName,
    String? customDescription,
    List<String>? personaValues,
    List<String>? detailTagValues,
    // 旧字段兼容
    // ignore: deprecated_member_use_from_same_package
    UserIdentityType? identityType,
    String? primaryGoal,
    // ignore: deprecated_member_use_from_same_package
    UserMotivation? motivation,
    // ignore: deprecated_member_use_from_same_package
    UserBarrier? mainBarrier,
    bool? hasCompletedPortrait,
    bool clearMotivation = false,
    bool clearBarrier = false,
    // 旧 key 兼容
    List<String>? profileTagValues,
    List<String>? lifestyleTagValues,
  }) {
    return UserProfile(
      nickname: nickname ?? this.nickname,
      aiName: aiName ?? this.aiName,
      customDescription: customDescription ?? this.customDescription,
      personaValues: personaValues ??
          profileTagValues ??
          lifestyleTagValues ??
          this.personaValues,
      detailTagValues: detailTagValues ?? this.detailTagValues,
      identityType: identityType ?? this.identityType,
      primaryGoal: primaryGoal ?? this.primaryGoal,
      motivation:
          clearMotivation ? null : (motivation ?? this.motivation),
      mainBarrier:
          clearBarrier ? null : (mainBarrier ?? this.mainBarrier),
      hasCompletedPortrait:
          hasCompletedPortrait ?? this.hasCompletedPortrait,
    );
  }

  // ── 序列化 ───────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
        'nickname': nickname,
        'aiName': aiName,
        'customDescription': customDescription,
        'personaValues': personaValues,
        'detailTagValues': detailTagValues,
        // 旧字段保留
        'identityType': identityType.value,
        'primaryGoal': primaryGoal,
        'motivation': motivation?.value,
        'mainBarrier': mainBarrier?.value,
        'hasCompletedPortrait': hasCompletedPortrait,
        // 旧 key 别名
        'profileTagValues': personaValues,
        'lifestyleTagValues': personaValues,
      };

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    // 新 key 优先，fallback 到旧 key
    final personaVals =
        (map['personaValues'] as List<dynamic>? ??
                map['profileTagValues'] as List<dynamic>? ??
                map['lifestyleTagValues'] as List<dynamic>? ??
                [])
            .map((e) => e.toString())
            .toList();

    final detailVals =
        (map['detailTagValues'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList();

    return UserProfile(
      nickname: map['nickname'] as String? ?? '',
      aiName: map['aiName'] as String? ?? '小瞬',
      customDescription: map['customDescription'] as String? ?? '',
      personaValues: personaVals,
      detailTagValues: detailVals,
      // ignore: deprecated_member_use_from_same_package
      identityType: UserIdentityType.values.firstWhere(
        (e) => e.value == map['identityType'],
        // ignore: deprecated_member_use_from_same_package
        orElse: () => UserIdentityType.general,
      ),
      primaryGoal: map['primaryGoal'] as String? ?? '',
      // ignore: deprecated_member_use_from_same_package
      motivation: map['motivation'] != null
          // ignore: deprecated_member_use_from_same_package
          ? UserMotivation.values.firstWhere(
              (e) => e.value == map['motivation'],
              // ignore: deprecated_member_use_from_same_package
              orElse: () => UserMotivation.unknown,
            )
          : null,
      // ignore: deprecated_member_use_from_same_package
      mainBarrier: map['mainBarrier'] != null
          // ignore: deprecated_member_use_from_same_package
          ? UserBarrier.values.firstWhere(
              (e) => e.value == map['mainBarrier'],
              // ignore: deprecated_member_use_from_same_package
              orElse: () => UserBarrier.firstTime,
            )
          : null,
      hasCompletedPortrait:
          map['hasCompletedPortrait'] as bool? ?? false,
    );
  }

  // ── AI System Prompt 生成 ────────────────────────────────────

  /// 生成注入给 AI 的用户上下文（三层叠加）
  ///
  /// [checklistTitles] 用户当前清单的标题列表，用于第三层行为推断
  String buildAiPersonaContext({List<String> checklistTitles = const []}) {
    final name = nickname.isNotEmpty ? nickname : '用户';
    final buffer = StringBuffer();

    buffer.writeln('用户昵称：「$name」');

    // ── 第一层：人物原型（权重最高）─────────────────────────────
    final archetypes = personas;
    if (archetypes.isNotEmpty) {
      buffer.writeln('\n【用户画像·核心】');
      for (final p in archetypes) {
        buffer.writeln('• ${p.emoji} ${p.label}：${p.aiHint}');
      }
    }

    // ── 第三层：行为推断（从清单行为推断，权重次之）────────────
    if (checklistTitles.isNotEmpty) {
      final allText = checklistTitles.join(' ');
      final inferredHints = <String>[];
      for (final rule in InferredTagRules.all) {
        final hit = rule.keywords.any((kw) => allText.contains(kw));
        if (hit) {
          inferredHints.add('• 📊 ${rule.inferredLabel}（行为推断）：${rule.aiHint}');
        }
      }
      if (inferredHints.isNotEmpty) {
        buffer.writeln('\n【用户画像·行为推断】');
        for (final h in inferredHints) {
          buffer.writeln(h);
        }
      }
    }

    // ── 第二层：细分兴趣标签（补充信息）────────────────────────
    final details = detailTags;
    if (details.isNotEmpty) {
      buffer.writeln('\n【用户画像·兴趣偏好】');
      for (final t in details) {
        buffer.writeln('• ${t.emoji} ${t.label}：${t.aiHint}');
      }
    }

    // 补充说明
    if (customDescription.isNotEmpty) {
      buffer.writeln('\n【用户补充说明】$customDescription');
    }

    // 旧字段兜底（无新标签时使用）
    if (archetypes.isEmpty && details.isEmpty) {
      if (primaryGoal.isNotEmpty) {
        buffer.writeln('\n【近期目标】$primaryGoal');
      }
    }

    return buffer.toString().trim();
  }

  /// 向后兼容属性（旧代码引用）
  String get aiPersonaContext => buildAiPersonaContext();
}

// ─────────────────────────────────────────────────────────────────
//  向后兼容别名
//  旧代码引用了 ProfileTag / ProfileTags / ProfileDimension /
//  LifestyleTag / LifestyleTags / LifestyleTagGroup
//  保留这些 typedef 让旧代码不报错
// ─────────────────────────────────────────────────────────────────

/// 统一的画像标签（向后兼容，映射到 DetailTag）
typedef ProfileTag = DetailTag;
typedef LifestyleTag = DetailTag;

/// 标签静态数据库（向后兼容）
class ProfileTags {
  ProfileTags._();
  static List<DetailTag> get all => DetailTags.all;
  static List<DetailTag> byDimension(dynamic dim) {
    if (dim is DetailTagGroup) return DetailTags.byGroup(dim);
    return DetailTags.all;
  }
  static DetailTag? fromValue(String value) => DetailTags.fromValue(value);
  static List<DetailTag> byGroup(dynamic group) {
    if (group is DetailTagGroup) return DetailTags.byGroup(group);
    return DetailTags.all;
  }
}

typedef LifestyleTags = ProfileTags;

/// 维度枚举（向后兼容，映射到 DetailTagGroup）
typedef ProfileDimension = DetailTagGroup;
typedef LifestyleTagGroup = DetailTagGroup;
