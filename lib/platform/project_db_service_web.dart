// Project 数据库服务 - Web 实现（内存存储）
import '../models/project.dart';
import 'project_db_service.dart';

export 'project_db_service.dart';

ProjectDbService createProjectDb() => WebProjectDbService();

class WebProjectDbService implements ProjectDbService {
  final List<Project> _projects = [];

  @override
  Future<void> init() async {}

  @override
  Future<void> insertProject(Project project) async {
    _projects.removeWhere((p) => p.id == project.id);
    _projects.add(project);
  }

  @override
  Future<void> updateProject(Project project) async {
    final idx = _projects.indexWhere((p) => p.id == project.id);
    if (idx != -1) _projects[idx] = project;
  }

  @override
  Future<void> deleteProject(String id) async {
    _projects.removeWhere((p) => p.id == id);
  }

  @override
  Future<List<Project>> getAllProjects() async {
    return List<Project>.from(_projects)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<List<Project>> getProjectsByGoalId(String goalId) async {
    return _projects.where((p) => p.goalId == goalId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<List<Project>> getActiveProjects() async {
    return _projects
        .where((p) =>
            p.status == ProjectStatus.todo ||
            p.status == ProjectStatus.inProgress)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<Project?> getProjectById(String id) async {
    try {
      return _projects.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> updateProjectStats({
    required String projectId,
    required int taskCount,
    required int completedTaskCount,
  }) async {
    final idx = _projects.indexWhere((p) => p.id == projectId);
    if (idx != -1) {
      _projects[idx] = _projects[idx].copyWith(
        taskCount: taskCount,
        completedTaskCount: completedTaskCount,
        updatedAt: DateTime.now(),
      );
    }
  }
}
