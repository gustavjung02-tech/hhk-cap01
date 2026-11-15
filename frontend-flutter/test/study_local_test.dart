import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hhk_cap01/data/local_store.dart';
import 'package:hhk_cap01/data/study_ledger.dart';
import 'package:hhk_cap01/features/study/quiz_evaluator.dart';

class InMemoryStore implements LocalStore {
  final values = <String, String>{};

  @override
  Future<void> open() async {}
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
  @override
  Future<String> update(String key, String Function(String?) transform) async {
    final next = transform(values[key]);
    values[key] = next;
    return next;
  }
  @override
  Future<void> close() async {}
}

void main() {
  test('true/false accepts Vietnamese and boolean source answers', () {
    for (final expected in ['Đúng', 'true']) {
      final question = {'questionType': 'true_false', 'correctAnswer': expected};
      expect(QuizEvaluator.canGrade(question), true);
      expect(QuizEvaluator.correct(question, 'Đúng'), true);
      expect(QuizEvaluator.correct(question, 'Sai'), false);
    }
    expect(QuizEvaluator.correct(
        {'questionType': 'true_false', 'correctAnswer': 'Sai'}, 'false'), true);
  });

  test('number and choice are strict; unknown/text/multi are not scored', () {
    expect(QuizEvaluator.correct(
        {'questionType': 'fill_number', 'correctAnswer': '1.5'}, '1,5'), true);
    final choice = {
      'questionType': 'single_choice',
      'optionsJson': jsonEncode(['A', 'B']),
      'correctAnswer': 'B'
    };
    expect(QuizEvaluator.canGrade(choice), true);
    expect(QuizEvaluator.correct(choice, 'B'), true);
    expect(QuizEvaluator.correct(choice, 'C'), false);
    for (final kind in ['multiple_choice', 'fill_text', 'essay', 'unknown']) {
      final question = {'questionType': kind, 'correctAnswer': 'A'};
      expect(QuizEvaluator.canGrade(question), false);
      expect(QuizEvaluator.correct(question, 'A'), false);
    }
    expect(QuizEvaluator.canGrade({
      'questionType': 'single_choice',
      'optionsJson': 'bad json',
      'correctAnswer': 'B'
    }), false);
  });

  test('3 profiles / 2 grades, restart, XP, retry and review isolation', () async {
    final store = InMemoryStore();
    await store.open();
    var ledger = StudyLedger(store);
    await ledger.initialize();
    final p1 = await ledger.activeProfile();
    final p2 = await ledger.createProfile('Bé thứ hai', 4);
    final p3 = await ledger.createProfile('Bé thứ ba', 3);
    expect((await ledger.listProfiles()).length, 3);
    await ledger.recordResult(
        profileId: p1.id, grade: 3, lessonId: 54, attemptId: 'a1',
        subjectCode: 'math', correct: 5, total: 10,
        wrongQuestionIds: [1, 2],
        completedAt: DateTime.utc(2026, 11, 1));
    final first = await ledger.recordResult(
        profileId: p1.id, grade: 3, lessonId: 54, attemptId: 'a1',
        subjectCode: 'math', correct: 5, total: 10);
    expect(first.attempts, 1);
    await ledger.recordResult(
        profileId: p1.id, grade: 3, lessonId: 54, attemptId: 'a2',
        correct: 3, total: 10);
    await ledger.recordResult(
        profileId: p2.id, grade: 4, lessonId: 54, attemptId: 'b1',
        correct: 9, total: 10);
    await ledger.recordResult(
        profileId: p3.id, grade: 3, lessonId: 54, attemptId: 'c1',
        correct: 1, total: 10);
    await store.close();
    ledger = StudyLedger(store);
    await store.open();
    await ledger.initialize();
    expect((await ledger.load(profileId: p1.id, grade: 3, lessonId: 54))!.attempts, 2);
    expect((await ledger.load(profileId: p1.id, grade: 3, lessonId: 54))!.bestXp, 50);
    expect(await ledger.totalXp(p2.id), 90);
    expect(await ledger.totalXp(p3.id), 10);
    expect(await ledger.load(profileId: p2.id, grade: 3, lessonId: 54), isNull);
    expect((await ledger.subjectStatistics(p1.id, 3)).single.attempts, 2);
    expect((await ledger.dueForReview(p1.id, DateTime.utc(2026, 12, 1))).length, 1);
    expect((await ledger.activeProfile()).id, p3.id);
    await ledger.changeGrade(p3.id, 5);
    expect((await ledger.selectProfile(p3.id)).grade, 5);
  });

  test('v1 best XP is preserved without assigning it to other profiles', () async {
    final store = InMemoryStore();
    await store.open();
    await store.write('selected_grade', '4');
    await store.write('progress:v1:4:100', jsonEncode({
      'grade': 4, 'lessonId': 100, 'attempts': 3,
      'bestCorrect': 8, 'totalQuestions': 10,
      'updatedAt': '2026-11-01T00:00:00.000Z'
    }));
    final ledger = StudyLedger(store);
    await ledger.initialize();
    final legacy = await ledger.activeProfile();
    expect(legacy.grade, 4);
    expect((await ledger.load(profileId: legacy.id, grade: 4, lessonId: 100))!.bestXp, 80);
    final next = await ledger.recordResult(
        profileId: legacy.id, grade: 4, lessonId: 100,
        attemptId: 'after-upgrade', correct: 7, total: 10);
    expect(next.attempts, 4);
    expect(next.bestXp, 80);
    final another = await ledger.createProfile('Khác', 4);
    expect(await ledger.load(profileId: another.id, grade: 4, lessonId: 100), isNull);
  });

  test('parallel save with same attempt id is recorded once', () async {
    final store = InMemoryStore();
    await store.open();
    final first = StudyLedger(store);
    final second = StudyLedger(store);
    await first.initialize();
    final p = await first.activeProfile();
    await Future.wait([
      first.recordResult(profileId: p.id, grade: 3, lessonId: 9,
          attemptId: 'same-attempt', correct: 4, total: 10),
      second.recordResult(profileId: p.id, grade: 3, lessonId: 9,
          attemptId: 'same-attempt', correct: 4, total: 10),
    ]);
    final saved = await first.load(profileId: p.id, grade: 3, lessonId: 9);
    expect(saved!.attempts, 1);
    expect(saved.bestXp, 40);
  });

  test('invalid score and unknown profile do not write progress', () async {
    final store = InMemoryStore();
    await store.open();
    final ledger = StudyLedger(store);
    await ledger.initialize();
    await expectLater(
        ledger.recordResult(profileId: 'missing', grade: 3, lessonId: 1,
            attemptId: 'x', correct: 0, total: 10),
        throwsArgumentError);
    await expectLater(
        ledger.recordResult(profileId: StudyLedger.defaultProfileId, grade: 3,
            lessonId: 1, attemptId: 'x', correct: 11, total: 10),
        throwsArgumentError);
  });
}
