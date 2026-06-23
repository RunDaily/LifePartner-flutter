// Record 数据库服务抽象接口
import '../models/record.dart';

abstract class RecordDbService {
  Future<void> init();
  Future<void> insertRecord(Record record);
  Future<void> updateRecord(Record record);
  Future<void> deleteRecord(String id);
  Future<List<Record>> getAllRecords();
  Future<List<Record>> getRecordsByType(RecordType type);
  Future<List<Record>> getRecordsByGoalId(String goalId);
  Future<List<Record>> getRecordsByProjectId(String projectId);
  Future<List<Record>> getRecordsByHabitId(String habitId);
  Future<List<Record>> getTodaySchedules();
  Future<List<Record>> getTodayTasks();
  Future<List<Record>> getHabitLogsByDate(DateTime date);
  Future<List<Record>> getFavoriteRecords();
  Future<Record?> getRecordById(String id);
  Future<List<Record>> searchRecords(String query);
  Future<List<Record>> getRecordsInDateRange(DateTime from, DateTime to);
  Future<int> getRecordCountByProjectId(String projectId);
  Future<int> getCompletedCountByProjectId(String projectId);

  /// 获取某版块下的所有任务类 Record
  Future<List<Record>> getRecordsBySectionId(String sectionId);

  /// 统计某版块下的任务数
  Future<int> getRecordCountBySectionId(String sectionId);

  /// 统计某版块下已完成任务数
  Future<int> getCompletedCountBySectionId(String sectionId);
}
