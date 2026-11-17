import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';
import '../data/catalog_repository.dart';
import '../data/study_ledger.dart';

/// Phone-first HHK visual system. All learning statistics are local and real.
class HhkNative {
  static const bg = Color(0xFFF7F6FF);
  static const ink = Color(0xFF26243D);
  static const muted = Color(0xFF7A7893);
  static const purple = Color(0xFF7862E8);
  static const lilac = Color(0xFFEDE9FF);
  static const mint = Color(0xFFC9F3E9);
  static const pink = Color(0xFFFBE5EF);
  static const yellow = Color(0xFFFFEABB);
  static const blue = Color(0xFFDEEBFF);

  static Color subjectColor(String code) {
    final name = code.toLowerCase();
    if (name.contains('math') || name.contains('toan')) return yellow;
    if (name.contains('viet')) return pink;
    if (name.contains('english') || name.contains('anh')) return blue;
    if (name.contains('science') || name.contains('khoa')) return mint;
    return lilac;
  }

  static String emoji(Map<String, dynamic> s) {
    final symbol = s['emoji']?.toString() ?? '';
    if (symbol.isNotEmpty) return symbol;
    final name = s['code']?.toString().toLowerCase() ?? '';
    if (name.contains('math') || name.contains('toan')) return '🔢';
    if (name.contains('viet')) return '📖';
    if (name.contains('english') || name.contains('anh')) return '🌎';
    return '📚';
  }
}

class NativePanel extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color color;
  final EdgeInsetsGeometry padding;
  const NativePanel({super.key, required this.child, this.onTap,
    this.color = Colors.white, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: color, borderRadius: BorderRadius.circular(23),
      boxShadow: const [BoxShadow(color: Color(0x130B0847),
        blurRadius: 18, offset: Offset(0, 7))]),
    child: Material(type: MaterialType.transparency,
      borderRadius: BorderRadius.circular(23),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap,
        child: Padding(padding: padding, child: child))),
  );
}

class NativeHeading extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const NativeHeading(this.title, {super.key, this.action, this.onAction});
  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: Text(title, style: const TextStyle(fontSize: 18,
      color: HhkNative.ink, fontWeight: FontWeight.w900))),
    if (action != null) TextButton(onPressed: onAction,
      child: Text(action!, style: const TextStyle(fontSize: 12,
        color: HhkNative.purple, fontWeight: FontWeight.w800))),
  ]);
}

class NativeSubjectChip extends StatelessWidget {
  final Map<String, dynamic> subject;
  final int count;
  final VoidCallback onTap;
  const NativeSubjectChip({super.key, required this.subject,
    required this.count, required this.onTap});
  @override
  Widget build(BuildContext context) => NativePanel(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 7),
    onTap: onTap,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 56, height: 56, alignment: Alignment.center,
        decoration: BoxDecoration(
          color: HhkNative.subjectColor(subject['code']?.toString() ?? ''),
          borderRadius: BorderRadius.circular(19)),
        child: Text(HhkNative.emoji(subject),
          style: const TextStyle(fontSize: 30))),
      const SizedBox(height: 9),
      Text(subject['name']?.toString() ?? 'Môn học',
        maxLines: 2, overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w800,
          color: HhkNative.ink, fontSize: 12)),
      const SizedBox(height: 4),
      Text('$count bài', style: const TextStyle(
        fontSize: 10, color: HhkNative.muted)),
    ]),
  );
}

class NativeLessonRow extends StatelessWidget {
  final Map<String, dynamic> lesson;
  final int index;
  final LessonProgress? progress;
  final VoidCallback onTap;
  final bool practice;
  const NativeLessonRow({super.key, required this.lesson,
    required this.index, required this.onTap,
    this.progress, this.practice = false});

