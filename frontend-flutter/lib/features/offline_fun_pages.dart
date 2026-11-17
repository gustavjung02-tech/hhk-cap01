import 'package:material_ui/material_ui.dart';

import '../data/catalog_repository.dart';
import '../data/local_store.dart';
import '../data/study_ledger.dart';
import '../data/offline_fun.dart';
import 'native_ui.dart';

class OfflineMiniGameHubPage extends StatelessWidget {
  final GradePack pack;
  final StudentProfile profile;
  final LocalStore storage;
  const OfflineMiniGameHubPage({super.key, required this.pack,
    required this.profile, required this.storage});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: HhkNative.bg,
    appBar: AppBar(title: const Text('Vương quốc Mini-Game')),
    body: ListView(padding: const EdgeInsets.fromLTRB(18, 16, 18, 26),
      children: [
        const NativeDopiBanner(
          title: 'Cùng Dopi vui học! 🎮',
          subtitle: 'Các trò chơi chạy offline, điểm lưu riêng từng bé.',
          color: HhkNative.yellow),
        const SizedBox(height: 22),
        const NativeHeading('Trò chơi đã chuyển'),
        const SizedBox(height: 9),
        NativePanel(color: HhkNative.mint,
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => OfflineFunRoundPage(
              mode: FunMode.trueFalse, pack: pack,
              profile: profile, storage: storage))),
          child: const ListTile(
            leading: Text('✅', style: TextStyle(fontSize: 35)),
            title: Text('Đúng hay Sai', style: TextStyle(
              fontWeight: FontWeight.w900, color: HhkNative.ink)),
            subtitle: Text('Nhận biết đúng sai từ câu hỏi thật.'),
            trailing: Icon(Icons.chevron_right, color: HhkNative.purple))),
        const SizedBox(height: 12),
        NativePanel(color: HhkNative.pink,
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => OfflineFunRoundPage(
              mode: FunMode.quickMath, pack: pack,
              profile: profile, storage: storage))),
          child: const ListTile(
            leading: Text('🚀', style: TextStyle(fontSize: 35)),
            title: Text('Toán Siêu Tốc', style: TextStyle(
              fontWeight: FontWeight.w900, color: HhkNative.ink)),
            subtitle: Text('Tính nhẩm theo cấp lớp, thử thách 10 câu.'),
            trailing: Icon(Icons.chevron_right, color: HhkNative.purple))),
        const SizedBox(height: 19),
        const NativePanel(child: Text(
          'Các trò chơi khác của app cũ sẽ được chuyển theo từng đợt. '
          'Điểm mini-game không tự cộng vào XP bài học.')),
      ],
    ),
  );
}

/// Port of DailyChallenge + TrueFalseBlitz + QuickMathRush from the pinned
/// legacy app. Never fetches learner answers or progress from the backend.
class OfflineFunRoundPage extends StatefulWidget {
  final FunMode mode;
  final GradePack pack;
  final StudentProfile profile;
  final LocalStore storage;
  final DateTime? day;
  const OfflineFunRoundPage({super.key, required this.mode,
    required this.pack, required this.profile,
    required this.storage, this.day});

  @override
  State<OfflineFunRoundPage> createState() => _OfflineFunRoundPageState();
}

class _OfflineFunRoundPageState extends State<OfflineFunRoundPage> {
  late final List<FunQuestion> questions;
  late final FunResultStore results;
  late final String date;
  final input = TextEditingController();
  bool loading = true;
  bool saving = false;
  bool finished = false;
  bool? lastCorrect;
  int current = 0;
  int correct = 0;
  int combo = 0;
  int bestCombo = 0;
  int bestScore = 0;
  FunResult? dailySaved;
  String? error;

  @override
  void initState() {
    super.initState();
    results = FunResultStore(widget.storage);
    final now = widget.day ?? DateTime.now();
    date = localStudyDate(now);
    questions = switch (widget.mode) {
      FunMode.daily => FunQuestionEngine.daily(
          widget.pack, widget.profile.id, now),
      FunMode.trueFalse => FunQuestionEngine.trueFalse(
          widget.pack, widget.profile.id, now),
      FunMode.quickMath => FunQuestionEngine.quickMath(
          widget.profile.grade, widget.profile.id, now),
    };
    _load();
  }

