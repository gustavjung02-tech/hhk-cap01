import 'dart:convert';
import 'package:material_ui/material_ui.dart';
import '../../data/study_ledger.dart';
import 'quiz_evaluator.dart';

class PracticePage extends StatefulWidget {
  final List<Map<String, dynamic>> questions;
  final String lessonTitle;
  final int grade;
  final int lessonId;
  final StudyLedger ledger;
  const PracticePage({
    super.key,
    required this.questions,
    required this.lessonTitle,
    required this.grade,
    required this.lessonId,
    required this.ledger,
  });
  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage> {
  int index = 0;
  int correctCount = 0;
  String? selected;
  bool submitted = false;
  bool saving = false;
  LessonProgress? savedProgress;
  String? storageError;

  Future<void> _finish() async {
    if (saving || savedProgress != null) return;
    setState(() {
      saving = true;
      storageError = null;
    });
    try {
      final result = await widget.ledger.recordResult(
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
    List<String> options = [];
    if (kind == 'single_choice') {
      try {
        options = (jsonDecode(question['optionsJson']?.toString() ?? '[]') as List)
            .map((value) => value.toString()).toList(growable: false);
      } catch (_) {
        options = [];
      }
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
        if (options.isNotEmpty)
          ...options.map((option) => Card(
                child: ListTile(
                  title: Text(option),
                  selected: selected == option,
                  leading: Icon(selected == option
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked),
                  onTap: submitted ? null : () => setState(() => selected = option),
                ),
              ))
        else
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
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(QuizEvaluator.correct(question, selected ?? '')
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
                      submitted = false;
                    });
                  }
                }
              : () {
                  if (selected == null || selected!.trim().isEmpty) return;
                  if (QuizEvaluator.correct(question, selected!)) correctCount++;
                  setState(() => submitted = true);
                },
          child: Text(submitted
              ? index + 1 == widget.questions.length ? 'Lưu kết quả' : 'Câu tiếp theo'
              : 'Kiểm tra'),
        ),
      ]),
    );
  }
}
