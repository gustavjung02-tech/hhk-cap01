import 'dart:async';
import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../data/catalog_repository.dart';
import '../data/local_store.dart';
import '../data/offline_extra_fun.dart';
import '../data/offline_fun.dart';
import '../data/study_ledger.dart';
import 'native_ui.dart';

class _MemoryTile {
  final int pair;
  final String text;
  const _MemoryTile(this.pair, this.text);
}

/// Four real, offline game interactions matching the pinned legacy rules.
/// Scores are separate from lesson StudyLedger XP.
class OfflineExtraGamePage extends StatefulWidget {
  final FunMode mode;
  final GradePack pack;
  final StudentProfile profile;
  final LocalStore storage;
  final DateTime? day;
  const OfflineExtraGamePage({super.key, required this.mode,
    required this.pack, required this.profile,
    required this.storage, this.day});

  @override
  State<OfflineExtraGamePage> createState() => _OfflineExtraGamePageState();
}

class _OfflineExtraGamePageState extends State<OfflineExtraGamePage>
    with WidgetsBindingObserver {
  late final FunResultStore store;
  late final List<FunQuestion> questions;
  late final List<WordPuzzle> puzzles;
  late final List<MatchPair> pairs;
  late final List<_MemoryTile> cards;
  final input = TextEditingController();
  final pickedLetters = <int>[];
  final matched = <int>{};
  final spoiled = <int>{};
  Timer? timer;
  DateTime? deadline;
  int remaining = 8;
  int current = 0;
  int correct = 0;
  int combo = 0;
  int bestCombo = 0;
  int bestScore = 0;
  int? firstCard;
  int? secondCard;
  bool loading = true;
  bool saving = false;
  bool finished = false;
  bool submitted = false;
  bool? answerWasCorrect;
  String? error;

  bool get isMatching => widget.mode == FunMode.match;
  bool get isScramble => widget.mode == FunMode.scramble;
  bool get isSpeed => widget.mode == FunMode.speed;
  bool get isFill => widget.mode == FunMode.fillBlank;
  int get total => isMatching ? pairs.length :
      isScramble ? puzzles.length : questions.length;

  @override
  void initState() {
    super.initState();
    assert(isMatching || isScramble || isSpeed || isFill);
    WidgetsBinding.instance.addObserver(this);
    store = FunResultStore(widget.storage);
    final day = widget.day ?? DateTime.now();
    pairs = isMatching
        ? OfflineExtraFunEngine.match(widget.pack, widget.profile.id, day)
        : const <MatchPair>[];
    puzzles = isScramble
        ? OfflineExtraFunEngine.scramble(
            widget.pack, widget.profile.id, day)
        : const <WordPuzzle>[];
    questions = switch (widget.mode) {
      FunMode.speed => OfflineExtraFunEngine.speed(
          widget.pack, widget.profile.id, day),
      FunMode.fillBlank => OfflineExtraFunEngine.fillBlank(
          widget.pack, widget.profile.id, day),
      _ => const <FunQuestion>[],
    };
    final random = Random(FunQuestionEngine.stableSeed(
      'deck:${widget.profile.id}:${widget.profile.grade}:${localStudyDate(day)}'));
    cards = <_MemoryTile>[
      for (var i = 0; i < pairs.length; i++) ...[
        _MemoryTile(i, pairs[i].question),
        _MemoryTile(i, pairs[i].answer),
      ],
    ]..shuffle(random);
    _load();
  }

  Future<void> _load() async {
    try {
      final old = await store.bestGameScore(
          widget.profile.id, widget.profile.grade, widget.mode);
      if (!mounted) {
        return;
      }
      setState(() {
        bestScore = old;
        loading = false;
      });
      if (isSpeed && total > 0) {
        _startCountdown();
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        loading = false;
        error = 'Không đọc được kết quả đã lưu. Vui lòng thử lại.';
      });
    }
  }

  void _startCountdown() {
    timer?.cancel();
    if (!isSpeed || finished || submitted || total == 0) {
      return;
    }
    remaining = 8;
    deadline = DateTime.now().add(const Duration(seconds: 8));
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || finished || submitted) {
        return;
      }
      final ms = deadline!.difference(DateTime.now()).inMilliseconds;
      final byClock = (ms / 1000).ceil().clamp(0, 8);
      final next = min(remaining - 1, byClock);
      if (next != remaining) {
        setState(() => remaining = next);
      }
      if (next <= 0) {
        _answer(null);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!isSpeed || !mounted || finished || submitted || loading) {
      return;
    }
    if (state == AppLifecycleState.resumed && deadline != null &&
        !DateTime.now().isBefore(deadline!)) {
      _answer(null);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    input.dispose();
    super.dispose();
  }

  void _answer(String? value) {
    if (loading || finished || saving || submitted || total == 0) {
      return;
    }
    if (value != null && value.trim().isEmpty) {
      return;
    }
    final success = isScramble
        ? value?.toLowerCase() == puzzles[current].answer.toLowerCase()
        : value != null && questions[current].accepts(value);
    timer?.cancel();
    setState(() {
      submitted = true;
      answerWasCorrect = success;
      if (success) {
        correct++;
        combo++;
        bestCombo = max(bestCombo, combo);
      } else {
        combo = 0;
      }
    });
  }

  void _chooseCard(int index) {
    if (!isMatching || finished || saving || secondCard != null ||
        matched.contains(cards[index].pair) || firstCard == index) {
      return;
    }
    if (firstCard == null) {
      setState(() => firstCard = index);
      return;
    }
    final one = cards[firstCard!], two = cards[index];
    setState(() {
      secondCard = index;
      if (one.pair == two.pair) {
        matched.add(one.pair);
        if (!spoiled.contains(one.pair)) {
          correct++;
        }
      } else {
        spoiled.add(one.pair);
        spoiled.add(two.pair);
      }
    });
  }

  void _selectLetter(int index) {
    if (!isScramble || submitted || pickedLetters.contains(index)) {
      return;
    }
    setState(() => pickedLetters.add(index));
  }

  void _unselectLetter(int index) {
    if (!isScramble || submitted) {
      return;
    }
    setState(() => pickedLetters.remove(index));
  }

  void _submitScramble() {
    if (!isScramble || pickedLetters.length !=
        puzzles[current].tiles.length) return;
    _answer(pickedLetters.map((i) =>
        puzzles[current].tiles[i]).join());
  }

  Future<void> _next() async {
    if (saving || finished) {
      return;
    }
    if (isMatching) {
      if (secondCard == null) {
        return;
      }
      if (matched.length == pairs.length) {
        await _finish();
      } else {
        setState(() { firstCard = null; secondCard = null; });
      }
      return;
    }
    if (!submitted) {
      return;
    }
    if (current + 1 >= total) {
      await _finish();
    } else {
      setState(() {
        current++;
        submitted = false;
        answerWasCorrect = null;
        pickedLetters.clear();
        input.clear();
      });
      if (isSpeed) {
        _startCountdown();
      }
    }
  }

  Future<void> _finish() async {
    if (saving || finished) {
      return;
    }
    timer?.cancel();
    setState(() { saving = true; error = null; });
    try {
      final value = await store.saveGame(widget.profile.id,
          widget.profile.grade, widget.mode, correct);
      if (!mounted) {
        return;
      }
      setState(() {
        bestScore = value;
        finished = true;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => error =
        'Không lưu được kết quả offline. Bấm Lưu lại và giữ màn hình này.');
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  void _restart() {
    timer?.cancel();
    setState(() {
      firstCard = null; secondCard = null;
      matched.clear(); spoiled.clear();
      pickedLetters.clear(); input.clear();
      current = 0; correct = 0; combo = 0; bestCombo = 0;
      finished = false; submitted = false;
      answerWasCorrect = null; error = null;
    });
    if (isSpeed) {
        _startCountdown();
      }
  }

  Widget _finalResult() => ListView(
    padding: const EdgeInsets.fromLTRB(18, 25, 18, 30),
    children: [
      NativePanel(color: HhkNative.lilac, child: Column(children: [
        Image.asset('assets/brand/dopi-avatar.png', width: 140, height: 130),
        const Text('Hoàn thành rồi! 🎉',
          style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900,
            color: HhkNative.ink)),
        const SizedBox(height: 10),
        Text('$correct/$total điểm',
          key: const Key('extra-game-score'),
          style: const TextStyle(fontSize: 27,
            fontWeight: FontWeight.w900, color: HhkNative.purple)),
        const SizedBox(height: 7),
        Text('Kỷ lục: $bestScore · Combo cao nhất: $bestCombo',
          style: const TextStyle(color: HhkNative.muted)),
        const SizedBox(height: 10),
        const Text('Kết quả lưu offline theo hồ sơ và lớp. '
          'Mini-game không tự tăng XP bài học.',
          textAlign: TextAlign.center,
          style: TextStyle(color: HhkNative.muted)),
      ])),
      const SizedBox(height: 18),
      FilledButton.icon(onPressed: _restart,
        icon: const Icon(Icons.refresh), label: const Text('Chơi lại')),
      const SizedBox(height: 10),
      OutlinedButton(onPressed: () => Navigator.pop(context),
        child: const Text('Chọn trò khác')),
    ],
  );

  Widget _matchView() => ListView(
    padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
    children: [
      NativeDopiBanner(title: '🃏 Ghép Cặp',
        subtitle: 'Lật hai thẻ để tìm câu hỏi và đáp án đúng.',
        color: HhkNative.blue),
      const SizedBox(height: 16),
      Text('Đã ghép ${matched.length}/$total cặp · '
          'Đúng ngay lần đầu: $correct',
        style: const TextStyle(color: HhkNative.ink,
          fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: cards.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, mainAxisSpacing: 10,
          crossAxisSpacing: 10, childAspectRatio: 1.25),
        itemBuilder: (context, index) {
          final tile = cards[index];
          final isMatched = matched.contains(tile.pair);
          final exposed = isMatched || firstCard == index ||
              secondCard == index;
          return NativePanel(
            padding: const EdgeInsets.all(9),
            onTap: isMatched ? null : () => _chooseCard(index),
            color: isMatched ? HhkNative.mint :
                exposed ? HhkNative.lilac : Colors.white,
            child: Center(child: Text(exposed ? tile.text : '❔',
              maxLines: 5, overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: exposed ? 12 : 26,
                fontWeight: FontWeight.w800, color: HhkNative.ink))),
          );
        },
      ),
      if (secondCard != null) ...[
        const SizedBox(height: 15),
        Text(cards[firstCard!].pair == cards[secondCard!].pair
          ? '✨ Ghép đúng rồi!' : 'Chưa khớp, thử tiếp nhé!',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w900,
            color: HhkNative.ink)),
        const SizedBox(height: 9),
        FilledButton(
          key: const Key('match-continue'),
          onPressed: saving ? null : _next,
          child: Text(matched.length == total
            ? 'Lưu kết quả' : 'Lật tiếp')),
      ],
      if (error != null) ...[
        Text(error!, style: const TextStyle(color: Colors.red)),
        FilledButton(onPressed: saving ? null : _finish,
          child: const Text('Lưu lại')),
      ],
    ],
  );

  Widget _answerView() {
    final q = isScramble ? null : questions[current];
    final word = isScramble ? puzzles[current] : null;
    return ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
      children: [
        NativeDopiBanner(
          title: '${widget.mode.emoji} ${widget.mode.label}',
          subtitle: 'Lớp ${widget.profile.grade} · Combo $combo',
          color: isSpeed ? HhkNative.pink : HhkNative.mint),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Câu ${current + 1}/$total',
            style: const TextStyle(color: HhkNative.ink,
              fontWeight: FontWeight.w900)),
          Text('Đúng $correct câu',
            style: const TextStyle(color: HhkNative.purple,
              fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 9),
        LinearProgressIndicator(value: (current + 1)/total,
          minHeight: 6, backgroundColor: HhkNative.lilac,
          valueColor: const AlwaysStoppedAnimation<Color>(HhkNative.purple)),
        if (isSpeed) ...[
          const SizedBox(height: 10),
          Text('⏱ Còn $remaining giây',
            key: const Key('speed-countdown'),
            style: TextStyle(fontWeight: FontWeight.w900,
              color: remaining <= 3 ? Colors.red : HhkNative.purple)),
        ],
        const SizedBox(height: 18),
        NativePanel(child: Text(word?.hint ?? q!.prompt,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 19,
            fontWeight: FontWeight.w900, color: HhkNative.ink))),
        const SizedBox(height: 18),
        if (isScramble) ...[
          NativePanel(color: HhkNative.lilac,
            child: Center(child: Text(
              pickedLetters.map((i) => word!.tiles[i]).join(),
              key: const Key('scramble-assembled'),
              style: const TextStyle(fontSize: 23,
                fontWeight: FontWeight.w900, color: HhkNative.ink)))),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 9,
            children: [
              for (var i = 0; i < word!.tiles.length; i++)
                OutlinedButton(
                  key: Key('scramble-tile-$i'),
                  onPressed: submitted || pickedLetters.contains(i)
                      ? null : () => _selectLetter(i),
                  child: Text(word.tiles[i],
                    style: const TextStyle(fontSize: 17,
                      fontWeight: FontWeight.w800))),
            ]),
          const SizedBox(height: 8),
          TextButton(onPressed: submitted || pickedLetters.isEmpty
              ? null : () => _unselectLetter(pickedLetters.last),
            child: const Text('Xóa chữ cuối')),
          FilledButton(
            key: const Key('scramble-submit'),
            onPressed: submitted || pickedLetters.length != word.tiles.length
                ? null : _submitScramble,
            child: const Text('Kiểm tra từ')),
        ] else if (isSpeed) ...[
          for (final option in q!.options)
            Padding(padding: const EdgeInsets.only(bottom: 10),
              child: NativePanel(
                onTap: submitted ? null : () => _answer(option),
                color: submitted && q.accepts(option)
                    ? HhkNative.mint : Colors.white,
                child: Text(option, style: const TextStyle(
                  fontWeight: FontWeight.w800, color: HhkNative.ink)))),
        ] else ...[
          TextField(
            key: const Key('fill-blank-answer'),
            controller: input, enabled: !submitted,
            keyboardType: q!.numberAnswer
                ? const TextInputType.numberWithOptions(
                    decimal: true, signed: true)
                : TextInputType.text,
            decoration: const InputDecoration(
              border: OutlineInputBorder(), labelText: 'Nhập đáp án'),
            onChanged: (_) => setState(() {}),
            onSubmitted: _answer,
          ),
          const SizedBox(height: 11),
          FilledButton(
            key: const Key('fill-blank-submit'),
            onPressed: submitted || input.text.trim().isEmpty
                ? null : () => _answer(input.text),
            child: const Text('Kiểm tra đáp án')),
        ],
        if (submitted) ...[
          const SizedBox(height: 17),
          NativePanel(
            color: answerWasCorrect! ? HhkNative.mint : HhkNative.pink,
            child: Text(answerWasCorrect! ? 'Chính xác! 🎉'
                : 'Chưa đúng. Đáp án: ${word?.answer ?? q!.expected}',
              style: const TextStyle(fontWeight: FontWeight.w800,
                color: HhkNative.ink))),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('extra-next'),
            onPressed: saving ? null : _next,
            icon: const Icon(Icons.arrow_forward),
            label: Text(current + 1 == total
                ? 'Lưu kết quả' : 'Câu tiếp theo')),
        ],
        if (error != null) ...[
          const SizedBox(height: 9),
          Text(error!, style: const TextStyle(color: Colors.red)),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.mode.label)),
        body: const Center(child: CircularProgressIndicator()));
    }
    if (finished) {
      return Scaffold(
        backgroundColor: HhkNative.bg,
        appBar: AppBar(title: Text(widget.mode.label)),
        body: _finalResult());
    }
    if (total == 0 || (error != null && current == 0 &&
        !submitted && !isMatching)) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.mode.label)),
        body: Center(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(error ??
              'Chưa có đủ câu hỏi đã được kiểm duyệt cho trò này.',
            textAlign: TextAlign.center))));
    }
    return Scaffold(
      backgroundColor: HhkNative.bg,
      appBar: AppBar(title: Text(widget.mode.label)),
      body: isMatching ? _matchView() : _answerView());
  }
}
