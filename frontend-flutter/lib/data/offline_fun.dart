import 'dart:convert';
import 'dart:math';

import 'catalog_repository.dart';
import 'local_store.dart';
import '../features/study/quiz_evaluator.dart';

enum FunMode {
  daily('Thử thách hằng ngày', '🌟'),
  trueFalse('Đúng hay Sai', '✅'),
  quickMath('Toán Siêu Tốc', '🚀'),
  match('Ghép Cặp', '🃏'),
  scramble('Xếp Chữ', '🔤'),
  speed('Tốc Độ', '⚡'),
  fillBlank('Điền Từ', '✏️');

  final String label;
  final String emoji;
  const FunMode(this.label, this.emoji);
}

/// A self-contained question: no answer is revealed until the child submits.
/// Content answers reuse the same audited evaluator as regular practice.
class FunQuestion {
  final String id;
  final String prompt;
  final List<String> options;
  final String expected;
  final String explanation;
  final bool numberAnswer;
  final Map<String, dynamic>? source;

  const FunQuestion({
    required this.id,
    required this.prompt,
    required this.options,
    required this.expected,
    this.explanation = '',
    this.numberAnswer = false,
    this.source,
  });

  bool accepts(String answer) {
    if (source != null) return QuizEvaluator.correct(source!, answer);
    if (numberAnswer) {
      final value = num.tryParse(answer.trim().replaceAll(',', '.'));
      final target = num.tryParse(expected);
      return value != null && target != null && value == target;
    }
    return answer.trim().toLowerCase() == expected.trim().toLowerCase();
  }
}

/// FNV-1a is stable across Dart VM/browser sessions unlike String.hashCode.
int _stableHash(String value) {
  var hash = 2166136261;
  for (final code in value.codeUnits) {
    hash = ((hash ^ code) * 16777619) & 0xffffffff;
  }
  return hash;
}

