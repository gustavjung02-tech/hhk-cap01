import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hhk_cap01/data/account_api.dart';
import 'package:hhk_cap01/data/offline_license.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';
import 'package:hhk_cap01/features/account/account_page.dart';

class FakeVault implements LicenseVault {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key,String value) async {}
}

void main() {
  testWidgets('account screen offers login and registration, not local fake auth', (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AccountPage())));
    expect(find.text('Tài khoản & key'), findsOneWidget);
    expect(find.text('Đăng nhập'), findsWidgets);
    expect(find.text('Chưa có tài khoản? Đăng ký'), findsOneWidget);
    await tester.tap(find.text('Chưa có tài khoản? Đăng ký'));
    await tester.pump();
    expect(find.text('Tạo tài khoản & đăng nhập'), findsOneWidget);
    expect(find.text('Mở camera quét QR'), findsNothing);
    expect(find.textContaining('tối thiểu 12 ký tự'), findsOneWidget);
  });
  testWidgets('signed-in key inventory has device activation and generic QR language',
      (tester) async {
    const licenseId='12345678-1234-4123-8123-123456789abc';
    final api=AccountApi(baseUrl:'https://example.test',
      client:MockClient((req) async {
        if(req.url.path=='/api/v1/account/keys') {
          return http.Response(jsonEncode({'ok':true,'keys':[{
            'id':licenseId,'status':'issued','grades':[1,3],
            'maxDevices':1,'activeDevices':0,'validUntil':null
          }]}),200);
        }
        return http.Response(jsonEncode({'ok':false,'code':'NOT_FOUND'}),404);
      }));
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:AccountPage(
      api:api,
      licenseManager:OfflineLicenseManager(vault:FakeVault()),
      initialSession:const AccountSession('sess_fake','parent@example.test'),
    ))));
    await tester.pumpAndSettle();
    expect(find.text('Quét mã QR nhận quyền học'),findsOneWidget);
    expect(find.text('Kích hoạt'),findsOneWidget);
    expect(find.text('Gia hạn'),findsOneWidget);
    expect(find.text('Đổi thiết bị'),findsOneWidget);
    expect(find.textContaining('lốc'),findsNothing);
    api.close();
  });

  testWidgets('pasted QR and existing key share one manual entry and correct API route',
      (tester) async {
    const qrToken = 'qr_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdef';
    const licenseKey = 'lic_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdef';
    final seen = <String>[];
    final api = AccountApi(baseUrl: 'https://api.example.test',
      client: MockClient((request) async {
        seen.add(request.url.path);
        if (request.url.path.endsWith('/account/keys')) {
          return http.Response('{"ok":true,"keys":[]}', 200);
        }
        if (request.url.path.endsWith('/account/claims/redeem')) {
          expect(jsonDecode(request.body)['token'], qrToken);
          return http.Response(jsonEncode({
            'ok': true, 'licenseKey': licenseKey,
            'licenseId': 'id-1', 'grades': [1, 2]
          }), 200);
        }
        if (request.url.path.endsWith('/account/keys/link')) {
          expect(jsonDecode(request.body)['licenseKey'], licenseKey);
          return http.Response('{"ok":true,"linked":true}', 200);
        }
        return http.Response('{"ok":false,"code":"NOT_FOUND"}', 404);
      }));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AccountPage(
      api: api, licenseManager: OfflineLicenseManager(vault: FakeVault()),
      initialSession: const AccountSession('sess_test', 'parent@example.test'),
    ))));
    await tester.pumpAndSettle();
    expect(find.text('Đã có key từ trước?'), findsNothing);

    final input = find.byKey(const Key('account-access-code'));
    final submit = find.text('Nhận quyền / thêm key');
    await tester.ensureVisible(input);
    await tester.enterText(input, '  $qrToken  ');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(seen, contains('/api/v1/account/claims/redeem'));
    expect(seen, isNot(contains('/api/v1/account/keys/link')));
    expect(find.text('Đã nhận key vào tài khoản'), findsOneWidget);
    await tester.tap(find.text('Đã lưu'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(input);
    await tester.enterText(input, '  $licenseKey  ');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump(const Duration(milliseconds: 250));
    expect(seen, contains('/api/v1/account/keys/link'));
    expect(find.text('Đã thêm key vào tài khoản.'), findsOneWidget);
    expect(find.byKey(const Key('hhk-toast-message')), findsOneWidget);
    // Toast is an overlay, not an inline layout card.
    expect(find.ancestor(
      of: find.byKey(const Key('hhk-toast-message')),
      matching: find.byType(Positioned)), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(find.byKey(const Key('hhk-toast-message')), findsNothing);
    api.close();
  });

  testWidgets('invalid pasted code shows transient localized toast without API call',
      (tester) async {
    var calls = 0;
    final api = AccountApi(baseUrl:'https://api.example.test',
      client:MockClient((req) async {
        calls++;
        return http.Response('{"ok":true,"keys":[]}', 200);
      }));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AccountPage(
      api:api, licenseManager:OfflineLicenseManager(vault:FakeVault()),
      initialSession: const AccountSession('sess_test','parent@example.test'),
    ))));
    await tester.pumpAndSettle();
    final before = calls;
    final input = find.byKey(const Key('account-access-code'));
    await tester.ensureVisible(input);
    await tester.enterText(input,'INVALID-LICENSE');
    final submit = find.text('Nhận quyền / thêm key');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    expect(calls, before);
    expect(find.textContaining('Mã chưa đúng.'), findsOneWidget);
    expect(find.byKey(const Key('hhk-toast-message')), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(find.byKey(const Key('hhk-toast-message')), findsNothing);
    api.close();
  });

}
