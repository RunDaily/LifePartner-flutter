/// 服务定位器 - 平台无缝切换的核心
///
/// ╔══════════════════════════════════════════════════════════════╗
/// ║               三端兼容架构说明                                ║
/// ╠══════════════════════════════════════════════════════════════╣
/// ║  平台       SDK                  切换方式                    ║
/// ║  Android   官方 Flutter SDK     默认，无需任何修改            ║
/// ║  iOS       官方 Flutter SDK     默认，无需任何修改            ║
/// ║  Web       官方 Flutter SDK     自动检测，内存存储预览         ║
/// ║  鸿蒙      flutter-ohos SDK     仅修改平台 import            ║
/// ╚══════════════════════════════════════════════════════════════╝
library;

import 'package:flutter/foundation.dart' show kIsWeb;

import 'kv_store_service.dart';
import 'record_db_service.dart';
import 'goal_db_service.dart';
import 'project_db_service.dart';
import 'project_section_db_service.dart';
import 'habit_db_service.dart';
import 'checklist_db_service.dart';
// ── Web 平台实现（内存存储）──────────────────────────────────────
import 'kv_store_service_web.dart' as web_kv_impl;
import 'record_db_service_web.dart' as web_record_impl;
import 'goal_db_service_web.dart' as web_goal_impl;
import 'project_db_service_web.dart' as web_project_impl;
import 'project_section_db_service_web.dart' as web_section_impl;
import 'habit_db_service_web.dart' as web_habit_impl;
import 'checklist_db_service_web.dart' as web_checklist_impl;
// ══════════════════════════════════════════════════════════════
//  ⬇️  平台切换开关 - 只需修改下面的 import ⬇️
// ══════════════════════════════════════════════════════════════

// ✅ Android / iOS（默认）
import 'kv_store_service_mobile.dart' as kv_impl;
import 'record_db_service_mobile.dart' as record_impl;
import 'goal_db_service_mobile.dart' as goal_impl;
import 'project_db_service_mobile.dart' as project_impl;
import 'project_section_db_service_mobile.dart' as section_impl;
import 'habit_db_service_mobile.dart' as habit_impl;
import 'checklist_db_service_mobile.dart' as checklist_impl;
// 🔄 HarmonyOS - 切换鸿蒙时，注释上面的 import，取消注释下面的：
// import 'kv_store_service_ohos.dart' as kv_impl;
// import 'record_db_service_mobile.dart' as record_impl;
// import 'goal_db_service_mobile.dart' as goal_impl;
// import 'project_db_service_mobile.dart' as project_impl;
// import 'habit_db_service_mobile.dart' as habit_impl;

// ══════════════════════════════════════════════════════════════

/// 全局服务定位器
class ServiceLocator {
  ServiceLocator._();

  static KvStoreService? _kvStore;
  static RecordDbService? _recordDb;
  static GoalDbService? _goalDb;
  static ProjectDbService? _projectDb;
  static ProjectSectionDbService? _sectionDb;
  static HabitDbService? _habitDb;
  static ChecklistDbService? _checklistDb;
  /// KV 存储服务（用户偏好等）
  static KvStoreService get kvStore {
    _kvStore ??= kIsWeb ? web_kv_impl.createKvStore() : kv_impl.createKvStore();
    return _kvStore!;
  }

  /// 记录数据库服务 ★ 核心
  static RecordDbService get recordDb {
    _recordDb ??= kIsWeb ? web_record_impl.createRecordDb() : record_impl.createRecordDb();
    return _recordDb!;
  }

  /// 目标数据库服务
  static GoalDbService get goalDb {
    _goalDb ??= kIsWeb ? web_goal_impl.createGoalDb() : goal_impl.createGoalDb();
    return _goalDb!;
  }

  /// 项目数据库服务
  static ProjectDbService get projectDb {
    _projectDb ??= kIsWeb ? web_project_impl.createProjectDb() : project_impl.createProjectDb();
    return _projectDb!;
  }

  /// 版块数据库服务
  static ProjectSectionDbService get sectionDb {
    _sectionDb ??= kIsWeb
        ? web_section_impl.createProjectSectionDb()
        : section_impl.createProjectSectionDb();
    return _sectionDb!;
  }

  /// 习惯数据库服务
  static HabitDbService get habitDb {
    _habitDb ??= kIsWeb ? web_habit_impl.createHabitDb() : habit_impl.createHabitDb();
    return _habitDb!;
  }

  /// 清单数据库服务
  static ChecklistDbService get checklistDb {
    _checklistDb ??= kIsWeb
        ? web_checklist_impl.createChecklistDb()
        : checklist_impl.createChecklistDb();
    return _checklistDb!;
  }
  /// 应用启动时调用，预热服务
  static Future<void> initialize() async {
    // ignore: unnecessary_statements
    kvStore;
    // ignore: unnecessary_statements
    recordDb;
    // ignore: unnecessary_statements
    goalDb;
    // ignore: unnecessary_statements
    projectDb;
    // ignore: unnecessary_statements
    sectionDb;
    // ignore: unnecessary_statements
    habitDb;
    // ignore: unnecessary_statements
    checklistDb;
  }

  /// 测试时替换实现（依赖注入）
  static void overrideKvStore(KvStoreService impl) => _kvStore = impl;
  static void overrideRecordDb(RecordDbService impl) => _recordDb = impl;
  static void overrideGoalDb(GoalDbService impl) => _goalDb = impl;
  static void overrideProjectDb(ProjectDbService impl) => _projectDb = impl;
  static void overrideSectionDb(ProjectSectionDbService impl) => _sectionDb = impl;
  static void overrideHabitDb(HabitDbService impl) => _habitDb = impl;
  static void overrideChecklistDb(ChecklistDbService impl) => _checklistDb = impl;
  /// 重置（测试用）
  static void reset() {
    _kvStore = null;
    _recordDb = null;
    _goalDb = null;
    _projectDb = null;
    _sectionDb = null;
    _habitDb = null;
    _checklistDb = null;
  }
}