String localStudyDate(DateTime now) {
  final local = now.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

class FunQuestionEngine {
  static int stableSeed(String value) => _stableHash(value);

  static List<FunQuestion> selectTypes(GradePack pack, String profileId,
      DateTime day, Set<String> kinds, int count, String mode) =>
      _select(_candidates(pack, kinds),
          '$mode:${pack.grade}:$profileId:${localStudyDate(day)}', count);

  static bool _valid(Map<String, dynamic> q, Set<int> lessons) {
    final id = (q['id'] as num?)?.toInt();
    final lessonId = (q['lessonId'] as num?)?.toInt();
    final text = q['questionText']?.toString().trim() ?? '';
    return id != null && id > 0 &&
        lessonId != null && lessons.contains(lessonId) &&
        q['isActive'] != 0 && text.isNotEmpty &&
        QuizEvaluator.canGrade(q);
  }

  static List<Map<String, dynamic>> _candidates(GradePack pack,
      Set<String> kinds) {
    final activeLessons = pack.lessons
        .where((row) => row['isActive'] != 0 && row['id'] is num)
        .map((row) => (row['id'] as num).toInt()).toSet();
    return pack.questions.where((q) =>
        kinds.contains(q['questionType']?.toString()) &&
        _valid(q, activeLessons)).toList();
  }

  static List<FunQuestion> _select(
      List<Map<String, dynamic>> source, String seed, int count) {
    final unique = <int, Map<String, dynamic>>{};
    for (final row in source) {
      unique.putIfAbsent((row['id'] as num).toInt(), () => row);
    }
    final sorted = unique.values.toList()
      ..sort((a, b) {
        final ai = (a['id'] as num).toInt();
        final bi = (b['id'] as num).toInt();
        final cmp = _stableHash('$seed:$ai')
            .compareTo(_stableHash('$seed:$bi'));
        return cmp == 0 ? ai.compareTo(bi) : cmp;
      });
    return sorted.take(count).map((q) {
      final kind = q['questionType']?.toString() ?? '';
      final answers = kind == 'true_false'
          ? const ['Đúng', 'Sai']
          : kind == 'single_choice'
              ? QuizEvaluator.options(q) : const <String>[];
      return FunQuestion(
        id: (q['id'] as num).toInt().toString(),
        prompt: q['questionText']?.toString() ?? '',
        options: answers,
        expected: q['correctAnswer']?.toString() ?? '',
        explanation: q['explanationSimple']?.toString() ?? '',
        numberAnswer: kind == 'fill_number',
        source: q,
      );
    }).toList(growable: false);
  }

  static List<FunQuestion> daily(GradePack pack, String profileId,
      DateTime today, {int count = 5}) =>
      _select(_candidates(pack,
          {'single_choice', 'true_false', 'fill_number'}),
          'daily:${pack.grade}:$profileId:${localStudyDate(today)}', count);

  /// Only unambiguous real true/false questions; never fabricate correctness.
  static List<FunQuestion> trueFalse(GradePack pack, String profileId,
      DateTime today, {int count = 15}) =>
      _select(_candidates(pack, {'true_false'}),
          'truefalse:${pack.grade}:$profileId:${localStudyDate(today)}', count);

  /// Grade-appropriate arithmetic is generated locally, with exact integer
  /// answers and no network, API, or invented lesson/XP records.
  static List<FunQuestion> quickMath(int grade, String profileId,
      DateTime today, {int count = 10}) {
    if (grade < 1 || grade > 5) throw ArgumentError.value(grade, 'grade');
    if (count < 1 || count > 30) throw ArgumentError.value(count, 'count');
    final random = Random(_stableHash(
        'quickmath:$grade:$profileId:${localStudyDate(today)}'));
    return List.generate(count, (index) {
      late final int a, b, answer;
      late final String operator;
      switch (grade) {
        case 1:
          a = random.nextInt(10) + 1;
          b = random.nextInt(10) + 1;
          if (index.isEven) {
            operator = '+';
            answer = a + b;
          } else {
            operator = '−';
            answer = (a + b) - a;
          }
          break;
        case 2:
          a = random.nextInt(60) + 21;
          b = random.nextInt(20) + 1;
          if (index.isEven) {
            operator = '+';
            answer = a + b;
          } else {
            operator = '−';
            answer = a - b;
          }
          break;
        case 3:
          a = random.nextInt(8) + 2;
          b = random.nextInt(9) + 1;
          operator = '×';
          answer = a * b;
          break;
        case 4:
          a = random.nextInt(9) + 2;
          b = random.nextInt(9) + 2;
          operator = ':';
          answer = a;
          break;
        default:
          a = random.nextInt(70) + 11;
          b = random.nextInt(8) + 2;
          operator = '×';
          answer = a * b;
          break;
      }
      final left = grade == 1 && index.isOdd
          ? a + b : grade == 4 ? a * b : a;
      final right = grade == 1 && index.isOdd ? a : b;
      return FunQuestion(
        id: 'math:$grade:$index',
        prompt: '$left $operator $right = ?',
        options: const [],
        expected: '$answer',
        numberAnswer: true,
      );
    }, growable: false);
  }
}

class FunResult {
  final String date;
  final int correct;
  final int total;
  final String completedAt;
  const FunResult(this.date, this.correct, this.total, this.completedAt);
  int get percent => total == 0 ? 0 : (correct * 100 / total).round();

  factory FunResult.fromJson(Map<String, dynamic> row) {
    final result = FunResult(
      row['date'] as String,
      (row['correct'] as num).toInt(),
      (row['total'] as num).toInt(),
      row['completedAt'] as String);
    if (result.correct < 0 || result.total < 1 ||
        result.correct > result.total) {
      throw const FormatException('Invalid daily result');
    }
    DateTime.parse(result.completedAt);
    return result;
  }

  Map<String, dynamic> toJson() => {
    'date': date, 'correct': correct, 'total': total,
    'completedAt': completedAt,
  };
}

class FunResultStore {
  final LocalStore store;
  const FunResultStore(this.store);

  String _dailyKey(String profileId, int grade, String date) =>
      'fun:daily:v1:${Uri.encodeComponent(profileId)}:$grade:$date';
  String _gameKey(String profileId, int grade, FunMode mode) =>
      'fun:game:v1:${Uri.encodeComponent(profileId)}:$grade:${mode.name}';

  Future<FunResult?> readDaily(String profileId, int grade, String date) async {
    final value = await store.read(_dailyKey(profileId, grade, date));
    return value == null ? null
        : FunResult.fromJson(Map<String, dynamic>.from(jsonDecode(value) as Map));
  }

  /// Atomic first-write-wins: retries cannot count twice or overwrite scores.
  Future<FunResult> completeDaily(String profileId, int grade,
      FunResult result) async {
    final raw = await store.update(_dailyKey(profileId, grade, result.date),
        (existing) {
      if (existing != null) return existing;
      return jsonEncode(result.toJson());
    });
    return FunResult.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
  }

  Future<int> bestGameScore(String profileId, int grade, FunMode mode) async {
    if (mode == FunMode.daily) throw ArgumentError.value(mode, 'mode');
    final raw = await store.read(_gameKey(profileId, grade, mode));
    if (raw == null) return 0;
    return (jsonDecode(raw) as Map)['best'] as int;
  }

  Future<int> saveGame(String profileId, int grade,
      FunMode mode, int correct) async {
    if (mode == FunMode.daily) throw ArgumentError.value(mode, 'mode');
    final raw = await store.update(_gameKey(profileId, grade, mode),
        (current) {
      final old = current == null
          ? <String, dynamic>{'plays': 0, 'best': 0}
          : Map<String, dynamic>.from(jsonDecode(current) as Map);
      return jsonEncode({
        'plays': ((old['plays'] as num?)?.toInt() ?? 0) + 1,
        'best': max((old['best'] as num?)?.toInt() ?? 0, correct),
      });
    });
    return (jsonDecode(raw) as Map)['best'] as int;
  }
}
