import 'dart:math';
import 'package:material_ui/material_ui.dart';
import '../../data/study_ledger.dart';
import 'quiz_evaluator.dart';

class PracticePage extends StatefulWidget {
  final List<Map<String, dynamic>> questions;
  final String lessonTitle;
  final int grade;
  final int lessonId;
  final StudyLedger ledger;
  final String profileId;
  final String subjectCode;
  const PracticePage({
    super.key,
    required this.questions,
    required this.lessonTitle,
    required this.grade,
    required this.lessonId,
    required this.ledger,
    required this.profileId,
    required this.subjectCode,
  });
  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage> {
  final String attemptId =
      'attempt-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 30)}';
  final List<int> wrongQuestionIds = [];
  int index = 0;
  int correctCount = 0;
  String? selected;
  final Set<String> selectedMultiple = <String>{};
  final Map<int, int> selectedMatching = <int, int>{};
  final List<String> selectedOrdering = <String>[];
  bool submitted = false;
  bool saving = false;
  LessonProgress? savedProgress;
  String? storageError;

  bool _answerCorrect(Map<String, dynamic> question) {
    switch (question['questionType']) {
      case 'multi_choice':
        return QuizEvaluator.correctMultiple(question, selectedMultiple);
      case 'matching':
        return QuizEvaluator.correctMatching(question, selectedMatching);
      case 'ordering':
        return QuizEvaluator.correctOrdering(question, selectedOrdering);
      default:
        return QuizEvaluator.correct(question, selected ?? '');
    }
  }

  bool _answerCompleted(String? kind, Map<String, dynamic> question) {
    switch (kind) {
      case 'multi_choice':
        return selectedMultiple.isNotEmpty;
      case 'matching':
        final parsed = QuizEvaluator.matchingQuestion(question);
        return parsed != null && selectedMatching.length == parsed.left.length;
      case 'ordering':
        final parsed = QuizEvaluator.orderingQuestion(question);
        return parsed != null && selectedOrdering.length == parsed.options.length;
      default:
        return selected != null && selected!.trim().isNotEmpty;
    }
  }

  Future<void> _finish() async {
    if (saving || savedProgress != null) return;
    setState(() {
      saving = true;
      storageError = null;
    });
    try {
      final result = await widget.ledger.recordResult(
        profileId: widget.profileId,
        subjectCode: widget.subjectCode,
        attemptId: attemptId,
        wrongQuestionIds: wrongQuestionIds,
        grade: widget.grade,
        lessonId: widget.lessonId,
        correct: correctCount,
        total: widget.questions.length,
      );
      if (mounted) setState(() => savedProgress = result);
    } catch (_) {
      if (mounted) {
        setState(() => storageError =
            'Chưa lưu được kết quả trên thiết bị. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (index >= widget.questions.length) {
      return Scaffold(
        appBar: AppBar(title: const Text('Hoàn thành')),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.emoji_events, size: 64, color: Colors.orange),
            Text('Đúng $correctCount / ${widget.questions.length}',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            if (saving) const CircularProgressIndicator(),
            if (savedProgress != null)
              Text('Đã lưu offline • XP tốt nhất: ${savedProgress!.bestXp}'),
            if (storageError != null) ...[
              Text(storageError!, textAlign: TextAlign.center),
              TextButton(onPressed: _finish, child: const Text('Thử lưu lại')),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: saving ? null : () => Navigator.pop(context),
              child: const Text('Về bài học'),
            ),
          ]),
        ),
      );
    }

    final question = widget.questions[index];
    final kind = question['questionType']?.toString();
    final matching = kind == 'matching' ? QuizEvaluator.matchingQuestion(question) : null;
    final ordering = kind == 'ordering' ? QuizEvaluator.orderingQuestion(question) : null;
    final orderingChoices = ordering == null
        ? <String>[]
        : (List<String>.from(ordering.options)
          ..shuffle(Random(((question['id'] as num?)?.toInt() ?? index + 1) ^ widget.lessonId)));
    if (ordering != null &&
        List.generate(orderingChoices.length, (i) => orderingChoices[i].trim().toLowerCase())
            .join('|') == ordering.expected.join('|')) {
      orderingChoices.setAll(0, orderingChoices.reversed.toList());
    }
    List<String> options = [];
    if (kind == 'single_choice' || kind == 'multi_choice') {
      options = QuizEvaluator.options(question);
    } else if (kind == 'true_false') {
      options = const ['Đúng', 'Sai'];
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.lessonTitle)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        LinearProgressIndicator(value: (index + 1) / widget.questions.length),
        const SizedBox(height: 18),
        Text('Câu ${index + 1} / ${widget.questions.length}',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Text(question['questionText']?.toString() ?? '',
                style: Theme.of(context).textTheme.titleLarge),
          ),
        ),
        if (kind == 'matching' && matching != null) ...[
          const Text('Chọn một vế phù hợp cho mỗi dòng'),
          for (var i = 0; i < matching.left.length; i++)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(matching.left[i], style: Theme.of(context).textTheme.titleMedium),
                    DropdownButton<int>(
                      isExpanded: true,
                      value: selectedMatching[i],
                      hint: const Text('Chọn đáp án để nối'),
                      items: [
                        for (var j = 0; j < matching.right.length; j++)
                          DropdownMenuItem<int>(
                            value: j,
                            child: Text(matching.right[j],
                                overflow: TextOverflow.ellipsis),
                          )
                      ],
                      onChanged: submitted ? null : (value) {
                        if (value == null) return;
                        setState(() {
                          selectedMatching.removeWhere(
                              (key, existing) => key != i && existing == value);
                          selectedMatching[i] = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
        if (kind == 'ordering' && ordering != null) ...[
          const Text('Chạm các mục theo thứ tự đúng. Chạm lại để bỏ chọn.'),
          for (final option in orderingChoices)
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(selectedOrdering.contains(option)
                      ? (selectedOrdering.indexOf(option) + 1).toString()
                      : '•'),
                ),
                title: Text(option),
                selected: selectedOrdering.contains(option),
                onTap: submitted ? null : () => setState(() {
                  if (selectedOrdering.contains(option)) {
                    selectedOrdering.remove(option);
                  } else {
                    selectedOrdering.add(option);
                  }
                }),
              ),
            ),
        ],
        if (kind == 'multi_choice')
          const Text('Chọn tất cả đáp án đúng'),
        if (options.isNotEmpty)
          ...options.map((option) {
            final isMulti = kind == 'multi_choice';
            final active =
                isMulti ? selectedMultiple.contains(option) : selected == option;
            return Card(
              child: ListTile(
                title: Text(option),
                selected: active,
                leading: Icon(isMulti
                    ? (active ? Icons.check_box : Icons.check_box_outline_blank)
                    : (active
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked)),
                onTap: submitted
                    ? null
                    : () => setState(() {
                          if (isMulti) {
                            if (!selectedMultiple.add(option)) {
                              selectedMultiple.remove(option);
                            }
                          } else {
                            selected = option;
                          }
                        }),
              ),
            );
          })
        else if (kind != 'matching' && kind != 'ordering')
          TextField(
            key: ValueKey('answer-$index'),
            enabled: !submitted,
            keyboardType: kind == 'fill_number'
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            decoration: const InputDecoration(
                labelText: 'Nhập câu trả lời', border: OutlineInputBorder()),
            onChanged: (value) => selected = value,
          ),
        if (submitted)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        _answerCorrect(question)
                            ? 'Chính xác!'
                            : 'Chưa đúng. Đáp án: ${question['correctAnswer']}',
                        style: Theme.of(context).textTheme.titleMedium),
                    if (question['explanationSimple'] != null)
                      Text(question['explanationSimple'].toString()),
                  ]),
            ),
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: submitted
              ? () {
                  if (index + 1 >= widget.questions.length) {
                    setState(() => index = widget.questions.length);
                    _finish();
                  } else {
                    setState(() {
                      index++;
                      selected = null;
                      selectedMultiple.clear();
                      selectedMatching.clear();
                      selectedOrdering.clear();
                      submitted = false;
                    });
                  }
                }
              : () {
                  if (!_answerCompleted(kind, question)) return;
                  if (_answerCorrect(question)) {
                    correctCount++;
                  } else if (question['id'] is num) {
                    wrongQuestionIds.add((question['id'] as num).toInt());
                  }
                  setState(() => submitted = true);
                },
          child: Text(submitted
              ? index + 1 == widget.questions.length
                  ? 'Lưu kết quả'
                  : 'Câu tiếp theo'
              : 'Kiểm tra'),
        ),
      ]),
    );
  }
}
