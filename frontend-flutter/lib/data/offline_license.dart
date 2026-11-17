import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'account_api.dart';

abstract interface class LicenseVault {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class PlatformLicenseVault implements LicenseVault {
  final FlutterSecureStorage storage;
  PlatformLicenseVault({FlutterSecureStorage? storage})
      : storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> read(String key) => storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      storage.write(key: key, value: value);
}

/// Ed25519 private key never travels to the backend. Offline lease is verified
/// against a PINNED signing key, never by trusting a public key from a request.
/// Pin can be replaced at build time when shipping production signing keys.
class OfflineLicenseManager {
  static const stagingPublicKey = String.fromEnvironment(
    'HHK_LEASE_PUBLIC_KEY',
    defaultValue: 'MCowBQYDK2VwAyEAllWZapGxpQZEvOD7QS0zo_gChlgqDsqIMO0VtoKzNW4',
  );
  static const _deviceKey = 'hhk:device:ed25519:v1';
  static const _leaseIds = 'hhk:lease:ids:v1';
  static const _spkiPrefix = [0x30, 0x2a, 0x30, 0x05, 0x06, 0x03,
      0x2b, 0x65, 0x70, 0x03, 0x21, 0x00];

  final LicenseVault vault;
  final Ed25519 algorithm;
  final String signingPublicKey;
  OfflineLicenseManager({LicenseVault? vault, Ed25519? algorithm,
    this.signingPublicKey = stagingPublicKey})
      : vault = vault ?? PlatformLicenseVault(),
        algorithm = algorithm ?? Ed25519();

  Future<SimpleKeyPairData> _device() async {
    final saved = await vault.read(_deviceKey);
    if (saved != null) {
      try {
        final raw = jsonDecode(saved) as Map<String, dynamic>;
        final privateBytes = base64Url.decode(base64Url.normalize(raw['private'] as String));
        final publicBytes = base64Url.decode(base64Url.normalize(raw['public'] as String));
        if (privateBytes.length != 32 || publicBytes.length != 32) {
          throw const FormatException();
        }
        return SimpleKeyPairData(privateBytes,
            publicKey: SimplePublicKey(publicBytes, type: KeyPairType.ed25519),
            type: KeyPairType.ed25519);
      } catch (_) {
        throw const FormatException('SECURE_DEVICE_KEY_CORRUPTED');
      }
    }
    final pair = await algorithm.newKeyPair();
    final privateBytes = await pair.extractPrivateKeyBytes();
    final publicKey = await pair.extractPublicKey();
    if (privateBytes.length != 32 || publicKey.bytes.length != 32) {
      throw const FormatException('INVALID_DEVICE_KEY');
    }
    // Save before activation; failing persistence must NOT enroll a disposable
    // device key that could consume a permanent slot on the server.
    await vault.write(_deviceKey, jsonEncode({
      'private': base64UrlEncode(privateBytes),
      'public': base64UrlEncode(publicKey.bytes),
    }));
    return SimpleKeyPairData(privateBytes,
        publicKey: SimplePublicKey(publicKey.bytes, type: KeyPairType.ed25519),
        type: KeyPairType.ed25519);
  }

  Future<Map<String, dynamic>> _proof(String licenseId, String action) async {
    final pair = await _device();
    final publicKey = pair.publicKey;
    final devicePublicKey = base64UrlEncode(publicKey.bytes).replaceAll('=', '');
    final rng = Random.secure();
    final nonceBytes = List<int>.generate(18, (_) => rng.nextInt(256));
    final nonce = base64UrlEncode(nonceBytes).replaceAll('=', '');
    final signedAt = DateTime.now().millisecondsSinceEpoch;
    final message = ['HHK-DEVICE-PROOF-v1', action, licenseId, devicePublicKey,
      nonce, signedAt.toString()].join('\n');
    final signature = await algorithm.sign(utf8.encode(message), keyPair: pair);
    return {
      'licenseId':licenseId, 'devicePublicKey':devicePublicKey,
      'nonce':nonce, 'signedAt':signedAt,
      'proof':base64UrlEncode(signature.bytes).replaceAll('=', ''),
    };
  }

  Future<void> activate(AccountApi api, AccountSession session, String licenseId) async {
    final proof = await _proof(licenseId, 'account-activate');
    final lease = await api.activateKey(session, proof);
    if (!await verifyLease(lease, licenseId: licenseId)) {
      throw const FormatException('INVALID_SIGNED_LEASE');
    }
    final rawIds = await vault.read(_leaseIds);
    final ids = rawIds == null ? <String>[] :
        (jsonDecode(rawIds) as List).cast<String>().toList();
    await vault.write('hhk:lease:$licenseId', lease);
    if (!ids.contains(licenseId)) {
      ids.add(licenseId);
      await vault.write(_leaseIds, jsonEncode(ids));
    }
  }


