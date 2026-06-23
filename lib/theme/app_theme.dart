import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  每日调色板（日间模式专用）
//  一周 7 天，每天有独特的氛围色系
//  深色模式统一使用 DarkPalette（深灰近黑，只微调强调色）
// ─────────────────────────────────────────────────────────────────────────────

/// 单套日间调色板
class DayPalette {
  final String dayName; // 星期名（调试/展示用）
  final Color primary; // 主色
  final Color primaryLight; // 主色亮版（hover/渐变）
  final Color primaryDark; // 主色暗版
  final Color background; // 页面背景
  final Color surface; // 卡片/Surface 背景
  final List<Color> gradient; // 渐变背景（通常两色）
  final Color inputFill; // 输入框填充色
  final Color hintText; // 提示文字色

  const DayPalette({
    required this.dayName,
    required this.primary,
    required this.primaryLight,
    required this.primaryDark,
    required this.background,
    required this.surface,
    required this.gradient,
    required this.inputFill,
    required this.hintText,
  });
}

/// 深色模式调色板（全周统一，仅强调色带微妙变化）
class DarkPalette {
  final Color primary; // 强调色（根据当天星期微调）
  final Color primaryLight;

  // 深灰背景一律固定
  static const Color background = Color(0xFF141414); // 近黑
  static const Color surface = Color(0xFF1E1E1E); // 深灰 Surface
  static const Color card = Color(0xFF252525); // 卡片
  static const Color inputFill = Color(0xFF2A2A2A);
  static const Color hintText = Color(0xFF666666);

  // 文字色固定
  static const Color textPrimary = Color(0xFFEEEEEE);
  static const Color textSecondary = Color(0xFFAAAAAA);
  static const Color textTertiary = Color(0xFF777777);

  static const List<Color> gradient = [Color(0xFF141414), Color(0xFF0A0A0A)];

  const DarkPalette({required this.primary, required this.primaryLight});
}

// ─────────────────────────────────────────────────────────────────────────────
//  WeeklyTheme：7 套日间调色板 + 7 套深色强调色
// ─────────────────────────────────────────────────────────────────────────────

class WeeklyTheme {
  // ── 7 套日间调色板（index 0 = 周一, … , 6 = 周日）──

  // ──────────────────────────────────────────────────────────────────────────
  //  配色主题：「时光流动」
  //
  //  应用名「瞬间」承载的核心意象是"记录当下、珍视流逝的时光"。
  //  主色选用 琥珀暖橙（Amber）：联想晨光、日出、温暖记忆，比紫色更有
  //  烟火气与亲近感，与"记录生活瞬间"高度契合。
  //
  //  一周节律：以暖橙为锚点，向两侧延伸不同情绪色温，形成自然的情绪节律：
  //  周一 橙金（新开始）→ 周二 琥珀蜂蜜（延续暖意）→ 周三 薄荷绿（清醒专注）
  //  → 周四 天蓝（平静中段）→ 周五 玫瑰珊瑚（期待放松）→ 周六 暖紫薰衣草
  //  （慵懒周末）→ 周日 暮橙夕阳（温柔收尾）
  // ──────────────────────────────────────────────────────────────────────────

