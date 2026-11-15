import 'dart:convert';

/// Strictly typed, local-only grading. Unsupported or ambiguous source
/// answers are excluded from scored practice until editorial review.
class QuizEvaluator {
  static String _normalize(String value) => value.trim().toLowerCase();

  static bool? _boolean(String value) => switch (_normalize(value)) {
        'đúng' || 'true' => true,
        'sai' || 'false' => false,
        _ => null,
      };

  static num? _number(String value) =>
      num.tryParse(value.trim().replaceAll(',', '.'));

  static List<String>? _options(Map<String, dynamic> question) {
    try {
      final data = jsonDecode(question['optionsJson']?.toString() ?? '');
      if (data is! List || data.length < 2 || data.any((v) => v is! String)) {
        return null;
      }
      final options = data.cast<String>();
      if (options.any((v) => _normalize(v).isEmpty) ||
          options.map(_normalize).toSet().length != options.length) {
        return null;
      }
      return options;
    } catch (_) {
      return null;
    }
  }

  static bool canGrade(Map<String, dynamic> question) {
    final expected = question['correctAnswer']?.toString() ?? '';
    switch (question['questionType']?.toString()) {
      case 'true_false':
        return _boolean(expected) != null;
      case 'fill_number':
        return _number(expected) != null;
      case 'single_choice':
        final options = _options(question);
        return options != null &&
            options.any((option) => _normalize(option) == _normalize(expected));
      default:
        // Never give points for multi-select, free text, essay, unknown types
        // without explicit answer semantics.
        return false;
    }
  }

  static bool correct(Map<String, dynamic> question, String selected) {
    if (!canGrade(question)) return false;
    final expected = question['correctAnswer'].toString();
    switch (question['questionType']?.toString()) {
      case 'true_false':
        final value = _boolean(selected);
        return value != null && value == _boolean(expected);
      case 'fill_number':
        final value = _number(selected);
        return value != null && value == _number(expected);
      case 'single_choice':
        final options = _options(question)!;
        return options.any((option) => _normalize(option) == _normalize(selected)) &&
            _normalize(selected) == _normalize(expected);
      default:
        return false;
    }
  }
}
