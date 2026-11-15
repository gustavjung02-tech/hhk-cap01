import 'dart:convert';
import 'dart:math';

import 'local_store.dart';

/// Offline-only records. There is no learner identifier or progress API
/// on the Prisma backend. Version 1 records remain for recoverability.
class StudentProfile {
  final String id;
  final String name;
  final int grade;

  const StudentProfile(
      {required this.id, required this.name, required this.grade});

  factory StudentProfile.fromJson(Map<String, dynamic> m) => StudentProfile(
        id: m['id'] as String,
        name: m['name'] as String,
        grade: (m['grade'] as num).toInt(),
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'grade': grade};
}

class LessonProgress {
  final String profileId;
  final int grade;
  final int lessonId;
  final String subjectCode;
  final int attempts;
  final int bestCorrect;
  final int totalQuestions;
  final String updatedAt;
  final List<String> attemptIds;
  final List<int> wrongQuestionIds;
  final List<Map<String, dynamic>> recentHistory;

  const LessonProgress({
    required this.profileId,
    required this.grade,
    required this.lessonId,
    required this.subjectCode,
    required this.attempts,
    required this.bestCorrect,
    required this.totalQuestions,
    required this.updatedAt,
    required this.attemptIds,
    required this.wrongQuestionIds,
    required this.recentHistory,
  });

  int get bestXp => bestCorrect * 10;

  /// Review mistakes after 1 day, otherwise refresh the lesson after 7 days.
  DateTime get reviewDueAt => DateTime.parse(updatedAt).add(
      Duration(days: wrongQuestionIds.isNotEmpty ? 1 : 7));

  factory LessonProgress.fromJson(Map<String, dynamic> m) => LessonProgress(
        profileId: m['profileId'] as String,
        grade: (m['grade'] as num).toInt(),
        lessonId: (m['lessonId'] as num).toInt(),
        subjectCode: m['subjectCode'] as String? ?? '',
        attempts: (m['attempts'] as num).toInt(),
        bestCorrect: (m['bestCorrect'] as num).toInt(),
        totalQuestions: (m['totalQuestions'] as num).toInt(),
        updatedAt: m['updatedAt'] as String,
        attemptIds: List<String>.from(m['attemptIds'] as List? ?? const []),
        wrongQuestionIds:
            (m['wrongQuestionIds'] as List? ?? const []).cast<num>().map((v) => v.toInt()).toList(),
        recentHistory: (m['recentHistory'] as List? ?? const [])
            .map((v) => Map<String, dynamic>.from(v as Map))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'profileId': profileId,
        'grade': grade,
        'lessonId': lessonId,
        'subjectCode': subjectCode,
        'attempts': attempts,
        'bestCorrect': bestCorrect,
        'totalQuestions': totalQuestions,
        'updatedAt': updatedAt,
        'attemptIds': attemptIds,
        'wrongQuestionIds': wrongQuestionIds,
        'recentHistory': recentHistory,
      };
}

class SubjectStatistics {
  final String subjectCode;
  final int lessonsPractised;
  final int attempts;
  final int xp;
  const SubjectStatistics(this.subjectCode, this.lessonsPractised, this.attempts, this.xp);
}

class StudyLedger {
  static const _stateKey = 'study:state:v2';
  static const defaultProfileId = 'local-default';
  final LocalStore storage;
  final Random _random = Random.secure();

  StudyLedger(this.storage);

  Map<String, dynamic> _decode(String value) {
    final map = Map<String, dynamic>.from(jsonDecode(value) as Map);
    if (map['version'] != 2 ||
        map['profiles'] is! List ||
        map['progress'] is! Map ||
        map['activeProfileId'] is! String) {
      throw StateError('Local study schema unsupported; do not overwrite');
    }
    return map;
  }

  Future<void> initialize() async {
    final oldGrade = int.tryParse(await storage.read('selected_grade') ?? '');
    final grade = oldGrade != null && oldGrade >= 1 && oldGrade <= 5
        ? oldGrade
        : 3;
    await storage.update(_stateKey, (raw) {
      if (raw != null) {
        _decode(raw);
        return raw;
      }
      return jsonEncode({
        'version': 2,
        'activeProfileId': defaultProfileId,
        'profiles': [
          StudentProfile(id: defaultProfileId, name: 'Học sinh 1', grade: grade)
              .toJson()
        ],
        'progress': <String, dynamic>{}
      });
    });
  }

