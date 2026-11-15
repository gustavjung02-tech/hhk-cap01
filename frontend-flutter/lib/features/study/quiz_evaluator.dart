import 'dart:convert';

class MatchingQuestion {
  final List<String> left;
  final List<String> right;
  final Map<int, int> expected;
  const MatchingQuestion(this.left, this.right, this.expected);
}

class OrderingQuestion {
  final List<String> options;
  final List<String> expected;
  const OrderingQuestion(this.options, this.expected);
}

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

  /// Only a real two-column bijection can be graded. A legacy single list
  /// with an answer like 0-0,1-1 has no right-hand options, so it stays hidden.
  static MatchingQuestion? matchingQuestion(Map<String, dynamic> question) {
    try {
      final value = jsonDecode(question['optionsJson']?.toString() ?? '');
      if (value is! Map || value['left'] is! List || value['right'] is! List) {
        return null;
      }
      final left = List<String>.from(value['left'] as List);
      final right = List<String>.from(value['right'] as List);
      if (left.length < 2 || left.length > 12 || left.length != right.length ||
          left.any((v) => _normalize(v).isEmpty) ||
          right.any((v) => _normalize(v).isEmpty) ||
          left.map(_normalize).toSet().length != left.length ||
          right.map(_normalize).toSet().length != right.length) {
        return null;
      }
      final raw = question['correctAnswer']?.toString() ?? '';
      final tokens = raw.split(',');
      if (tokens.length != left.length) return null;
      final mapping = <int, int>{};
      final usedRight = <int>{};
      final pattern = RegExp(r'^([0-9]+)-([0-9]+)$');
      for (final token in tokens) {
        final match = pattern.firstMatch(token.trim());
        if (match == null) { return null; }
        final l = int.parse(match.group(1)!);
        final r = int.parse(match.group(2)!);
        if (l >= left.length || r >= right.length ||
            mapping.containsKey(l) || !usedRight.add(r)) { return null; }
        mapping[l] = r;
      }
      if (mapping.length != left.length) { return null; }
      return MatchingQuestion(left, right, mapping);
    } catch (_) {
      return null;
    }
  }

  static bool correctMatching(Map<String, dynamic> question,
      Map<int, int> selected) {
    if (question['questionType'] != 'matching') { return false; }
    final parsed = matchingQuestion(question);
    if (parsed == null || selected.length != parsed.left.length) { return false; }
    for (final entry in parsed.expected.entries) {
      if (selected[entry.key] != entry.value) { return false; }
    }
    return true;
  }

  /// CSV is intentionally rejected whenever an option contains a comma:
  /// those source records cannot be split unambiguously.
  static OrderingQuestion? orderingQuestion(Map<String, dynamic> question) {
    final options = _options(question);
    if (options == null || options.length > 12 ||
        options.any((v) => v.contains(','))) { return null; }
    final ordered = (question['correctAnswer']?.toString() ?? '')
        .split(',')
        .map(_normalize)
        .toList();
    if (ordered.length != options.length ||
        ordered.any((v) => v.isEmpty) ||
        ordered.toSet().length != options.length) { return null; }
    final optionSet = options.map(_normalize).toSet();
    if (!ordered.toSet().containsAll(optionSet)) { return null; }
    return OrderingQuestion(options, ordered);
  }

  static bool correctOrdering(
      Map<String, dynamic> question, List<String> selected) {
    if (question['questionType'] != 'ordering') { return false; }
    final parsed = orderingQuestion(question);
    if (parsed == null || parsed.expected.length != selected.length) {
      return false;
    }
    for (var i = 0; i < selected.length; i++) {
      if (_normalize(selected[i]) != parsed.expected[i]) { return false; }
    }
    return true;
  }

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
