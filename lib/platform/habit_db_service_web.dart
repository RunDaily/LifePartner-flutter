// Habit 数据库服务 - Web 实现（内存存储）
import '../models/habit.dart';
import 'habit_db_service.dart';

export 'habit_db_service.dart';

HabitDbService createHabitDb() => WebHabitDbService();

class WebHabitDbService implements HabitDbService {
  final List<Habit> _habits = [];

  @override
  Future<void> init() async {}

  @override
  Future<void> insertHabit(Habit habit) async {
    _habits.removeWhere((h) => h.id == habit.id);
    _habits.add(habit);
  }

  @override
  Future<void> updateHabit(Habit habit) async {
    final idx = _habits.indexWhere((h) => h.id == habit.id);
    if (idx != -1) _habits[idx] = habit;
  }

  @override
  Future<void> deleteHabit(String id) async {
    _habits.removeWhere((h) => h.id == id);
  }

  @override
  Future<List<Habit>> getAllHabits() async {
    return List<Habit>.from(_habits)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  @override
  Future<List<Habit>> getActiveHabits() async {
    return _habits.where((h) => h.isActive).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  @override
  Future<Habit?> getHabitById(String id) async {
    try {
      return _habits.firstWhere((h) => h.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> updateHabitStats({
    required String habitId,
    required int currentStreak,
    required int longestStreak,
    required int totalCheckIns,
    required DateTime? lastCheckInAt,
  }) async {
    final idx = _habits.indexWhere((h) => h.id == habitId);
    if (idx != -1) {
      _habits[idx] = _habits[idx].copyWith(
        currentStreak: currentStreak,
        longestStreak: longestStreak,
        totalCheckIns: totalCheckIns,
        lastCheckInAt: lastCheckInAt,
        updatedAt: DateTime.now(),
      );
    }
  }
}
