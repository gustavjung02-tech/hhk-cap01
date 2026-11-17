import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hhk_cap01/data/catalog_repository.dart';
import 'package:hhk_cap01/data/local_store.dart';
import 'package:hhk_cap01/data/offline_extra_fun.dart';
import 'package:hhk_cap01/data/offline_fun.dart';
import 'package:hhk_cap01/data/study_ledger.dart';
import 'package:hhk_cap01/features/offline_extra_game_page.dart';
import 'package:hhk_cap01/features/offline_fun_pages.dart';

class FakeStore implements LocalStore {
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
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
  @override
  Future<String> update(String key, String Function(String?) fn) async {
    final value = fn(values[key]);
    values[key] = value;
    return value;
  }
}

Map<String, dynamic> choice(int id, String answer,
    {bool active = true, int lessonId = 1}) => {
  'id': id,
  'lessonId': lessonId,
  'isActive': active ? 1 : 0,
  'questionType': 'single_choice',
  'questionText': 'Câu hỏi kiến thức số $id?',
  'correctAnswer': answer,
  'optionsJson': jsonEncode([answer, 'Sai $id', 'Khác $id']),
};

GradePack testPack(List<Map<String, dynamic>> qs) => GradePack(
  3, const [], const [
    {'id': 1, 'isActive': 1},
    {'id': 2, 'isActive': 0},
  ], const [], qs);

const pupil = StudentProfile(id: 'student1', name: 'Bé Một', grade: 3);
final today = DateTime(2026, 11, 17);

