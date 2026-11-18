import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'catalog_repository.dart';
import 'local_store.dart';

const audioContentVersion = '2026-04-27-v1';

class AudioGradeIndex {
  final int grade;
  final String archiveSha256;
  final int assetCount;
  final List<(int, int)> ranges;
  const AudioGradeIndex(this.grade, this.archiveSha256,
      this.assetCount, this.ranges);

  bool contains(int cardId) => ranges.any((r) =>
      cardId >= r.$1 && cardId <= r.$2);
}

class OfflineAudioCatalog {
  final Map<int, AudioGradeIndex> grades;
  const OfflineAudioCatalog(this.grades);

  factory OfflineAudioCatalog.fromJson(Map<String, dynamic> data) {
    if (data['schema'] != 'hhk-audio-v1' ||
        data['contentVersion'] != audioContentVersion) {
      throw const FormatException('Unsupported offline audio catalog');
    }
    final result = <int, AudioGradeIndex>{};
    for (final entry in data['grades'] as List) {
      final row = Map<String, dynamic>.from(entry as Map);
      final grade = (row['grade'] as num).toInt();
      if (grade < 1 || grade > 5 || result.containsKey(grade)) {
        throw const FormatException('Duplicate or invalid audio grade');
      }
      final ranges = <(int, int)>[];
      final ids = <int>{};
      for (final pair in row['ranges'] as List) {
        final values = List<num>.from(pair as List);
        if (values.length != 2) {
          throw const FormatException('Invalid audio card range');
        }
        final from = values[0].toInt();
        final to = values[1].toInt();
        if (from < 1 || to < from || to > 100000 || to - from > 1000) {
          throw const FormatException('Invalid audio card range');
        }
        for (var id = from; id <= to; id++) {
          if (!ids.add(id)) {
            throw const FormatException('Duplicate audio card ID');
          }
        }
        ranges.add((from, to));
      }
      final count = (row['assetCount'] as num).toInt();
      final sha = row['sha256'].toString();
      if (ids.length != count ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(sha)) {
        throw const FormatException('Unverified audio catalog');
      }
      result[grade] = AudioGradeIndex(grade, sha, count, ranges);
    }
    if (result.length != 5) {
      throw const FormatException('Audio catalog must cover grades 1–5');
    }
    return OfflineAudioCatalog(result);
  }

  static Future<OfflineAudioCatalog> load() async {
    final raw = await rootBundle.loadString(
        'assets/content/audio/catalog.json');
    return OfflineAudioCatalog.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map));
  }

  bool hasCard(int grade, int cardId) =>
      grades[grade]?.contains(cardId) ?? false;

  /// Cards in a grade with genuine source audio; 140 cards per grade have none.
  List<int> gradeCardIds(int grade) {
    final row = grades[grade];
    if (row == null) return const [];
    final ids = <int>[];
    for (final range in row.ranges) {
      for (var id = range.$1; id <= range.$2; id++) {
        ids.add(id);
      }
    }
    return ids..sort();
  }

  List<int> cardsForLesson(GradePack pack, int lessonId) {
    if (pack.grade < 1 || pack.grade > 5) return [];
    return pack.cardsFor(lessonId)
        .where((card) => card['id'] is num)
        .map((card) => (card['id'] as num).toInt())
        .where((id) => hasCard(pack.grade, id))
        .toList(growable: false);
  }
}

class AudioNotReady implements Exception {
  final String message;
  const AudioNotReady(this.message);
  @override
  String toString() => message;
}

/// Only app-origin, verified-catalog, actual MP3s may enter the local cache.
/// No learner profile, keys, account identity or progress is transmitted.
class OfflineAudioStore {
  static const maxFileBytes = 500000;
  final LocalStore localStore;
  final OfflineAudioCatalog catalog;
  final http.Client client;
  final bool _ownsClient;
  final Uri assetOrigin;

  OfflineAudioStore(this.localStore, this.catalog,
      {http.Client? client, String? origin})
      : client = client ?? http.Client(),
        _ownsClient = client == null,
        assetOrigin = Uri.parse(origin ??
            (kIsWeb ? Uri.base.origin :
              const String.fromEnvironment('HHK_PWA_ORIGIN',
                defaultValue: 'https://hhk-cap01-pwa.vercel.app')));

  String _key(int grade, int cardId) =>
      'hhk:audio:$audioContentVersion:g$grade:c$cardId';

  Uri assetUri(int grade, int cardId) {
    if (!catalog.hasCard(grade, cardId)) {
      throw const AudioNotReady('Bài này chưa có bản thu âm.');
    }
    if (assetOrigin.scheme != 'https' &&
        assetOrigin.host != 'localhost' &&
        assetOrigin.host != '127.0.0.1') {
      throw const AudioNotReady('Nguồn âm thanh không an toàn.');
    }
    return assetOrigin.resolve(
        '/audio/tts/$audioContentVersion/grade-$grade/lesson-card-$cardId.mp3');
  }

