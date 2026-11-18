import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hhk_cap01/data/account_api.dart';
import 'package:hhk_cap01/data/catalog_repository.dart';
import 'package:hhk_cap01/data/creative_port.dart';
import 'package:hhk_cap01/data/local_store.dart';
import 'package:hhk_cap01/data/offline_license.dart';
import 'package:hhk_cap01/data/study_ledger.dart';
import 'package:hhk_cap01/features/account/account_page.dart';
import 'package:hhk_cap01/features/creative_drawing_page.dart';
import 'package:hhk_cap01/features/creative_learning_pages.dart';
import 'package:hhk_cap01/widgets/compact_bottom_navigation_bar.dart';

/// CI viewport tests are simulations, not proof of physical iPhone/Android QA.
class _Store implements LocalStore {
  final values = <String, String>{};
  @override
  Future<void> open() async {}
  @override
  Future<void> close() async {}
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<List<String>> keys(String prefix) async =>
      values.keys.where((key) => key.startsWith(prefix)).toList();
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
  @override
  Future<String> update(String key, String Function(String?) transform) async {
    final next = transform(values[key]);
    values[key] = next;
    return next;
  }
}

class _LicenseVault implements LicenseVault {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
}

Future<void> _pumpPhone(WidgetTester tester, Size size, Widget content,
    {double scale = 1.0, double keyboard = 0}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  final top = size.width < 400 ? 47.0 : 59.0;
  final bottom = size.width < 600 ? 34.0 : 0.0;
  await tester.pumpWidget(MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        size: size,
        padding: EdgeInsets.only(top: top, bottom: keyboard > 0 ? 0 : bottom),
        viewPadding: EdgeInsets.only(top: top, bottom: bottom),
        viewInsets: EdgeInsets.only(bottom: keyboard),
        textScaler: TextScaler.linear(scale),
      ),
      child: content,
    ),
  ));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('iPhone SE navigation fits home indicator and readable labels',
      (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await _pumpPhone(
      tester,
      const Size(320, 568),
      Scaffold(
        body: const Center(child: Text('HHK')),
        bottomNavigationBar: CompactBottomNavigationBar(
          selectedIndex: 0, onDestinationSelected: (_) {}),
      ),
      scale: 1.1,
    );
    expect(find.text('Trang chủ'), findsOneWidget);
    expect(find.text('Luyện tập'), findsOneWidget);
    expect(find.text('Cài đặt'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('small iPhone account page can scroll to manual QR/key input',
      (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final api = AccountApi(baseUrl: 'https://qa.invalid',
        client: MockClient((_) async =>
            http.Response(jsonEncode({'ok': true, 'keys': []}), 200)));
    await _pumpPhone(
      tester,
      const Size(320, 568),
      Scaffold(
        body: AccountPage(
          api: api,
          initialSession: const AccountSession('sess_fake', 'parent@example.test'),
          licenseManager: OfflineLicenseManager(vault: _LicenseVault()),
        ),
      ),
      scale: 1.25,
    );
    final manual = find.byKey(const Key('account-access-code'));
    await tester.ensureVisible(manual);
    await tester.pumpAndSettle();
    expect(manual, findsOneWidget);
    expect(find.text('Nhận quyền / thêm key'), findsOneWidget);
    expect(tester.takeException(), isNull);
    api.close();
  });

  testWidgets('drawing survives restart on compact Android screen',
      (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final store = _Store();
    await _pumpPhone(tester, const Size(360, 740),
      CreativeDrawingPage(store: store, profileId: 'child-1', grade: 3),
      scale: 1.2);
    expect(find.text('Vẽ & tô màu'), findsOneWidget);
    final canvas = find.byType(AspectRatio).first;
    await tester.ensureVisible(canvas);
    await tester.pumpAndSettle();
    // Horizontal stroke must be consumed by the canvas rather than the list.
    await tester.dragFrom(tester.getCenter(canvas), const Offset(70, 2));
    await tester.pumpAndSettle();
    // On a phone the important case is a vertical stroke, which must not be
    // swallowed by the vertically scrolling controls around the drawing.
    await tester.dragFrom(tester.getCenter(canvas), const Offset(2, 70));
    await tester.pumpAndSettle();
    final saved = await ArtStore(store).load('child-1', 3);
    expect(saved.strokes.length, 2);
    expect(tester.takeException(), isNull);
    // Rebuilding the page simulates returning after closing it.
    await _pumpPhone(tester, const Size(360, 740),
      CreativeDrawingPage(store: store, profileId: 'child-1', grade: 3));
    expect(find.byType(AspectRatio), findsOneWidget);
  });

  testWidgets('memory room cards and feedback fit narrow mobile viewport',
      (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final pack = GradePack(2, const [], [
      {'id': 7, 'title': 'Phép cộng', 'isActive': 1}
    ], const [], [
      {'id': 1, 'lessonId': 7, 'questionText': '2 + 2 = ?',
        'questionType': 'single_choice',
        'optionsJson': '["3","4","5"]',
        'correctAnswer': '4', 'isActive': 1}
    ]);
    await _pumpPhone(tester, const Size(320, 568),
      MemoryRoomPage(pack: pack, store: _Store(), profileId: 'child-1'),
      scale: 1.25);
    expect(find.text('Xem đáp án'), findsOneWidget);
    await tester.tap(find.text('Xem đáp án'));
    await tester.pumpAndSettle();
    expect(find.text('4'), findsOneWidget);
    expect(find.text('Dễ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mind map and avatar inventory stay usable at 320dp',
      (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final pack = GradePack(2, const [], [
      {'id': 7, 'title': 'Cây và lá',
        'summarySimple': 'Cây cần nước', 'isActive': 1}
    ], [
      {'lessonId': 7, 'title': 'Lá',
        'content': 'Lá cây giúp quang hợp'}
    ], const []);
    await _pumpPhone(tester, const Size(320, 568),
      MindMapPage(pack: pack), scale: 1.3);
    expect(find.text('Cây và lá'), findsOneWidget);
    await tester.ensureVisible(find.text('Lá'));
    await tester.tap(find.text('Lá'));
    await tester.pumpAndSettle();
    expect(find.text('Lá cây giúp quang hợp'), findsOneWidget);
    expect(tester.takeException(), isNull);

  });

  testWidgets('avatar inventory fits compact iPhone when opened as a route',
      (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final store = _Store();
    final ledger = StudyLedger(store);
    await ledger.initialize();
    // Avatar XP queries require a real locally persisted learner profile.
    final profile = await ledger.createProfile('Bé An', 2);
    await _pumpPhone(tester, const Size(320, 568),
      AvatarShopPage(
        store: store, ledger: ledger,
        profile: profile,
      ), scale: 1.25);
    expect(find.text('Bé An'), findsOneWidget);
    expect(find.text('Mèo con'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
