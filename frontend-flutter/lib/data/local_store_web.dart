import 'package:idb_shim/idb_browser.dart';
import 'package:idb_shim/idb_shim.dart';
import 'local_store.dart';

class WebIndexedDbStore implements LocalStore {
  // Keep the original DB name to preserve existing PWA users' v1 data.
  static const dbName = 'hhk_cap01_v1';
  static const table = 'settings';
  Database? _database;

  @override
  Future<void> open() async {
    _database ??=
        await idbFactoryWeb.open(dbName, version: 2, onUpgradeNeeded: (event) {
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
  Future<List<String>> keys(String prefix) async {
    final tx = _db.transaction(table, idbModeReadOnly);
    final keys = await tx.objectStore(table).getAllKeys();
    await tx.completed;
    return keys.whereType<String>().where((key) => key.startsWith(prefix)).toList();
  }

  @override
  Future<void> write(String key, String value) async {
    final tx = _db.transaction(table, idbModeReadWrite);
    await tx.objectStore(table).put(value, key);
    await tx.completed;
  }

  @override
  Future<String> update(
      String key, String Function(String?) transform) async {
    final tx = _db.transaction(table, idbModeReadWrite);
    final store = tx.objectStore(table);
    final previous = await store.getObject(key) as String?;
    final next = transform(previous);
    await store.put(next, key);
    await tx.completed;
    return next;
  }

  @override
  Future<void> close() async {
    _database?.close();
    _database = null;
  }
}

LocalStore createLocalStore() => WebIndexedDbStore();
