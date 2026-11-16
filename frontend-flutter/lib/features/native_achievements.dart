import 'package:material_ui/material_ui.dart';
import '../data/study_ledger.dart';
import 'native_ui.dart';

/// Rewards are earned from offline learner records. No imaginary streaks.
class NativeAchievementsPage extends StatelessWidget {
  final String profileName;
  final int grade;
  final List<LessonProgress> progress;
  final VoidCallback onDetails;
  const NativeAchievementsPage({super.key, required this.profileName,
    required this.grade, required this.progress, required this.onDetails});

  @override
  Widget build(BuildContext context) {
    final totalAttempts = progress.fold<int>(
        0, (count, item) => count + item.attempts);
    final totalXp = progress.fold<int>(
        0, (count, item) => count + item.bestXp);
    final perfect = progress.any((p) =>
      p.totalQuestions > 0 && p.bestCorrect == p.totalQuestions);

    return Scaffold(
      backgroundColor: HhkNative.bg,
      appBar: AppBar(title: const Text('Thành tích')),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        children: [
          NativePanel(color: HhkNative.lilac,
            child: Row(children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Bé thật tuyệt vời! 🌟',
                    style: TextStyle(fontSize: 21,
                      color: HhkNative.ink, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text('$profileName · Lớp $grade',
                    style: const TextStyle(color: HhkNative.muted)),
                  const SizedBox(height: 7),
                  const Text('Mỗi lần luyện tập đều đáng ghi nhận.',
                    style: TextStyle(color: HhkNative.muted, fontSize: 12)),
                ])),
              Image.asset('assets/brand/dopi-avatar.png',
                width: 108, height: 108, fit: BoxFit.contain),
            ])),
          const SizedBox(height: 22),
          const NativeHeading('Tiến bộ của bé'),
          const SizedBox(height: 9),
          NativePanel(child: Row(children: [
            _stat(progress.length.toString(), 'Bài đã luyện', '📖'),
            _stat(totalAttempts.toString(), 'Lượt luyện', '🔥'),
            _stat(totalXp.toString(), 'XP', '⭐'),
          ])),
          const SizedBox(height: 22),
          const NativeHeading('Dấu mốc học tập'),
          const SizedBox(height: 9),
          NativePanel(child: Column(children: [
            _badge('🌱', 'Bước khởi đầu', progress.isNotEmpty),
            const Divider(height: 23),
            _badge('💯', 'Chinh phục bài học', perfect),
            const Divider(height: 23),
            _badge('✨', 'Chăm chỉ', totalAttempts >= 10),
          ])),
          const SizedBox(height: 19),
          FilledButton.icon(onPressed: onDetails,
            icon: const Icon(Icons.insights_rounded),
            label: const Text('Xem lịch sử học tập')),
          const SizedBox(height: 14),
          const Text('Số liệu lấy từ kết quả thật lưu trên thiết bị.',
            textAlign: TextAlign.center,
            style: TextStyle(color: HhkNative.muted, fontSize: 11)),
        ]),
    );
  }

  Widget _stat(String value, String label, String emoji) =>
      Expanded(child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 26)),
        const SizedBox(height: 7),
        Text(value, style: const TextStyle(
          color: HhkNative.ink, fontSize: 20,
          fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        Text(label, textAlign: TextAlign.center,
          style: const TextStyle(color: HhkNative.muted, fontSize: 11)),
      ]));

  Widget _badge(String emoji, String title, bool earned) =>
      Row(children: [
        Opacity(opacity: earned ? 1 : .35,
          child: Text(emoji, style: const TextStyle(fontSize: 30))),
        const SizedBox(width: 12),
        Expanded(child: Text(title, style: const TextStyle(
          color: HhkNative.ink, fontWeight: FontWeight.w800))),
        Text(earned ? 'Đã đạt' : 'Chưa đạt',
          style: TextStyle(fontSize: 11,
            color: earned ? HhkNative.purple : HhkNative.muted)),
      ]);
}
