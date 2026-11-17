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

}
