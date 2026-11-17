import 'dart:math';

import 'catalog_repository.dart';
import 'offline_fun.dart';

/// Game inputs are drawn exclusively from strictly gradeable catalog rows.
class MatchPair {
  final String id;
  final String question;
  final String answer;
  const MatchPair(this.id, this.question, this.answer);
}

class WordPuzzle {
  final String id;
  final String hint;
  final String answer;
  final List<String> tiles;
  const WordPuzzle(this.id, this.hint, this.answer, this.tiles);
}

class OfflineExtraFunEngine {
  static final RegExp _word = RegExp(r'^[a-zA-ZÀ-ỹĐđ]+$');

  static List<MatchPair> match(GradePack pack, String profileId,
      DateTime day, {int count = 5}) {
    final choices = FunQuestionEngine.selectTypes(pack, profileId, day,
      {'single_choice'}, 80, 'match');
    final usedQuestions = <String>{}, usedAnswers = <String>{};
    final result = <MatchPair>[];
    for (final q in choices) {
      final prompt = q.prompt.trim(), answer = q.expected.trim();
      final qKey = prompt.toLowerCase(), aKey = answer.toLowerCase();
      if (prompt.length > 72 || prompt.length < 4 ||
          answer.length > 28 || answer.isEmpty ||
          !usedQuestions.add(qKey) || !usedAnswers.add(aKey) ||
          qKey == aKey) {
        continue;
      }
      result.add(MatchPair(q.id, prompt, answer));
      if (result.length >= count) break;
    }
    // Require meaningful genuine pairs rather than generating fake filler.
    return result.length < 3 ? const [] : result;
  }

  static List<WordPuzzle> scramble(GradePack pack, String profileId,
      DateTime day, {int count = 8}) {
    final candidates = FunQuestionEngine.selectTypes(pack, profileId, day,
      {'single_choice'}, 100, 'scramble');
    final used = <String>{}, result = <WordPuzzle>[];
    for (final q in candidates) {
      final raw = q.expected.trim();
      final chars = raw.runes.map(String.fromCharCode).toList();
      if (chars.length < 3 || chars.length > 12 ||
          !_word.hasMatch(raw) || chars.toSet().length < 2 ||
          !used.add(raw.toLowerCase()) || q.prompt.trim().isEmpty) {
        continue;
      }
      final rng = Random(FunQuestionEngine.stableSeed(
          'scramble:$profileId:${pack.grade}:${localStudyDate(day)}:${q.id}'));
      final tiles = List<String>.from(chars)..shuffle(rng);
      if (tiles.join() == raw) {
        tiles.add(tiles.removeAt(0));
      }
      result.add(WordPuzzle(q.id, q.prompt, raw, tiles));
      if (result.length >= count) break;
    }
    return result.length < 3 ? const [] : result;
  }

  static List<FunQuestion> speed(GradePack pack, String profileId,
      DateTime day, {int count = 10}) =>
      FunQuestionEngine.selectTypes(pack, profileId, day,
          {'single_choice'}, count, 'speed');

  static List<FunQuestion> fillBlank(GradePack pack, String profileId,
      DateTime day, {int count = 10}) {
    // fill_text remains ungradable in QuizEvaluator; do not guess its answer.
    return FunQuestionEngine.selectTypes(pack, profileId, day,
      {'fill_number', 'single_choice'}, 80, 'fillblank')
      .where((q) => q.expected.trim().isNotEmpty &&
          q.expected.length <= 30 && q.options.length <= 6)
      .take(count).toList(growable: false);
  }
}
