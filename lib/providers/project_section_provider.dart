// ─────────────────────────────────────────────────────────────────
//  ProjectSectionProvider —— 版块状态管理
//
//  【职责】
//  - 管理某个项目下所有版块（包含子版块）的加载、增删改
//  - 提供树形结构查询：顶级版块、子版块
//  - 提供版块内任务统计刷新
// ─────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/project_section.dart';
import '../platform/service_locator.dart';

class ProjectSectionProvider extends ChangeNotifier {
  /// 当前加载的项目 ID
  String? _currentProjectId;

  /// 当前项目下的所有版块（平铺，包含子版块）
  List<ProjectSection> _sections = [];

  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get currentProjectId => _currentProjectId;

  /// 所有版块（平铺列表）
  List<ProjectSection> get sections => _sections;

  /// 顶级版块（无父版块）
  List<ProjectSection> get topLevelSections =>
      _sections.where((s) => s.parentSectionId == null).toList();

  /// 获取某版块的直接子版块
  List<ProjectSection> childSectionsOf(String parentId) =>
      _sections.where((s) => s.parentSectionId == parentId).toList();

  /// 根据 ID 获取版块
  ProjectSection? findById(String? id) {
    if (id == null) return null;
    try {
      return _sections.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 加载某个项目的所有版块
  Future<void> loadSectionsForProject(String projectId) async {
    if (_currentProjectId == projectId && _sections.isNotEmpty) return;
    _currentProjectId = projectId;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _sections =
          await ServiceLocator.sectionDb.getSectionsByProjectId(projectId);
    } catch (e) {
      _error = e.toString();
      debugPrint('Error loading sections for project $projectId: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 强制重新加载（用于增删改后）
  Future<void> reload() async {
    if (_currentProjectId == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      _sections = await ServiceLocator.sectionDb
          .getSectionsByProjectId(_currentProjectId!);
    } catch (e) {
      _error = e.toString();
      debugPrint('Error reloading sections: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 新增版块
  Future<ProjectSection> addSection({
    required String projectId,
    String? parentSectionId,
    required String title,
    String description = '',
    String emoji = '📂',
    String colorHex = '#4A90D9',
  }) async {
    final now = DateTime.now();
    // 计算排序权重（当前最大值 + 1）
    final siblings = parentSectionId == null
        ? topLevelSections
        : childSectionsOf(parentSectionId);
    final maxOrder = siblings.isEmpty
        ? 0
        : siblings.map((s) => s.sortOrder).reduce((a, b) => a > b ? a : b);

    final section = ProjectSection(
      id: const Uuid().v4(),
      projectId: projectId,
      parentSectionId: parentSectionId,
      title: title,
      description: description,
      emoji: emoji,
      colorHex: colorHex,
      sortOrder: maxOrder + 1,
      createdAt: now,
      updatedAt: now,
    );
    await ServiceLocator.sectionDb.insertSection(section);
    _sections = [..._sections, section];
    notifyListeners();
    return section;
  }

  /// 更新版块
  Future<void> updateSection(ProjectSection updated) async {
    final section = updated.copyWith(updatedAt: DateTime.now());
    await ServiceLocator.sectionDb.updateSection(section);
    _sections =
        _sections.map((s) => s.id == section.id ? section : s).toList();
    notifyListeners();
  }

  /// 删除版块（同时删除其所有子版块）
  Future<void> deleteSection(String sectionId) async {
    // 收集所有需要删除的 ID（递归子版块）
    final toDelete = _collectDescendantIds(sectionId);
    await ServiceLocator.sectionDb.deleteSection(sectionId);
    _sections =
        _sections.where((s) => !toDelete.contains(s.id)).toList();
    notifyListeners();
  }

  /// 刷新版块的任务统计
  Future<void> refreshSectionStats({
    required String sectionId,
    required int taskCount,
    required int completedTaskCount,
  }) async {
    await ServiceLocator.sectionDb.updateSectionStats(
      sectionId: sectionId,
      taskCount: taskCount,
      completedTaskCount: completedTaskCount,
    );
    final idx = _sections.indexWhere((s) => s.id == sectionId);
    if (idx != -1) {
      _sections[idx] = _sections[idx].copyWith(
        taskCount: taskCount,
        completedTaskCount: completedTaskCount,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
    }
  }

  /// 切换版块折叠状态（纯 UI 状态，不持久化）
  void toggleCollapse(String sectionId) {
    final idx = _sections.indexWhere((s) => s.id == sectionId);
    if (idx == -1) return;
    _sections[idx] = _sections[idx].copyWith(
      isCollapsed: !_sections[idx].isCollapsed,
    );
    notifyListeners();
  }

  /// 清空当前项目数据（切换项目时调用）
  void clear() {
    _currentProjectId = null;
    _sections = [];
    _error = null;
    notifyListeners();
  }

  // ── 私有辅助 ──────────────────────────────────────────────────

  /// 收集某版块及其所有后代版块的 ID 集合
  Set<String> _collectDescendantIds(String rootId) {
    final result = <String>{rootId};
    final children = childSectionsOf(rootId);
    for (final child in children) {
      result.addAll(_collectDescendantIds(child.id));
    }
    return result;
  }
}
