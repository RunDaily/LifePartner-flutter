// Goal 数据库服务 - Android / iOS 实现
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/goal.dart';
import 'goal_db_service.dart';

export 'goal_db_service.dart';

GoalDbService createGoalDb() => MobileGoalDbService();

class MobileGoalDbService implements GoalDbService {
  static const _dbName = 'goals_v2.db';
  static const _dbVersion = 1;
  static const _table = 'goals';

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
        emoji TEXT NOT NULL DEFAULT '🎯',
        colorHex TEXT NOT NULL DEFAULT '#E07818',
        status TEXT NOT NULL DEFAULT 'active',
        timeframe TEXT NOT NULL DEFAULT 'custom',
        deadline INTEGER,
        isPinned INTEGER NOT NULL DEFAULT 0,
        sortOrder INTEGER NOT NULL DEFAULT 0,
        milestones TEXT NOT NULL DEFAULT '[]',
        progress INTEGER NOT NULL DEFAULT 0,
        autoProgress INTEGER NOT NULL DEFAULT 1,
        aiInsight TEXT,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_goals_status ON $_table (status)');
  }

  Future<Database> get _database async {
    if (_db == null) await init();
    return _db!;
  }

  @override
  Future<void> insertGoal(Goal goal) async {
    final db = await _database;
    await db.insert(_table, goal.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> updateGoal(Goal goal) async {
    final db = await _database;
    await db.update(_table, goal.toMap(), where: 'id = ?', whereArgs: [goal.id]);
  }

  @override
  Future<void> deleteGoal(String id) async {
    final db = await _database;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<List<Goal>> getAllGoals() async {
    final db = await _database;
    final maps = await db.query(_table, orderBy: 'isPinned DESC, sortOrder DESC, createdAt DESC');
    return maps.map(Goal.fromMap).toList();
  }

  @override
  Future<List<Goal>> getActiveGoals() async {
    final db = await _database;
    final maps = await db.query(_table, where: "status = 'active'", orderBy: 'isPinned DESC, sortOrder DESC, createdAt DESC');
    return maps.map(Goal.fromMap).toList();
  }

  @override
  Future<Goal?> getGoalById(String id) async {
    final db = await _database;
    final maps = await db.query(_table, where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return Goal.fromMap(maps.first);
  }
}
