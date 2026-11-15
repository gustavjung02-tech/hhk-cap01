/// Domain logic for local checking of source question answers.
/// No network request, no server-side XP.
class QuizEvaluator {
  static String _normalize(String value) => value.trim().toLowerCase();

  static bool correct(Map<String, dynamic> question, String selected) {
    final expected = _normalize(question['correctAnswer']?.toString() ?? '');
    if (expected.isEmpty) return false;
    final kind = question['questionType']?.toString() ?? '';
    if (kind == 'true_false') {
      final answer = _normalize(selected);
      final normalized = switch (answer) {
        'đúng' || 'true' => 'true',
        'sai' || 'false' => 'false',
        _ => '',
      };
      return normalized == expected;
    }
    if (kind == 'fill_number') {
      final lhs = num.tryParse(selected.trim().replaceAll(',', '.'));
      final rhs = num.tryParse(expected.replaceAll(',', '.'));
      if (lhs != null && rhs != null) return lhs == rhs;
    }
    return _normalize(selected) == expected;
  }
}
