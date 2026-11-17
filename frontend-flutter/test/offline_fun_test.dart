import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hhk_cap01/data/catalog_repository.dart';
import 'package:hhk_cap01/data/local_store.dart';
import 'package:hhk_cap01/data/offline_fun.dart';
import 'package:hhk_cap01/data/study_ledger.dart';
import 'package:hhk_cap01/features/offline_fun_pages.dart';

class MemoryStore implements LocalStore {
  final values = <String, String>{};
  @override
  Future<void> open() async {}
  @override
  Future<void> close() async {}
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<List<String>> keys(String prefix) async =>
      values.keys.where((key) => key.startsWith(prefix)).toList();
  @override
  Future<void> write(String key, String value) async { values[key] = value; }
  @override
  Future<String> update(String key, String Function(String?) transform) async {
    final next = transform(values[key]);
    values[key] = next;
    return next;
  }
}

Map<String, dynamic> question(int id, String type,
    {String answer = 'Đúng', int lessonId = 1, bool active = true}) => {
  'id': id,
  'lessonId': lessonId,
  'questionType': type,
  'questionText': 'Câu hỏi $id',
  'correctAnswer': answer,
  'optionsJson': jsonEncode(['A', 'B']),
  'isActive': active ? 1 : 0,
};

GradePack pack({List<Map<String, dynamic>>? questions}) =>
    GradePack(3, const [], [
      {'id': 1, 'isActive': 1},
      {'id': 2, 'isActive': 0},
    ], const [], questions ?? [
      for (var i = 1; i <= 10; i++)
        question(i, 'true_false', answer: i.isEven ? 'Sai' : 'Đúng'),
    ]);

