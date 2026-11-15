import 'package:idb_shim/idb_browser.dart';
import 'package:idb_shim/idb_shim.dart';
import 'local_store.dart';

class WebIndexedDbStore implements LocalStore {
  static const dbName = 'hhk_cap01_v1';
  static const table = 'settings';
  Database? _database;

  @override
  Future<void> open() async {
    _database ??= await idbFactoryWeb.open(dbName,
      version: 1, onUpgradeNeeded: (event) {
        final db = event.database;
        if (!db.objectStoreNames.contains(table)) db.createObjectStore(table);
      });
  }

  Database get _db {
    final db = _database;
    if (db == null) throw StateError('Chưa mở IndexedDB');
    return db;
  }

  @override
  Future<String?> read(String key) async {
    final tx = _db.transaction(table, idbModeReadOnly);
    final value = await tx.objectStore(table).getObject(key);
    await tx.completed;
    return value as String?;
  }

  @override
  Future<void> write(String key, String value) async {
    final tx = _db.transaction(table, idbModeReadWrite);
    await tx.objectStore(table).put(value, key);
    await tx.completed;
  }

  @override
  Future<void> close() async {
    _database?.close();
    _database = null;
  }
}
LocalStore createLocalStore() => WebIndexedDbStore();
