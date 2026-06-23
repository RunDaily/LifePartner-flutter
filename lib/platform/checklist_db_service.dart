// Checklist 数据库服务抽象接口
import '../models/checklist.dart';

abstract class ChecklistDbService {
  Future<void> init();
  Future<void> insertChecklist(Checklist checklist);
  Future<void> updateChecklist(Checklist checklist);
  Future<void> deleteChecklist(String id);
  Future<List<Checklist>> getAllChecklists();
  Future<List<Checklist>> getChecklistsByScene(ChecklistScene scene);
  Future<Checklist?> getChecklistById(String id);
}
