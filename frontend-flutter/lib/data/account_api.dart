import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// This is a *server* account. Nothing here changes the offline student ledger.
class AccountApiException implements Exception {
  final String code;
  const AccountApiException(this.code);

  String get message => switch (code) {
        'ACCOUNT_EXISTS' => 'Email này đã có tài khoản.',
        'INVALID_CREDENTIALS' => 'Email hoặc mật khẩu không đúng.',
        'ACCOUNT_LOCKED' => 'Tài khoản tạm khóa 15 phút vì thử sai quá nhiều.',
        'WEAK_PASSWORD' => 'Mật khẩu cần ít nhất 12 ký tự.',
        'INVALID_EMAIL' => 'Email chưa đúng định dạng.',
        'TOKEN_ALREADY_USED' => 'Mã QR đã được sử dụng.',
        'TOKEN_NOT_FOUND' => 'Không tìm thấy mã QR này.',
        'KEY_ALREADY_LINKED' => 'Key này đã gắn với tài khoản khác.',
        'LICENSE_NOT_FOUND' => 'Không tìm thấy key.',
        'UNAUTHORIZED' => 'Phiên bị thu hồi. Vui lòng đăng nhập lại.',
        'INVALID_ACTION_TOKEN' => 'Liên kết không hợp lệ, đã hết hạn hoặc đã được dùng.',
        'PASSWORD_UNCHANGED' => 'Mật khẩu mới phải khác mật khẩu hiện tại.',
        'CURRENT_SESSION' => 'Không thể thu hồi máy hiện tại ở đây.',
        'SESSION_NOT_FOUND' => 'Phiên thiết bị không còn hoạt động.',
        'RATE_LIMITED' => 'Đã gửi quá nhiều yêu cầu. Vui lòng thử lại sau.',
        'EMAIL_NOT_CONFIGURED' => 'Email xác minh chưa được cấu hình trên máy chủ.',
        'EMAIL_DELIVERY_FAILED' => 'Không gửi được email. Vui lòng thử lại sau.',
        'EMAIL_UNCHANGED' => 'Email mới phải khác email hiện tại.',
        'SESSION_STORAGE_UNAVAILABLE' => 'Không cập nhật được phiên an toàn. Vui lòng đăng nhập lại.',
        'NETWORK_UNAVAILABLE' => 'Không thể kết nối máy chủ. Vui lòng thử lại.',
        'NOT_CONFIGURED' || 'SERVICE_UNAVAILABLE' =>
          'Máy chủ đang chuẩn bị, vui lòng thử lại sau.',
        _ => 'Không thể hoàn tất yêu cầu ($code).',
      };

  @override
  String toString() => message;
}

class AccountKey {
  final String id;
  final String status;
  final List<int> grades;
  final int maxDevices;
  final int activeDevices;
  final DateTime? validUntil;

  const AccountKey({
    required this.id,
    required this.status,
    required this.grades,
    required this.maxDevices,
    required this.activeDevices,
    required this.validUntil,
  });

  factory AccountKey.fromJson(Map<String, dynamic> raw) => AccountKey(
        id: raw['id'] as String,
        status: raw['status'] as String,
        grades: (raw['grades'] as List).map((n) => (n as num).toInt()).toList(),
        maxDevices: (raw['maxDevices'] as num).toInt(),
        activeDevices: (raw['activeDevices'] as num).toInt(),
        validUntil: raw['validUntil'] == null
            ? null
            : DateTime.parse(raw['validUntil'] as String),
      );
}

class AccountSession {
  final String token;
  final String email;
  final bool emailVerified;
  const AccountSession(this.token, this.email, {this.emailVerified = false});
}

