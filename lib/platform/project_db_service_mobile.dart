// Project 数据库服务 - Android / iOS 实现
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/project.dart';
import 'project_db_service.dart';

export 'project_db_service.dart';

ProjectDbService createProjectDb() => MobileProjectDbService();

class MobileProjectDbService implements ProjectDbService {
  static const _dbName = 'projects_v2.db';
  static const _dbVersion = 1;
  static const _table = 'projects';

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
        title TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        emoji TEXT NOT NULL DEFAULT '📁',
        colorHex TEXT NOT NULL DEFAULT '#4A90D9',
        status TEXT NOT NULL DEFAULT 'todo',
        priority TEXT NOT NULL DEFAULT 'medium',
        goalId TEXT,
        startDate INTEGER,
        deadline INTEGER,
        isPinned INTEGER NOT NULL DEFAULT 0,
        sortOrder INTEGER NOT NULL DEFAULT 0,
        taskCount INTEGER NOT NULL DEFAULT 0,
        completedTaskCount INTEGER NOT NULL DEFAULT 0,
        aiInsight TEXT,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_projects_status ON $_table (status)');
    await db.execute('CREATE INDEX idx_projects_goalId ON $_table (goalId)');
  }

  Future<Database> get _database async {
    if (_db == null) await init();
    return _db!;
  }

  @override
  Future<void> insertProject(Project project) async {
    final db = await _database;
    await db.insert(_table, project.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> updateProject(Project project) async {
    final db = await _database;
    await db.update(_table, project.toMap(), where: 'id = ?', whereArgs: [project.id]);
  }

  @override
  Future<void> deleteProject(String id) async {
    final db = await _database;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<List<Project>> getAllProjects() async {
    final db = await _database;
    final maps = await db.query(_table, orderBy: 'isPinned DESC, sortOrder DESC, createdAt DESC');
    return maps.map(Project.fromMap).toList();
  }

  @override
  Future<List<Project>> getProjectsByGoalId(String goalId) async {
    final db = await _database;
    final maps = await db.query(_table, where: 'goalId = ?', whereArgs: [goalId], orderBy: 'sortOrder DESC, createdAt DESC');
    return maps.map(Project.fromMap).toList();
  }

  @override
  Future<List<Project>> getActiveProjects() async {
    final db = await _database;
    final maps = await db.query(_table, where: "status IN ('todo', 'in_progress')", orderBy: 'isPinned DESC, sortOrder DESC, createdAt DESC');
    return maps.map(Project.fromMap).toList();
  }

  @override
  Future<Project?> getProjectById(String id) async {
    final db = await _database;
    final maps = await db.query(_table, where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return Project.fromMap(maps.first);
  }

  @override
  Future<void> updateProjectStats({
    required String projectId,
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
      whereArgs: [projectId],
    );
  }
}
