import 'dart:convert';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../data/account_api.dart';
import 'account/account_security_page.dart';

/// Only OS-backed encrypted storage (or HTTPS Web secure storage) holds the
/// bearer token. It is never written into learner progress/IndexedDB keys.
abstract interface class AccountSessionVault {
  Future<AccountSession?> read();
  Future<void> save(AccountSession session);
  Future<void> clear();
}

class SecureAccountSessionVault implements AccountSessionVault {
  static const _key = 'hhk:account-session:v1';
  final FlutterSecureStorage storage;
  SecureAccountSessionVault({FlutterSecureStorage? storage})
      : storage = storage ?? const FlutterSecureStorage();

  @override
  Future<AccountSession?> read() async {
    final value = await storage.read(key: _key);
    if (value == null) {
      return null;
    }
    try {
      final data = jsonDecode(value) as Map<String, dynamic>;
      final token = data['token'] as String;
      final email = data['email'] as String;
      if (!RegExp(r'^sess_[A-Za-z0-9_-]{43}$').hasMatch(token) ||
          email.trim().isEmpty) {
        return null;
      }
      return AccountSession(token, email,
          emailVerified: data['emailVerified'] == true);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(AccountSession session) =>
      storage.write(key: _key,
          value: jsonEncode({'token': session.token, 'email': session.email,
              'emailVerified': session.emailVerified}));

  @override
  Future<void> clear() => storage.delete(key: _key);
}

/// A genuine server session is required to enter. Offline restarts may reuse
/// a previously authenticated session; they never manufacture new accounts.
class AuthGateway extends StatefulWidget {
  final AccountApi? api;
  final AccountSessionVault? vault;
  final Widget Function(AccountSession, Future<void> Function(), AccountApi) buildApp;

  const AuthGateway({super.key, this.api, this.vault,
    required this.buildApp});

  @override
  State<AuthGateway> createState() => _AuthGatewayState();
}

class _AuthGatewayState extends State<AuthGateway> {
  late final AccountApi api;
  late final AccountSessionVault vault;
  final email = TextEditingController();
  final password = TextEditingController();
  AccountSession? session;
  bool restoring = true;
  bool busy = false;
  bool register = false;
  bool obscure = true;
  bool recover = false;
  bool actionHandled = false;
  String? message;

  String? get _action {
    final kind=Uri.base.queryParameters['accountAction'];
    final token=Uri.base.queryParameters['token'];
    if (!{'reset','verify','email_change'}.contains(kind) ||
        token == null ||
        !RegExp(r'^act_[A-Za-z0-9_-]{43}$').hasMatch(token)) {
      return null;
    }
    return kind;
  }

  Future<void> _actionCompleted(bool reset) async {
    if(reset){
      await vault.clear();
      if (mounted) {
        setState(() {
          session=null;
          message='Đã đặt lại mật khẩu. Hãy đăng nhập bằng mật khẩu mới.';
          actionHandled=true;
        });
      }
    }else{
      final current=session;
      if(current!=null){
        try{
          final refreshed=await api.me(current);
          await vault.save(refreshed);
          if(mounted)setState(()=>session=refreshed);
        }catch(_){ /* Server still enforces email proof. */ }
      }
      if (mounted) {
        setState(() {
          message='Email đã xác minh. Có thể tiếp tục sử dụng tài khoản.';
          actionHandled=true;
        });
      }
    }
  }

  Future<void> _forgot() async {
    if(busy)return;
    setState(() {busy=true;message=null;});
    try{
      await api.forgotPassword(email.text);
      if (mounted) {
        setState(()=>message=
          'Nếu email đã được xác minh, liên kết đặt lại mật khẩu sẽ được gửi đến hộp thư.');
      }
    }on AccountApiException catch(e){
      if(mounted)setState(()=>message=e.message);
    }finally{
      if(mounted)setState(()=>busy=false);
    }
  }

  Future<void> _acceptRotated(AccountSession next) async {
    await vault.save(next);
    if(mounted)setState(()=>session=next);
  }

  @override
  void initState() {
    super.initState();
    api = widget.api ?? AccountApi();
    vault = widget.vault ?? SecureAccountSessionVault();
    api.onSessionRotated = _acceptRotated;
    _restore();
  }

  Future<void> _restore() async {
    try {
      final saved = await vault.read();
      if (saved != null) {
        try {
          final refreshed = await api.me(saved);
          if (mounted) {
            setState(() => session = refreshed);
          }
        } on AccountApiException catch (e) {
          if (e.code == 'UNAUTHORIZED') {
            await vault.clear();
          } else {
            // Preserve credentials through network outages/server maintenance.
            // This only enables offline *local* study; API retains auth checks.
            if (mounted) {
              setState(() {
                session = saved;
                message = 'Không thể kiểm tra máy chủ. Dữ liệu học offline vẫn dùng được.';
              });
            }
          }
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => message = 'Không mở được phiên đăng nhập đã lưu.');
      }
    } finally {
      if (mounted) {
        setState(() => restoring = false);
      }
    }
  }

  Future<void> _submit() async {
    if(recover){await _forgot();return;}
    if (busy) {
      return;
    }
    setState(() {
      busy = true;
      message = null;
    });
    try {
      if (register) {
        await api.register(email.text, password.text);
      }
      final next = await api.login(email.text, password.text);
      await vault.save(next); // Never enter the app before secure save succeeds.
      if (mounted) {
        setState(() {
          session = next;
          register = false;
          password.clear();
        });
      }
    } on AccountApiException catch (e) {
      if (mounted) {
        setState(() => message = e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => message =
            'Không lưu được phiên đăng nhập an toàn trên thiết bị.');
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await vault.clear();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        setState(() {
          session = null;
          message = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => message = 'Không thể xóa phiên cục bộ. Vui lòng thử lại.');
      }
    }
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    api.onSessionRotated = null;
    if (widget.api == null) {
      api.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (restoring) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final action=_action;
    if (!actionHandled && action!=null) {
      return AccountEmailActionPage(api:api,action:action,
          token:Uri.base.queryParameters['token']!,onCompleted:_actionCompleted);
    }
    if (session case final authenticated?) {
      return widget.buildApp(authenticated, _signOut, api);
    }
    return Scaffold(
      body: Stack(fit: StackFit.expand, children: [
        Image.asset('assets/brand/landing-hero.jpg', fit: BoxFit.cover),
        Positioned.fill(child: Opacity(
          opacity: 0.20,
          child: Image.asset('assets/brand/dopi-avatar.png',
              fit: BoxFit.contain, alignment: Alignment.bottomCenter),
        )),
        Container(color: const Color(0x660C443F)),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Image.asset('assets/brand/dopi-avatar.png',
                      width: 128, height: 128, fit: BoxFit.contain),
                  const SizedBox(height: 12),
                  const Text('Học Hứng Khởi',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 29,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 14),
                  Card(
                    elevation: 6,
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(recover?'Quên mật khẩu'
                            :register ? 'Tạo tài khoản' : 'Chào mừng trở lại!',
                              style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: 7),
                          Text(recover
                              ? 'Nhập email đã xác minh để nhận liên kết đặt lại mật khẩu.'
                              : 'Đăng nhập để cùng Dopi bắt đầu học nhé.'),
                          if (message != null) ...[
                            const SizedBox(height: 12),
                            Text(message!,
                                style: TextStyle(color:
                                    Theme.of(context).colorScheme.error)),
                          ],
                          const SizedBox(height: 18),
                          TextField(
                            key: const Key('auth-email'),
                            controller: email,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.alternate_email),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          if (!recover) ...[
                          const SizedBox(height: 12),
                          TextField(
                            key: const Key('auth-password'),
                            controller: password,
                            obscureText: obscure,
                            autocorrect: false,
                            enableSuggestions: false,
                            onSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              labelText: 'Mật khẩu',
                              prefixIcon: const Icon(Icons.lock_outline),
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                tooltip: obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                                onPressed: () => setState(() => obscure = !obscure),
                                icon: Icon(obscure ? Icons.visibility_outlined :
                                    Icons.visibility_off_outlined),
                              ),
                            ),
                          ),
                          ],
                          const SizedBox(height: 18),
                          FilledButton(
                            onPressed: busy ? null : _submit,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(recover?'Gửi liên kết khôi phục'
                                :register ? 'Tạo tài khoản và vào học' : 'Đăng nhập'),
                            ),
                          ),
                          if (busy) const LinearProgressIndicator(),
                          if(!recover)
                          TextButton(
                            onPressed: busy ? null : () => setState(() {
                              register = !register;
                              message = null;
                            }),
                            child: Text(register
                                ? 'Đã có tài khoản? Đăng nhập'
                                : 'Chưa có tài khoản? Đăng ký'),
                          ),
                          TextButton(
                            onPressed:busy?null:()=>setState((){
                              recover=!recover;register=false;message=null;
                            }),
                            child:Text(recover?'Quay về đăng nhập':'Quên mật khẩu?'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Bài làm và tiến độ được lưu offline trên thiết bị.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white)),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
