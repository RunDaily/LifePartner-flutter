import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/goal.dart';
import '../platform/service_locator.dart';

class GoalProvider extends ChangeNotifier {
  List<Goal> _goals = [];
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Goal> get goals => _goals;
  List<Goal> get activeGoals => _goals.where((g) => g.status == GoalStatus.active).toList();
  bool get isEmpty => _goals.isEmpty;

  Goal? findById(String? id) {
    if (id == null) return null;
    try {
      return _goals.firstWhere((g) => g.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> loadGoals() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _goals = await ServiceLocator.goalDb.getAllGoals();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error loading goals: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Goal> addGoal({
    required String title,
    String description = '',
    String emoji = '🎯',
    String colorHex = '#E07818',
    GoalStatus status = GoalStatus.active,
    GoalTimeframe timeframe = GoalTimeframe.custom,
    DateTime? deadline,
  }) async {
    final now = DateTime.now();
    final goal = Goal(
      id: const Uuid().v4(),
      title: title,
      description: description,
      emoji: emoji,
      colorHex: colorHex,
      status: status,
      timeframe: timeframe,
      deadline: deadline,
      createdAt: now,
      updatedAt: now,
    );
    await ServiceLocator.goalDb.insertGoal(goal);
    _goals = [goal, ..._goals];
    notifyListeners();
    return goal;
  }

  Future<void> updateGoal(Goal updated) async {
    final goal = updated.copyWith(updatedAt: DateTime.now());
    await ServiceLocator.goalDb.updateGoal(goal);
    _goals = _goals.map((g) => g.id == goal.id ? goal : g).toList();
    notifyListeners();
  }

  Future<void> deleteGoal(String id) async {
    await ServiceLocator.goalDb.deleteGoal(id);
    _goals = _goals.where((g) => g.id != id).toList();
    notifyListeners();
  }

  Future<void> updateProgress(String id, int progress) async {
    final goal = findById(id);
    if (goal == null) return;
    await updateGoal(goal.copyWith(progress: progress.clamp(0, 100)));
  }

  Future<void> toggleMilestone(String goalId, String milestoneId) async {
    final goal = findById(goalId);
    if (goal == null) return;
    final milestones = goal.milestones.map((m) {
      if (m.id != milestoneId) return m;
      return m.copyWith(
        isCompleted: !m.isCompleted,
        completedAt: !m.isCompleted ? DateTime.now() : null,
      );
    }).toList();
    await updateGoal(goal.copyWith(milestones: milestones));
  }
}
