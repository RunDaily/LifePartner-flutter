// ProjectSection 数据库服务抽象接口
import '../models/project_section.dart';

abstract class ProjectSectionDbService {
  Future<void> init();

  /// 插入一个版块
  Future<void> insertSection(ProjectSection section);

  /// 更新一个版块
  Future<void> updateSection(ProjectSection section);

  /// 删除版块（同时级联删除子版块）
  Future<void> deleteSection(String id);

  /// 删除某项目下的所有版块
  Future<void> deleteSectionsByProjectId(String projectId);

  /// 获取某项目的所有版块（包含子版块）
  Future<List<ProjectSection>> getSectionsByProjectId(String projectId);

  /// 获取某版块下的直接子版块
  Future<List<ProjectSection>> getChildSections(String parentSectionId);

  /// 根据 ID 获取版块
  Future<ProjectSection?> getSectionById(String id);

  /// 更新版块任务统计
  Future<void> updateSectionStats({
    required String sectionId,
    required int taskCount,
    required int completedTaskCount,
  });
}
