import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../data/account_api.dart';
import '../../data/offline_license.dart';
import 'account_security_page.dart';

/// Parent/user account and key registry. Learner profiles remain offline-only.
class AccountPage extends StatefulWidget {
  final AccountApi? api;
  final OfflineLicenseManager? licenseManager;
  final AccountSession? initialSession;
  final Future<void> Function()? onSignedOut;
  final Future<void> Function()? onLicenseChanged;
  const AccountPage({super.key, this.api, this.licenseManager, this.initialSession,
      this.onSignedOut, this.onLicenseChanged});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  late final AccountApi api;
  late final OfflineLicenseManager licenseManager;
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
    licenseManager = widget.licenseManager ?? OfflineLicenseManager();
    session = widget.initialSession;
    if (session != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => run(loadKeys));
    }
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


  Future<void> activateKey(AccountKey key) => run(() async {
    final current = session;
    if (current == null) return;
    await licenseManager.activate(api,current,key.id);
    await loadKeys();
    await widget.onLicenseChanged?.call();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('Đã kích hoạt quyền học offline trên thiết bị.')));
    }
  });

  Future<void> renewKey(AccountKey key) => run(() async {
    final current = session;
    if (current == null) return;
    try {
      await licenseManager.refresh(api,current,key.id);
    } finally {
      await widget.onLicenseChanged?.call();
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('Đã gia hạn quyền học offline.')));
    }
  });

  Future<void> transferKey(AccountKey key, String fromDeviceId) => run(() async {
    final current = session;
    if (current == null) return;
    await licenseManager.transfer(api,current,key.id,fromDeviceId);
    await loadKeys();
    await widget.onLicenseChanged?.call();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('Đã chuyển quyền sang thiết bị hiện tại.')));
    }
  });

  Future<void> openKeyDevices(AccountKey key) async {
    final current = session;
    if (current == null || busy) return;
    try {
      final devices = await api.devicesForKey(current,key.id);
      if (!mounted) return;
      final sourceId = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => SafeArea(
          child: Padding(padding: const EdgeInsets.all(16),
            child: ListView(shrinkWrap:true, children:[
              Text('Thiết bị của key',style:Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height:10),
              const Text('Để chuyển quyền sang máy đang dùng, chọn thiết bị cũ cần thay thế. Việc chuyển cần có kết nối mạng.'),
              const SizedBox(height:12),
              if (devices.isEmpty) const ListTile(
                title:Text('Chưa có thiết bị nào được kích hoạt.')),
              for (final device in devices)
                ListTile(
                  leading: Icon(device.active ? Icons.smartphone : Icons.phonelink_erase),
                  title: Text('Thiết bị ${device.fingerprint}'),
                  subtitle: Text(device.active ? 'Đang hoạt động' : 'Đã thu hồi'),
                  trailing: device.active
                    ? const Icon(Icons.swap_horiz) : null,
                  onTap: device.active
                    ? () => Navigator.pop(sheetContext,device.id) : null,
                ),
            ])),
        ),
      );
      if (sourceId != null && mounted) await transferKey(key,sourceId);
    } on AccountApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    }
  }

  Future<void> scanQr() async {
    if (busy || session == null) return;
    final scanned = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const ClaimQrScanner()));
    if (scanned != null && mounted) {
      await redeem(scanned);
    }
  }

  Future<void> changePassword() async {
    final current=session;
    if (current==null || busy)return;
    final rotated=await Navigator.of(context).push<AccountSession>(
      MaterialPageRoute(builder:(_)=>ChangePasswordPage(api:api,session:current)));
    if (rotated != null && mounted) {
      setState(() => session = rotated);
    }
  }

  Future<void> openSessions() async {
    final current=session;
    if(current==null || busy)return;
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder:(_)=>AccountSessionsPage(api:api,session:current,
        onSignedOut:widget.onSignedOut)));
  }

  Future<void> requestVerification() => run(() async {
    if(session==null)return;
    await api.requestEmailVerification(session!.email);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:Text('Nếu email chưa xác minh, một liên kết xác nhận sẽ được gửi.')));
    }
  });

  Future<void> signOut() => run(() async {
        final old = session;
        if (old == null) return;
        // Only clear the secure bearer credential after the server confirmed
        // revocation. An offline logout must not leave an active remote token.
        await api.logout(old);
        await widget.onSignedOut?.call();
        if (mounted) {
          setState(() {
            session = null;
            keys = const [];
            qr.clear();
            license.clear();
          });
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
      const Text('Tài khoản quản lý key online. Kích hoạt hoặc gia hạn để nhận quyền học offline có chữ ký bảo mật trên thiết bị này.',
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
            subtitle: Text(session!.emailVerified
              ? 'Email đã xác minh • Phiên được lưu an toàn trên thiết bị'
              : 'Email chưa xác minh • Phiên được lưu an toàn trên thiết bị'),
            trailing: TextButton(
                onPressed: busy ? null : signOut,
                child: const Text('Đăng xuất')),
          ),
        ),
        const SizedBox(height: 8),
        Card(child:Column(children:[
          ListTile(leading:const Icon(Icons.lock_outline),
            title:const Text('Đổi mật khẩu'),trailing:const Icon(Icons.chevron_right),
            onTap:busy?null:changePassword),
          ListTile(leading:const Icon(Icons.devices_outlined),
            title:const Text('Thiết bị đăng nhập'),trailing:const Icon(Icons.chevron_right),
            onTap:busy?null:openSessions),
          ListTile(leading:const Icon(Icons.alternate_email),
            title:const Text('Đổi email'),trailing:const Icon(Icons.chevron_right),
            onTap:busy||session==null?null:()=>Navigator.of(context).push(
              MaterialPageRoute<void>(builder:(_)=>EmailChangePage(api:api,session:session!)))),
          if(!session!.emailVerified)
            ListTile(leading:const Icon(Icons.mark_email_unread_outlined),
              title:const Text('Gửi email xác minh'),
              subtitle:const Text('Cần xác minh email để khôi phục mật khẩu'),
              onTap:busy?null:requestVerification),
        ])),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Quét mã QR nhận quyền học',
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
          Card(child: Padding(padding:const EdgeInsets.fromLTRB(8,8,8,12),
            child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
              ListTile(
                leading:const Icon(Icons.vpn_key_outlined),
                title:Text('Key ${key.id.substring(0, 8)}…'),
                subtitle:Text(
                  'Lớp ${key.grades.join(', ')} • ${key.status} • Thiết bị ${key.activeDevices}/${key.maxDevices}\n'
                  'Hạn: ${key.validUntil?.toLocal().toString().split(' ').first ?? 'Không giới hạn'}'),
              ),
              FutureBuilder<bool>(
                future:licenseManager.hasValidLease(key.id),
                builder:(context,snapshot)=>Padding(
                  padding:const EdgeInsets.symmetric(horizontal:14),
                  child:Row(children:[
                    Icon(snapshot.data == true
                      ? Icons.verified_user : Icons.offline_bolt_outlined,
                      size:17,color:snapshot.data == true ? Colors.green : Colors.grey),
                    const SizedBox(width:6),
                    Expanded(child:Text(snapshot.data == true
                      ? 'Đã có quyền offline hợp lệ trên máy này'
                      : 'Chưa có quyền offline hợp lệ trên máy này',
                      style:const TextStyle(fontSize:12))),
                  ]))),
              const SizedBox(height:6),
              Padding(padding:const EdgeInsets.symmetric(horizontal:8),
                child:Wrap(spacing:8,runSpacing:6,children:[
                  FilledButton.icon(
                    onPressed:busy || key.status == 'revoked' || key.status == 'expired'
                      ? null : ()=>activateKey(key),
                    icon:const Icon(Icons.verified_user_outlined,size:17),
                    label:const Text('Kích hoạt')),
                  OutlinedButton.icon(
                    onPressed:busy || key.status == 'revoked' || key.status == 'expired'
                      ? null : ()=>renewKey(key),
                    icon:const Icon(Icons.refresh,size:17),
                    label:const Text('Gia hạn')),
                  TextButton.icon(onPressed:busy?null:()=>openKeyDevices(key),
                    icon:const Icon(Icons.devices_outlined,size:17),
                    label:const Text('Đổi thiết bị')),
                ])),
            ]))),

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
        appBar: AppBar(title: const Text('Quét mã QR')),
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
