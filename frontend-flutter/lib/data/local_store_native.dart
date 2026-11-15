import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'local_store.dart';

class SqliteStore implements LocalStore {
  Database? _database;

  @override
  Future<void> open() async {
    _database ??= await openDatabase(
      path.join(await getDatabasesPath(), 'hhk_cap01.db'),
      version: 2,
      onCreate: (db, version) async {
        await db.execute(
            'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
      },
      // v1 settings rows are kept intact; StudyLedger migrates their content
      // lazily into the versioned v2 document without deleting the originals.
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 1) {
          await db.execute(
              'CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
        }
      },
    );
  }

  Database get _db {
    final db = _database;
    if (db == null) throw StateError('Chưa mở SQLite');
    return db;
  }

  @override
  Future<String?> read(String key) async {
    final rows = await _db.query('settings',
        columns: ['value'], where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  @override
  Future<void> write(String key, String value) async {
    await _db.insert('settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<String> update(String key, String Function(String?) transform) =>
      _db.transaction((txn) async {
        final rows = await txn.query('settings',
            columns: ['value'], where: 'key = ?', whereArgs: [key], limit: 1);
        final previous = rows.isEmpty ? null : rows.first['value'] as String?;
        final next = transform(previous);
        await txn.insert('settings', {'key': key, 'value': next},
            conflictAlgorithm: ConflictAlgorithm.replace);
        return next;
      });

  @override
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}

LocalStore createLocalStore() => SqliteStore();
