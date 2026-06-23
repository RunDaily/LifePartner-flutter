import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'platform/service_locator.dart';
import 'widgets/ai_debug_overlay.dart';
import 'providers/theme_provider.dart';
import 'providers/cursor_style_provider.dart';
import 'providers/user_profile_provider.dart';
import 'providers/energy_provider.dart';
import 'providers/record_provider.dart';
import 'providers/goal_provider.dart';
import 'providers/project_provider.dart';
import 'providers/habit_provider.dart';
import 'providers/checklist_provider.dart';
import 'providers/activity_collection_provider.dart';
import 'providers/project_section_provider.dart';
import 'screens/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化中文日期格式
  await initializeDateFormatting('zh_CN', null);

  // 初始化平台服务（数据库等）
  await ServiceLocator.initialize();

  // 设置状态栏透明（移动端生效）
  if (!kIsWeb) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => CursorStyleProvider()),
        ChangeNotifierProvider(create: (_) => UserProfileProvider()),
        ChangeNotifierProvider(create: (_) => EnergyProvider()),
        // ★ 核心数据层
        ChangeNotifierProvider(create: (_) => GoalProvider()),
        ChangeNotifierProvider(create: (_) => ProjectProvider()),
        ChangeNotifierProvider(create: (_) => ProjectSectionProvider()),
        ChangeNotifierProvider(create: (_) => HabitProvider()),
        ChangeNotifierProvider(create: (_) => ChecklistProvider()),
ChangeNotifierProvider(create: (_) => RecordProvider()),
ChangeNotifierProvider(create: (_) => ActivityCollectionProvider()),
],
      child: const LifeOSApp(),
    ),
  );
}

class LifeOSApp extends StatelessWidget {
  const LifeOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp(
          title: '瞬时',
          debugShowCheckedModeBanner: false,
          theme: themeProvider.lightThemeData,
          darkTheme: themeProvider.darkThemeData,
          themeMode: themeProvider.themeMode,
          home: const MainShell(),
          builder: (context, child) {
            final content = MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.noScaling,
              ),
              child: child!,
            );
            if (kDebugMode) {
              return AiDebugOverlayWrapper(child: content);
            }
            return content;
          },
        );
      },
    );
  }
}
