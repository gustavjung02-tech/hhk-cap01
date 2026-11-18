import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:hhk_cap01/data/local_store.dart';
import 'package:hhk_cap01/data/offline_license.dart';
import 'package:hhk_cap01/features/study/grade_audio_download_page.dart';

class _Store implements LocalStore {
  final values = <String, String>{};
  @override Future<void> open() async {}
  @override Future<void> close() async {}
  @override Future<String?> read(String key) async => values[key];
  @override Future<void> write(String key, String value) async {
    values[key] = value;
  }
  @override Future<List<String>> keys(String prefix) async =>
      values.keys.where((key) => key.startsWith(prefix)).toList();
  @override Future<String> update(String key,
      String Function(String?) transform) async {
    final value = transform(values[key]);
    values[key] = value;
    return value;
  }
}

class _Vault implements LicenseVault {
  @override Future<String?> read(String key) async => null;
  @override Future<void> write(String key, String value) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('phone grade download is one action, no per-lesson download',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(MaterialApp(home: GradeAudioDownloadPage(
      grade: 1, storage: _Store(),
      offlineLicense: OfflineLicenseManager(vault: _Vault()),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Tải một lần, nghe cả lớp'), findsOneWidget);
    expect(find.text('Lớp 1 • 700 đoạn có thu âm'), findsOneWidget);
    expect(find.text('Đã lưu 0/700 đoạn'), findsOneWidget);
    expect(find.text('Tải toàn bộ âm thanh lớp 1'), findsOneWidget);
    expect(find.text('Tải âm thanh bài này'), findsNothing);
    await tester.tap(find.text('Tải toàn bộ âm thanh lớp 1'));
    // The license read is asynchronous; advance until its toast is shown,
    // without pumpAndSettle (which can expire the transient toast).
    for (var i = 0; i < 10 &&
        find.textContaining('Hãy kích hoạt key').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.textContaining('Hãy kích hoạt key'), findsOneWidget);
    expect(find.text('Đã lưu 0/700 đoạn'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(tester.takeException(), isNull);
  });

}
