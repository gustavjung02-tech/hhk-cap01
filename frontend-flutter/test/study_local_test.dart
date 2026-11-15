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
  Future<void> close() async {}
}

void main() {
  test('Vietnamese true/false answers map to source booleans', () {
    final source = {'questionType': 'true_false', 'correctAnswer': 'true'};
    expect(QuizEvaluator.correct(source, 'Đúng'), isTrue);
    expect(QuizEvaluator.correct(source, 'Sai'), isFalse);
  });

  test('numeric input accepts decimal comma', () {
    expect(
        QuizEvaluator.correct(
            {'questionType': 'fill_number', 'correctAnswer': '1.5'}, '1,5'),
        isTrue);
  });

  test('local XP only increases for improved best answer count', () async {
    final store = InMemoryStore();
    final ledger = StudyLedger(store);
    await store.open();
    await ledger.recordResult(grade: 3, lessonId: 54, correct: 5, total: 10);
    await ledger.recordResult(grade: 3, lessonId: 54, correct: 3, total: 10);
    final result = await ledger.recordResult(
        grade: 3, lessonId: 54, correct: 8, total: 10);
    expect(result.attempts, 3);
    expect(result.bestXp, 80);
    expect((await ledger.load(3, 54))!.bestCorrect, 8);
    expect(await ledger.load(4, 54), isNull);
  });
}
