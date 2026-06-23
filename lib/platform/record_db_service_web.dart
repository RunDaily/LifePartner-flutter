// Record 数据库服务 - Web 实现（内存存储，预览用）
import '../models/record.dart';
import 'record_db_service.dart';

export 'record_db_service.dart';

RecordDbService createRecordDb() => WebRecordDbService();

class WebRecordDbService implements RecordDbService {
  final List<Record> _records = [];

  @override
  Future<void> init() async {}

  @override
  Future<void> insertRecord(Record record) async {
    _records.removeWhere((r) => r.id == record.id);
    _records.add(record);
  }

  @override
  Future<void> updateRecord(Record record) async {
    final idx = _records.indexWhere((r) => r.id == record.id);
    if (idx != -1) _records[idx] = record;
  }

  @override
  Future<void> deleteRecord(String id) async {
    _records.removeWhere((r) => r.id == id);
  }

  @override
  Future<List<Record>> getAllRecords() async {
    final list = List<Record>.from(_records);
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<List<Record>> getRecordsByType(RecordType type) async {
    final list = _records.where((r) => r.type == type).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<List<Record>> getRecordsByGoalId(String goalId) async {
    return _records.where((r) => r.goalId == goalId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<List<Record>> getRecordsByProjectId(String projectId) async {
    return _records.where((r) => r.projectId == projectId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<List<Record>> getRecordsByHabitId(String habitId) async {
    return _records.where((r) => r.habitId == habitId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<List<Record>> getTodaySchedules() async {
    final now = DateTime.now();
    return _records
        .where((r) =>
            r.type == RecordType.schedule &&
            r.scheduledAt != null &&
            r.scheduledAt!.year == now.year &&
            r.scheduledAt!.month == now.month &&
            r.scheduledAt!.day == now.day)
        .toList()
      ..sort((a, b) => (a.scheduledAt ?? a.createdAt)
          .compareTo(b.scheduledAt ?? b.createdAt));
  }

  @override
  Future<List<Record>> getTodayTasks() async {
    final now = DateTime.now();
    bool isToday(DateTime? dt) =>
        dt != null &&
        dt.year == now.year &&
        dt.month == now.month &&
        dt.day == now.day;
    return _records
        .where((r) =>
            (r.type == RecordType.task || r.type == RecordType.checkItem) &&
            !r.isCompleted &&
            (isToday(r.scheduledAt) || isToday(r.deadline)))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<List<Record>> getHabitLogsByDate(DateTime date) async {
    return _records
        .where((r) =>
            r.type == RecordType.habitLog &&
            r.createdAt.year == date.year &&
            r.createdAt.month == date.month &&
            r.createdAt.day == date.day)
        .toList();
  }

  @override
  Future<List<Record>> getFavoriteRecords() async {
    return _records.where((r) => r.isFavorite).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<Record?> getRecordById(String id) async {
    try {
      return _records.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Record>> searchRecords(String query) async {
    final q = query.toLowerCase();
    return _records
        .where((r) =>
            r.title.toLowerCase().contains(q) ||
            r.content.toLowerCase().contains(q))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<List<Record>> getRecordsInDateRange(DateTime from, DateTime to) async {
    return _records
        .where((r) =>
            r.createdAt.isAfter(from) && r.createdAt.isBefore(to))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<int> getRecordCountByProjectId(String projectId) async {
    return _records
        .where((r) =>
            r.projectId == projectId &&
            (r.type == RecordType.task || r.type == RecordType.checkItem))
        .length;
  }

  @override
  Future<int> getCompletedCountByProjectId(String projectId) async {
    return _records
        .where((r) =>
            r.projectId == projectId &&
            (r.type == RecordType.task || r.type == RecordType.checkItem) &&
            r.isCompleted)
        .length;
  }

  @override
  Future<List<Record>> getRecordsBySectionId(String sectionId) async {
    return _records
        .where((r) =>
            r.sectionId == sectionId &&
            (r.type == RecordType.task || r.type == RecordType.checkItem))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  @override
  Future<int> getRecordCountBySectionId(String sectionId) async {
    return _records
        .where((r) =>
            r.sectionId == sectionId &&
            (r.type == RecordType.task || r.type == RecordType.checkItem))
        .length;
  }

  @override
  Future<int> getCompletedCountBySectionId(String sectionId) async {
    return _records
        .where((r) =>
            r.sectionId == sectionId &&
            (r.type == RecordType.task || r.type == RecordType.checkItem) &&
            r.isCompleted)
        .length;
  }
}
