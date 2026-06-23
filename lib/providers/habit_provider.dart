import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/habit.dart';
import '../platform/service_locator.dart';

class HabitProvider extends ChangeNotifier {
  List<Habit> _habits = [];
  bool _isLoading = false;
  String? _error;

  /// 今天已打卡的 habitId 集合（由 RecordProvider 同步）
  final Set<String> _todayCheckedIn = {};

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Habit> get habits => _habits;
  List<Habit> get activeHabits => _habits.where((h) => h.isActive).toList();

  /// 今天需要打卡的习惯
  List<Habit> get todayHabits =>
      _habits.where((h) => h.isActive && h.isScheduledToday).toList();

  bool isTodayCheckedIn(String habitId) => _todayCheckedIn.contains(habitId);

  int get todayCheckedCount =>
      todayHabits.where((h) => isTodayCheckedIn(h.id)).length;

  int get todayTotalCount => todayHabits.length;

  double get todayCompletionRate =>
      todayTotalCount > 0 ? todayCheckedCount / todayTotalCount : 0;

  Habit? findById(String? id) {
    if (id == null) return null;
    try {
      return _habits.firstWhere((h) => h.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> loadHabits() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _habits = await ServiceLocator.habitDb.getAllHabits();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error loading habits: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 由 RecordProvider 同步今日打卡状态
  void syncTodayCheckIns(Set<String> checkedInHabitIds) {
    _todayCheckedIn
      ..clear()
      ..addAll(checkedInHabitIds);
    notifyListeners();
  }

  Future<Habit> addHabit({
    required String title,
    String description = '',
    String emoji = '🔁',
    String colorHex = '#27AE60',
    HabitFrequency frequency = HabitFrequency.daily,
    List<int> customDays = const [],
    HabitGoalType goalType = HabitGoalType.boolean,
    double goalValue = 1,
    String goalUnit = '',
    String? reminderTime,
    String? goalId,
  }) async {
    final now = DateTime.now();
    final habit = Habit(
      id: const Uuid().v4(),
      title: title,
      description: description,
      emoji: emoji,
      colorHex: colorHex,
      frequency: frequency,
      customDays: customDays,
      goalType: goalType,
      goalValue: goalValue,
      goalUnit: goalUnit,
      reminderTime: reminderTime,
      goalId: goalId,
      sortOrder: _habits.length,
      createdAt: now,
      updatedAt: now,
    );
    await ServiceLocator.habitDb.insertHabit(habit);
    _habits = [..._habits, habit];
    notifyListeners();
    return habit;
  }

  Future<void> updateHabit(Habit updated) async {
    final habit = updated.copyWith(updatedAt: DateTime.now());
    await ServiceLocator.habitDb.updateHabit(habit);
    _habits = _habits.map((h) => h.id == habit.id ? habit : h).toList();
    notifyListeners();
  }

  Future<void> deleteHabit(String id) async {
    await ServiceLocator.habitDb.deleteHabit(id);
    _habits = _habits.where((h) => h.id != id).toList();
    _todayCheckedIn.remove(id);
    notifyListeners();
  }

  Future<void> toggleActive(String id) async {
    final habit = findById(id);
    if (habit == null) return;
    await updateHabit(habit.copyWith(isActive: !habit.isActive));
  }

  /// 打卡后更新习惯统计（streak 等）
  Future<void> onCheckIn(String habitId) async {
    final habit = findById(habitId);
    if (habit == null) return;

    _todayCheckedIn.add(habitId);

    final newStreak = habit.currentStreak + 1;
    final newLongest = newStreak > habit.longestStreak ? newStreak : habit.longestStreak;
    final newTotal = habit.totalCheckIns + 1;
    final now = DateTime.now();

    await ServiceLocator.habitDb.updateHabitStats(
      habitId: habitId,
      currentStreak: newStreak,
      longestStreak: newLongest,
      totalCheckIns: newTotal,
      lastCheckInAt: now,
    );
    _habits = _habits.map((h) {
      if (h.id != habitId) return h;
      return h.copyWith(
        currentStreak: newStreak,
        longestStreak: newLongest,
        totalCheckIns: newTotal,
        lastCheckInAt: now,
      );
    }).toList();
    notifyListeners();
  }

  /// 取消打卡后更新统计
  Future<void> onUndoCheckIn(String habitId) async {
    final habit = findById(habitId);
    if (habit == null) return;

    _todayCheckedIn.remove(habitId);

    final newStreak = (habit.currentStreak - 1).clamp(0, 999);
    final newTotal = (habit.totalCheckIns - 1).clamp(0, 999999);

    await ServiceLocator.habitDb.updateHabitStats(
      habitId: habitId,
      currentStreak: newStreak,
      longestStreak: habit.longestStreak,
      totalCheckIns: newTotal,
      lastCheckInAt: habit.lastCheckInAt,
    );
    _habits = _habits.map((h) {
      if (h.id != habitId) return h;
      return h.copyWith(
        currentStreak: newStreak,
        totalCheckIns: newTotal,
      );
    }).toList();
    notifyListeners();
  }
}
