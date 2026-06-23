// Goal 数据库服务 - Web 实现（内存存储）
import '../models/goal.dart';
import 'goal_db_service.dart';

export 'goal_db_service.dart';

GoalDbService createGoalDb() => WebGoalDbService();

class WebGoalDbService implements GoalDbService {
  final List<Goal> _goals = [];

  @override
  Future<void> init() async {}

  @override
  Future<void> insertGoal(Goal goal) async {
    _goals.removeWhere((g) => g.id == goal.id);
    _goals.add(goal);
  }

  @override
  Future<void> updateGoal(Goal goal) async {
    final idx = _goals.indexWhere((g) => g.id == goal.id);
    if (idx != -1) _goals[idx] = goal;
  }

  @override
  Future<void> deleteGoal(String id) async {
    _goals.removeWhere((g) => g.id == id);
  }

  @override
  Future<List<Goal>> getAllGoals() async {
    return List<Goal>.from(_goals)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<List<Goal>> getActiveGoals() async {
    return _goals.where((g) => g.status == GoalStatus.active).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<Goal?> getGoalById(String id) async {
    try {
      return _goals.firstWhere((g) => g.id == id);
    } catch (_) {
      return null;
    }
  }
}