  Future<Map<String, dynamic>> _state() async {
    final raw = await storage.read(_stateKey);
    if (raw == null) throw StateError('Call initialize first');
    return _decode(raw);
  }

  Future<T> _mutate<T>(T Function(Map<String, dynamic>) change) async {
    late T result;
    await storage.update(_stateKey, (raw) {
      if (raw == null) throw StateError('Call initialize first');
      final state = _decode(raw);
      result = change(state);
      return jsonEncode(state);
    });
    return result;
  }

  Future<List<StudentProfile>> listProfiles() async =>
      (await _state())['profiles']
          .cast<Map>()
          .map<StudentProfile>(
              (m) => StudentProfile.fromJson(Map<String, dynamic>.from(m)))
          .toList();

  Future<StudentProfile> activeProfile() async {
    final state = await _state();
    final id = state['activeProfileId'] as String;
    return (state['profiles'] as List)
        .map((m) => StudentProfile.fromJson(Map<String, dynamic>.from(m as Map)))
        .firstWhere((p) => p.id == id);
  }

  static void _checkGrade(int grade) {
    if (grade < 1 || grade > 5) throw ArgumentError.value(grade, 'grade');
  }

  Future<StudentProfile> createProfile(String name, int grade) async {
    _checkGrade(grade);
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 32) {
      throw ArgumentError.value(name, 'name', '1–32 characters required');
    }
    final profile = StudentProfile(
        id: 'p-${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 30)}',
        name: trimmed,
        grade: grade);
    return _mutate((state) {
      (state['profiles'] as List).add(profile.toJson());
      state['activeProfileId'] = profile.id;
      return profile;
    });
  }

  Future<StudentProfile> selectProfile(String profileId) => _mutate((state) {
        final profile = _findProfile(state, profileId);
        state['activeProfileId'] = profile.id;
        return profile;
      });

  Future<StudentProfile> changeGrade(String profileId, int grade) async {
    _checkGrade(grade);
    return _mutate((state) {
      final rows = state['profiles'] as List;
      final index = rows.indexWhere((m) => (m as Map)['id'] == profileId);
      if (index < 0) throw ArgumentError.value(profileId, 'profileId');
      final old = StudentProfile.fromJson(Map<String, dynamic>.from(rows[index] as Map));
      final next = StudentProfile(id: old.id, name: old.name, grade: grade);
      rows[index] = next.toJson();
      return next;
    });
  }

  StudentProfile _findProfile(Map<String, dynamic> state, String id) =>
      (state['profiles'] as List)
          .map((m) => StudentProfile.fromJson(Map<String, dynamic>.from(m as Map)))
          .firstWhere((p) => p.id == id,
              orElse: () => throw ArgumentError.value(id, 'profileId'));

  String _key(String profileId, int grade, int lessonId) =>
      '$profileId:$grade:$lessonId';

  /// Import legacy best-XP for the default profile on first visit to a lesson.
  /// Legacy values are not modified, so failures never destroy v1 data.
  Future<void> _migrateLegacy(int grade, int lessonId) async {
    final raw = await storage.read('progress:v1:$grade:$lessonId');
    if (raw == null) return;
    final legacy = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    if (legacy['grade'] != grade || legacy['lessonId'] != lessonId) {
      throw StateError('Invalid legacy lesson progress');
    }
    await _mutate<bool>((state) {
      final progress = state['progress'] as Map;
      final key = _key(defaultProfileId, grade, lessonId);
      if (!progress.containsKey(key)) {
        final best = (legacy['bestCorrect'] as num).toInt();
        final attempts = (legacy['attempts'] as num).toInt();
        if (best < 0 || attempts < 0) throw StateError('Invalid legacy values');
        progress[key] = LessonProgress(
          profileId: defaultProfileId,
          grade: grade,
          lessonId: lessonId,
          subjectCode: '',
          attempts: attempts,
          bestCorrect: best,
          totalQuestions: (legacy['totalQuestions'] as num).toInt(),
          updatedAt: legacy['updatedAt'] as String,
          attemptIds: const [],
          wrongQuestionIds: const [],
          recentHistory: const [],
        ).toJson();
      }
      return true;
    });
  }

  Future<LessonProgress?> load(
      {required String profileId, required int grade, required int lessonId}) async {
    if (profileId == defaultProfileId) await _migrateLegacy(grade, lessonId);
    final state = await _state();
    _findProfile(state, profileId);
    final raw = (state['progress'] as Map)[_key(profileId, grade, lessonId)];
    if (raw == null) return null;
    final result = LessonProgress.fromJson(Map<String, dynamic>.from(raw as Map));
    if (result.profileId != profileId || result.grade != grade || result.lessonId != lessonId) {
      throw StateError('Invalid profile-scoped progress');
    }
    return result;
  }

  /// A stable attemptId survives save retries; atomic updates prevent two
  /// simultaneous taps/reloads from incrementing attempts twice.
  Future<LessonProgress> recordResult({
    required String profileId,
    required int grade,
    required int lessonId,
    required String attemptId,
    required int correct,
    required int total,
    String subjectCode = '',
    List<int> wrongQuestionIds = const [],
    DateTime? completedAt,
  }) async {
    _checkGrade(grade);
    if (profileId.isEmpty ||
        lessonId <= 0 ||
        attemptId.trim().isEmpty ||
        total <= 0 ||
        correct < 0 ||
        correct > total ||
        wrongQuestionIds.length > total ||
        wrongQuestionIds.toSet().length != wrongQuestionIds.length) {
      throw ArgumentError('Invalid local practice result');
    }
    if (profileId == defaultProfileId) await _migrateLegacy(grade, lessonId);
    final timestamp = (completedAt ?? DateTime.now()).toUtc().toIso8601String();
    return _mutate((state) {
      _findProfile(state, profileId);
      final data = state['progress'] as Map;
      final key = _key(profileId, grade, lessonId);
      final previous = data[key] == null
          ? null
          : LessonProgress.fromJson(Map<String, dynamic>.from(data[key] as Map));
      if (previous != null && previous.attemptIds.contains(attemptId)) {
        return previous;
      }
      final history = [
        ...?previous?.recentHistory,
        {
          'id': attemptId,
          'correct': correct,
          'total': total,
          'at': timestamp,
          'wrongQuestionIds': wrongQuestionIds
        }
      ];
      final result = LessonProgress(
        profileId: profileId,
        grade: grade,
        lessonId: lessonId,
        subjectCode: subjectCode.isNotEmpty ? subjectCode : previous?.subjectCode ?? '',
        attempts: (previous?.attempts ?? 0) + 1,
        bestCorrect: max(previous?.bestCorrect ?? 0, correct),
        totalQuestions: total,
        updatedAt: timestamp,
        // Keep IDs even when compact history is pruned, for durable dedupe.
        attemptIds: [...?previous?.attemptIds, attemptId],
        wrongQuestionIds: List<int>.from(wrongQuestionIds),
        recentHistory: history.length <= 20 ? history : history.sublist(history.length - 20),
      );
      data[key] = result.toJson();
      return result;
    });
  }

  Future<List<LessonProgress>> progressFor(
      String profileId, {int? grade, String? subjectCode}) async {
    final state = await _state();
    _findProfile(state, profileId);
    return (state['progress'] as Map).values
        .map((v) => LessonProgress.fromJson(Map<String, dynamic>.from(v as Map)))
        .where((p) =>
            p.profileId == profileId &&
            (grade == null || p.grade == grade) &&
            (subjectCode == null || p.subjectCode == subjectCode))
        .toList();
  }

  Future<int> totalXp(String profileId) async =>
      (await progressFor(profileId)).fold<int>(0, (sum, p) => sum + p.bestXp);

  Future<List<SubjectStatistics>> subjectStatistics(
      String profileId, int grade) async {
    final lessons = await progressFor(profileId, grade: grade);
    final subjects = <String, List<LessonProgress>>{};
    for (final lesson in lessons) {
      subjects.putIfAbsent(lesson.subjectCode, () => []).add(lesson);
    }
    return subjects.entries
        .map((entry) => SubjectStatistics(
            entry.key,
            entry.value.length,
            entry.value.fold<int>(0, (sum, p) => sum + p.attempts),
            entry.value.fold<int>(0, (sum, p) => sum + p.bestXp)))
        .toList();
  }

  Future<List<LessonProgress>> dueForReview(
      String profileId, DateTime now) async {
    final lessons = await progressFor(profileId);
    final due = lessons.where((p) => !p.reviewDueAt.isAfter(now.toUtc())).toList();
    due.sort((a, b) => a.reviewDueAt.compareTo(b.reviewDueAt));
    return due;
  }
}
