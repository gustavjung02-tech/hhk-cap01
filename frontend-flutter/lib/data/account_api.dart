import 'dart:convert';
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
        'UNAUTHORIZED' => 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
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
  const AccountSession(this.token, this.email);
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
          'https://hhk-cap01-license-staging-qpxfy7zmv-gustavjung02-techs-projects.vercel.app');
  final String baseUrl;
  final http.Client _client;

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

  Future<AccountSession> login(String email, String password) async {
    final result = await _call('/api/v1/accounts/login',
        body: {'email': email, 'password': password});
    final account = result['account'] as Map<String, dynamic>;
    return AccountSession(result['sessionToken'] as String,
        account['email'] as String);
  }

  Future<void> register(String email, String password) async {
    await _call('/api/v1/accounts/register',
        body: {'email': email, 'password': password});
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

  Future<void> logout(AccountSession session) async {
    await _call('/api/v1/account/logout', token: session.token, body: {});
  }

  void close() => _client.close();
}
