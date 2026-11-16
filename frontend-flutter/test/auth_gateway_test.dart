import 'dart:convert';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hhk_cap01/data/account_api.dart';
import 'package:hhk_cap01/features/auth_gateway.dart';

class TestVault implements AccountSessionVault {
  AccountSession? value;
  int saves = 0;
  int clears = 0;
  TestVault([this.value]);
  @override
  Future<AccountSession?> read() async => value;
  @override
  Future<void> save(AccountSession session) async {
    value = session;
    saves++;
  }
  @override
  Future<void> clear() async {
    value = null;
    clears++;
  }
}

void main() {
  const token = 'sess_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopq';
  testWidgets('login is mandatory before app, survives a widget restart and '
      'only explicit signout clears vault', (tester) async {
    final vault = TestVault();
    final calls = <String>[];
    final api = AccountApi(baseUrl: 'https://api.example.test',
      client: MockClient((r) async {
        calls.add(r.url.path);
        if (r.url.path.endsWith('/accounts/login')) {
          final body = jsonDecode(r.body) as Map<String, dynamic>;
          if (body['email'] != 'parent@example.test' ||
              body['password'] != 'a-very-long-password') {
            return http.Response('{"ok":false,"code":"INVALID_CREDENTIALS"}', 401);
          }
          return http.Response(jsonEncode({
            'ok': true, 'sessionToken': token,
            'account': {'id': 'parent-1', 'email': 'parent@example.test'}
          }), 200);
        }
        if (r.url.path.endsWith('/account/me')) {
          expect(r.headers['authorization'], 'Bearer $token');
          return http.Response('{"ok":true,"account":{"id":"parent-1","email":"parent@example.test"}}',200);
        }
        throw StateError('Unexpected request');
      }));
    Future<void> Function()? signOut;
    Widget build() => MaterialApp(home: AuthGateway(
      api: api, vault: vault,
      buildApp: (session, logout, accountApi) {
        signOut = logout;
        return Scaffold(body: Center(child: Text('Ứng dụng: ${session.email}')));
      },
    ));
    await tester.pumpWidget(build());
    await tester.pumpAndSettle();
    expect(find.text('Chào mừng trở lại!'), findsOneWidget);
    expect(find.textContaining('Ứng dụng:'), findsNothing);
    await tester.enterText(find.byKey(const Key('auth-email')),
        'parent@example.test');
    await tester.enterText(find.byKey(const Key('auth-password')),
        'a-very-long-password');
    await tester.tap(find.text('Đăng nhập').last);
    await tester.pumpAndSettle();
    expect(find.text('Ứng dụng: parent@example.test'), findsOneWidget);
    expect(vault.saves, 1);
    expect(vault.clears, 0);
    // Rebuild a new auth gateway; it must validate the saved bearer token.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(build());
    await tester.pumpAndSettle();
    expect(find.text('Ứng dụng: parent@example.test'), findsOneWidget);
    expect(calls, contains('/api/v1/account/me'));
    await signOut!.call();
    await tester.pumpAndSettle();
    expect(vault.value, isNull);
    expect(vault.clears, 1);
    expect(find.text('Chào mừng trở lại!'), findsOneWidget);
    api.close();
  });

  testWidgets('an expired or revoked session is not an authentication bypass',
      (tester) async {
    final vault = TestVault(const AccountSession(token,'parent@example.test'));
    final api = AccountApi(baseUrl: 'https://api.example.test',
        client: MockClient((request) async =>
            http.Response('{"ok":false,"code":"UNAUTHORIZED"}',401)));
    await tester.pumpWidget(MaterialApp(home: AuthGateway(
      api:api,vault:vault,buildApp: (_, __, ___) => const Text('PRIVATE APP'),
    )));
    await tester.pumpAndSettle();
    expect(find.text('PRIVATE APP'), findsNothing);
    expect(find.text('Chào mừng trở lại!'), findsOneWidget);
    expect(vault.clears, 1);
    api.close();
  });
}