void main() {
  test('daily 5 questions deterministic and never includes ungradable content',
      () {
    final source = pack(questions: [
      for (var i = 1; i <= 11; i++)
        question(i, 'single_choice', answer: 'A'),
      question(19, 'single_choice', answer: 'nonsense'),
      question(20, 'true_false', lessonId: 2),
      question(21, 'essay', answer: 'free text'),
      question(22, 'true_false', active: false),
    ]);
    final day = DateTime(2026, 11, 17);
    final a = FunQuestionEngine.daily(source, 'p1', day);
    final b = FunQuestionEngine.daily(source, 'p1', day);
    expect(a.length, 5);
    expect(a.map((x) => x.id).toList(), b.map((x) => x.id).toList());
    expect(a.map((x) => x.id).toSet().length, 5);
    expect(a.every((x) => x.accepts('A')), isTrue);
    expect(a.every((x) => !x.accepts('B')), isTrue);
    expect(a.map((x) => x.id), isNot(contains('19')));
    expect(a.map((x) => x.id), isNot(contains('20')));
    final tomorrow = FunQuestionEngine.daily(
        source, 'p1', DateTime(2026, 11, 18));
    expect(tomorrow.length, 5);
    expect(localStudyDate(day).length, 10);
  });

  test('true-false game keeps real graded statements only', () {
    final source = pack(questions: [
      question(1, 'true_false', answer: 'Sai'),
      question(2, 'true_false', answer: 'Đúng'),
      question(3, 'single_choice', answer: 'A'),
      question(4, 'true_false', answer: 'UNKNOWN'),
    ]);
    final qs = FunQuestionEngine.trueFalse(
        source, 'p1', DateTime(2026, 11, 17));
    expect(qs.length, 2);
    expect(qs.every((q) => q.options.join(',') == 'Đúng,Sai'), isTrue);
    for (final q in qs) {
      expect(q.accepts(q.expected), isTrue);
      expect(q.accepts(q.expected == 'Đúng' ? 'Sai' : 'Đúng'), isFalse);
    }
  });

  test('quick math is reproducible, grade-appropriate, exact and offline', () {
    for (var grade = 1; grade <= 5; grade++) {
      final today = DateTime(2026, 11, 17);
      final qs = FunQuestionEngine.quickMath(grade, 'p1', today);
      final again = FunQuestionEngine.quickMath(grade, 'p1', today);
      expect(qs.length, 10);
      expect(qs.map((q) => q.prompt).toList(),
          again.map((q) => q.prompt).toList());
      for (final q in qs) {
        expect(q.accepts(q.expected), isTrue);
        expect(q.accepts('not a number'), isFalse);
        expect(q.prompt.contains(' = ?'), isTrue);
        expect(int.parse(q.expected), greaterThanOrEqualTo(0));
      }
    }
    expect(() => FunQuestionEngine.quickMath(
        0, 'p1', DateTime(2026, 11, 17)), throwsArgumentError);
  });

  test('daily score first-write-wins, persists restart and isolates profiles',
      () async {
    final vault = MemoryStore();
    await vault.open();
    var results = FunResultStore(vault);
    const day = '2026-11-17';
    expect(await results.readDaily('p1', 3, day), isNull);
    final saved = await results.completeDaily(
      'p1', 3, const FunResult(day, 4, 5, '2026-11-17T08:00:00Z'));
    expect(saved.percent, 80);
    final retry = await results.completeDaily(
      'p1', 3, const FunResult(day, 5, 5, '2026-11-17T09:00:00Z'));
    expect(retry.correct, 4, reason: 'cannot overwrite first daily result');
    results = FunResultStore(vault);
    expect((await results.readDaily('p1', 3, day))!.correct, 4);
    expect(await results.readDaily('p2', 3, day), isNull);
    expect(await results.readDaily('p1', 4, day), isNull);
    expect(await results.readDaily('p1', 3, '2026-11-18'), isNull);
    expect(await results.saveGame('p1', 3, FunMode.trueFalse, 8), 8);
    expect(await results.saveGame('p1', 3, FunMode.trueFalse, 3), 8);
    expect(await results.bestGameScore('p2', 3, FunMode.trueFalse), 0);
    expect(await results.bestGameScore('p1', 3, FunMode.trueFalse), 8);
  });

  testWidgets('daily challenge records a real answer and does not replay',
      (tester) async {
    final vault = MemoryStore();
    await vault.open();
    const student = StudentProfile(id: 'p1', name: 'Bé A', grade: 3);
    final source = pack(questions: [
      question(101, 'single_choice', answer: 'A'),
    ]);
    Widget build() => MaterialApp(home: OfflineFunRoundPage(
      key: UniqueKey(),
      mode: FunMode.daily, pack: source, profile: student,
      storage: vault, day: DateTime(2026, 11, 17)));
    await tester.pumpWidget(build());
    await tester.pumpAndSettle();
    expect(find.text('Câu 1/1'), findsOneWidget);
    await tester.tap(find.text('A'));
    await tester.pump();
    expect(find.text('Chính xác! 🎉'), findsOneWidget);
    await tester.tap(find.byKey(const Key('fun-next')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fun-score')), findsOneWidget);
    expect((await FunResultStore(vault).readDaily(
      'p1', 3, localStudyDate(DateTime(2026, 11, 17))))!.correct, 1);
    await tester.pumpWidget(build());
    await tester.pumpAndSettle();
    expect(find.text('Hôm nay đã hoàn thành! 🌟'), findsOneWidget);
    expect(find.text('Câu 1/1'), findsNothing);
  });

  testWidgets('mini-game menu offers only implemented modes',
      (tester) async {
    final vault = MemoryStore();
    await vault.open();
    await tester.pumpWidget(MaterialApp(home: OfflineMiniGameHubPage(
      pack: pack(),
      profile: const StudentProfile(id: 'p1', name: 'A', grade: 3),
      storage: vault,
    )));
    await tester.pumpAndSettle();
    expect(find.text('Đúng hay Sai'), findsOneWidget);
    expect(find.text('Toán Siêu Tốc'), findsOneWidget);
    expect(find.text('Các trò chơi khác của app cũ sẽ được chuyển theo từng đợt. '
      'Điểm mini-game không tự cộng vào XP bài học.'), findsOneWidget);
  });
}
