// ProjectSection 数据库服务 - Android / iOS 实现
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/project_section.dart';
import 'project_section_db_service.dart';

export 'project_section_db_service.dart';

ProjectSectionDbService createProjectSectionDb() =>
    MobileProjectSectionDbService();

class MobileProjectSectionDbService implements ProjectSectionDbService {
  static const _dbName = 'project_sections_v1.db';
  static const _dbVersion = 1;
  static const _table = 'project_sections';

  Database? _db;

  @override
  Future<void> init() async {
    if (_db != null) return;
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    _db = await openDatabase(path, version: _dbVersion, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_table (
        id TEXT PRIMARY KEY,
        projectId TEXT NOT NULL,
        parentSectionId TEXT,
        title TEXT NOT NULL DEFAULT '',
        description TEXT NOT NULL DEFAULT '',
        emoji TEXT NOT NULL DEFAULT '📂',
        colorHex TEXT NOT NULL DEFAULT '#4A90D9',
        isCollapsed INTEGER NOT NULL DEFAULT 0,
        isCompleted INTEGER NOT NULL DEFAULT 0,
        sortOrder INTEGER NOT NULL DEFAULT 0,
        taskCount INTEGER NOT NULL DEFAULT 0,
        completedTaskCount INTEGER NOT NULL DEFAULT 0,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_sections_projectId ON $_table (projectId)');
    await db.execute(
        'CREATE INDEX idx_sections_parentSectionId ON $_table (parentSectionId)');
    await db.execute(
        'CREATE INDEX idx_sections_sortOrder ON $_table (sortOrder)');
  }

  Future<Database> get _database async {
    if (_db == null) await init();
    return _db!;
  }

  @override
  Future<void> insertSection(ProjectSection section) async {
    final db = await _database;
    await db.insert(_table, section.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> updateSection(ProjectSection section) async {
    final db = await _database;
    await db.update(_table, section.toMap(),
        where: 'id = ?', whereArgs: [section.id]);
  }

  @override
  Future<void> deleteSection(String id) async {
    final db = await _database;
    // 先递归删除所有子版块
    await _deleteSectionRecursive(db, id);
  }

  Future<void> _deleteSectionRecursive(Database db, String sectionId) async {
    // 找到所有直接子版块
    final children = await db.query(
      _table,
      where: 'parentSectionId = ?',
      whereArgs: [sectionId],
    );
    for (final child in children) {
      await _deleteSectionRecursive(db, child['id'] as String);
    }
    // 删除当前版块
    await db.delete(_table, where: 'id = ?', whereArgs: [sectionId]);
  }

  @override
  Future<void> deleteSectionsByProjectId(String projectId) async {
    final db = await _database;
    await db.delete(_table, where: 'projectId = ?', whereArgs: [projectId]);
  }

  @override
  Future<List<ProjectSection>> getSectionsByProjectId(
      String projectId) async {
    final db = await _database;
    final maps = await db.query(
      _table,
      where: 'projectId = ?',
      whereArgs: [projectId],
      orderBy: 'sortOrder ASC, createdAt ASC',
    );
    return maps.map(ProjectSection.fromMap).toList();
  }

  @override
  Future<List<ProjectSection>> getChildSections(
      String parentSectionId) async {
    final db = await _database;
    final maps = await db.query(
      _table,
      where: 'parentSectionId = ?',
      whereArgs: [parentSectionId],
      orderBy: 'sortOrder ASC, createdAt ASC',
    );
    return maps.map(ProjectSection.fromMap).toList();
  }

  @override
  Future<ProjectSection?> getSectionById(String id) async {
    final db = await _database;
    final maps =
        await db.query(_table, where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return ProjectSection.fromMap(maps.first);
  }

  @override
  Future<void> updateSectionStats({
    required String sectionId,
    required int taskCount,
    required int completedTaskCount,
  }) async {
    final db = await _database;
    await db.update(
      _table,
      {
        'taskCount': taskCount,
        'completedTaskCount': completedTaskCount,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [sectionId],
    );
  }
}