class AccountDeviceSession {
  final String id;
  final String label;
  final bool current;
  final DateTime createdAt;
  final DateTime lastUsedAt;
  const AccountDeviceSession({
    required this.id, required this.label, required this.current,
    required this.createdAt, required this.lastUsedAt,
  });
  factory AccountDeviceSession.fromJson(Map<String, dynamic> row) =>
      AccountDeviceSession(
        id: row['id'] as String, label: row['label'] as String,
        current: row['current'] == true,
        createdAt: DateTime.parse(row['createdAt'] as String),
        lastUsedAt: DateTime.parse(row['lastUsedAt'] as String),
      );
}

class RedeemedLicense {
  final String licenseKey;
  final String licenseId;
  final List<int> grades;
  const RedeemedLicense(this.licenseKey, this.licenseId, this.grades);
}

/// Accept only an opaque QR token or a URL carrying the 'token' parameter.
/// Never navigate to the QR's URL: it could point to an attacker-controlled site.
String? extractClaimToken(String value) {
  final trimmed = value.trim();
  final token = RegExp(r'^qr_[A-Za-z0-9_-]{32}$');
  if (token.hasMatch(trimmed)) return trimmed;
  final uri = Uri.tryParse(trimmed);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
  final extracted = uri.queryParameters['token'];
  return extracted != null && token.hasMatch(extracted) ? extracted : null;
}

class AccountApi {
  // Override for production release; this staging URL is not a production API.
  static const defaultBase = String.fromEnvironment('HHK_API_BASE_URL',
      defaultValue:
          'https://hhk-cap01-license-staging-gustavjung02-techs-projects.vercel.app');
  final String baseUrl;
  final http.Client _client;
  /// Installed by AuthGateway: rotated credentials must be securely persisted
  /// before the change-password UI reports success.
  Future<void> Function(AccountSession)? onSessionRotated;

  Future<void> acceptRotatedSession(AccountSession next) async {
    final save = onSessionRotated;
    if (save == null) {
      throw const AccountApiException('SESSION_STORAGE_UNAVAILABLE');
    }
    await save(next);
  }

  AccountApi({String baseUrl = defaultBase, http.Client? client})
      : baseUrl = baseUrl.replaceAll(RegExp(r'/$'), ''),
        _client = client ?? http.Client();

