// Only Dart abstractions are shared. Web uses IndexedDB; Android/iOS SQLite.
import 'local_store_native.dart'
    if (dart.library.html) 'local_store_web.dart' as platform;

abstract interface class LocalStore {
  Future<void> open();
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> close();
}

LocalStore createLocalStore() => platform.createLocalStore();
