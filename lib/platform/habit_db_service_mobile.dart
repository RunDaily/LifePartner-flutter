// Habit 数据库服务 - Android / iOS 实现
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/habit.dart';
import 'habit_db_service.dart';

export 'habit_db_service.dart';

HabitDbService createHabitDb() => MobileHabitDbService();

class MobileHabitDbService implements HabitDbService {
  static const _dbName = 'habits_v2.db';
  static const _dbVersion = 1;
  static const _table = 'habits';

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
        emoji TEXT NOT NULL DEFAULT '🔁',
        colorHex TEXT NOT NULL DEFAULT '#27AE60',
        frequency TEXT NOT NULL DEFAULT 'daily',
        customDays TEXT NOT NULL DEFAULT '',
        goalType TEXT NOT NULL DEFAULT 'boolean',
        goalValue REAL NOT NULL DEFAULT 1,
        goalUnit TEXT NOT NULL DEFAULT '',
        reminderTime TEXT,
        isActive INTEGER NOT NULL DEFAULT 1,
        goalId TEXT,
        sortOrder INTEGER NOT NULL DEFAULT 0,
        currentStreak INTEGER NOT NULL DEFAULT 0,
        longestStreak INTEGER NOT NULL DEFAULT 0,
        totalCheckIns INTEGER NOT NULL DEFAULT 0,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL,
        lastCheckInAt INTEGER
      )
    ''');
    await db.execute('CREATE INDEX idx_habits_isActive ON $_table (isActive)');
  }

  Future<Database> get _database async {
    if (_db == null) await init();
    return _db!;
  }

  @override
  Future<void> insertHabit(Habit habit) async {
    final db = await _database;
    await db.insert(_table, habit.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> updateHabit(Habit habit) async {
    final db = await _database;
    await db.update(_table, habit.toMap(), where: 'id = ?', whereArgs: [habit.id]);
  }

  @override
  Future<void> deleteHabit(String id) async {
    final db = await _database;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<List<Habit>> getAllHabits() async {
    final db = await _database;
    final maps = await db.query(_table, orderBy: 'sortOrder ASC, createdAt ASC');
    return maps.map(Habit.fromMap).toList();
  }

  @override
  Future<List<Habit>> getActiveHabits() async {
    final db = await _database;
    final maps = await db.query(_table, where: 'isActive = 1', orderBy: 'sortOrder ASC, createdAt ASC');
    return maps.map(Habit.fromMap).toList();
  }

  @override
  Future<Habit?> getHabitById(String id) async {
    final db = await _database;
    final maps = await db.query(_table, where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return Habit.fromMap(maps.first);
  }

  @override
  Future<void> updateHabitStats({
    required String habitId,
    required int currentStreak,
    required int longestStreak,
    required int totalCheckIns,
    required DateTime? lastCheckInAt,
  }) async {
    final db = await _database;
    await db.update(
      _table,
      {
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'totalCheckIns': totalCheckIns,
        'lastCheckInAt': lastCheckInAt?.millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [habitId],
    );
  }
}
