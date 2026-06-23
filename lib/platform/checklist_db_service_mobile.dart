// Checklist 数据库服务 - Android / iOS 实现
// v2 迁移：新增 checklistType / scheduledDate / repeatType / lastResetAt
// v3 迁移：新增 function / tags / aiTaggedItemCount（功能层 + 双轨标签体系）
// v5 迁移：新增 interactionMode（交互范式）
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/checklist.dart';
import 'checklist_db_service.dart';

export 'checklist_db_service.dart';

ChecklistDbService createChecklistDb() => MobileChecklistDbService();

class MobileChecklistDbService implements ChecklistDbService {
  // 注意：文件名不含版本号，版本由 _dbVersion 控制
  static const _dbName = 'checklists.db';
  // 每次新增字段时递增此版本号，触发 onUpgrade
  static const _dbVersion = 5;
  static const _table = 'checklists';

  Database? _db;

  @override
  Future<void> init() async {
    if (_db != null) return;
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    _db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_table (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        emoji TEXT NOT NULL DEFAULT '📋',
        colorHex TEXT NOT NULL DEFAULT '#5C7CFA',
        checklistType TEXT NOT NULL DEFAULT 'structural',
        scene TEXT NOT NULL DEFAULT 'general',
        style TEXT NOT NULL DEFAULT 'simple',
        status TEXT NOT NULL DEFAULT 'active',
        function TEXT NOT NULL DEFAULT 'checklist',
        interactionMode TEXT NOT NULL DEFAULT 'execution',
        tags TEXT NOT NULL DEFAULT '[]',
        aiTaggedItemCount INTEGER NOT NULL DEFAULT 0,
        isPinned INTEGER NOT NULL DEFAULT 0,
        sortOrder INTEGER NOT NULL DEFAULT 0,
        items TEXT NOT NULL DEFAULT '[]',
        aiSummary TEXT,
        dueDate INTEGER,
        scheduledDate INTEGER,
        repeatType TEXT NOT NULL DEFAULT 'none',
        lastResetAt INTEGER,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_checklists_status ON $_table (status)');
    await db.execute(
        'CREATE INDEX idx_checklists_scene ON $_table (scene)');
    await db.execute(
        'CREATE INDEX idx_checklists_type ON $_table (checklistType)');
    await db.execute(
        'CREATE INDEX idx_checklists_scheduled ON $_table (scheduledDate)');
    await db.execute(
        'CREATE INDEX idx_checklists_function ON $_table (function)');
    await db.execute(
        'CREATE INDEX idx_checklists_mode ON $_table (interactionMode)');
  }

  /// 安全执行 ALTER TABLE，列已存在时静默忽略
  Future<void> _safeAlter(Database db, String sql) async {
    try {
      await db.execute(sql);
    } catch (_) {
      // 列已存在或语法不支持时忽略，保证幂等性
    }
  }

  /// 迁移策略：
  /// v5 在 v4 基础上增量添加 interactionMode 列（v4 已是干净版本，增量安全）
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // 从任何旧版本升到 v4 之前：直接 DROP 重建（清理历史包袱）
    if (oldVersion < 4) {
      await db.execute('DROP TABLE IF EXISTS $_table');
      await _onCreate(db, newVersion);
      return;
    }
    // v4 → v5：增量添加 interactionMode 字段（v4 用户数据保留）
    if (oldVersion < 5) {
      await _safeAlter(db,
          "ALTER TABLE $_table ADD COLUMN interactionMode TEXT NOT NULL DEFAULT 'execution'");
      await _safeAlter(db,
          'CREATE INDEX idx_checklists_mode ON $_table (interactionMode)');
    }
  }

  Future<Database> get _database async {
    if (_db == null) await init();
    return _db!;
  }

  @override
  Future<void> insertChecklist(Checklist checklist) async {
    final db = await _database;
    await db.insert(_table, checklist.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> updateChecklist(Checklist checklist) async {
    final db = await _database;
    await db.update(_table, checklist.toMap(),
        where: 'id = ?', whereArgs: [checklist.id]);
  }

  @override
  Future<void> deleteChecklist(String id) async {
    final db = await _database;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<List<Checklist>> getAllChecklists() async {
    final db = await _database;
    final maps = await db.query(
      _table,
      orderBy: 'isPinned DESC, sortOrder DESC, updatedAt DESC',
    );
    return maps.map(Checklist.fromMap).toList();
  }

  @override
  Future<List<Checklist>> getChecklistsByScene(ChecklistScene scene) async {
    final db = await _database;
    final maps = await db.query(
      _table,
      where: 'scene = ?',
      whereArgs: [scene.value],
      orderBy: 'isPinned DESC, updatedAt DESC',
    );
    return maps.map(Checklist.fromMap).toList();
  }

  @override
  Future<Checklist?> getChecklistById(String id) async {
    final db = await _database;
    final maps =
        await db.query(_table, where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return Checklist.fromMap(maps.first);
  }

  /// 查询今日时态清单（scheduledDate 匹配今天）
  Future<List<Checklist>> getTodayTemporalChecklists() async {
    final db = await _database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day)
        .millisecondsSinceEpoch;
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59)
        .millisecondsSinceEpoch;
    final maps = await db.query(
      _table,
      where:
          "checklistType = 'temporal' AND scheduledDate >= ? AND scheduledDate <= ? AND status != 'archived'",
      whereArgs: [startOfDay, endOfDay],
      orderBy: 'isPinned DESC, sortOrder ASC',
    );
    return maps.map(Checklist.fromMap).toList();
  }
}
