import 'dart:convert';
import 'local_store.dart';

/// All practice progress is local-only. No network request and no account ID.
class LessonProgress {
  final int grade;
  final int lessonId;
  final int attempts;
  final int bestCorrect;
  final int totalQuestions;
  final String updatedAt;

  const LessonProgress({
    required this.grade,
    required this.lessonId,
    required this.attempts,
    required this.bestCorrect,
    required this.totalQuestions,
    required this.updatedAt,
  });

  int get bestXp => bestCorrect * 10;

  factory LessonProgress.fromJson(Map<String, dynamic> m) => LessonProgress(
        grade: (m['grade'] as num).toInt(),
        lessonId: (m['lessonId'] as num).toInt(),
        attempts: (m['attempts'] as num).toInt(),
        bestCorrect: (m['bestCorrect'] as num).toInt(),
        totalQuestions: (m['totalQuestions'] as num).toInt(),
        updatedAt: m['updatedAt'] as String,
      );

  Map<String, dynamic> toJson() => {
        'grade': grade,
        'lessonId': lessonId,
        'attempts': attempts,
        'bestCorrect': bestCorrect,
        'totalQuestions': totalQuestions,
        'updatedAt': updatedAt,
      };
}

class StudyLedger {
  final LocalStore storage;
  const StudyLedger(this.storage);

  String _key(int grade, int lessonId) => 'progress:v1:$grade:$lessonId';

  Future<LessonProgress?> load(int grade, int lessonId) async {
    final value = await storage.read(_key(grade, lessonId));
    if (value == null) return null;
    final progress = LessonProgress.fromJson(
        Map<String, dynamic>.from(jsonDecode(value) as Map));
    if (progress.grade != grade || progress.lessonId != lessonId) {
      throw StateError('Dữ liệu tiến độ không hợp lệ');
    }
    return progress;
  }

  /// Award XP only for best-ever correct count per lesson. Retrying the
  /// same questions cannot farm more XP; every attempt is still counted.
  Future<LessonProgress> recordResult({
    required int grade,
    required int lessonId,
    required int correct,
    required int total,
  }) async {
    if (grade < 1 || grade > 5 || lessonId <= 0 || total <= 0 ||
        correct < 0 || correct > total) {
      throw ArgumentError('Invalid local practice result');
    }
    final old = await load(grade, lessonId);
    final best = old == null || correct > old.bestCorrect ? correct : old.bestCorrect;
    final result = LessonProgress(
      grade: grade,
      lessonId: lessonId,
      attempts: (old?.attempts ?? 0) + 1,
      bestCorrect: best,
      totalQuestions: total,
      updatedAt: DateTime.now().toUtc().toIso8601String(),
    );
    await storage.write(_key(grade, lessonId), jsonEncode(result.toJson()));
    return result;
  }
}