  Future<Uint8List?> cached(int grade, int cardId) async {
    if (!catalog.hasCard(grade, cardId)) return null;
    final raw = await localStore.read(_key(grade, cardId));
    if (raw == null || raw.isEmpty) return null;
    try {
      final row = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      if (row['version'] != audioContentVersion ||
          row['grade'] != grade ||
          row['cardId'] != cardId) {
        return null;
      }
      final encoded = row['audio'] as String;
      if (encoded.length > (maxFileBytes * 4 ~/ 3 + 16)) return null;
      final bytes = base64Decode(encoded);
      if (bytes.isEmpty || bytes.length > maxFileBytes) return null;
      final actual = await Sha256().hash(bytes);
      final digest = actual.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      if (digest != row['sha256']) return null;
      return Uint8List.fromList(bytes);
    } catch (_) {
      // Fail closed on corrupted cache; never play arbitrary data.
      return null;
    }
  }

  Future<Uint8List> obtain(int grade, int cardId) async {
    final url = assetUri(grade, cardId);
    final stored = await cached(grade, cardId);
    if (stored != null) return stored;
    late final http.Response response;
    try {
      response = await client.get(url).timeout(const Duration(seconds: 20));
    } catch (_) {
      throw const AudioNotReady(
          'Chưa tải âm thanh bài này. Kết nối mạng để tải trước khi nghe offline.');
    }
    final mime = (response.headers['content-type'] ?? '').toLowerCase();
    if (response.statusCode != 200 || response.bodyBytes.isEmpty ||
        response.bodyBytes.length > maxFileBytes ||
        !(mime.contains('audio/mpeg') ||
          mime.contains('audio/mp3') ||
          mime.contains('application/octet-stream'))) {
      throw const AudioNotReady('File âm thanh không có hoặc không hợp lệ.');
    }
    final bytes = response.bodyBytes;
    if (!(bytes.length >= 3 &&
        (bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33 ||
         bytes[0] == 0xff && bytes[1] & 0xe0 == 0xe0))) {
      throw const AudioNotReady('Dữ liệu âm thanh sai định dạng MP3.');
    }
    final hash = await Sha256().hash(bytes);
    final digest = hash.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    try {
      await localStore.write(_key(grade, cardId), jsonEncode({
        'version': audioContentVersion, 'grade': grade, 'cardId': cardId,
        'sha256': digest, 'audio': base64Encode(bytes),
      }));
    } catch (_) {
      throw const AudioNotReady(
          'Bộ nhớ thiết bị không đủ để lưu âm thanh offline.');
    }
    return Uint8List.fromList(bytes);
  }

  Future<int> downloadedCount(int grade, List<int> cardIds) async {
    var count = 0;
    for (final id in cardIds) {
      if (await cached(grade, id) != null) count++;
    }
    return count;
  }

  Future<void> downloadLesson(int grade, List<int> cardIds,
      {void Function(int completed, int total)? onProgress}) async {
    var done = 0;
    for (final id in cardIds) {
      await obtain(grade, id);
      done++;
      onProgress?.call(done, cardIds.length);
    }
  }

  /// One-tap download for a whole grade. Uses up to four parallel,
  /// bounded MP3 requests, saving each verified file immediately. Repeated
  /// calls skip cached files: after disconnect/restart only missing cards
  /// need fetching. A failure never discards files already stored.
  Future<int> downloadGrade(int grade, {
    void Function(int saved, int total)? onProgress,
    bool Function()? isCancelled,
    int concurrency = 4,
  }) async {
    final ids = catalog.gradeCardIds(grade);
    if (ids.isEmpty) {
      throw const AudioNotReady('Lớp này chưa có bộ âm thanh.');
    }
    if (concurrency < 1 || concurrency > 6) {
      throw ArgumentError.value(concurrency, 'concurrency');
    }
    // Verify the local cache before scheduling network requests, so a
    // previously interrupted transfer can be resumed safely.
    final missing = <int>[];
    for (final id in ids) {
      if (await cached(grade, id) == null) missing.add(id);
    }
    var saved = ids.length - missing.length;
    onProgress?.call(saved, ids.length);
    if (missing.isEmpty) return saved;
    var nextIndex = 0;
    Object? firstError;
    final workers = <Future<void>>[];
    Future<void> worker() async {
      while (firstError == null && !(isCancelled?.call() ?? false)) {
        if (nextIndex >= missing.length) break;
        final id = missing[nextIndex++];
        try {
          await obtain(grade, id);
          saved++;
          onProgress?.call(saved, ids.length);
        } catch (e) {
          firstError ??= e;
        }
      }
    }
    for (var i = 0; i < concurrency && i < missing.length; i++) {
      workers.add(worker());
    }
    await Future.wait(workers);
    if (firstError != null) {
      if (firstError is AudioNotReady) {
        throw firstError!;
      }
      throw const AudioNotReady('Tải âm thanh bị gián đoạn. Bấm tiếp tục để tải phần còn thiếu.');
    }
    return saved;
  }

  void dispose() {
    if (_ownsClient) client.close();
  }
}
