import 'package:material_ui/material_ui.dart';
import '../../data/catalog_repository.dart';
import '../../data/study_ledger.dart';
import 'practice_page.dart';
import 'quiz_evaluator.dart';

class LessonPage extends StatelessWidget {
  final GradePack pack;
  final Map<String, dynamic> lesson;
  final StudyLedger ledger;
  final String profileId;
  const LessonPage(
      {super.key,
      required this.pack,
      required this.lesson,
      required this.ledger,
      required this.profileId});

  @override
  Widget build(BuildContext context) {
    final id = (lesson['id'] as num).toInt();
    final cards = pack.cardsFor(id);
    final allQuestions = pack.questionsFor(id);
    final questions = allQuestions.where(QuizEvaluator.canGrade).toList();
    final unsupported = allQuestions.length - questions.length;
    return Scaffold(
      appBar: AppBar(title: Text(lesson['title']?.toString() ?? 'Bài học')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('Lớp ${pack.grade} • ${lesson['subjectCode']}',
            style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Text(lesson['title']?.toString() ?? '',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        if ((lesson['summarySimple']?.toString() ?? '').isNotEmpty)
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(lesson['summarySimple'].toString()))),
        for (final card in cards)
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(card['title']?.toString() ?? '',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 6),
                        SelectableText(card['content']?.toString() ?? ''),
                      ]))),
        const SizedBox(height: 12),
        if (unsupported > 0)
          Text('$unsupported câu chưa có quy tắc chấm đã được tạm ẩn.',
              style: Theme.of(context).textTheme.bodySmall),
        FilledButton.icon(
          onPressed: questions.isEmpty
              ? null
              : () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => PracticePage(
                      questions: questions,
                      profileId: profileId,
                      subjectCode: lesson['subjectCode']?.toString() ?? '',
                      grade: pack.grade,
                      lessonId: id,
                      ledger: ledger,
                      lessonTitle:
                          lesson['title']?.toString() ?? 'Luyện tập'))),
          icon: const Icon(Icons.quiz_outlined),
          label: Text(questions.isEmpty
              ? 'Chưa có câu hỏi'
              : 'Luyện tập • ${questions.length} câu'),
        ),
      ]),
    );
  }
}
