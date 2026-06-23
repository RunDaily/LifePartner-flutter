import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/project.dart';
import '../platform/service_locator.dart';

class ProjectProvider extends ChangeNotifier {
  List<Project> _projects = [];
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Project> get projects => _projects;

  List<Project> get activeProjects => _projects
      .where((p) =>
          p.status == ProjectStatus.todo ||
          p.status == ProjectStatus.inProgress)
      .toList();

  List<Project> projectsForGoal(String goalId) =>
      _projects.where((p) => p.goalId == goalId).toList();

  bool get isEmpty => _projects.isEmpty;

  Project? findById(String? id) {
    if (id == null) return null;
    try {
      return _projects.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> loadProjects() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _projects = await ServiceLocator.projectDb.getAllProjects();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error loading projects: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Project> addProject({
    required String title,
    String description = '',
    String emoji = '📁',
    String colorHex = '#4A90D9',
    ProjectStatus status = ProjectStatus.todo,
    ProjectPriority priority = ProjectPriority.medium,
    String? goalId,
    DateTime? startDate,
    DateTime? deadline,
  }) async {
    final now = DateTime.now();
    final project = Project(
      id: const Uuid().v4(),
      title: title,
      description: description,
      emoji: emoji,
      colorHex: colorHex,
      status: status,
      priority: priority,
      goalId: goalId,
      startDate: startDate,
      deadline: deadline,
      createdAt: now,
      updatedAt: now,
    );
    await ServiceLocator.projectDb.insertProject(project);
    _projects = [project, ..._projects];
    notifyListeners();
    return project;
  }

  Future<void> updateProject(Project updated) async {
    final project = updated.copyWith(updatedAt: DateTime.now());
    await ServiceLocator.projectDb.updateProject(project);
    _projects = _projects.map((p) => p.id == project.id ? project : p).toList();
    notifyListeners();
  }

  Future<void> deleteProject(String id) async {
    await ServiceLocator.projectDb.deleteProject(id);
    _projects = _projects.where((p) => p.id != id).toList();
    notifyListeners();
  }

  /// 刷新项目任务统计（RecordProvider 在 addRecord 后调用）
  Future<void> refreshStats(String projectId) async {
    final taskCount =
        await ServiceLocator.recordDb.getRecordCountByProjectId(projectId);
    final completedCount =
        await ServiceLocator.recordDb.getCompletedCountByProjectId(projectId);
    await ServiceLocator.projectDb.updateProjectStats(
      projectId: projectId,
      taskCount: taskCount,
      completedTaskCount: completedCount,
    );
    final idx = _projects.indexWhere((p) => p.id == projectId);
    if (idx != -1) {
      _projects[idx] = _projects[idx].copyWith(
        taskCount: taskCount,
        completedTaskCount: completedCount,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
    }
  }
}
