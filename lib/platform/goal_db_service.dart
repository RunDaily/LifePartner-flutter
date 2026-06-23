// Goal 数据库服务抽象接口
import '../models/goal.dart';

abstract class GoalDbService {
  Future<void> init();
  Future<void> insertGoal(Goal goal);
  Future<void> updateGoal(Goal goal);
  Future<void> deleteGoal(String id);
  Future<List<Goal>> getAllGoals();
  Future<List<Goal>> getActiveGoals();
  Future<Goal?> getGoalById(String id);
}
