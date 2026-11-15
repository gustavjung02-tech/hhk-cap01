import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'local_store.dart';

class SqliteStore implements LocalStore {
  Database? _database;
  Future<void> open() async {
    _database ??= await openDatabase(
      path.join(await getDatabasesPath(), 'hhk_cap01.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
      },
    );
  }

  Database get _db {
    final db = _database;
    if (db == null) throw StateError('Chưa mở SQLite');
    return db;
  }

  Future<String?> read(String key) async {
    final rows = await _db.query('settings', columns: ['value'],
        where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> write(String key, String value) async {
    await _db.insert('settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
LocalStore createLocalStore() => SqliteStore();
