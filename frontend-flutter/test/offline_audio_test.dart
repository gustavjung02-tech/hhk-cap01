import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hhk_cap01/data/catalog_repository.dart';
import 'package:hhk_cap01/data/local_store.dart';
import 'package:hhk_cap01/data/offline_audio.dart';

class _Store implements LocalStore {
  final rows = <String, String>{};
  @override Future<void> open() async {}
  @override Future<void> close() async {}
  @override Future<String?> read(String key) async => rows[key];
  @override Future<void> write(String key, String value) async {
    rows[key] = value;
  }
  @override Future<List<String>> keys(String prefix) async =>
      rows.keys.where((k) => k.startsWith(prefix)).toList();
  @override Future<String> update(String key, String Function(String?) fn) async {
    final next = fn(rows[key]);
    rows[key] = next;
    return next;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('verified catalog covers exactly 4200 source cards, never missing cards',
      () async {
    final catalog = await OfflineAudioCatalog.load();
    expect(catalog.grades.keys.toList(), [1, 2, 3, 4, 5]);
    expect(catalog.grades.values.fold<int>(0, (sum, g) => sum + g.assetCount),
        4200);
    expect(catalog.hasCard(1, 1), isTrue);
    expect(catalog.hasCard(1, 53260), isTrue);
    expect(catalog.hasCard(1, 53261), isFalse);
    expect(catalog.hasCard(2, 81), isTrue);
    expect(catalog.hasCard(3, 3001), isTrue);
    expect(catalog.hasCard(4, 53381), isTrue);
    expect(catalog.hasCard(5, 53500), isTrue);
    expect(catalog.hasCard(5, 99999), isFalse);
    final pack = GradePack(1, const [], [
      {'id': 77, 'title': 'Bài 77'}
    ], [
      {'id': 1, 'lessonId': 77},
      {'id': 2, 'lessonId': 77},
      {'id': 99999, 'lessonId': 77},
    ], const []);
    expect(catalog.cardsForLesson(pack, 77), [1, 2]);
  });

  test('download verified MP3 once, then replay offline after restart',
      () async {
    final catalog = await OfflineAudioCatalog.load();
    final db = _Store();
    final validAudio = Uint8List.fromList([0xff, 0xfb, 0x90, 0x64, 1, 2, 3, 4]);
    var fetches = 0;
    final online = OfflineAudioStore(db, catalog,
      origin: 'https://hhk.example.test',
      client: MockClient((request) async {
        fetches++;
        expect(request.url.path,
            '/audio/tts/2026-04-27-v1/grade-1/lesson-card-1.mp3');
        return http.Response.bytes(validAudio, 200,
          headers: {'content-type': 'audio/mpeg'});
      }));
    expect(await online.cached(1, 1), isNull);
    expect(await online.obtain(1, 1), validAudio);
    expect(fetches, 1);
    expect(await online.obtain(1, 1), validAudio);
    expect(fetches, 1);
    online.dispose();

    final offline = OfflineAudioStore(db, catalog,
      origin: 'https://hhk.example.test',
      client: MockClient((_) async {
        throw Exception('AIRPLANE_MODE');
      }));
    expect(await offline.obtain(1, 1), validAudio);
    expect(await offline.downloadedCount(1, [1, 2]), 1);
    offline.dispose();
  });

  test('rejects HTTP errors and HTML fallback instead of caching broken audio',
      () async {
    final catalog = await OfflineAudioCatalog.load();
    final db = _Store();
    final bad = OfflineAudioStore(db, catalog,
      origin: 'https://hhk.example.test',
      client: MockClient((_) async => http.Response(
        '<!doctype html><html>Flutter fallback</html>', 200,
        headers: {'content-type': 'text/html'})));
    await expectLater(bad.obtain(1, 1), throwsA(isA<AudioNotReady>()));
    expect(db.rows, isEmpty);
    await expectLater(bad.obtain(1, 99999), throwsA(isA<AudioNotReady>()));
    bad.dispose();
  });

  test('corrupt local SHA, wrong profile or invalid base64 never plays',
      () async {
    final catalog = await OfflineAudioCatalog.load();
    final db = _Store();
    final bad = OfflineAudioStore(db, catalog,
      origin: 'https://hhk.example.test',
      client: MockClient((_) async => http.Response('', 503)));
    db.rows['hhk:audio:2026-04-27-v1:g1:c1'] = jsonEncode({
      'version': audioContentVersion, 'grade': 1, 'cardId': 1,
      'sha256': '0' * 64, 'audio': base64Encode([0xff, 0xfb, 0x90, 0x64])
    });
    expect(await bad.cached(1, 1), isNull);
    db.rows['hhk:audio:2026-04-27-v1:g1:c1'] = '{"badJson":null}';
    expect(await bad.cached(1, 1), isNull);
    bad.dispose();
  });

  test('prefetch stops on network failure and keeps completed cards cached',
      () async {
    final catalog = await OfflineAudioCatalog.load();
    final db = _Store();
    final seen = <int>[];
    final service = OfflineAudioStore(db, catalog,
      origin: 'https://hhk.example.test',
      client: MockClient((req) async {
        if (req.url.path.contains('lesson-card-2.mp3')) {
          return http.Response('Service unavailable', 503);
        }
        return http.Response.bytes([0xff, 0xfb, 0x90, 0x64, 2],
          200, headers: {'content-type': 'audio/mpeg'});
      }));
    await expectLater(service.downloadLesson(1, [1, 2],
      onProgress: (done, _) => seen.add(done)), throwsA(isA<AudioNotReady>()));
    expect(seen, [1]);
    expect(await service.cached(1, 1), isNotNull);
    expect(await service.cached(1, 2), isNull);
    service.dispose();
  });
  test('download all grade cards once; offline interruption resumes only missing',
      () async {
    // A reduced deterministic catalog exercises the same whole-grade path
    // without making hundreds of mock requests in a CI unit test.
    final catalog = OfflineAudioCatalog.fromJson({
      'schema': 'hhk-audio-v1',
      'contentVersion': audioContentVersion,
      'grades': List.generate(5, (i) {
        final ids = i == 0 ? [1, 4] : [100 + i, 100 + i];
        return {
          'grade': i + 1,
          'ranges': [ids],
          'assetCount': i == 0 ? 4 : 1,
          'sizeBytes': 100,
          'sha256': 'a' * 64,
        };
      }),
    });
    expect(catalog.gradeCardIds(1), [1, 2, 3, 4]);
    final db = _Store();
    final fetched = <int>[];
    final audio = [0xff, 0xfb, 0x90, 0x64, 1, 2, 3, 4];
    final firstAttempt = OfflineAudioStore(db, catalog,
        origin: 'https://hhk.example.test',
        client: MockClient((req) async {
          final file = req.url.pathSegments.last;
          final id = int.parse(file.split('-').last.split('.').first);
          fetched.add(id);
          if (id == 3) return http.Response('Network lost', 503);
          return http.Response.bytes(audio, 200,
              headers: {'content-type': 'audio/mpeg'});
        }));
    await expectLater(firstAttempt.downloadGrade(1, concurrency: 1),
        throwsA(isA<AudioNotReady>()));
    expect(fetched, [1, 2, 3]);
    expect(await firstAttempt.cached(1, 1), isNotNull);
    expect(await firstAttempt.cached(1, 2), isNotNull);
    expect(await firstAttempt.cached(1, 3), isNull);
    firstAttempt.dispose();

    fetched.clear();
    final progress = <int>[];
    final resumed = OfflineAudioStore(db, catalog,
        origin: 'https://hhk.example.test',
        client: MockClient((req) async {
          final file = req.url.pathSegments.last;
          fetched.add(int.parse(file.split('-').last.split('.').first));
          return http.Response.bytes(audio, 200,
              headers: {'content-type': 'audio/mpeg'});
        }));
    expect(await resumed.downloadGrade(1, concurrency: 2,
        onProgress: (count, _) => progress.add(count)), 4);
    expect(fetched, unorderedEquals([3, 4]));
    expect(progress.first, 2);
    expect(progress.last, 4);
    fetched.clear();
    expect(await resumed.downloadGrade(1), 4);
    expect(fetched, isEmpty);
    expect(await resumed.downloadedCount(1, catalog.gradeCardIds(1)), 4);
    resumed.dispose();
  });

  test('whole-grade stop is incremental and resumes without duplicate fetches',
      () async {
    final catalog = OfflineAudioCatalog.fromJson({
      'schema': 'hhk-audio-v1',
      'contentVersion': audioContentVersion,
      'grades': List.generate(5, (i) => {
        'grade': i + 1,
        'ranges': i == 0 ? [[1, 5]] : [[100 + i, 100 + i]],
        'assetCount': i == 0 ? 5 : 1,
        'sizeBytes': 100,
        'sha256': 'b' * 64,
      }),
    });
    final store = _Store();
    var requested = 0;
    var stop = false;
    final service = OfflineAudioStore(store, catalog,
        origin: 'https://hhk.example.test',
        client: MockClient((_) async {
          requested++;
          return http.Response.bytes([0xff, 0xfb, 0x90, 0x64, 4],
              200, headers: {'content-type': 'audio/mpeg'});
        }));
    final saved = await service.downloadGrade(1, concurrency: 1,
        isCancelled: () => stop,
        onProgress: (count, _) {
          if (count == 2) stop = true;
        });
    expect(saved, 2);
    expect(requested, 2);
    expect(await service.downloadGrade(1, concurrency: 2), 5);
    expect(requested, 5);
    service.dispose();
  });

}