  Future<void> _load() async {
    try {
      if (widget.mode == FunMode.daily) {
        dailySaved = await results.readDaily(
          widget.profile.id, widget.profile.grade, date);
      } else {
        bestScore = await results.bestGameScore(
          widget.profile.id, widget.profile.grade, widget.mode);
      }
      if (mounted) setState(() => loading = false);
    } catch (_) {
      if (mounted) setState(() {
        loading = false;
        error = 'Chưa đọc được kết quả đã lưu trên máy. Hãy thử lại.';
      });
    }
  }

  void _answer(String value) {
    if (loading || saving || finished || lastCorrect != null ||
        current >= questions.length) return;
    if (value.trim().isEmpty) return;
    final passed = questions[current].accepts(value);
    setState(() {
      lastCorrect = passed;
      if (passed) {
        correct++;
        combo++;
        if (combo > bestCombo) bestCombo = combo;
      } else {
        combo = 0;
      }
    });
  }

  Future<void> _next() async {
    if (lastCorrect == null || saving || finished) return;
    if (current + 1 < questions.length) {
      setState(() {
        current++;
        lastCorrect = null;
        input.clear();
      });
      return;
    }
    await _finish();
  }

  Future<void> _finish() async {
    if (saving || (finished && error == null)) return;
    setState(() { saving = true; error = null; });
    try {
      if (widget.mode == FunMode.daily) {
        dailySaved = await results.completeDaily(
          widget.profile.id, widget.profile.grade,
          FunResult(date, correct, questions.length,
            DateTime.now().toUtc().toIso8601String()));
      } else {
        bestScore = await results.saveGame(
          widget.profile.id, widget.profile.grade, widget.mode, correct);
      }
      if (mounted) setState(() => finished = true);
    } catch (_) {
      if (mounted) setState(() => error =
        'Không lưu được kết quả offline. Hãy thử lưu lại, '
        'đừng đóng màn hình lúc này.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Widget _resultCard(int score, int total, {required bool savedToday}) {
    final percent = total > 0 ? (score * 100 / total).round() : 0;
    return ListView(padding: const EdgeInsets.fromLTRB(18, 24, 18, 30),
      children: [
        NativePanel(color: HhkNative.lilac,
          child: Column(children: [
            Image.asset('assets/brand/dopi-avatar.png',
              width: 140, height: 140),
            const SizedBox(height: 9),
            Text(savedToday ? 'Hôm nay đã hoàn thành! 🌟'
                : 'Giỏi quá, bé ơi! 🎉',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w900,
                fontSize: 22, color: HhkNative.ink)),
            const SizedBox(height: 10),
            Text('$score/$total câu đúng · $percent điểm',
              key: const Key('fun-score'),
              style: const TextStyle(fontSize: 21,
                fontWeight: FontWeight.w900, color: HhkNative.purple)),
            if (widget.mode != FunMode.daily) ...[
              const SizedBox(height: 6),
              Text('Kỷ lục: $bestScore/$total · Combo: $bestCombo',
                style: const TextStyle(color: HhkNative.muted)),
            ],
            const SizedBox(height: 15),
            Text(widget.mode == FunMode.daily
                ? 'Thử thách này được lưu một lần mỗi ngày '
                  'cho riêng hồ sơ và lớp học của bé.'
                : 'Kết quả mini-game đã lưu offline trên thiết bị.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: HhkNative.muted)),
          ])),
        const SizedBox(height: 18),
        if (widget.mode != FunMode.daily)
          FilledButton.icon(
            onPressed: () => setState(() {
              current = 0; correct = 0; combo = 0;
              bestCombo = 0; finished = false; lastCorrect = null;
              input.clear();
            }),
            icon: const Icon(Icons.refresh),
            label: const Text('Chơi lại')),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: () => Navigator.pop(context),
          child: const Text('Trở lại')),
        const SizedBox(height: 12),
        const Text('Điểm trò chơi không tự cộng XP bài học.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: HhkNative.muted)),
      ]);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return Scaffold(
      appBar: AppBar(title: Text(widget.mode.label)),
      body: const Center(child: CircularProgressIndicator()));
    if (dailySaved != null) {
      return Scaffold(backgroundColor: HhkNative.bg,
        appBar: AppBar(title: Text(widget.mode.label)),
        body: _resultCard(dailySaved!.correct, dailySaved!.total,
          savedToday: true));
    }
    if (finished) {
      return Scaffold(backgroundColor: HhkNative.bg,
        appBar: AppBar(title: Text(widget.mode.label)),
        body: _resultCard(correct, questions.length, savedToday: false));
    }
    if (questions.isEmpty || (error != null && lastCorrect == null)) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.mode.label)),
        body: Center(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(error ??
            'Chưa có đủ câu hỏi phù hợp cho lớp này.',
            textAlign: TextAlign.center))));
    }
    final q = questions[current];
    return Scaffold(backgroundColor: HhkNative.bg,
      appBar: AppBar(title: Text(widget.mode.label)),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
        children: [
          NativeDopiBanner(
            title: '${widget.mode.emoji} ${widget.mode.label}',
            subtitle: widget.mode == FunMode.daily
                ? 'Ngày $date · Lớp ${widget.profile.grade}'
                : 'Lớp ${widget.profile.grade} · Combo $combo',
            color: widget.mode == FunMode.quickMath
                ? HhkNative.yellow : HhkNative.mint),
          const SizedBox(height: 15),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Câu ${current + 1}/${questions.length}',
              style: const TextStyle(fontWeight: FontWeight.w800,
                color: HhkNative.ink)),
            Text('Đúng $correct câu',
              style: const TextStyle(color: HhkNative.purple,
                fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (current + 1) / questions.length, minHeight: 7,
            backgroundColor: HhkNative.lilac,
            valueColor: const AlwaysStoppedAnimation<Color>(HhkNative.purple)),
          const SizedBox(height: 20),
          NativePanel(child: Text(q.prompt,
            style: const TextStyle(fontSize: 21,
              fontWeight: FontWeight.w800, color: HhkNative.ink),
            textAlign: TextAlign.center)),
          const SizedBox(height: 15),
          if (q.options.isNotEmpty)
            for (final option in q.options)
              Padding(padding: const EdgeInsets.only(bottom: 10),
                child: NativePanel(
                  onTap: lastCorrect == null ? () => _answer(option) : null,
                  color: lastCorrect != null && q.accepts(option)
                      ? HhkNative.mint : Colors.white,
                  child: Row(children: [
                    Expanded(child: Text(option, style: const TextStyle(
                      color: HhkNative.ink, fontWeight: FontWeight.w700))),
                    if (lastCorrect != null && q.accepts(option))
                      const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF2E9E81)),
                  ]),
                )),
          if (q.options.isEmpty)
            Row(children: [
              Expanded(child: TextField(
                key: Key('fun-answer-$current'),
                controller: input, enabled: lastCorrect == null,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true, decimal: true),
                onSubmitted: _answer,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Nhập đáp án', border: OutlineInputBorder()))),
              const SizedBox(width: 9),
              FilledButton(
                onPressed: lastCorrect == null &&
                    input.text.trim().isNotEmpty
                    ? () => _answer(input.text) : null,
                child: const Text('Kiểm tra')),
            ]),
          if (lastCorrect != null) ...[
            const SizedBox(height: 16),
            NativePanel(color: lastCorrect!
                ? HhkNative.mint : HhkNative.pink,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(lastCorrect! ? 'Chính xác! 🎉'
                      : 'Câu này chưa đúng. Đáp án: ${q.expected}',
                    style: const TextStyle(color: HhkNative.ink,
                      fontWeight: FontWeight.w900)),
                  if (q.explanation.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(q.explanation),
                  ],
                ])),
            const SizedBox(height: 14),
            if (error != null) Text(error!,
              style: const TextStyle(color: Colors.red)),
            FilledButton.icon(
              key: const Key('fun-next'),
              onPressed: saving ? null : _next,
              icon: const Icon(Icons.arrow_forward),
              label: Text(saving ? 'Đang lưu...' :
                current + 1 == questions.length
                  ? 'Lưu kết quả' : 'Câu tiếp theo')),
          ],
        ],
      ),
    );
  }
}
