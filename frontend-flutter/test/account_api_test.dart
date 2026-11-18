import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hhk_cap01/data/account_api.dart';

void main() {
  const qr = 'qr_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdef';
  const key = 'lic_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdef';

  test('QR parser recognizes opaque token or HTTPS URL without navigation', () {
    expect(extractClaimToken(qr), qr);
    expect(extractClaimToken('https://company.example/claim?token=$qr'), qr);
    expect(extractClaimToken('http://company.example/claim?token=$qr'), isNull);
    expect(extractClaimToken('javascript:alert(1)'), isNull);
    expect(extractClaimToken('https://company.example/?token=wrong'), isNull);
    expect(extractClaimToken('qr-short'), isNull);
  });

  test('manual key parser is distinct from claim QR tokens', () {
    expect(extractLicenseKey(key), key);
    expect(extractLicenseKey(' \n$key \t'), key);
    expect(extractLicenseKey(qr), isNull);
    expect(extractClaimToken(key), isNull);
    expect(extractLicenseKey('https://example.test/?token=$key'), isNull);
    expect(const AccountApiException('INVALID_TOKEN').message,
        contains('Mã QR'));
    expect(const AccountApiException('INVALID_LICENSE_KEY').message,
        contains('lic_'));
  });

  test('login is server authenticated, inventory is scoped to bearer token', () async {
    final calls = <String>[];
    final mock = MockClient((request) async {
      calls.add('${request.method} ${request.url.path}');
      if (request.url.path.endsWith('/accounts/login')) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['password'], 'a-secure-passphrase');
        return http.Response(jsonEncode({
          'ok': true,
          'sessionToken': 'sess_ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ',
          'account': {'id': 'id-parent', 'email': 'parent@example.test'}
        }), 200);
      }
      expect(request.headers['authorization'], 'Bearer sess_ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ');
      if (request.url.path.endsWith('/account/keys')) {
        return http.Response(jsonEncode({
          'ok': true,
          'keys': [{
            'id': '12345678-1234-1234-8234-123456789abc',
            'status': 'issued',
            'grades': [1, 3],
            'validUntil': '2026-12-10T00:00:00.000Z',
            'maxDevices': 1,
            'activeDevices': 0
          }]
        }), 200);
      }
      if (request.url.path.endsWith('/account/claims/redeem')) {
        expect(jsonDecode(request.body)['token'], qr);
        return http.Response(jsonEncode({
          'ok':true,'licenseKey':key,'licenseId':'id-1','grades':[1,3]
        }), 200);
      }
      if (request.url.path.endsWith('/account/keys/link')) {
        expect(jsonDecode(request.body)['licenseKey'], key);
        return http.Response('{"ok":true,"linked":true}', 200);
      }
      if (request.url.path.endsWith('/account/logout')) {
        return http.Response('{"ok":true,"loggedOut":true}', 200);
      }
      throw StateError('Unexpected API request');
    });
    final api = AccountApi(baseUrl:'https://api.example.test',client:mock);
    final session = await api.login('parent@example.test','a-secure-passphrase');
    expect(session.email, 'parent@example.test');
    final list = await api.keys(session);
    expect(list, hasLength(1));
    expect(list.single.grades, [1,3]);
    final issued = await api.redeem(session,qr);
    expect(issued.licenseKey,key);
    await api.linkKey(session,key);
    await api.logout(session);
    expect(calls, [
      'POST /api/v1/accounts/login',
      'GET /api/v1/account/keys',
      'POST /api/v1/account/claims/redeem',
      'POST /api/v1/account/keys/link',
      'POST /api/v1/account/logout',
    ]);
    api.close();
  });

  test('account API returns structured errors, never invents a local license', () async {
    final api=AccountApi(baseUrl:'https://api.example.test',client:MockClient((request) async {
      return http.Response('{"ok":false,"code":"INVALID_CREDENTIALS"}',401);
    }));
    await expectLater(
        api.login('none@example.test','wrong'),
        throwsA(isA<AccountApiException>()
            .having((e)=>e.code,'code','INVALID_CREDENTIALS')));
    await expectLater(
        api.redeem(const AccountSession('sess_test','x@example.test'),'not qr'),
        throwsA(isA<AccountApiException>()
            .having((e)=>e.code,'code','INVALID_TOKEN')));
    api.close();
  });

  test('password rotation and security actions use server and bearer',() async {
    final calls=<String>[];
    const original=AccountSession('sess_old','parent@example.test',emailVerified:true);
    final api=AccountApi(baseUrl:'https://api.example.test',client:MockClient((request)async{
      calls.add(request.url.path);
      if(request.url.path.contains('/account/') && 
         !request.url.path.endsWith('/account/me')){
        expect(request.headers['authorization'],'Bearer sess_old');
      }
      if(request.url.path.endsWith('/password/change')){
        expect(jsonDecode(request.body)['currentPassword'],'old-password-123');
        return http.Response('{"ok":true,"sessionToken":"sess_new"}',200);
      }
      if(request.url.path.endsWith('/account/sessions')){
        return http.Response('{"ok":true,"sessions":[{"id":"a","label":"iPhone","current":true,"createdAt":"2026-01-01T00:00:00Z","lastUsedAt":"2026-01-02T00:00:00Z"}]}',200);
      }
      return http.Response('{"ok":true,"requested":true}',200);
    }));
    final rotated=await api.changePassword(original,'old-password-123','new-password-123');
    expect(rotated.token,'sess_new');
    expect(rotated.emailVerified,true);
    final sessions=await api.sessions(original);
    expect(sessions.single.current,true);
    await api.forgotPassword('parent@example.test');
    await api.requestEmailVerification('parent@example.test');
    await api.requestEmailChange(original,'new@example.test','old-password-123');
    expect(calls,contains('/api/v1/accounts/password/forgot'));
    api.close();
  });

}
