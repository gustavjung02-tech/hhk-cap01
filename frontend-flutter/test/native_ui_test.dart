import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hhk_cap01/features/native_ui.dart';
import 'package:hhk_cap01/features/native_achievements.dart';
import 'package:hhk_cap01/data/study_ledger.dart';

void main() {
  testWidgets('native lesson panel shows real persisted progress only',
      (tester) async {
    final lesson = <String, dynamic>{'id': 1, 'title': 'Cộng trừ vui'};
    final progress = LessonProgress(
      profileId: 'student', grade: 3, lessonId: 1,
      subjectCode: 'math', attempts: 2, bestCorrect: 6,
      totalQuestions: 8, updatedAt: DateTime.now().toUtc().toIso8601String(),
      attemptIds: const [], wrongQuestionIds: const [],
      recentHistory: const []);
    var opened = false;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: NativeLessonRow(
      lesson: lesson, index: 1, progress: progress,
      onTap: () => opened = true))));
    expect(find.text('Cộng trừ vui'), findsOneWidget);
    expect(find.text('6/8'), findsOneWidget);
    expect(find.text('Đã luyện 2 lượt'), findsOneWidget);
    await tester.tap(find.text('Cộng trừ vui'));
    expect(opened, isTrue);
  });

  testWidgets('native achievements never invent trophies before practice',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: NativeAchievementsPage(
      profileName: 'Bé A', grade: 3, progress: const [],
      onDetails: () {})));
    await tester.pumpAndSettle();
    expect(find.text('Bước khởi đầu'), findsOneWidget);
    expect(find.text('Chưa đạt'), findsNWidgets(3));
    expect(find.text('0'), findsNWidgets(3));
  });
}
