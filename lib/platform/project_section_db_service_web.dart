// ProjectSection 数据库服务 - Web 实现（内存存储）
import '../models/project_section.dart';
import 'project_section_db_service.dart';

export 'project_section_db_service.dart';

ProjectSectionDbService createProjectSectionDb() =>
    WebProjectSectionDbService();

class WebProjectSectionDbService implements ProjectSectionDbService {
  final List<ProjectSection> _sections = [];

  @override
  Future<void> init() async {}

  @override
  Future<void> insertSection(ProjectSection section) async {
    _sections.removeWhere((s) => s.id == section.id);
    _sections.add(section);
  }

  @override
  Future<void> updateSection(ProjectSection section) async {
    final idx = _sections.indexWhere((s) => s.id == section.id);
    if (idx != -1) _sections[idx] = section;
  }

  @override
  Future<void> deleteSection(String id) async {
    _deleteSectionRecursive(id);
  }

  void _deleteSectionRecursive(String sectionId) {
    // 找到并删除所有子版块
    final children =
        _sections.where((s) => s.parentSectionId == sectionId).toList();
    for (final child in children) {
      _deleteSectionRecursive(child.id);
    }
    _sections.removeWhere((s) => s.id == sectionId);
  }

  @override
  Future<void> deleteSectionsByProjectId(String projectId) async {
    _sections.removeWhere((s) => s.projectId == projectId);
  }

  @override
  Future<List<ProjectSection>> getSectionsByProjectId(
      String projectId) async {
    return _sections
        .where((s) => s.projectId == projectId)
        .toList()
      ..sort((a, b) {
        final cmp = a.sortOrder.compareTo(b.sortOrder);
        if (cmp != 0) return cmp;
        return a.createdAt.compareTo(b.createdAt);
      });
  }

  @override
  Future<List<ProjectSection>> getChildSections(
      String parentSectionId) async {
    return _sections
        .where((s) => s.parentSectionId == parentSectionId)
        .toList()
      ..sort((a, b) {
        final cmp = a.sortOrder.compareTo(b.sortOrder);
        if (cmp != 0) return cmp;
        return a.createdAt.compareTo(b.createdAt);
      });
  }

  @override
  Future<ProjectSection?> getSectionById(String id) async {
    try {
      return _sections.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> updateSectionStats({
    required String sectionId,
    required int taskCount,
    required int completedTaskCount,
  }) async {
    final idx = _sections.indexWhere((s) => s.id == sectionId);
    if (idx != -1) {
      _sections[idx] = _sections[idx].copyWith(
        taskCount: taskCount,
        completedTaskCount: completedTaskCount,
        updatedAt: DateTime.now(),
      );
    }
  }
}
