import 'package:flutter_test/flutter_test.dart';
import 'package:hhk_cap01/data/catalog_repository.dart';
import 'package:hhk_cap01/data/creative_port.dart';
import 'package:hhk_cap01/data/local_store.dart';

class FakeLocalStore implements LocalStore {
  final rows = <String, String>{};
  @override Future<void> open() async {}
  @override Future<void> close() async {}
  @override Future<String?> read(String key) async => rows[key];
  @override Future<List<String>> keys(String prefix) async =>
      rows.keys.where((k) => k.startsWith(prefix)).toList();
  @override Future<void> write(String key, String value) async {
    rows[key] = value;
  }
  @override Future<String> update(String key, String Function(String?) transform) async {
    final result = transform(rows[key]);
    rows[key] = result;
    return result;
  }
}

void main() {
  test('art persists, undoes and isolates learners and grades', () async {
    final db = FakeLocalStore();
    final service = ArtStore(db);
    final drawing = ArtDocument(template: 2, strokes: [
      ArtStroke(0xffef4444, 6,
        [const ArtPoint(.1, .1), const ArtPoint(.9, .9)]),
    ]);
    await service.save('child1', 3, drawing);
    expect((await service.load('child1', 3)).strokes.length, 1);
    expect((await service.load('child2', 3)).strokes, isEmpty);
    expect((await service.load('child1', 4)).strokes, isEmpty);
    await service.save('child1', 3, const ArtDocument(template: 2));
    expect((await service.load('child1', 3)).strokes, isEmpty);
    db.rows[service.key('child1', 3)] = '{"version":99}';
    await expectLater(service.save('child1', 3, drawing), throwsFormatException);
    expect(db.rows[service.key('child1', 3)], '{"version":99}');
  });

  test('memory cards are taken only from valid active real questions', () {
    final pack = GradePack(3, const [], [
      {'id': 7, 'title': 'Bài 7', 'isActive': 1},
    ], const [], [
      {'id': 1, 'lessonId': 7, 'questionText': '2 + 2?',
        'questionType': 'single_choice', 'optionsJson': '["3","4","5"]',
        'correctAnswer': '4', 'isActive': 1},
      {'id': 2, 'lessonId': 7, 'questionText': 'Tự do?',
        'questionType': 'fill_text', 'correctAnswer': 'tùy ý', 'isActive': 1},
      {'id': 3, 'lessonId': 7, 'questionText': 'Đúng?',
        'questionType': 'true_false', 'correctAnswer': 'true', 'isActive': 1},
      {'id': 4, 'lessonId': 8, 'questionText': 'Sai bài',
        'questionType': 'fill_number', 'correctAnswer': '5', 'isActive': 1},
    ]);
    final cards = ReviewDeck.fromPack(pack);
    expect(cards.map((q) => q.id).toList(), [1, 3]);
    expect(cards.first.answer, '4');
    expect(cards.last.answer, 'Đúng');
  });

  test('review schedule is profile and grade isolated with spaced intervals', () async {
    final db = FakeLocalStore();
    final service = MemoryRoomStore(db);
    final now = DateTime.utc(2026, 11, 18);
    final hard = await service.rate('one', 2, 7, 'hard', now);
    expect(hard.intervalIndex, 0);
    expect(hard.atMillis - now.millisecondsSinceEpoch, 60000);
    final easy = await service.rate('one', 2, 7, 'easy', now);
    expect(easy.intervalIndex, 2);
    expect((await service.load('one', 2))[7]!.intervalIndex, 2);
    expect(await service.load('two', 2), isEmpty);
    expect(await service.load('one', 3), isEmpty);
  });

  test('mind-map branches come from actual lesson cards', () {
    final pack = GradePack(2, const [], [
      {'id': 3, 'title': 'Thiên nhiên', 'summarySimple': 'Cây cần nước'},
    ], [
      {'lessonId': 3, 'title': 'Lá', 'content': 'Lá cây quang hợp'},
    ], const []);
    expect(MindMapDeck.fromLesson(pack, 3).map((b) => b.title),
      ['Tổng quan', 'Lá']);
    expect(MindMapDeck.fromLesson(pack, 99), isEmpty);
  });

  test('avatar purchases are one-time, cannot mint XP or leak between profiles', () async {
    final db = FakeLocalStore();
    final shop = AvatarStore(db);
    await expectLater(shop.buy('one', 'av_panda', 50), throwsStateError);
    final owned = await shop.buy('one', 'av_panda', 150);
    expect(owned.spent, 50);
    final repeated = await shop.buy('one', 'av_panda', 150);
    expect(repeated.spent, 50);
    expect((await shop.load('two')).spent, 0);
    await expectLater(shop.equip('two', 'av_panda'), throwsStateError);
    final equipped = await shop.equip('one', 'av_panda');
    expect(equipped.equipped, 'av_panda');
  });
}