  @override
  Widget build(BuildContext context) {
    final total = progress?.totalQuestions ?? 0;
    final ratio = total == 0 ? 0.0 :
        (progress!.bestCorrect / total).clamp(0.0, 1.0);
    return NativePanel(padding: const EdgeInsets.all(12),
      onTap: onTap, child: Row(children: [
      Container(width: 64, height: 69,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: practice ? HhkNative.pink : HhkNative.lilac),
        child: practice
            ? const Icon(Icons.extension_rounded, size: 33,
                color: HhkNative.purple)
            : Text('$index', style: const TextStyle(fontSize: 27,
                fontWeight: FontWeight.w900, color: HhkNative.purple))),
      const SizedBox(width: 13),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(lesson['title']?.toString() ?? 'Bài học',
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800,
              fontSize: 14, color: HhkNative.ink)),
          const SizedBox(height: 5),
          Text(progress == null ? 'Chưa luyện tập' :
              'Đã luyện ${progress!.attempts} lượt',
            style: const TextStyle(fontSize: 11, color: HhkNative.muted)),
          if (progress != null) ...[
            const SizedBox(height: 9),
            Row(children: [
              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(value: ratio,
                  minHeight: 5, backgroundColor: HhkNative.lilac,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    HhkNative.purple)))),
              const SizedBox(width: 8),
              Text('${progress!.bestCorrect}/$total',
                style: const TextStyle(fontSize: 10, color: HhkNative.muted)),
            ]),
          ],
        ])),
      const SizedBox(width: 8),
      Container(width: 38, height: 38,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(colors: [
            Color(0xFFA995FF), HhkNative.purple])),
        child: const Icon(Icons.chevron_right, color: Colors.white)),
    ]));
  }
}

class NativeDopiBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  const NativeDopiBanner({super.key, required this.title,
    required this.subtitle, this.color = HhkNative.mint});
  @override
  Widget build(BuildContext context) => NativePanel(color: color,
    padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 20,
            color: HhkNative.ink, fontWeight: FontWeight.w900)),
          const SizedBox(height: 7),
          Text(subtitle, style: const TextStyle(fontSize: 12,
            color: HhkNative.muted)),
        ])),
      Image.asset('assets/brand/dopi-avatar.png',
        width: 99, height: 99, fit: BoxFit.contain),
    ]));
}

class NativeHomePage extends StatelessWidget {
  final GradePack pack;
  final int grade;
  final String profileName;
  final List<LessonProgress> progress;
  final ValueChanged<Map<String, dynamic>> onSubject;
  final ValueChanged<Map<String, dynamic>> onLesson;
  final VoidCallback onSubjects;
  final VoidCallback onPractice;
  final VoidCallback onDaily;
  final VoidCallback onGames;
  final VoidCallback onProfile;
  final VoidCallback onAchievements;
  final VoidCallback onAccount;
  const NativeHomePage({super.key, required this.pack, required this.grade,
    required this.profileName, required this.progress,
    required this.onSubject, required this.onLesson,
    required this.onSubjects, required this.onPractice,
    required this.onDaily, required this.onGames,
    required this.onProfile, required this.onAchievements,
    required this.onAccount});

