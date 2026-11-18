import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/catalog_repository.dart';
import '../../data/local_store.dart';
import '../../data/offline_audio.dart';
import '../../data/offline_license.dart';
import '../../data/study_ledger.dart';
import '../account/hhk_toast.dart';
import 'practice_page.dart';
import 'quiz_evaluator.dart';

class LessonPage extends StatefulWidget {
  final GradePack pack;
  final Map<String, dynamic> lesson;
  final StudyLedger ledger;
  final String profileId;
  final LocalStore? storage;
  final OfflineLicenseManager? offlineLicense;

  const LessonPage({
    super.key,
    required this.pack,
    required this.lesson,
    required this.ledger,
    required this.profileId,
    this.storage,
    this.offlineLicense,
  });

  @override
  State<LessonPage> createState() => _LessonPageState();
}

class _LessonPageState extends State<LessonPage> {
  OfflineAudioCatalog? catalog;
  OfflineAudioStore? audio;
  AudioPlayer? player;
  StreamSubscription<void>? completeSubscription;
  List<int> playableIds = [];
  int cachedCount = 0;
  int downloadProgress = 0;
  int? playingId;
  bool paused = false;
  bool downloading = false;
  bool playingBusy = false;

  @override
  void initState() {
    super.initState();
    loadAudio();
  }

  Future<void> loadAudio() async {
    if (widget.storage == null) return;
    try {
      final index = await OfflineAudioCatalog.load();
      final store = OfflineAudioStore(widget.storage!, index);
      final lessonId = (widget.lesson['id'] as num).toInt();
      final ids = index.cardsForLesson(widget.pack, lessonId);
      final count = await store.downloadedCount(widget.pack.grade, ids);
      if (!mounted) {
        store.dispose();
        return;
      }
      setState(() {
        audio = store;
        catalog = index;
        playableIds = ids;
        cachedCount = count;
      });
    } catch (_) {
      if (mounted) {
        HhkToast.show(context, 'Chưa tải được danh mục âm thanh.',
            kind: HhkToastKind.error);
      }
    }
  }

  Future<bool> entitled() async {
    final allowed = await (widget.offlineLicense ??
        OfflineLicenseManager()).gradeAllowed(widget.pack.grade);
    if (!allowed && mounted) {
      HhkToast.show(context,
          'Quyền học lớp này chưa được kích hoạt trên thiết bị.',
          kind: HhkToastKind.error);
    }
    return allowed;
  }

  Future<void> downloadAudio() async {
    final service = audio;
    if (service == null || downloading || playableIds.isEmpty ||
        !await entitled()) {
      return;
    }
    setState(() {
      downloading = true;
      downloadProgress = 0;
    });
    try {
      await service.downloadLesson(widget.pack.grade, playableIds,
        onProgress: (completed, total) {
          if (mounted) {
            setState(() => downloadProgress = completed);
          }
        });
      if (!mounted) return;
      final count = await service.downloadedCount(
          widget.pack.grade, playableIds);
      if (!mounted) return;
      setState(() => cachedCount = count);
      HhkToast.show(context,
          'Đã tải âm thanh của bài vào thiết bị để nghe offline.',
          kind: HhkToastKind.success);
    } on AudioNotReady catch (e) {
      if (mounted) {
        HhkToast.show(context, e.message, kind: HhkToastKind.error);
      }
    } catch (_) {
      if (mounted) {
        HhkToast.show(context, 'Không thể tải âm thanh bài này.',
            kind: HhkToastKind.error);
      }
    } finally {
      if (mounted) setState(() => downloading = false);
    }
  }