void main() {
  test('four game types never use ungradeable, inactive or fictional content', () {
    final source = testPack([
      choice(1, 'HANOI'), choice(2, 'SAIGON'), choice(3, 'DANANG'),
      choice(4, 'HUE'), choice(5, 'NHATRANG'),
      choice(6, 'HANOI'), // duplicate answer must not create false match
      choice(7, 'UNKNOWN', active: false),
      choice(8, 'BANNED', lessonId: 2),
      {...choice(9, 'SAO'), 'correctAnswer':'not an option'},
      {'id': 10, 'lessonId': 1, 'isActive': 1,
        'questionType': 'fill_text', 'questionText':'Không thể kiểm duyệt',
        'correctAnswer':'guess'},
    ]);
    final matches=OfflineExtraFunEngine.match(source,'student1',today);
    final words=OfflineExtraFunEngine.scramble(source,'student1',today);
    final speed=OfflineExtraFunEngine.speed(source,'student1',today);
    final blanks=OfflineExtraFunEngine.fillBlank(source,'student1',today);
    expect(matches.length, 5);
    expect(matches.map((p)=>p.answer.toLowerCase()).toSet().length, 5);
    expect(matches.any((p)=>p.answer == 'BANNED'), false);
    expect(matches.any((p)=>p.answer == 'UNKNOWN'), false);
    expect(words.length, 5);
    expect(words.every((p)=>p.answer.runes.length >=3), true);
    for(final word in words) {
      expect(word.tiles.toList()..sort(),
        word.answer.runes.map(String.fromCharCode).toList()..sort());
    }
    expect(speed.every((q)=>q.accepts(q.expected)),true);
    expect(blanks.every((q)=>q.accepts(q.expected)),true);
    expect(blanks.any((q)=>q.id=='10'),false);
    expect(OfflineExtraFunEngine.match(source,'student1',today)
      .map((x)=>x.id).toList(), matches.map((x)=>x.id).toList());
  });

  test('empty state rather than invented content when quiz is unsuitable', () {
    final source=testPack([
      {'id':1,'lessonId':1,'isActive':1,'questionType':'fill_text',
       'questionText':'Biết chữ','correctAnswer':'Không xác minh'},
      choice(2,'NA',active:false),
    ]);
    expect(OfflineExtraFunEngine.match(source,'x',today),isEmpty);
    expect(OfflineExtraFunEngine.scramble(source,'x',today),isEmpty);
    expect(OfflineExtraFunEngine.speed(source,'x',today),isEmpty);
    expect(OfflineExtraFunEngine.fillBlank(source,'x',today),isEmpty);
  });

  test('fill blank supports strict numeric grading but no free text', () {
    final source=testPack([
      {'id':1,'lessonId':1,'isActive':1,'questionType':'fill_number',
       'questionText':'2+3=?','correctAnswer':'5'},
      {'id':2,'lessonId':1,'isActive':1,'questionType':'fill_text',
       'questionText':'Trả lời tự do','correctAnswer':'năm'},
    ]);
    final qs=OfflineExtraFunEngine.fillBlank(source,'x',today);
    expect(qs.length,1);
    expect(qs.first.accepts('5'),true);
    expect(qs.first.accepts('5,0'),true);
    expect(qs.first.accepts('năm'),false);
  });

  test('all four game scores persist separately by profile and grade',
      () async {
    final vault=FakeStore();
    final results=FunResultStore(vault);
    for (final mode in [FunMode.match,FunMode.scramble,
        FunMode.speed,FunMode.fillBlank]) {
      expect(await results.saveGame('student1',3,mode,4),4);
      expect(await results.saveGame('student1',3,mode,2),4);
      expect(await results.bestGameScore('student1',3,mode),4);
      expect(await results.bestGameScore('student2',3,mode),0);
      expect(await results.bestGameScore('student1',4,mode),0);
    }
    expect(await results.bestGameScore('student1',3,FunMode.trueFalse),0);
    expect(vault.values.keys.length,4);
    expect(vault.values.keys.every((key)=>key.startsWith('fun:game:')),true);
  });

  testWidgets('fill blank grades and saves a real numeric answer',
      (tester) async {
    final vault=FakeStore();
    final source=testPack([
      {'id': 1, 'lessonId':1,'isActive':1,'questionType':'fill_number',
        'questionText':'2+3=?', 'correctAnswer':'5'},
    ]);
    await tester.pumpWidget(MaterialApp(home: OfflineExtraGamePage(
      mode:FunMode.fillBlank,pack:source,profile:pupil,storage:vault,
      day:today)));
    await tester.pumpAndSettle();
    expect(find.text('2+3=?'),findsOneWidget);
    await tester.enterText(find.byKey(const Key('fill-blank-answer')),'5');
    await tester.tap(find.byKey(const Key('fill-blank-submit')));
    await tester.pump();
    expect(find.text('Chính xác! 🎉'),findsOneWidget);
    await tester.tap(find.byKey(const Key('extra-next')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('extra-game-score')),findsOneWidget);
    expect(await FunResultStore(vault).bestGameScore(
      pupil.id,3,FunMode.fillBlank),1);
  });

  testWidgets('speed timer scores zero when eight seconds expire',
      (tester) async {
    final vault=FakeStore();
    await tester.pumpWidget(MaterialApp(home: OfflineExtraGamePage(
      mode:FunMode.speed,
      pack:testPack([choice(1,'HANOI')]),
      profile:pupil,storage:vault,day:today)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds:100));
    expect(find.text('⏱ Còn 8 giây'),findsOneWidget);
    await tester.pump(const Duration(seconds:9));
    await tester.pump();
    expect(find.textContaining('Chưa đúng. Đáp án:'),findsOneWidget);
    await tester.tap(find.byKey(const Key('extra-next')));
    await tester.pumpAndSettle();
    expect(find.text('0/1 điểm'),findsOneWidget);
    expect(await FunResultStore(vault).bestGameScore(
      pupil.id,3,FunMode.speed),0);
  });

  testWidgets('matching turns over cards without revealing all answers',
      (tester) async {
    final source=testPack([
      choice(1,'HANOI'),choice(2,'SAIGON'),choice(3,'DANANG')
    ]);
    await tester.pumpWidget(MaterialApp(home:OfflineExtraGamePage(
      mode:FunMode.match,pack:source,profile:pupil,
      storage:FakeStore(),day:today)));
    await tester.pumpAndSettle();
    expect(find.text('❔'),findsNWidgets(6));
    await tester.tap(find.text('❔').first);
    await tester.pump();
    expect(find.text('❔'),findsNWidgets(5));
    await tester.tap(find.text('❔').first);
    await tester.pump();
    expect(find.byKey(const Key('match-continue')),findsOneWidget);
  });

  testWidgets('hub refuses nested game entry when signed access expires',
      (tester) async {
    var verified=0;
    await tester.pumpWidget(MaterialApp(home:OfflineMiniGameHubPage(
      pack:testPack([choice(1,'HANOI'),choice(2,'SAIGON'),
        choice(3,'DANANG')]),profile:pupil,storage:FakeStore(),
      ensureAccess:() async { verified++; return false; })));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ghép Cặp'));
    await tester.pumpAndSettle();
    expect(verified,1);
    expect(find.text('Cần key hợp lệ để chơi offline.'),findsOneWidget);
    expect(find.text('Vương quốc Mini-Game'),findsOneWidget);
  });
}
