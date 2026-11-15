import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hhk_cap01/data/local_store_web.dart';
import 'package:hhk_cap01/data/study_ledger.dart';

/// Browser-only integration tests for the *real* IndexedDB adapter.
/// This file lives outside test/ so dart:html cannot be compiled by VM tests.
void main() {
  test('IndexedDB survives close/reopen with isolated profiles and XP',
      () async {
    var storage = WebIndexedDbStore();
    await storage.open();
    final suffix = DateTime.now().microsecondsSinceEpoch.toString();
    final markerKey = 'browser-smoke:$suffix';
    await storage.write(markerKey, 'persisted');
    var ledger = StudyLedger(storage);
    await ledger.initialize();
    final first = await ledger.createProfile('Chrome A', 3);
    final second = await ledger.createProfile('Chrome B', 4);
    final attemptId = 'browser-attempt-$suffix';
    await ledger.recordResult(
        profileId: first.id,
        grade: 3,
        lessonId: 940011,
        attemptId: attemptId,
        correct: 7,
        total: 10,
        subjectCode: 'math',
        wrongQuestionIds: [101, 102, 103]);
    await ledger.recordResult(
        profileId: second.id,
        grade: 4,
        lessonId: 940011,
        attemptId: 'second-$suffix',
        correct: 9,
        total: 10,
        subjectCode: 'english');
    expect(await ledger.totalXp(first.id), 70);
    expect(await ledger.totalXp(second.id), 90);
    await storage.close();

    // New IndexedDB connection + new StudyLedger, as on app startup.
    storage = WebIndexedDbStore();
    await storage.open();
    ledger = StudyLedger(storage);
    await ledger.initialize();
    expect(await storage.read(markerKey), 'persisted');
    expect((await ledger.activeProfile()).id, second.id);
    expect(await ledger.totalXp(first.id), 70);
    expect(await ledger.totalXp(second.id), 90);
    expect(
        (await ledger.load(
                profileId: first.id, grade: 3, lessonId: 940011))!
            .attempts,
        1);
    expect(
        await ledger.load(
            profileId: second.id, grade: 3, lessonId: 940011),
        isNull);
    await ledger.recordResult(
        profileId: first.id,
        grade: 3,
        lessonId: 940011,
        attemptId: attemptId,
        correct: 7,
        total: 10);
    expect(
        (await ledger.load(
                profileId: first.id, grade: 3, lessonId: 940011))!
            .attempts,
        1);
    await storage.close();
  });

  test('IndexedDB migrates legacy lesson keys on restart without loss',
      () async {
    var storage = WebIndexedDbStore();
    await storage.open();
    final suffix = DateTime.now().microsecondsSinceEpoch.toString();
    // Use unused lesson IDs to keep the real persistent IndexedDB state safe
    // even if a developer runs this test in a reused browser profile.
    final lessonId = 980000 + int.parse(suffix.substring(suffix.length - 5));
    final key = 'progress:v1:3:$lessonId';
    final legacy = jsonEncode({
      'grade': 3,
      'lessonId': lessonId,
      'attempts': 2,
      'bestCorrect': 6,
      'totalQuestions': 10,
      'updatedAt': '2026-11-01T00:00:00.000Z',
    });
    await storage.write(key, legacy);
    var ledger = StudyLedger(storage);
    await ledger.initialize();
    final migrated = await ledger.load(
        profileId: StudyLedger.defaultProfileId,
        grade: 3,
        lessonId: lessonId);
    expect(migrated?.bestXp, 60);
    expect(migrated?.attempts, 2);
    await storage.close();

    storage = WebIndexedDbStore();
    await storage.open();
    ledger = StudyLedger(storage);
    await ledger.initialize();
    expect(await storage.read(key), legacy); // non-destructive migration
    final again = await ledger.load(
        profileId: StudyLedger.defaultProfileId,
        grade: 3,
        lessonId: lessonId);
    expect(again?.attempts, 2);
    expect(again?.bestXp, 60);
    await storage.close();
  });
}