  static const List<DayPalette> lightPalettes = [
    // 周一：橙金晨光 — 充满希望的新开始，暖意盎然
    // 这是整个 App 的基准主色，贯穿"瞬间"的核心气质
    DayPalette(
      dayName: '周一',
      primary: Color(0xFFE07818),      // 橙金，饱满有力
      primaryLight: Color(0xFFF5973A), // 亮橙，渐变高光
      primaryDark: Color(0xFFB85E08),  // 深橙，按压态
      background: Color(0xFFFFF8F0),   // 极浅暖白，透着橙意
      surface: Color(0xFFFFFFFF),
      gradient: [Color(0xFFFFF3E0), Color(0xFFFFEDD0)],
      inputFill: Color(0xFFFFF0DC),
      hintText: Color(0xFFCCA06A),
    ),

    // 周二：琥珀蜂蜜 — 暖意延续，沉稳中带甜
    DayPalette(
      dayName: '周二',
      primary: Color(0xFFC8870A),      // 琥珀棕橙
      primaryLight: Color(0xFFE4A52A),
      primaryDark: Color(0xFFA06800),
      background: Color(0xFFFFFAF0),
      surface: Color(0xFFFFFFFF),
      gradient: [Color(0xFFFFF6DC), Color(0xFFFFF0C0)],
      inputFill: Color(0xFFFFF2CC),
      hintText: Color(0xFFBB9040),
    ),

    // 周三：薄荷清绿 — 清醒、专注、充满活力的爬坡日
    DayPalette(
      dayName: '周三',
      primary: Color(0xFF2A9D6E),      // 清爽绿，不过于鲜亮
      primaryLight: Color(0xFF48B88A),
      primaryDark: Color(0xFF1A7A52),
      background: Color(0xFFF2FCF7),
      surface: Color(0xFFFFFFFF),
      gradient: [Color(0xFFE4F7EE), Color(0xFFD6F2E6)],
      inputFill: Color(0xFFDDF5EB),
      hintText: Color(0xFF7BBDA0),
    ),

    // 周四：天空晴蓝 — 清透沉静，周中的一口气
    DayPalette(
      dayName: '周四',
      primary: Color(0xFF2878CC),      // 经典天蓝，清透不沉闷
      primaryLight: Color(0xFF4A96E4),
      primaryDark: Color(0xFF185CA0),
      background: Color(0xFFF3F8FF),
      surface: Color(0xFFFFFFFF),
      gradient: [Color(0xFFE4EFFF), Color(0xFFD8E8FF)],
      inputFill: Color(0xFFDCECFF),
      hintText: Color(0xFF80AADD),
    ),

    // 周五：玫瑰珊瑚 — 轻盈愉悦，周末快到了
    DayPalette(
      dayName: '周五',
      primary: Color(0xFFD44470),      // 玫瑰粉，活泼不过艳
      primaryLight: Color(0xFFEC6490),
      primaryDark: Color(0xFFAC2A54),
      background: Color(0xFFFFF5F8),
      surface: Color(0xFFFFFFFF),
      gradient: [Color(0xFFFFE8F0), Color(0xFFFFDCE8)],
      inputFill: Color(0xFFFFE0EC),
      hintText: Color(0xFFD898B0),
    ),

    // 周六：暖紫薰衣草 — 慵懒、放松，给自己喘息的一天
    DayPalette(
      dayName: '周六',
      primary: Color(0xFF7E5FC0),      // 温柔薰衣草紫
      primaryLight: Color(0xFF9E80D8),
      primaryDark: Color(0xFF5C40A0),
      background: Color(0xFFF8F4FF),
      surface: Color(0xFFFFFFFF),
      gradient: [Color(0xFFFFF0DC), Color(0xFFE8E0FF)],
      inputFill: Color(0xFFEEE8FF),
      hintText: Color(0xFFAA98CC),
    ),

    // 周日：暮橙夕阳 — 温柔收尾，心里装着一周的故事
    DayPalette(
      dayName: '周日',
      primary: Color(0xFFCC5828),      // 夕阳橙红，比周一更沉更柔
      primaryLight: Color(0xFFE47848),
      primaryDark: Color(0xFFA83C14),
      background: Color(0xFFFFF6F2),
      surface: Color(0xFFFFFFFF),
      gradient: [Color(0xFFFFEDE0), Color(0xFFFFE4D0)],
      inputFill: Color(0xFFFFE6D8),
      hintText: Color(0xFFCC9878),
    ),
  ];

  // ── 7 套深色模式强调色（深灰近黑为底，强调色与日间色系呼应但更亮更轻盈）──
  static const List<DarkPalette> darkPalettes = [
    DarkPalette(primary: Color(0xFFF5973A), primaryLight: Color(0xFFFFB060)), // 周一：橙金
    DarkPalette(primary: Color(0xFFE4A52A), primaryLight: Color(0xFFF5BE48)), // 周二：琥珀
    DarkPalette(primary: Color(0xFF48B88A), primaryLight: Color(0xFF66D0A4)), // 周三：薄荷
    DarkPalette(primary: Color(0xFF4A96E4), primaryLight: Color(0xFF68B0F8)), // 周四：天蓝
    DarkPalette(primary: Color(0xFFEC6490), primaryLight: Color(0xFFFF85AA)), // 周五：玫瑰
    DarkPalette(primary: Color(0xFF9E80D8), primaryLight: Color(0xFFBCA0EE)), // 周六：薰衣草
    DarkPalette(primary: Color(0xFFE47848), primaryLight: Color(0xFFF59868)), // 周日：暮橙
  ];

