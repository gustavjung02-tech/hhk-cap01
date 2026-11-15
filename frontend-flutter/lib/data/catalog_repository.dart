import 'dart:convert';
import 'package:flutter/services.dart';

class GradePack {
  final int grade;
  final List<Map<String, dynamic>> subjects;
  final List<Map<String, dynamic>> lessons;
  final List<Map<String, dynamic>> cards;
  final List<Map<String, dynamic>> questions;
  const GradePack(this.grade, this.subjects, this.lessons, this.cards, this.questions);

  factory GradePack.fromJson(Map<String, dynamic> value) {
    List<Map<String, dynamic>> rows(String key) =>
        ((value[key] as List?) ?? const []).whereType<Map>().map((row) =>
            Map<String, dynamic>.from(row)).toList(growable: false);
    return GradePack((value['grade'] as num).toInt(),
        rows('subjects'), rows('lessons'), rows('cards'), rows('questions'));
  }

  List<Map<String, dynamic>> lessonsFor(String subject) =>
      lessons.where((row) => row['subjectCode'] == subject && row['isActive'] != 0).toList()
        ..sort((a, b) => ((a['sortOrder'] as num?)?.toInt() ?? 0)
            .compareTo((b['sortOrder'] as num?)?.toInt() ?? 0));

  List<Map<String, dynamic>> cardsFor(int lessonId) =>
      cards.where((row) => row['lessonId'] == lessonId && row['isActive'] != 0).toList()
        ..sort((a, b) => ((a['sortOrder'] as num?)?.toInt() ?? 0)
            .compareTo((b['sortOrder'] as num?)?.toInt() ?? 0));

  List<Map<String, dynamic>> questionsFor(int lessonId) =>
      questions.where((row) => row['lessonId'] == lessonId && row['isActive'] != 0).toList();
}

class CatalogRepository {
  Future<GradePack> loadGrade(int grade) async {
    if (grade < 1 || grade > 5) throw ArgumentError.value(grade, 'grade');
    final raw = await rootBundle.loadString('assets/content/grades/grade-$grade.json');
    final value = jsonDecode(raw) as Map<String, dynamic>;
    final pack = GradePack.fromJson(value);
    if (pack.grade != grade) throw StateError('Sai phiên bản gói nội dung lớp $grade');
    return pack;
  }
}
