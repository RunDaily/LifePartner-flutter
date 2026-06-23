import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/record.dart';
import '../platform/service_locator.dart';

// ─────────────────────────────────────────────────────────────────
//  RecordProvider —— 统一内容条目的状态管理
//
//  【域划分说明】
//  RecordProvider 按「空间 Tab」的 6 个功能模块边界管理数据：
//
//  ┌─────────────┬──────────────────────────┬────────────────────┐
//  │  域         │  RecordType              │  对应 Screen       │
//  ├─────────────┼──────────────────────────┼────────────────────┤
//  │  日记域     │  note / idea / mood      │  JournalScreen     │
//  │  知识域     │  collect / reading       │  NotesScreen       │
//  │  活动域     │  event / habitLog        │  ActivityScreen    │
//  │  项目域附属 │  review / transaction    │  PlanScreen        │
//  ├─────────────┼──────────────────────────┼────────────────────┤
//  │  执行域(✝)  │  task/checkItem/schedule │  [已迁移→Checklist]│
//  └─────────────┴──────────────────────────┴────────────────────┘
//
//  ✝ 执行域：task/checkItem/schedule 在 RecordType 中标记为
//    @deprecated，新代码不应继续创建此类型 Record。
//    历史数据和 TodayScreen 的 todayTasks/todaySchedules 仍兼容
//    读取旧数据，但不应作为新功能的主要数据源。
// ─────────────────────────────────────────────────────────────────

class RecordProvider extends ChangeNotifier {
  List<Record> _allRecords = [];
  // ✝ 以下三个字段仍兼容读取执行域/活动域的遗留数据（TodayScreen 使用）
  List<Record> _todaySchedules = [];
  List<Record> _todayTasks = [];
  List<Record> _todayHabitLogs = [];

  bool _isLoading = false;
  bool _isAllLoaded = false;
  String? _error;

  // 按 projectId 缓存
  final Map<String, List<Record>> _projectRecordsCache = {};

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Record> get allRecords => _allRecords;
  List<Record> get todaySchedules => _todaySchedules;
  List<Record> get todayTasks => _todayTasks;
  List<Record> get todayHabitLogs => _todayHabitLogs;

  /// 今日活动记录（活动域：event 类型，extra.activityId 关联 ActivityDefinition）
  List<Record> get todayEvents {
    final now = DateTime.now();
    return _allRecords.where((r) {
      if (r.type != RecordType.event) return false;
      final t = r.scheduledAt ?? r.createdAt;
      return t.year == now.year && t.month == now.month && t.day == now.day;
    }).toList();
  }

  /// 今日心情记录（日记域：mood 类型）
  List<Record> get todayMoods {
    final now = DateTime.now();
    return _allRecords.where((r) {
      if (r.type != RecordType.mood) return false;
      return r.createdAt.year == now.year &&
          r.createdAt.month == now.month &&
          r.createdAt.day == now.day;
    }).toList();
  }

  // ══ 域过滤 getter ════════════════════════════════════════════
  // 对应空间 Tab 各模块，严格按域边界划分

  // ── 日记域（JournalScreen）────────────────────────────────────
  /// 日记域全量：笔记 / 灵感 / 心情
  List<Record> get journalRecords => _allRecords
      .where((r) => r.type.isJournalDomain)
      .toList();

  List<Record> get notes =>
      _allRecords.where((r) => r.type == RecordType.note).toList();
  List<Record> get ideas =>
      _allRecords.where((r) => r.type == RecordType.idea).toList();
  List<Record> get moods =>
      _allRecords.where((r) => r.type == RecordType.mood).toList();

  // ── 知识域（NotesScreen）─────────────────────────────────────
  /// 知识域全量：收藏 / 阅读
  List<Record> get knowledgeRecords => _allRecords
      .where((r) => r.type.isKnowledgeDomain)
      .toList();

  List<Record> get collects =>
      _allRecords.where((r) => r.type == RecordType.collect).toList();
  List<Record> get readings =>
      _allRecords.where((r) => r.type == RecordType.reading).toList();

  // ── 活动域（ActivityCollectionScreen）────────────────────────
  /// 活动域全量：活动记录 / 习惯打卡
  List<Record> get activityRecords => _allRecords
      .where((r) => r.type.isActivityDomain)
      .toList();

  List<Record> get events =>
      _allRecords.where((r) => r.type == RecordType.event).toList();
  List<Record> get habitLogs =>
      _allRecords.where((r) => r.type == RecordType.habitLog).toList();