  Future<void> togglePlayback(int cardId) async {
    final service = audio;
    if (service == null || playingBusy || !await entitled()) return;
    setState(() => playingBusy = true);
    try {
      final current = player;
      if (current != null && playingId == cardId) {
        if (paused) {
          await current.resume();
          if (mounted) setState(() => paused = false);
        } else {
          await current.pause();
          if (mounted) setState(() => paused = true);
        }
        return;
      }
      final bytes = await service.obtain(widget.pack.grade, cardId);
      if (!mounted) return;
      final count = await service.downloadedCount(
          widget.pack.grade, playableIds);
      if (!mounted) return;
      final active = player ??= AudioPlayer();
      await completeSubscription?.cancel();
      completeSubscription = active.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() {
            playingId = null;
            paused = false;
          });
        }
      });
      await active.stop();
      await active.play(BytesSource(bytes, mimeType: 'audio/mpeg'));
      if (mounted) {
        setState(() {
          playingId = cardId;
          paused = false;
          cachedCount = count;
        });
      }
    } on AudioNotReady catch (e) {
      if (mounted) {
        HhkToast.show(context, e.message, kind: HhkToastKind.error);
      }
    } catch (_) {
      if (mounted) {
        HhkToast.show(context,
            'Không phát được file âm thanh. Hãy thử tải lại bài.',
            kind: HhkToastKind.error);
      }
    } finally {
      if (mounted) setState(() => playingBusy = false);
    }
  }

  @override
  void dispose() {
    unawaited(completeSubscription?.cancel());
    if (player != null) unawaited(player!.dispose());
    audio?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = (widget.lesson['id'] as num).toInt();
    final cards = widget.pack.cardsFor(id);
    final allQuestions = widget.pack.questionsFor(id);
    final questions = allQuestions.where(QuizEvaluator.canGrade).toList();
    final unsupported = allQuestions.length - questions.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lesson['title']?.toString() ?? 'Bài học'),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('Lớp ${widget.pack.grade} • ${widget.lesson['subjectCode']}',
            style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Text(widget.lesson['title']?.toString() ?? '',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        if ((widget.lesson['summarySimple']?.toString() ?? '').isNotEmpty)
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(widget.lesson['summarySimple'].toString()))),
        if (catalog != null && playableIds.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('🔊 Nghe bài học',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 5),
                  Text('Đã lưu offline $cachedCount/${playableIds.length} thẻ. '
                      'Tải một lần để nghe khi mất mạng.'),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: downloading ? null : downloadAudio,
                    icon: Icon(downloading
                        ? Icons.downloading : Icons.download_for_offline_outlined),
                    label: Text(downloading
                        ? 'Đang tải $downloadProgress/${playableIds.length}'
                        : cachedCount == playableIds.length
                            ? 'Đã tải âm thanh bài này'
                            : 'Tải âm thanh bài này'),
                  ),
                ],
              ),
            ),
          ),
        for (final card in cards)
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(card['title']?.toString() ?? '',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 6),
                        SelectableText(card['content']?.toString() ?? ''),
                        if (catalog?.hasCard(
                            widget.pack.grade,
                            (card['id'] as num?)?.toInt() ?? -1) ?? false)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: OutlinedButton.icon(
                              onPressed: playingBusy
                                  ? null
                                  : () => togglePlayback(
                                      (card['id'] as num).toInt()),
                              icon: Icon(playingId == card['id'] && !paused
                                  ? Icons.pause_circle_outline
                                  : Icons.play_circle_outline),
                              label: Text(playingId == card['id'] && !paused
                                  ? 'Tạm dừng'
                                  : playingId == card['id'] && paused
                                      ? 'Tiếp tục nghe'
                                      : 'Nghe thẻ này'),
                            ),
                          ),
                      ]))),
        const SizedBox(height: 12),
        if (unsupported > 0)
          Text('$unsupported câu chưa có quy tắc chấm đã được tạm ẩn.',
              style: Theme.of(context).textTheme.bodySmall),
        FilledButton.icon(
          onPressed: questions.isEmpty
              ? null
              : () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => PracticePage(
                      questions: questions,
                      profileId: widget.profileId,
                      subjectCode:
                          widget.lesson['subjectCode']?.toString() ?? '',
                      grade: widget.pack.grade,
                      lessonId: id,
                      ledger: widget.ledger,
                      lessonTitle: widget.lesson['title']?.toString() ??
                          'Luyện tập'))),
          icon: const Icon(Icons.quiz_outlined),
          label: Text(questions.isEmpty
              ? 'Chưa có câu hỏi'
              : 'Luyện tập • ${questions.length} câu'),
        ),
      ]),
    );
  }
}
