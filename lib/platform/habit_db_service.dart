// Habit 数据库服务抽象接口
import '../models/habit.dart';

abstract class HabitDbService {
  Future<void> init();
  Future<void> insertHabit(Habit habit);
  Future<void> updateHabit(Habit habit);
  Future<void> deleteHabit(String id);
  Future<List<Habit>> getAllHabits();
  Future<List<Habit>> getActiveHabits();
  Future<Habit?> getHabitById(String id);
  Future<void> updateHabitStats({
    required String habitId,
    required int currentStreak,
    required int longestStreak,
    required int totalCheckIns,
    required DateTime? lastCheckInAt,
  });
}
