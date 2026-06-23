// Record 数据库服务 - Android / iOS 实现
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/record.dart';
import 'record_db_service.dart';

export 'record_db_service.dart';

RecordDbService createRecordDb() => MobileRecordDbService();

class MobileRecordDbService implements RecordDbService {
  static const _dbName = 'records_v2.db';
  static const _dbVersion = 2;  // v2: 添加 sectionId 字段
  static const _table = 'records';

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
        type TEXT NOT NULL DEFAULT 'note',
        title TEXT NOT NULL DEFAULT '',
        content TEXT NOT NULL DEFAULT '',
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL,
        goalId TEXT,
        projectId TEXT,
        sectionId TEXT,
        scheduledAt INTEGER,
        deadline INTEGER,
        isAllDay INTEGER NOT NULL DEFAULT 0,
        reminderMinutes INTEGER NOT NULL DEFAULT -1,
        habitId TEXT,
        isCompleted INTEGER NOT NULL DEFAULT 0,
        completedAt INTEGER,
        imagePaths TEXT NOT NULL DEFAULT '',
        url TEXT,
        isFavorite INTEGER NOT NULL DEFAULT 0,
        readingProgress INTEGER NOT NULL DEFAULT 0,
        contactIds TEXT NOT NULL DEFAULT '',
        amount REAL,
        transactionCategory TEXT,
        mood TEXT,
        energy TEXT,
        location TEXT,
        weather TEXT,
        tags TEXT NOT NULL DEFAULT '',
        aiMeta TEXT,
        extra TEXT NOT NULL DEFAULT '{}'
      )
    ''');
    await db.execute('CREATE INDEX idx_records_type ON $_table (type)');
    await db.execute('CREATE INDEX idx_records_goalId ON $_table (goalId)');
    await db.execute('CREATE INDEX idx_records_projectId ON $_table (projectId)');
    await db.execute('CREATE INDEX idx_records_sectionId ON $_table (sectionId)');
    await db.execute('CREATE INDEX idx_records_habitId ON $_table (habitId)');
    await db.execute('CREATE INDEX idx_records_createdAt ON $_table (createdAt DESC)');
    await db.execute('CREATE INDEX idx_records_scheduledAt ON $_table (scheduledAt)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // v1 -> v2: 添加 sectionId 列
      await db.execute('ALTER TABLE $_table ADD COLUMN sectionId TEXT');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_records_sectionId ON $_table (sectionId)');
    }
  }

  Future<Database> get _database async {
    if (_db == null) await init();
    return _db!;
  }

  @override
  Future<void> insertRecord(Record record) async {
    final db = await _database;
    await db.insert(_table, record.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> updateRecord(Record record) async {
    final db = await _database;
    await db.update(_table, record.toMap(), where: 'id = ?', whereArgs: [record.id]);
  }

  @override
  Future<void> deleteRecord(String id) async {
    final db = await _database;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<List<Record>> getAllRecords() async {
    final db = await _database;
    final maps = await db.query(_table, orderBy: 'createdAt DESC');
    return maps.map(Record.fromMap).toList();
  }

  @override
  Future<List<Record>> getRecordsByType(RecordType type) async {
    final db = await _database;
    final maps = await db.query(_table, where: 'type = ?', whereArgs: [type.value], orderBy: 'createdAt DESC');
    return maps.map(Record.fromMap).toList();
  }

  @override
  Future<List<Record>> getRecordsByGoalId(String goalId) async {
    final db = await _database;
    final maps = await db.query(_table, where: 'goalId = ?', whereArgs: [goalId], orderBy: 'createdAt DESC');
    return maps.map(Record.fromMap).toList();
  }

  @override
  Future<List<Record>> getRecordsByProjectId(String projectId) async {
    final db = await _database;
    final maps = await db.query(_table, where: 'projectId = ?', whereArgs: [projectId], orderBy: 'createdAt DESC');
    return maps.map(Record.fromMap).toList();
  }

  @override
  Future<List<Record>> getRecordsByHabitId(String habitId) async {
    final db = await _database;
    final maps = await db.query(_table, where: 'habitId = ?', whereArgs: [habitId], orderBy: 'createdAt DESC');
    return maps.map(Record.fromMap).toList();
  }

  @override
  Future<List<Record>> getTodaySchedules() async {
    final db = await _database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59).millisecondsSinceEpoch;
    final maps = await db.rawQuery(
      '''SELECT * FROM $_table WHERE type = 'schedule'
         AND scheduledAt >= ? AND scheduledAt <= ?
         ORDER BY scheduledAt ASC''',
      [startOfDay, endOfDay],
    );
    return maps.map(Record.fromMap).toList();
  }

  @override
  Future<List<Record>> getTodayTasks() async {
    final db = await _database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59).millisecondsSinceEpoch;
    final maps = await db.rawQuery(
      '''SELECT * FROM $_table WHERE type IN ('task', 'check_item')
         AND isCompleted = 0
         AND (deadline >= ? AND deadline <= ? OR scheduledAt >= ? AND scheduledAt <= ?)
         ORDER BY createdAt DESC''',
      [startOfDay, endOfDay, startOfDay, endOfDay],
    );
    return maps.map(Record.fromMap).toList();
  }

  @override
  Future<List<Record>> getHabitLogsByDate(DateTime date) async {
    final db = await _database;
    final startOfDay = DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59).millisecondsSinceEpoch;
    final maps = await db.rawQuery(
      '''SELECT * FROM $_table WHERE type = 'habit_log'
         AND createdAt >= ? AND createdAt <= ?
         ORDER BY createdAt DESC''',
      [startOfDay, endOfDay],
    );
    return maps.map(Record.fromMap).toList();
  }

  @override
  Future<List<Record>> getFavoriteRecords() async {
    final db = await _database;
    final maps = await db.query(_table, where: 'isFavorite = 1', orderBy: 'createdAt DESC');
    return maps.map(Record.fromMap).toList();
  }

  @override
  Future<Record?> getRecordById(String id) async {
    final db = await _database;
    final maps = await db.query(_table, where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return Record.fromMap(maps.first);
  }

  @override
  Future<List<Record>> searchRecords(String query) async {
    final db = await _database;
    final q = '%$query%';
    final maps = await db.rawQuery(
      'SELECT * FROM $_table WHERE title LIKE ? OR content LIKE ? ORDER BY createdAt DESC',
      [q, q],
    );
    return maps.map(Record.fromMap).toList();
  }

  @override
  Future<List<Record>> getRecordsInDateRange(DateTime from, DateTime to) async {
    final db = await _database;
    final maps = await db.query(
      _table,
      where: 'createdAt >= ? AND createdAt <= ?',
      whereArgs: [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
      orderBy: 'createdAt DESC',
    );
    return maps.map(Record.fromMap).toList();
  }

  @override
  Future<int> getRecordCountByProjectId(String projectId) async {
    final db = await _database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) FROM $_table WHERE projectId = ? AND type IN ('task', 'check_item')",
      [projectId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  @override
  Future<int> getCompletedCountByProjectId(String projectId) async {
    final db = await _database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) FROM $_table WHERE projectId = ? AND type IN ('task', 'check_item') AND isCompleted = 1",
      [projectId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  @override
  Future<List<Record>> getRecordsBySectionId(String sectionId) async {
    final db = await _database;
    final maps = await db.query(
      _table,
      where: "sectionId = ? AND type IN ('task', 'check_item')",
      whereArgs: [sectionId],
      orderBy: 'createdAt ASC',
    );
    return maps.map(Record.fromMap).toList();
  }

  @override
  Future<int> getRecordCountBySectionId(String sectionId) async {
    final db = await _database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) FROM $_table WHERE sectionId = ? AND type IN ('task', 'check_item')",
      [sectionId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  @override
  Future<int> getCompletedCountBySectionId(String sectionId) async {
    final db = await _database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) FROM $_table WHERE sectionId = ? AND type IN ('task', 'check_item') AND isCompleted = 1",
      [sectionId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