  Future<bool> hasValidLease(String licenseId) async {
    final lease = await vault.read('hhk:lease:$licenseId');
    return lease != null && await verifyLease(lease, licenseId: licenseId);
  }

  /// New device signs its own key, account ownership validated by server.
  Future<void> transfer(AccountApi api, AccountSession session,
      String licenseId, String fromDeviceId) async {
    final proof = await _proof(licenseId, 'account-transfer');
    final lease = await api.transferKey(session, {...proof, 'fromDeviceId':fromDeviceId});
    if (!await verifyLease(lease,licenseId:licenseId)) {
      throw const FormatException('INVALID_SIGNED_LEASE');
    }
    final rawIds = await vault.read(_leaseIds);
    final ids = rawIds == null ? <String>[] :
        (jsonDecode(rawIds) as List).cast<String>().toList();
    await vault.write('hhk:lease:$licenseId',lease);
    if (!ids.contains(licenseId)) {
      ids.add(licenseId);
      await vault.write(_leaseIds,jsonEncode(ids));
    }
  }

  Future<void> refresh(AccountApi api, AccountSession session, String licenseId) async {
    final proof = await _proof(licenseId, 'account-verify');
    late final String lease;
    try {
      lease = await api.verifyKey(session, proof);
    } on AccountApiException catch(e) {
      if ({'LICENSE_EXPIRED','LICENSE_REVOKED','DEVICE_NOT_ACTIVE','DEVICE_REVOKED'}
          .contains(e.code)) {
        await vault.write('hhk:lease:$licenseId','');
      }
      rethrow;
    }
    if (!await verifyLease(lease, licenseId: licenseId)) {
      throw const FormatException('INVALID_SIGNED_LEASE');
    }
    await vault.write('hhk:lease:$licenseId', lease);
  }

  Future<bool> gradeAllowed(int grade) async {
    if (grade < 1 || grade > 5) {
      return false;
    }
    final rawIds = await vault.read(_leaseIds);
    if (rawIds == null) {
      return false;
    }
    try {
      final ids = (jsonDecode(rawIds) as List).cast<String>();
      for (final id in ids) {
        final lease = await vault.read('hhk:lease:$id');
        if (lease == null) {
          continue;
        }
        if (await verifyLease(lease, licenseId: id, grade: grade)) {
          return true;
        }
      }
    } catch (_) {
      return false;
    }
    return false;
  }

  Future<bool> verifyLease(String lease, {
    required String licenseId,
    int? grade,
    DateTime? now,
    String? pinnedPublicKey,
  }) async {
    try {
      final parts = lease.split('.');
      if (parts.length != 2) {
        return false;
      }
      final payloadEncoded = parts[0], signatureEncoded = parts[1];
      final payloadBytes = base64Url.decode(base64Url.normalize(payloadEncoded));
      final signature = base64Url.decode(base64Url.normalize(signatureEncoded));
      if (signature.length != 64) {
        return false;
      }
      final payload = jsonDecode(utf8.decode(payloadBytes)) as Map<String, dynamic>;
      if (payload['kind'] != 'hhk-offline-license-v1' ||
          payload['licenseId'] != licenseId) {
        return false;
      }
      final issuedAt = DateTime.parse(payload['issuedAt'] as String).toUtc();
      final expiresAt = DateTime.parse(payload['expiresAt'] as String).toUtc();
      final current = (now ?? DateTime.now()).toUtc();
      if (issuedAt.isAfter(current.add(const Duration(minutes: 5))) ||
          !expiresAt.isAfter(current) ||
          expiresAt.isAfter(issuedAt.add(const Duration(days: 7, minutes: 1)))) {
        return false;
      }
      final grades = (payload['grades'] as List).map((x) => (x as num).toInt()).toList();
      if (grades.isEmpty || grades.any((g) => g < 1 || g > 5) ||
          (grade != null && !grades.contains(grade))) {
        return false;
      }
      final device = await _device();
      final expected = await Sha256().hash(device.publicKey.bytes);
      final hex = expected.bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
      if (payload['deviceKeyHash'] != hex) {
        return false;
      }

      final spki = base64Url.decode(base64Url.normalize(pinnedPublicKey ?? signingPublicKey));
      if (spki.length != _spkiPrefix.length + 32) {
        return false;
      }
      for (var i = 0; i < _spkiPrefix.length; i++) {
        if (spki[i] != _spkiPrefix[i]) {
          return false;
        }
      }
      final pub = SimplePublicKey(spki.sublist(_spkiPrefix.length), type:KeyPairType.ed25519);
      return await algorithm.verify(
        ascii.encode(payloadEncoded),
        signature: Signature(signature, publicKey: pub),
      );
    } catch (_) {
      return false;
    }
  }
}
