import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:hhk_cap01/data/catalog_repository.dart';
import 'package:hhk_cap01/data/local_store.dart';
import 'package:hhk_cap01/data/study_ledger.dart';
import 'package:hhk_cap01/features/study/lesson_page.dart';

class _Store implements LocalStore {
  final rows = <String, String>{};
  @override Future<void> open() async {}
  @override Future<void> close() async {}
  @override Future<String?> read(String key) async => rows[key];
  @override Future<void> write(String key, String value) async {
    rows[key] = value;
  }
  @override Future<List<String>> keys(String prefix) async =>
      rows.keys.where((key) => key.startsWith(prefix)).toList();
  @override Future<String> update(String key, String Function(String?) transform) async {
    final next = transform(rows[key]);
    rows[key] = next;
    return next;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('audio buttons show only verified MP3 cards, not all lesson cards',
      (tester) async {
    final store = _Store();
    await store.open();
    final pack = GradePack(1, const [], [
      {'id': 1, 'title': 'Bài số một', 'subjectCode': 'math', 'isActive': 1}
    ], [
      {'id': 1, 'lessonId': 1, 'title': 'Giới thiệu',
        'content': 'Nội dung của thẻ một', 'sortOrder': 1, 'isActive': 1},
      {'id': 2, 'lessonId': 1, 'title': 'Bài hai',
        'content': 'Nội dung của thẻ hai', 'sortOrder': 2, 'isActive': 1},
      {'id': 99999, 'lessonId': 1, 'title': 'Thẻ mới chưa có audio',
        'content': 'Nội dung mới', 'sortOrder': 3, 'isActive': 1},
    ], const []);
    await tester.pumpWidget(MaterialApp(home: LessonPage(
      pack: pack, lesson: pack.lessons.first,
      ledger: StudyLedger(store), profileId: 'child1', storage: store,
    )));
    await tester.pumpAndSettle();
    expect(find.text('Tải âm thanh bài này'), findsOneWidget);
    expect(find.text('Đã lưu offline 0/2 thẻ. Tải một lần để nghe khi mất mạng.'),
        findsOneWidget);
    expect(find.text('Nghe thẻ này'), findsNWidgets(2));
    await tester.scrollUntilVisible(
      find.text('Thẻ mới chưa có audio'), 180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Thẻ mới chưa có audio'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('without a storage backend, no pretend offline controls appear',
      (tester) async {
    final pack = GradePack(2, const [], [
      {'id': 9, 'title': 'Bài 9', 'isActive': 1, 'subjectCode': 'math'}
    ], [
      {'id': 81, 'lessonId': 9, 'title': 'Thẻ', 'content': 'Bài học',
        'isActive': 1}
    ], const []);
    await tester.pumpWidget(MaterialApp(home: LessonPage(
      pack: pack, lesson: pack.lessons.first,
      ledger: StudyLedger(_Store()), profileId: 'child1',
    )));
    await tester.pumpAndSettle();
    expect(find.text('Tải âm thanh bài này'), findsNothing);
    expect(find.text('Nghe thẻ này'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