  /// 根据当前星期几返回日间调色板（DateTime.weekday: 1=周一 … 7=周日）
  static DayPalette getLightPalette([DateTime? date]) {
    final day = (date ?? DateTime.now()).weekday; // 1~7
    return lightPalettes[day - 1];
  }

  /// 根据当前星期几返回深色调色板
  static DarkPalette getDarkPalette([DateTime? date]) {
    final day = (date ?? DateTime.now()).weekday;
    return darkPalettes[day - 1];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  AppColors：兼容旧代码的静态访问入口
//  建议新代码直接通过 WeeklyTheme.getLightPalette() 获取当天颜色
// ─────────────────────────────────────────────────────────────────────────────

class AppColors {
  // ── 从当天调色板获取（便捷方法，始终返回今天的颜色）──
  static Color get primary => WeeklyTheme.getLightPalette().primary;
  static Color get primaryLight => WeeklyTheme.getLightPalette().primaryLight;
  static Color get primaryDark => WeeklyTheme.getLightPalette().primaryDark;
  static Color get backgroundLight => WeeklyTheme.getLightPalette().background;
  static Color get surfaceLight => WeeklyTheme.getLightPalette().surface;
  static Color get cardLight => WeeklyTheme.getLightPalette().surface;

  // ── 深色模式（固定深灰，强调色微变）──
  static Color get darkPrimary => WeeklyTheme.getDarkPalette().primary;
  static Color get darkPrimaryLight => WeeklyTheme.getDarkPalette().primaryLight;
  static const Color backgroundDark = DarkPalette.background;
  static const Color surfaceDark = DarkPalette.surface;
  static const Color cardDark = DarkPalette.card;
  static const Color inputFillDark = DarkPalette.inputFill;
  static const Color textPrimaryDark = DarkPalette.textPrimary;
  static const Color textSecondaryDark = DarkPalette.textSecondary;
  static const Color textTertiaryDark = DarkPalette.textTertiary;

  // ── 渐变背景（动态：随当天调色板变化）──
  static List<Color> get gradientLight => WeeklyTheme.getLightPalette().gradient;
  static List<Color> get gradientDark => DarkPalette.gradient;

  // ── 辅助色（固定不变）──
  static const secondary = Color(0xFFFF8A65);
  static const secondaryLight = Color(0xFFFFB74D);

  // ── 心情颜色（固定不变）──
  static const moodHappy = Color(0xFFFFD54F);
  static const moodExcited = Color(0xFFFF7043);
  static const moodNeutral = Color(0xFF90CAF9);
  static const moodTouched = Color(0xFFEF9AA0);
  static const moodSad = Color(0xFF80DEEA);
  static const moodAngry = Color(0xFFEF9A9A);
  static const moodAnxious = Color(0xFFCE93D8);
  static const moodTired = Color(0xFFB0BEC5);

  // 获取心情颜色
  static Color getMoodColor(String mood) {
    switch (mood) {
      case 'happy':
        return moodHappy;
      case 'excited':
        return moodExcited;
      case 'neutral':
        return moodNeutral;
      case 'touched':
        return moodTouched;
      case 'sad':
        return moodSad;
      case 'angry':
        return moodAngry;
      case 'anxious':
        return moodAnxious;
      case 'tired':
        return moodTired;
      default:
        return moodNeutral;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  RecordTypeStyle：记录类型视觉规范
//  与 today_screen.dart 的 _entryTypes 保持颜色/emoji/label 完全一致，
//  但以公共形式暴露，供 MomentCard、DetailScreen 等地方使用。
// ─────────────────────────────────────────────────────────────────────────────

class RecordTypeStyle {
  final String id;
  final String emoji;
  final String label;
  final Color color;

  const RecordTypeStyle({
    required this.id,
    required this.emoji,
    required this.label,
    required this.color,
  });

  /// 根据 recordTypeId 返回对应样式，找不到返回 null
  static RecordTypeStyle? of(String? id) {
    if (id == null) return null;
    try {
      return _all.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  static const List<RecordTypeStyle> _all = [
    RecordTypeStyle(
      id: 'plan',
      emoji: '📋',
      label: '计划',
      color: Color(0xFF4A90D9), // 蓝 — 理性/执行
    ),
    RecordTypeStyle(
      id: 'thought',
      emoji: '💭',
      label: '想法',
      color: Color(0xFF9B59B6), // 紫 — 感性/思考
    ),
    RecordTypeStyle(
      id: 'collect',
      emoji: '💎',
      label: '收藏',
      color: Color(0xFFE67E22), // 橙 — 价值/收藏
    ),
    RecordTypeStyle(
      id: 'event',
      emoji: '🎉',
label: '时刻',
color: Color(0xFF27AE60), // 绿 — 活跃/事件
    ),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
//  AppTheme：根据当天星期自动生成 ThemeData
// ─────────────────────────────────────────────────────────────────────────────

class AppTheme {
  /// 日间主题 —— 根据当天星期自动切换调色板
  static ThemeData lightTheme([DateTime? date]) {
    final p = WeeklyTheme.getLightPalette(date);
    return _buildLightTheme(p);
  }

  /// 深色主题 —— 深灰近黑，强调色随星期微变
  static ThemeData darkTheme([DateTime? date]) {
    final p = WeeklyTheme.getDarkPalette(date);
    return _buildDarkTheme(p);
  }

  // ── 内部构建方法 ──

  static ThemeData _buildLightTheme(DayPalette p) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: p.primary,
        brightness: Brightness.light,
        primary: p.primary,
        secondary: AppColors.secondary,
        surface: p.surface,
      ),
      scaffoldBackgroundColor: p.background,
      textTheme: GoogleFonts.notoSansScTextTheme().copyWith(
        displayLarge: GoogleFonts.notoSansSc(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF1A1410), // 暖黑，带极淡橙调
        ),
        headlineMedium: GoogleFonts.notoSansSc(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF2C221A), // 深暖棕
        ),
        titleLarge: GoogleFonts.notoSansSc(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF2C221A),
        ),
        bodyLarge: GoogleFonts.notoSansSc(
          fontSize: 16,
          color: const Color(0xFF3D3028), // 中暖棕，正文主力
        ),
        bodyMedium: GoogleFonts.notoSansSc(
          fontSize: 14,
          color: const Color(0xFF6A5848), // 浅暖棕，次要文字
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.notoSansSc(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: p.primary,
        ),
        iconTheme: IconThemeData(color: p.primary),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.primary,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.primary, width: 2),
        ),
        hintStyle: TextStyle(color: p.hintText),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
    );
  }

  static ThemeData _buildDarkTheme(DarkPalette p) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: p.primary,
        brightness: Brightness.dark,
        primary: p.primary,
        secondary: AppColors.secondaryLight,
        surface: DarkPalette.surface,
      ),
      scaffoldBackgroundColor: DarkPalette.background,
      textTheme: GoogleFonts.notoSansScTextTheme(ThemeData.dark().textTheme)
          .copyWith(
        displayLarge: GoogleFonts.notoSansSc(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: DarkPalette.textPrimary,
        ),
        headlineMedium: GoogleFonts.notoSansSc(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: DarkPalette.textPrimary,
        ),
        titleLarge: GoogleFonts.notoSansSc(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: DarkPalette.textPrimary,
        ),
        bodyLarge: GoogleFonts.notoSansSc(
          fontSize: 16,
          color: DarkPalette.textSecondary,
        ),
        bodyMedium: GoogleFonts.notoSansSc(
          fontSize: 14,
          color: DarkPalette.textTertiary,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.notoSansSc(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: p.primaryLight,
        ),
        iconTheme: IconThemeData(color: p.primaryLight),
      ),
      cardTheme: CardThemeData(
        color: DarkPalette.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.primary,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DarkPalette.inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.primary, width: 2),
        ),
        hintStyle: const TextStyle(color: DarkPalette.hintText),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
    );
  }
}
