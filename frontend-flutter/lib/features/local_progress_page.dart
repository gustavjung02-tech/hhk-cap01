import 'package:material_ui/material_ui.dart';
import '../data/catalog_repository.dart';
import '../data/study_ledger.dart';
import 'study/lesson_page.dart';

/// Real offline progress & scheduled review; no cloud learner tracking.
class LocalProgressPage extends StatelessWidget {
  final StudyLedger ledger;
  final StudentProfile profile;
  final int grade;
  final bool review;
  final Future<GradePack> currentPack;

  const LocalProgressPage({super.key, required this.ledger,
    required this.profile, required this.grade, required this.currentPack,
    this.review = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(review ? 'Ôn tập thông minh' : 'Tiến bộ học tập')),
      body: FutureBuilder<List<LessonProgress>>(
        future: review
            ? ledger.dueForReview(profile.id, DateTime.now())
            : ledger.progressFor(profile.id, grade: grade),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Không đọc được dữ liệu offline.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final records = snapshot.data!.where((p) => p.grade == grade).toList();
          final xp = records.fold<int>(0, (sum, p) => sum + p.bestXp);
          final attempts = records.fold<int>(0, (sum, p) => sum + p.attempts);
          return ListView(padding: const EdgeInsets.all(16), children: [
            Text('${profile.name} · Lớp $grade',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: Card(child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(children: [
                  Text('${records.length}',
                      style: Theme.of(context).textTheme.headlineMedium),
                  Text(review ? 'Bài cần ôn' : 'Bài đã luyện'),
                ]),
              ))),
              Expanded(child: Card(child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(children: [
                  Text('$xp',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const Text('XP tốt nhất'),
                ]),
              ))),
              Expanded(child: Card(child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(children: [
                  Text('$attempts',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const Text('Lượt làm'),
                ]),
              ))),
            ]),
            const SizedBox(height: 12),
            if (records.isEmpty)
              Card(child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(review
                    ? 'Chưa có bài đến hạn ôn. Tiếp tục luyện tập nhé!'
                    : 'Chưa có kết quả luyện tập cho lớp này.'),
              )),
            FutureBuilder<GradePack>(
              future: currentPack,
              builder: (context, packSnapshot) {
                if (!packSnapshot.hasData) {
                  return const SizedBox.shrink();
                }
                final pack = packSnapshot.data!;
                return Column(children: [
                  for (final record in records)
                    ListTile(
                      leading: Icon(record.wrongQuestionIds.isNotEmpty
                          ? Icons.refresh : Icons.check_circle_outline),
                      title: Text(_title(pack, record.lessonId)),
                      subtitle: Text('Đã làm ${record.attempts} lượt · '
                          'Tốt nhất ${record.bestCorrect}/${record.totalQuestions} · '
                          'Sai ${record.wrongQuestionIds.length} câu'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        final lesson = _find(pack, record.lessonId);
                        if (lesson == null) return;
                        Navigator.push(context, MaterialPageRoute<void>(
                          builder: (_) => LessonPage(pack: pack, lesson: lesson,
                            ledger: ledger, profileId: profile.id),
                        ));
                      },
                    ),
                ]);
              },
            ),
          ]);
        },
      ),
    );
  }

  Map<String, dynamic>? _find(GradePack pack, int id) {
    for (final lesson in pack.lessons) {
      if (lesson['id'] == id) return lesson;
    }
    return null;
  }

  String _title(GradePack pack, int id) =>
      _find(pack, id)?['title']?.toString() ?? 'Bài $id';
}

class ParentOverviewPage extends StatelessWidget {
  final StudyLedger ledger;
  final List<StudentProfile> profiles;
  const ParentOverviewPage({super.key, required this.ledger,
    required this.profiles});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Góc phụ huynh')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      Text('Theo dõi tiến độ trên thiết bị',
          style: Theme.of(context).textTheme.titleLarge),
      const Text('Không đồng bộ điểm của học sinh lên máy chủ.'),
      const SizedBox(height: 12),
      for (final profile in profiles)
        FutureBuilder<int>(
          future: ledger.totalXp(profile.id),
          builder: (context, snapshot) => Card(child: ListTile(
            leading: const Icon(Icons.school_outlined),
            title: Text(profile.name),
            subtitle: Text('Lớp ${profile.grade}'),
            trailing: Text('${snapshot.data ?? 0} XP'),
          )),
        ),
    ]),
  );
}