  @override
  Widget build(BuildContext context) {
    final subjects = pack.subjects.where((s) =>
        pack.lessonsFor(s['code']?.toString() ?? '').isNotEmpty).toList();
    final today = DateTime.now();
    final done = progress.where((p) {
      final time = DateTime.tryParse(p.updatedAt)?.toLocal();
      return time != null && time.year == today.year &&
        time.month == today.month && time.day == today.day;
    }).length;
    final sorted = List<LessonProgress>.from(progress)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final recent = sorted.isEmpty ? null : sorted.first;
    Map<String, dynamic>? next;
    for (final l in pack.lessons) {
      if (l['id'] == recent?.lessonId) { next = l; break; }
    }
    if (next == null && pack.lessons.isNotEmpty) next = pack.lessons.first;
    return ListView(padding: const EdgeInsets.fromLTRB(18, 5, 18, 28),
      children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Chào $profileName! 👋', maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: HhkNative.muted, fontSize: 13)),
              const SizedBox(height: 8),
              const Text('Hôm nay mình\nhọc gì nhỉ?',
                style: TextStyle(fontSize: 27,
                  fontWeight: FontWeight.w900, color: HhkNative.ink,
                  height: 1.16)),
              const SizedBox(height: 6),
              TextButton.icon(onPressed: onProfile,
                icon: const Icon(Icons.swap_horiz_rounded, size: 17),
                label: Text('Lớp $grade · Đổi hồ sơ'),
                style: TextButton.styleFrom(
                  foregroundColor: HhkNative.purple, padding: EdgeInsets.zero)),
            ])),
          Image.asset('assets/brand/dopi-avatar.png',
            width: 130, height: 144, fit: BoxFit.contain),
        ]),
        const SizedBox(height: 7),
        NativeHeading('Khám phá môn học', action: 'Xem tất cả',
          onAction: onSubjects),
        const SizedBox(height: 7),
        if (subjects.isEmpty)
          const NativePanel(child: Text('Chưa có môn học cho lớp này.'))
        else Row(children: [
          for (var i = 0; i < math.min(3, subjects.length); i++) ...[
            if (i != 0) const SizedBox(width: 10),
            Expanded(child: NativeSubjectChip(subject: subjects[i],
              count: pack.lessonsFor(subjects[i]['code']?.toString() ?? '').length,
              onTap: () => onSubject(subjects[i]))),
          ],
        ]),
        const SizedBox(height: 20),
        NativePanel(color: HhkNative.purple, onTap: onAchievements,
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('⭐ Mục tiêu hôm nay',
                  style: TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w900, fontSize: 15)),
                const SizedBox(height: 5),
                const Text('Mỗi bài học là một bước tiến!',
                  style: TextStyle(color: Color(0xFFECE8FF), fontSize: 12)),
                const SizedBox(height: 14),
                ClipRRect(borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: math.min(done, 3) / 3, minHeight: 7,
                    backgroundColor: const Color(0x66FFFFFF),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white))),
                const SizedBox(height: 7),
                Text('$done bài đã luyện hôm nay · Mục tiêu 3 bài',
                  style: const TextStyle(color: Colors.white, fontSize: 11)),
              ])),
            const SizedBox(width: 8),
            const Text('🌟', style: TextStyle(fontSize: 52)),
          ])),
        const SizedBox(height: 19),
        NativeHeading('Tiếp tục học', action: 'Luyện tập',
          onAction: onPractice),
        const SizedBox(height: 7),
        if (next != null)
          NativeLessonRow(lesson: next, index: 1,
            progress: next['id'] == recent?.lessonId ? recent : null,
            onTap: () => onLesson(next!))
        else
          const NativePanel(child: Text('Chọn môn học để bắt đầu nhé!')),
        const SizedBox(height: 19),
        NativeHeading('Dành cho bạn', action: 'Thành tích',
          onAction: onAchievements),
        const SizedBox(height: 7),
        Row(children: [
          Expanded(child: NativePanel(color: HhkNative.mint,
            onTap: onDaily, child: const Column(children: [
              Icon(Icons.calendar_month_rounded, size: 34,
                color: Color(0xFF338679)),
              SizedBox(height: 8),
              Text('Thử thách ngày', style: TextStyle(fontWeight: FontWeight.w800,
                fontSize: 12, color: HhkNative.ink)),
            ]))),
          const SizedBox(width: 12),
          Expanded(child: NativePanel(color: HhkNative.yellow,
            onTap: onGames, child: const Column(children: [
              Icon(Icons.sports_esports_rounded, size: 34,
                color: Color(0xFFAF8129)),
              SizedBox(height: 8),
              Text('Mini-game', style: TextStyle(fontWeight: FontWeight.w800,
                fontSize: 12, color: HhkNative.ink)),
            ]))),
        ]),
        const SizedBox(height: 15),
        TextButton.icon(onPressed: onAccount,
          icon: const Icon(Icons.verified_user_outlined),
          label: const Text('Tài khoản & quyền học offline')),
      ]);
  }
}
