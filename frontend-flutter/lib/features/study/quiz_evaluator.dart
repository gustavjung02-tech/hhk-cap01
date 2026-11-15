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

  /// Parse source CSV only when no option itself contains a comma.
  /// A multi-select answer is an exact SET, not a free-text string.
  static Set<String>? _multipleExpected(Map<String, dynamic> question) {
    final options = _options(question);
    if (options == null || options.any((option) => option.contains(','))) {
      return null;
    }
    final fields = (question['correctAnswer']?.toString() ?? '')
        .split(',')
        .map(_normalize)
        .toList();
    final expected = fields.toSet();
    if (fields.length < 2 ||
        expected.length != fields.length ||
        !expected.every((answer) => options.map(_normalize).contains(answer))) {
      return null;
    }
    return expected;
  }

  static List<String> options(Map<String, dynamic> question) =>
      _options(question) ?? const [];

  static bool correctMultiple(
      Map<String, dynamic> question, Set<String> selected) {
    if (question['questionType'] != 'multi_choice') return false;
    final expected = _multipleExpected(question);
    if (expected == null || selected.isEmpty) return false;
    final values = selected.map(_normalize).toSet();
    final options = optionsForComparison(question);
    return values.length == selected.length &&
        values.every(options.contains) &&
        values.length == expected.length &&
        values.containsAll(expected);
  }

  static Set<String> optionsForComparison(Map<String, dynamic> question) =>
      options(question).map(_normalize).toSet();

  static bool canGrade(Map<String, dynamic> question) {
    final expected = question['correctAnswer']?.toString() ?? '';
    switch (question['questionType']?.toString()) {
      case 'true_false':
        return _boolean(expected) != null;
      case 'fill_number':
        return _number(expected) != null;
      case 'multi_choice':
        return _multipleExpected(question) != null;
      case 'single_choice':
        final options = _options(question);
        return options != null &&
            options.any((option) => _normalize(option) == _normalize(expected));
      default:
        // Free text, matching, ordering, and unknown types remain excluded
        // pending explicit semantics and UI.
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
