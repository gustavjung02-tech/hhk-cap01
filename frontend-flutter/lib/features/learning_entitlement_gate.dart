import 'package:material_ui/material_ui.dart';
import 'native_ui.dart';

/// Single display boundary for offline signed-grade access.
/// The caller also checks a fresh lease before every deep learning route.
class LearningEntitlementGate extends StatelessWidget {
  final Future<bool> entitlement;
  final int grade;
  final Widget child;
  final VoidCallback onActivate;
  final VoidCallback onRefresh;
  final VoidCallback onSwitchProfile;
  final ValueChanged<int> onGrade;
  const LearningEntitlementGate({
    super.key,
    required this.entitlement,
    required this.grade,
    required this.child,
    required this.onActivate,
    required this.onRefresh,
    required this.onSwitchProfile,
    required this.onGrade,
  });

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: entitlement,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.data == true && !snapshot.hasError) return child;
      final problem = snapshot.hasError;
      return ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
        children: [
          NativePanel(color: HhkNative.lilac, child: Column(children: [
            Image.asset('assets/brand/dopi-avatar.png',
              width: 130, height: 130, fit: BoxFit.contain),
            const SizedBox(height: 10),
            Text(problem ? 'Không kiểm tra được quyền học'
                : 'Kích hoạt quyền học cùng Dopi',
              textAlign: TextAlign.center,
              style: const TextStyle(color: HhkNative.ink, fontSize: 21,
                fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Text(problem
                ? 'Không thể kiểm tra license lưu trên máy. Hãy thử lại; '
                  'ứng dụng không tự mở khóa khi xác minh thất bại.'
                : 'Chưa có quyền học hợp lệ cho lớp $grade trên máy này. '
                  'Mở tài khoản để nhận key và kích hoạt bằng mạng, '
                  'sau đó học offline trong thời hạn được cấp.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: HhkNative.muted)),
            const SizedBox(height: 17),
            FilledButton.icon(
              key: const Key('activate-learning-license'),
              onPressed: onActivate,
              icon: const Icon(Icons.vpn_key_rounded),
              label: const Text('Quản lý và kích hoạt key')),
            TextButton.icon(
              key: const Key('retry-learning-license'),
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Kiểm tra lại quyền học')),
          ])),
          const SizedBox(height: 20),
          const NativeHeading('Chọn lớp đang có quyền'),
          const SizedBox(height: 10),
          SingleChildScrollView(scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (var number = 1; number <= 5; number++)
                Padding(padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text('Lớp $number'),
                    selected: grade == number,
                    onSelected: (_) => onGrade(number),
                  )),
            ])),
          const SizedBox(height: 13),
          OutlinedButton.icon(
            onPressed: onSwitchProfile,
            icon: const Icon(Icons.people_outline),
            label: const Text('Đổi hồ sơ học sinh')),
          const SizedBox(height: 12),
          const Text('Thông tin học tập vẫn nằm trên thiết bị; '
            'việc chưa có key không xóa tiến độ đã lưu.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: HhkNative.muted)),
        ],
      );
    },
  );
}
