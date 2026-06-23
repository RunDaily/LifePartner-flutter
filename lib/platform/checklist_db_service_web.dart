// Checklist 数据库服务 - Web 实现（内存存储）
import '../models/checklist.dart';
import 'checklist_db_service.dart';

export 'checklist_db_service.dart';

ChecklistDbService createChecklistDb() => WebChecklistDbService();

class WebChecklistDbService implements ChecklistDbService {
  final List<Checklist> _checklists = [];

  @override
  Future<void> init() async {}

  @override
  Future<void> insertChecklist(Checklist checklist) async {
    _checklists.removeWhere((c) => c.id == checklist.id);
    _checklists.add(checklist);
  }

  @override
  Future<void> updateChecklist(Checklist checklist) async {
    final idx = _checklists.indexWhere((c) => c.id == checklist.id);
    if (idx != -1) _checklists[idx] = checklist;
  }

  @override
  Future<void> deleteChecklist(String id) async {
    _checklists.removeWhere((c) => c.id == id);
  }

  @override
  Future<List<Checklist>> getAllChecklists() async {
    return List<Checklist>.from(_checklists)
      ..sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
  }

  @override
  Future<List<Checklist>> getChecklistsByScene(ChecklistScene scene) async {
    return _checklists
        .where((c) => c.scene == scene)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  Future<Checklist?> getChecklistById(String id) async {
    try {
      return _checklists.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }
}
