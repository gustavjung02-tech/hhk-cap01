import 'package:material_ui/material_ui.dart';

class LegacyMenuItem {
  final String id;
  final String label;
  final IconData icon;
  final bool available;
  const LegacyMenuItem(this.id, this.label, this.icon,
      {this.available = false});
}

class LegacyMenuGroup {
  final String title;
  final List<LegacyMenuItem> items;
  const LegacyMenuGroup(this.title, this.items);
}

/// Audited against the original cap-01 Sidebar.tsx / appRoutes.tsx. No fake
/// buttons: unavailable tools open an explicit "not yet migrated" explanation.
const legacyMenuGroups = <LegacyMenuGroup>[
  LegacyMenuGroup('Học tập', [
    LegacyMenuItem('lessons', 'Bài học', Icons.menu_book_outlined,
        available: true),
    LegacyMenuItem('review', 'Ôn tập thông minh', Icons.refresh,
        available: true),
    LegacyMenuItem('memory', 'Phòng trí nhớ', Icons.psychology_outlined),
    LegacyMenuItem('mindmap', 'Sơ đồ tư duy', Icons.account_tree_outlined),
    LegacyMenuItem('curriculum', 'Giáo trình', Icons.book_outlined,
        available: true),
    LegacyMenuItem('assistant', 'Trợ lý học tập', Icons.lightbulb_outline),
  ]),
  LegacyMenuGroup('Vui chơi', [
    LegacyMenuItem('daily', 'Thử thách hằng ngày',
        Icons.calendar_month_outlined),
    LegacyMenuItem('games', 'Mini-Game', Icons.sports_esports_outlined),
    LegacyMenuItem('drawing', 'Vẽ & tô màu', Icons.brush_outlined),
    LegacyMenuItem('competition', 'Thi đấu', Icons.sports_kabaddi_outlined),
  ]),
  LegacyMenuGroup('Thành tích', [
    LegacyMenuItem('progress', 'Tiến bộ', Icons.bar_chart, available: true),
    LegacyMenuItem('analytics', 'Phân tích học tập',
        Icons.insights_outlined, available: true),
    LegacyMenuItem('badges', 'Huy hiệu', Icons.military_tech_outlined),
    LegacyMenuItem('leaderboard', 'Bảng xếp hạng',
        Icons.emoji_events_outlined),
    LegacyMenuItem('achievements', 'Thành tựu', Icons.star_outline),
    LegacyMenuItem('avatar', 'Cửa hàng avatar',
        Icons.shopping_bag_outlined),
  ]),
  LegacyMenuGroup('Cài đặt & gia đình', [
    LegacyMenuItem('profiles', 'Hồ sơ học sinh',
        Icons.people_outline, available: true),
    LegacyMenuItem('parent', 'Phụ huynh',
        Icons.family_restroom, available: true),
    LegacyMenuItem('tts', 'Giọng đọc', Icons.record_voice_over_outlined),
    LegacyMenuItem('audio', 'Audio offline',
        Icons.download_outlined),
    LegacyMenuItem('offline', 'Ngoại tuyến & cập nhật',
        Icons.offline_bolt_outlined),
    LegacyMenuItem('theme', 'Giao diện', Icons.palette_outlined),
    LegacyMenuItem('data', 'Dữ liệu', Icons.storage_outlined),
    LegacyMenuItem('account', 'Tài khoản & key',
        Icons.manage_accounts_outlined, available: true),
  ]),
];

class LegacyFeatureDrawer extends StatelessWidget {
  final String profileName;
  final int grade;
  final ValueChanged<LegacyMenuItem> onSelect;
  const LegacyFeatureDrawer({super.key, required this.profileName,
    required this.grade, required this.onSelect});

  @override
  Widget build(BuildContext context) => Drawer(
    child: SafeArea(
      child: ListView(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(children: [
            Image.asset('assets/brand/dopi-avatar.png', width: 62,
                height: 62, fit: BoxFit.contain),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Khám phá HHK',
                    style: Theme.of(context).textTheme.titleLarge),
                Text('$profileName • Lớp $grade',
                    overflow: TextOverflow.ellipsis),
              ],
            )),
          ]),
        ),
        const Divider(),
        for (final group in legacyMenuGroups)
          ExpansionTile(
            initiallyExpanded: group.title == 'Học tập',
            title: Text(group.title),
            children: [
              for (final item in group.items)
                ListTile(
                  key: Key('menu-${item.id}'),
                  dense: true,
                  leading: Icon(item.icon),
                  title: Text(item.label),
                  trailing: item.available
                      ? const Icon(Icons.chevron_right, size: 18)
                      : const Text('Chưa chuyển',
                          style: TextStyle(fontSize: 11)),
                  onTap: () {
                    Navigator.pop(context);
                    onSelect(item);
                  },
                ),
            ],
          ),
      ]),
    ),
  );
}

class LegacyComingSoonPage extends StatelessWidget {
  final LegacyMenuItem feature;
  const LegacyComingSoonPage({super.key, required this.feature});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(feature.label)),
    body: Center(child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(feature.icon, size: 52),
        const SizedBox(height: 16),
        Text(feature.label, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        const Text('Tính năng này có trong app gốc nhưng chưa chuyển xong '
            'sang Flutter. Chúng em sẽ bổ sung nghiệp vụ thật, '
            'không tạo số liệu giả hoặc điều hướng trống.',
            textAlign: TextAlign.center),
        const SizedBox(height: 22),
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Quay lại'),
        ),
      ]),
    )),
  );
}