  Future<Map<String, dynamic>> _call(
      String path, {
        String? token,
        Map<String, dynamic>? body,
      }) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final headers = <String, String>{
        'Accept': 'application/json',
        if (body != null) 'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
      final response = (body == null
              ? _client.get(uri, headers: headers)
              : _client.post(uri, headers: headers, body: jsonEncode(body)))
          .timeout(const Duration(seconds: 15));
      final result = await response;
      final parsed = jsonDecode(result.body);
      if (parsed is! Map<String, dynamic>) {
        throw const AccountApiException('INVALID_RESPONSE');
      }
      if (result.statusCode < 200 || result.statusCode >= 300 ||
          parsed['ok'] != true) {
        throw AccountApiException(
            (parsed['code'] as String?) ?? 'SERVICE_UNAVAILABLE');
      }
      return parsed;
    } on AccountApiException {
      rethrow;
    } catch (_) {
      throw const AccountApiException('NETWORK_UNAVAILABLE');
    }
  }

  String get deviceLabel {
    if (kIsWeb) return 'Trình duyệt web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'iPhone / iPad',
      TargetPlatform.android => 'Thiết bị Android',
      TargetPlatform.macOS => 'Máy Mac',
      TargetPlatform.windows => 'Máy Windows',
      TargetPlatform.linux => 'Máy Linux',
      _ => 'Thiết bị HHK',
    };
  }

  Future<AccountSession> login(String email, String password) async {
    final result = await _call('/api/v1/accounts/login',
        body: {'email': email, 'password': password, 'deviceLabel': deviceLabel});
    final account = result['account'] as Map<String, dynamic>;
    return AccountSession(result['sessionToken'] as String,
        account['email'] as String,
        emailVerified: account['emailVerified'] == true);
  }

  Future<void> register(String email, String password) async {
    await _call('/api/v1/accounts/register',
        body: {'email': email, 'password': password});
  }

  Future<AccountSession> me(AccountSession session) async {
    final result = await _call('/api/v1/account/me', token: session.token);
    final account = result['account'] as Map<String, dynamic>;
    return AccountSession(session.token, account['email'] as String,
        emailVerified: account['emailVerified'] == true);
  }

  Future<void> requestEmailVerification(String email) async {
    await _call('/api/v1/accounts/email/verification/request',body: {'email':email});
  }

  Future<void> verifyEmail(String token) async {
    await _call('/api/v1/accounts/email/verify',body: {'token': token});
  }

  Future<void> forgotPassword(String email) async {
    await _call('/api/v1/accounts/password/forgot',body: {'email': email});
  }

  Future<void> resetPassword(String token, String newPassword) async {
    await _call('/api/v1/accounts/password/reset',
      body: {'token': token, 'newPassword': newPassword});
  }

  Future<AccountSession> changePassword(AccountSession current,
      String currentPassword, String newPassword) async {
    final result=await _call('/api/v1/account/password/change',
      token:current.token,body: {
        'currentPassword':currentPassword,'newPassword':newPassword
      });
    return AccountSession(result['sessionToken'] as String,current.email,
        emailVerified:current.emailVerified);
  }

  Future<List<AccountDeviceSession>> sessions(AccountSession session) async {
    final result=await _call('/api/v1/account/sessions',token:session.token);
    return (result['sessions'] as List)
      .map((x)=>AccountDeviceSession.fromJson(Map<String,dynamic>.from(x as Map)))
      .toList();
  }

  Future<void> revokeSession(AccountSession session,String id) async {
    await _call('/api/v1/account/sessions/revoke',
        token:session.token,body:{'sessionId':id});
  }

  Future<void> logoutAll(AccountSession session) async {
    await _call('/api/v1/account/logout-all',token:session.token,body:{});
  }

  Future<void> requestEmailChange(AccountSession session,
      String newEmail,String currentPassword) async {
    await _call('/api/v1/account/email/change/request',token:session.token,
        body:{'newEmail':newEmail,'currentPassword':currentPassword});
  }

  Future<void> confirmEmailChange(String token) async {
    await _call('/api/v1/accounts/email/change/confirm',body:{'token':token});
  }

  Future<List<AccountKey>> keys(AccountSession session) async {
    final result = await _call('/api/v1/account/keys', token: session.token);
    return (result['keys'] as List)
        .map((raw) => AccountKey.fromJson(Map<String, dynamic>.from(raw as Map)))
        .toList();
  }

  Future<RedeemedLicense> redeem(AccountSession session, String rawQr) async {
    final token = extractClaimToken(rawQr);
    if (token == null) throw const AccountApiException('INVALID_TOKEN');
    final result = await _call('/api/v1/account/claims/redeem',
        token: session.token, body: {'token': token});
    return RedeemedLicense(
        result['licenseKey'] as String,
        result['licenseId'] as String,
        (result['grades'] as List).map((n) => (n as num).toInt()).toList());
  }

  Future<void> linkKey(AccountSession session, String rawKey) async {
    final key = rawKey.trim();
    if (!RegExp(r'^lic_[A-Za-z0-9_-]{32}$').hasMatch(key)) {
      throw const AccountApiException('INVALID_LICENSE_KEY');
    }
    await _call('/api/v1/account/keys/link',
        token: session.token, body: {'licenseKey': key});
  }

  Future<String> activateKey(AccountSession session, Map<String, dynamic> proof) async {
    final result = await _call('/api/v1/account/keys/activate',
        token: session.token, body: proof);
    return result['lease'] as String;
  }

  Future<String> verifyKey(AccountSession session, Map<String, dynamic> proof) async {
    final result = await _call('/api/v1/account/keys/verify',
        token: session.token, body: proof);
    return result['lease'] as String;
  }

  Future<void> logout(AccountSession session) async {
    await _call('/api/v1/account/logout', token: session.token, body: {});
  }

  void close() => _client.close();
}