  // ── 项目域附属（PlanScreen 使用）────────────────────────────
  List<Record> get projectDomainRecords => _allRecords
      .where((r) => r.type.isProjectDomain)
      .toList();

  /// 获取某个项目下的记录（有缓存则直接返回）
  List<Record> recordsForProject(String projectId) {
    return _projectRecordsCache[projectId] ?? [];
  }

  /// 获取某个项目下今日未完成任务数（用于 Today 提示）
  int pendingTaskCountForProject(String projectId) {
    return (_projectRecordsCache[projectId] ?? [])
        .where((r) =>
            (r.type == RecordType.task || r.type == RecordType.checkItem) &&
            !r.isCompleted)
        .length;
  }

  // ── 加载 ──────────────────────────────────────────────────────

  /// 加载今天相关数据（TodayScreen 使用）
  Future<void> loadTodayData() async {
    _isLoading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        ServiceLocator.recordDb.getTodaySchedules(),
        ServiceLocator.recordDb.getTodayTasks(),
        ServiceLocator.recordDb.getHabitLogsByDate(DateTime.now()),
      ]);
      _todaySchedules = results[0];
      _todayTasks = results[1];
      _todayHabitLogs = results[2];
    } catch (e) {
      _error = e.toString();
      debugPrint('Error loading today data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 全量加载（JournalScreen 使用）
  Future<void> loadAllRecords() async {
    if (_isAllLoaded) return;
    _isLoading = true;
    notifyListeners();
    try {
      _allRecords = await ServiceLocator.recordDb.getAllRecords();
      _isAllLoaded = true;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error loading all records: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 加载某个项目的记录
  Future<void> loadRecordsForProject(String projectId) async {
    try {
      _projectRecordsCache[projectId] =
          await ServiceLocator.recordDb.getRecordsByProjectId(projectId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading records for project $projectId: $e');
    }
  }

  // ── 增删改 ────────────────────────────────────────────────────

  Future<Record> addRecord({
    required RecordType type,
    String title = '',
    required String content,
    String? goalId,
    String? projectId,
    String? sectionId,
    String? habitId,
    DateTime? scheduledAt,
    DateTime? deadline,
    bool isAllDay = false,
    int reminderMinutes = -1,
    List<String> imagePaths = const [],
    String? url,
    bool isFavorite = false,
    List<String> contactIds = const [],
    double? amount,
    String? transactionCategory,
    String? mood,
    String? energy,
    String? location,
    String? weather,
    List<String> tags = const [],
    Map<String, dynamic> extra = const {},
  }) async {
    final now = DateTime.now();
    final record = Record(
      id: const Uuid().v4(),
      type: type,
      title: title,
      content: content,
      createdAt: now,
      updatedAt: now,
      goalId: goalId,
      projectId: projectId,
      sectionId: sectionId,
      habitId: habitId,
      scheduledAt: scheduledAt,
      deadline: deadline,
      isAllDay: isAllDay,
      reminderMinutes: reminderMinutes,
      imagePaths: imagePaths,
      url: url,
      isFavorite: isFavorite,
      contactIds: contactIds,
      amount: amount,
      transactionCategory: transactionCategory,
      mood: mood,
      energy: energy,
      location: location,
      weather: weather,
      tags: tags,
      extra: extra,
    );
    await ServiceLocator.recordDb.insertRecord(record);
    _addToLocalCaches(record);
    notifyListeners();
    return record;
  }

  Future<void> updateRecord(Record updated) async {
    final record = updated.copyWith(updatedAt: DateTime.now());
    await ServiceLocator.recordDb.updateRecord(record);
    _updateInLocalCaches(record);
    notifyListeners();
  }

  Future<void> deleteRecord(String id) async {
    await ServiceLocator.recordDb.deleteRecord(id);
    _removeFromLocalCaches(id);
    notifyListeners();
  }

  Future<void> toggleComplete(String id) async {
    final all = [..._allRecords, ..._todayTasks, ..._todaySchedules];
    Record? record;
    try {
      record = all.firstWhere((r) => r.id == id);
    } catch (_) {
      // 从数据库加载
      record = await ServiceLocator.recordDb.getRecordById(id);
    }
    if (record == null) return;
    final now = DateTime.now();
    final updated = record.copyWith(
      isCompleted: !record.isCompleted,
      completedAt: !record.isCompleted ? now : null,
      updatedAt: now,
    );
    await ServiceLocator.recordDb.updateRecord(updated);
    _updateInLocalCaches(updated);
    notifyListeners();
  }

  Future<void> toggleFavorite(String id) async {
    Record? record;
    try {
      record = _allRecords.firstWhere((r) => r.id == id);
    } catch (_) {
      record = await ServiceLocator.recordDb.getRecordById(id);
    }
    if (record == null) return;
    final updated = record.copyWith(
      isFavorite: !record.isFavorite,
      updatedAt: DateTime.now(),
    );
    await ServiceLocator.recordDb.updateRecord(updated);
    _updateInLocalCaches(updated);
    notifyListeners();
  }

  Future<List<Record>> search(String query) async {
    if (query.isEmpty) return [];
    return ServiceLocator.recordDb.searchRecords(query);
  }

  // ── 习惯打卡 ─────────────────────────────────────────────────

  /// 今天是否已经对某个习惯打卡
  bool isTodayCheckedIn(String habitId) {
    return _todayHabitLogs.any((r) => r.habitId == habitId);
  }

  /// 打卡习惯（创建一条 habitLog Record）
  Future<Record> checkInHabit({
    required String habitId,
    String content = '',
    double? value,
    String? mood,
    String? note,
  }) async {
    final extra = <String, dynamic>{};
    if (value != null) extra['value'] = value;
    if (note != null && note.isNotEmpty) extra['note'] = note;

    final record = await addRecord(
      type: RecordType.habitLog,
      content: content,
      habitId: habitId,
      mood: mood,
      extra: extra,
    );

    // 同步到今日打卡缓存
    _todayHabitLogs = [..._todayHabitLogs, record];
    notifyListeners();
    return record;
  }

  /// 取消今天的打卡
  Future<void> undoTodayCheckIn(String habitId) async {
    final log = _todayHabitLogs.where((r) => r.habitId == habitId).lastOrNull;
    if (log == null) return;
    await deleteRecord(log.id);
    _todayHabitLogs = _todayHabitLogs.where((r) => r.habitId != habitId || r.id != log.id).toList();
    notifyListeners();
  }

  // ── 私有缓存辅助 ──────────────────────────────────────────────

  void _addToLocalCaches(Record record) {
    // 加入全量缓存
    if (_isAllLoaded) {
      _allRecords = [record, ..._allRecords];
    }
    // 加入今日缓存
    final now = DateTime.now();
    if (record.type == RecordType.schedule &&
        record.scheduledAt != null &&
        record.scheduledAt!.year == now.year &&
        record.scheduledAt!.month == now.month &&
        record.scheduledAt!.day == now.day) {
      _todaySchedules = [record, ..._todaySchedules];
    }
    if ((record.type == RecordType.task || record.type == RecordType.checkItem) &&
        !record.isCompleted) {
      _todayTasks = [record, ..._todayTasks];
    }
    // 加入项目缓存
    if (record.projectId != null && _projectRecordsCache.containsKey(record.projectId)) {
      _projectRecordsCache[record.projectId!] = [
        record,
        ..._projectRecordsCache[record.projectId!]!
      ];
    }
  }

  void _updateInLocalCaches(Record record) {
    if (_isAllLoaded) {
      _allRecords = _allRecords.map((r) => r.id == record.id ? record : r).toList();
    }
    _todaySchedules = _todaySchedules.map((r) => r.id == record.id ? record : r).toList();
    _todayTasks = _todayTasks.map((r) => r.id == record.id ? record : r).toList();
    _todayHabitLogs = _todayHabitLogs.map((r) => r.id == record.id ? record : r).toList();
    for (final key in _projectRecordsCache.keys) {
      _projectRecordsCache[key] =
          _projectRecordsCache[key]!.map((r) => r.id == record.id ? record : r).toList();
    }
  }

  void _removeFromLocalCaches(String id) {
    if (_isAllLoaded) {
      _allRecords = _allRecords.where((r) => r.id != id).toList();
    }
    _todaySchedules = _todaySchedules.where((r) => r.id != id).toList();
    _todayTasks = _todayTasks.where((r) => r.id != id).toList();
    _todayHabitLogs = _todayHabitLogs.where((r) => r.id != id).toList();
    for (final key in _projectRecordsCache.keys) {
      _projectRecordsCache[key] =
          _projectRecordsCache[key]!.where((r) => r.id != id).toList();
    }
  }

  void invalidateAll() {
    _isAllLoaded = false;
    _allRecords = [];
    _projectRecordsCache.clear();
  }
}
