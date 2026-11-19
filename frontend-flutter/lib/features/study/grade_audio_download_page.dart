import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../data/local_store.dart';
import '../../data/offline_audio.dart';
import '../../data/offline_license.dart';
import '../account/hhk_toast.dart';

/// Whole-grade offline download: already stored MP3s survive interruptions.
class GradeAudioDownloadPage extends StatefulWidget {
  final int grade;
  final LocalStore storage;
  final OfflineLicenseManager offlineLicense;

  const GradeAudioDownloadPage({
    super.key,
    required this.grade,
    required this.storage,
    required this.offlineLicense,
  });

  @override
  State<GradeAudioDownloadPage> createState() =>
      _GradeAudioDownloadPageState();
}

class _GradeAudioDownloadPageState extends State<GradeAudioDownloadPage> {
  OfflineAudioStore? _store;
  AudioGradeIndex? _index;
  Future<int>? _activeDownload;
  String? _loadError;
  int _cached = 0;
  int _receivedBytes = 0;
  bool _loading = true;
  bool _downloading = false;
  bool _cancel = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final catalog = await OfflineAudioCatalog.load();
      final index = catalog.grades[widget.grade];
      if (index == null) {
        throw const AudioNotReady('Chưa có âm thanh cho lớp này.');
      }
      final store = OfflineAudioStore(widget.storage, catalog);
      final count = await store.downloadedCount(
          widget.grade, catalog.gradeCardIds(widget.grade));
      if (!mounted) {
        store.dispose();
        return;
      }
      setState(() {
        _index = index;
        _store = store;
        _cached = count;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadError = 'Không đọc được bộ âm thanh của lớp.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _download() async {
    if (_downloading || _store == null || _index == null) return;
    bool allowed = false;
    try {
      allowed = await widget.offlineLicense.gradeAllowed(widget.grade);
    } catch (_) {
      // Never start a download without a verifiable signed grade lease.
    }
    if (!mounted) return;
    if (!allowed) {
      HhkToast.show(context,
          'Hãy kích hoạt key của lớp này trước khi tải âm thanh.',
          kind: HhkToastKind.error);
      return;
    }
    setState(() {
      _cancel = false;
      _receivedBytes = 0;
      _downloading = true;
    });
    final service = _store!;
    final running = service.downloadGrade(widget.grade,
        isCancelled: () => _cancel || !mounted,
        onBytes: (received, total) {
          if (mounted) setState(() => _receivedBytes = received);
        },
        onProgress: (saved, total) {
          if (mounted) setState(() => _cached = saved);
        });
    _activeDownload = running;
    try {
      final saved = await running;
      if (!mounted) return;
      setState(() => _cached = saved);
      HhkToast.show(context,
          saved == _index!.assetCount
              ? 'Đã tải đủ âm thanh lớp ${widget.grade}. Có thể nghe offline.'
              : 'Đã dừng. Lần sau chỉ tải tiếp các đoạn chưa có.',
          kind: HhkToastKind.success);
    } on AudioNotReady catch (e) {
      if (mounted) {
        HhkToast.show(context, e.message, kind: HhkToastKind.error);
      }
    } catch (_) {
      if (mounted) {
        HhkToast.show(context,
            'Tải bị gián đoạn. Bấm tải tiếp để hoàn thành.',
            kind: HhkToastKind.error);
      }
    } finally {
      if (identical(_activeDownload, running)) _activeDownload = null;
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  void dispose() {
    _cancel = true;
    final running = _activeDownload;
    final service = _store;
    if (running != null) {
      // Finish in-flight requests before closing this page's HTTP client.
      unawaited(running.then<void>((_) => service?.dispose(),
          onError: (Object _) => service?.dispose()));
    } else {
      service?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = _index?.assetCount ?? 0;
    final completed = total > 0 && _cached == total;
    final percent = total == 0 ? 0.0 : _cached / total;
    final size = _index == null ? '' :
        (_index!.archiveBytes / (1024 * 1024)).toStringAsFixed(1);

    return Scaffold(
      appBar: AppBar(title: Text('Âm thanh offline lớp ${widget.grade}')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Tải một lần, nghe cả lớp',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 10),
          const Text('Tải một tệp ZIP cho cả lớp rồi lưu các bản thu trên máy. '
              'Không cần tải riêng từng bài học.'),
          const SizedBox(height: 22),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_loadError != null)
            Text(_loadError!, style: TextStyle(
                color: Theme.of(context).colorScheme.error))
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Lớp ${widget.grade} • $total đoạn có thu âm',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    Text(_downloading && _receivedBytes < _index!.archiveBytes
                        ? 'Đang tải gói ZIP: ${(_receivedBytes / (1024 * 1024)).toStringAsFixed(1)} / $size MB'
                        : 'Đã lưu $_cached/$total đoạn',
                        key: const Key('grade-audio-progress')),
                    if (_downloading && _receivedBytes >= _index!.archiveBytes)
                      const Text('Đã nhận gói ZIP. Đang lưu các bản thu...'),
                    const SizedBox(height: 9),
                    LinearProgressIndicator(
                      value: _downloading && _receivedBytes < _index!.archiveBytes
                          ? _receivedBytes / _index!.archiveBytes : percent,
                      minHeight: 7,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    const SizedBox(height: 8),
                    Text(completed
                        ? 'Đã sẵn sàng nghe không cần mạng.'
                        : 'Dữ liệu tải qua mạng khoảng $size MB. '
                          'Dung lượng lưu trên máy có thể lớn hơn.'),
                    const SizedBox(height: 16),
                    if (_downloading)
                      OutlinedButton.icon(
                        onPressed: () => setState(() => _cancel = true),
                        icon: const Icon(Icons.stop_circle_outlined),
                        label: Text(_cancel ? 'Đang dừng...' : 'Dừng tải'),
                      )
                    else
                      FilledButton.icon(
                        key: const Key('download-all-grade-audio'),
                        onPressed: completed ? null : _download,
                        icon: Icon(completed ? Icons.check_circle_outline :
                            Icons.download_for_offline_outlined),
                        label: Text(completed ? 'Đã tải đủ âm thanh lớp này'
                            : _cached > 0
                                ? 'Tải tiếp phần còn thiếu'
                                : 'Tải toàn bộ âm thanh lớp ${widget.grade}'),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 14),
          const Text('Một số thẻ mới chưa có bản thu âm. '
              'Các file đã lưu không bị xóa nếu dừng tải hoặc mất mạng.'),
        ],
      ),
    );
  }
}
