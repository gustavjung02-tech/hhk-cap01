import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hhk_cap01/data/account_api.dart';
import 'package:hhk_cap01/data/offline_license.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class MemoryLicenseVault implements LicenseVault {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {values[key] = value;}
}

void main() {
  test('signed account activation uses real device signature and survives offline reload', () async {
    const licenseId = '12345678-1234-4123-8123-123456789abc';
    final algorithm = Ed25519();
    final serverKey = await algorithm.newKeyPair();
    final serverPublic = await serverKey.extractPublicKey();
    final spki = <int>[
      0x30, 0x2a, 0x30, 0x05, 0x06, 0x03, 0x2b, 0x65, 0x70, 0x03, 0x21, 0x00,
      ...serverPublic.bytes
    ];
    final pin = base64UrlEncode(spki).replaceAll('=', '');
    final vault = MemoryLicenseVault();
    final offline = OfflineLicenseManager(vault:vault, signingPublicKey:pin);
    final api = AccountApi(baseUrl:'https://api.example.test',
        client:MockClient((request) async {
      expect(request.url.path,'/api/v1/account/keys/activate');
      expect(request.headers['authorization'],'Bearer test-session');
      final p = jsonDecode(request.body) as Map<String, dynamic>;
      expect(p['licenseId'],licenseId);
      final devicePublic = base64Url.decode(base64Url.normalize(p['devicePublicKey'] as String));
      final deviceSignature = base64Url.decode(base64Url.normalize(p['proof'] as String));
      final deviceKey = SimplePublicKey(devicePublic,type:KeyPairType.ed25519);
      final signedMessage = ['HHK-DEVICE-PROOF-v1','account-activate', licenseId,
        p['devicePublicKey'],p['nonce'], (p['signedAt'] as num).toInt().toString()].join('\n');
      expect(await algorithm.verify(
        utf8.encode(signedMessage),
        signature:Signature(deviceSignature,publicKey:deviceKey),
      ), isTrue);
      final hash = await Sha256().hash(devicePublic);
      final issued = DateTime.now().toUtc();
      final expires = issued.add(const Duration(hours:24));
      final payload = {
        'kind':'hhk-offline-license-v1',
        'licenseId':licenseId,
        'deviceKeyHash':hash.bytes.map((b)=>b.toRadixString(16).padLeft(2,'0')).join(),
        'grades':[1,3],
        'issuedAt':issued.toIso8601String(),
        'expiresAt':expires.toIso8601String(),
      };
      final encoded = base64UrlEncode(utf8.encode(jsonEncode(payload))).replaceAll('=', '');
      final signature = await algorithm.sign(ascii.encode(encoded),keyPair:serverKey);
      final lease = '$encoded.${base64UrlEncode(signature.bytes).replaceAll('=', '')}';
      return http.Response(jsonEncode({'ok':true,'lease':lease}),200);
    }));
    const session = AccountSession('test-session','parent@example.test');
    await offline.activate(api,session,licenseId);
    expect(await offline.gradeAllowed(1),isTrue);
    expect(await offline.hasValidLease(licenseId),isTrue);
    expect(await offline.gradeAllowed(3),isTrue);
    expect(await offline.gradeAllowed(4),isFalse);
    final recovered = OfflineLicenseManager(vault:vault,signingPublicKey:pin);
    expect(await recovered.gradeAllowed(3),isTrue,
      reason:'Signing key and lease must persist independent of the Flutter widget tree');
    final signedLease = vault.values['hhk:lease:$licenseId']!;
    expect(await recovered.verifyLease(signedLease,licenseId:licenseId,grade:3),isTrue);
    expect(await recovered.verifyLease(signedLease,licenseId:licenseId,grade:4),isFalse);
    final components = signedLease.split('.');
    final altered = '${components[0]}.${base64UrlEncode(List.filled(64, 3)).replaceAll('=', '')}';
    expect(await recovered.verifyLease(altered,licenseId:licenseId,grade:3),isFalse);
    expect(await recovered.verifyLease(signedLease,licenseId:licenseId,
      now:DateTime.now().toUtc().add(const Duration(days:3))),isFalse);
    final otherVault = MemoryLicenseVault();
    final otherDevice = OfflineLicenseManager(vault:otherVault,signingPublicKey:pin);
    expect(await otherDevice.hasValidLease(licenseId),isFalse);
    expect(await otherDevice.verifyLease(signedLease,licenseId:licenseId),isFalse,
      reason:'A valid signature for another device must be rejected');
    api.close();
  });
}
