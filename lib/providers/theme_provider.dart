// ThemeProvider - 主题状态管理
// 使用 ServiceLocator.kvStore 读写主题偏好，
// 底层自动适配 shared_preferences（移动端）
// 或 shared_preferences_ohos（鸿蒙端）。
import 'package:flutter/material.dart';
import '../platform/service_locator.dart';
import '../theme/app_theme.dart';

class ThemeProvider extends ChangeNotifier {
  static const _themeKey = 'theme_mode';
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  // ── 每日调色板（根据今天的星期几自动返回）──

  /// 当天日间调色板
  DayPalette get todayLightPalette => WeeklyTheme.getLightPalette();

  /// 当天深色调色板
  DarkPalette get todayDarkPalette => WeeklyTheme.getDarkPalette();

  /// 当天的主色（跟随亮/暗模式返回对应主色）
  Color get todayPrimary =>
      isDarkMode ? todayDarkPalette.primary : todayLightPalette.primary;

  /// 当天的主色亮版
  Color get todayPrimaryLight =>
      isDarkMode ? todayDarkPalette.primaryLight : todayLightPalette.primaryLight;

  /// 便捷方法：根据 isDark 返回对应背景色
  Color get todayBackground => isDarkMode
      ? DarkPalette.background
      : todayLightPalette.background;

  /// 根据当前日期构建日间 ThemeData
  ThemeData get lightThemeData => AppTheme.lightTheme();

  /// 根据当前日期构建深色 ThemeData
  ThemeData get darkThemeData => AppTheme.darkTheme();

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final themeIndex =
        await ServiceLocator.kvStore.getInt(_themeKey) ??
        ThemeMode.system.index;
    _themeMode = ThemeMode.values[themeIndex];
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await ServiceLocator.kvStore.setInt(_themeKey, mode.index);
  }

  Future<void> toggleTheme() async {
    await setThemeMode(
      _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
    );
  }
}
