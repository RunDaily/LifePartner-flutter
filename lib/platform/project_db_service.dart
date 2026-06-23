// Project 数据库服务抽象接口
import '../models/project.dart';

abstract class ProjectDbService {
  Future<void> init();
  Future<void> insertProject(Project project);
  Future<void> updateProject(Project project);
  Future<void> deleteProject(String id);
  Future<List<Project>> getAllProjects();
  Future<List<Project>> getProjectsByGoalId(String goalId);
  Future<List<Project>> getActiveProjects();
  Future<Project?> getProjectById(String id);
  Future<void> updateProjectStats({
    required String projectId,
    required int taskCount,
    required int completedTaskCount,
  });
}
