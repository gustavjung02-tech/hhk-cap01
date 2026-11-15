import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../data/account_api.dart';

/// Parent/user account and key registry. Learner profiles remain offline-only.
class AccountPage extends StatefulWidget {
  final AccountApi? api;
  final Future<void> Function()? onLicenseChanged;
  const AccountPage({super.key, this.api, this.onLicenseChanged});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  late final AccountApi api;
  final email = TextEditingController();
  final password = TextEditingController();
  final qr = TextEditingController();
  final license = TextEditingController();
  AccountSession? session;
  List<AccountKey> keys = const [];
  bool busy = false;
  String? error;
  bool createMode = false;

  @override
  void initState() {
    super.initState();
    api = widget.api ?? AccountApi();
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    qr.dispose();
    license.dispose();
    if (widget.api == null) api.close();
    super.dispose();
  }

  Future<void> run(Future<void> Function() task) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await task();
    } on AccountApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Kết nối thất bại, vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> authenticate() => run(() async {
        if (createMode) await api.register(email.text, password.text);
        final next = await api.login(email.text, password.text);
        if (!mounted) return;
        setState(() {
          session = next;
          password.clear(); // No passwords in the learner offline store.
          keys = const [];
          createMode = false;
        });
        await loadKeys();
      });

  Future<void> loadKeys() async {
    final current = session;
    if (current == null) return;
    final result = await api.keys(current);
    if (mounted && session == current) {
      setState(() => keys = result);
    }
  }

  Future<void> redeem(String raw) => run(() async {
        final current = session;
        if (current == null) return;
        final issued = await api.redeem(current, raw);
        qr.clear();
        await loadKeys();
        if (!mounted) return;
        await showDialog<void>(
            context: context,
            builder: (dialogContext) => AlertDialog(
                  title: const Text('Đã nhận key vào tài khoản'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Key chỉ được hiển thị lần này. Hãy lưu lại an toàn.'),
                      const SizedBox(height: 12),
                      SelectableText(issued.licenseKey),
                      const SizedBox(height: 8),
                      Text('Quyền lớp: ${issued.grades.join(', ')}'),
                    ],
                  ),
                  actions: [
                    TextButton.icon(
                        icon: const Icon(Icons.copy),
                        label: const Text('Sao chép key'),
                        onPressed: () async {
                          await Clipboard.setData(
                              ClipboardData(text: issued.licenseKey));
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                        }),
                    FilledButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Đã lưu')),
                  ],
                ));
      });

  Future<void> attachKey() => run(() async {
        final current = session;
        if (current == null) return;
        await api.linkKey(current, license.text);
        license.clear();
        await loadKeys();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Đã thêm key vào tài khoản.')));
        }
      });

  Future<void> scanQr() async {
    if (busy || session == null) return;
    final scanned = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const ClaimQrScanner()));
    if (scanned != null && mounted) {
      await redeem(scanned);
    }
  }

  Future<void> signOut() => run(() async {
        final old = session;
        if (old == null) return;
        try {
          await api.logout(old);
        } finally {
          // Never keep a locally privileged session after an attempted logout.
          if (mounted) {
            setState(() {
              session = null;
              keys = const [];
              qr.clear();
              license.clear();
            });
          }
        }
      });

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Tài khoản & key',
          style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      const Text('Một tài khoản quản lý các key được nhận từ QR. Hồ sơ học sinh, XP và lịch sử học vẫn lưu offline trên máy.'),
      const SizedBox(height: 12),
      if (error != null)
        Card(child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(error!, style: const TextStyle(color: Colors.red)),
        )),
      if (busy) const LinearProgressIndicator(),
      if (session == null) _loggedOut() else _loggedIn(),
      const SizedBox(height: 12),
      const Text('Tài khoản là quản lý key online. Gắn key chưa đồng nghĩa đã kích hoạt quyền học offline trên thiết bị; bước xác minh chữ ký sẽ được tích hợp riêng.',
          style: TextStyle(fontSize: 12, color: Colors.grey)),
    ]);
  }

  Widget _loggedOut() => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(createMode ? 'Tạo tài khoản' : 'Đăng nhập',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 8),
            TextField(
                controller: password,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                    labelText: 'Mật khẩu (tối thiểu 12 ký tự)')),
            const SizedBox(height: 12),
            FilledButton(
                onPressed: busy ? null : authenticate,
                child: Text(createMode ? 'Tạo tài khoản & đăng nhập' : 'Đăng nhập')),
            TextButton(
                onPressed: busy
                    ? null
                    : () => setState(() {
                          createMode = !createMode;
                          error = null;
                        }),
                child: Text(createMode
                    ? 'Đã có tài khoản? Đăng nhập'
                    : 'Chưa có tài khoản? Đăng ký')),
          ]),
        ),
      );

  Widget _loggedIn() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.account_circle_outlined),
            title: Text(session!.email),
            subtitle: const Text('Phiên đăng nhập chỉ giữ trong bộ nhớ của app.'),
            trailing: TextButton(
                onPressed: busy ? null : signOut,
                child: const Text('Đăng xuất')),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Quét QR trên lốc 20 cuốn',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              FilledButton.icon(
                  onPressed: busy ? null : scanQr,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Mở camera quét QR')),
              const SizedBox(height: 8),
              TextField(
                  controller: qr,
                  decoration: const InputDecoration(
                      labelText: 'Hoặc nhập mã QR / dán đường dẫn')),
              const SizedBox(height: 8),
              OutlinedButton(
                  onPressed: busy ? null : () => redeem(qr.text),
                  child: const Text('Đổi QR lấy key trong tài khoản')),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Đã có key từ trước?',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                  controller: license,
                  decoration: const InputDecoration(
                      labelText: 'Nhập key lic_... để liên kết')),
              const SizedBox(height: 8),
              OutlinedButton(
                  onPressed: busy ? null : attachKey,
                  child: const Text('Thêm key vào tài khoản')),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: Text('Key của tôi (${keys.length})',
              style: Theme.of(context).textTheme.titleLarge)),
          IconButton(
              onPressed: busy ? null : () => run(loadKeys),
              tooltip: 'Làm mới danh sách key',
              icon: const Icon(Icons.refresh)),
        ]),
        if (keys.isEmpty)
          const Card(child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('Chưa có key. Quét QR hoặc nhập key để thêm vào tài khoản.'),
          )),
        for (final key in keys)
          Card(child: ListTile(
            leading: const Icon(Icons.vpn_key_outlined),
            title: Text('Key ${key.id.substring(0, 8)}…'),
            subtitle: Text(
                'Lớp ${key.grades.join(', ')} • ${key.status} • Thiết bị ${key.activeDevices}/${key.maxDevices}\n'
                'Hạn: ${key.validUntil?.toLocal().toString().split(' ').first ?? 'Không giới hạn'}'),
          )),
      ]);
}

class ClaimQrScanner extends StatefulWidget {
  const ClaimQrScanner({super.key});
  @override
  State<ClaimQrScanner> createState() => _ClaimQrScannerState();
}

class _ClaimQrScannerState extends State<ClaimQrScanner> {
  bool scanned = false;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Quét QR trên lốc tập')),
        body: Column(children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Đưa QR vào khung hình. App chỉ đọc mã claim, không mở đường dẫn bên ngoài.'),
          ),
          Expanded(
            child: MobileScanner(
              onDetect: (capture) {
                if (scanned) return;
                for (final barcode in capture.barcodes) {
                  final raw = barcode.rawValue;
                  if (raw == null) continue;
                  final token = extractClaimToken(raw);
                  if (token != null) {
                    scanned = true;
                    Navigator.of(context).pop(token);
                    return;
                  }
                }
              },
            ),
          ),
        ]),
      );
}
