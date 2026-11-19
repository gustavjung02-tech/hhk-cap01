import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hhk_cap01/features/legacy_feature_drawer.dart';

void main() {
  test('all original sidebar categories are catalogued and support truthful status', () {
    final groups = legacyMenuGroups.map((g) => g.title).toList();
    expect(groups, ['Học tập', 'Vui chơi', 'Thành tích', 'Cài đặt & gia đình']);
    final entries = legacyMenuGroups.expand((group) => group.items).toList();
    expect(entries.map((e) => e.id), containsAll([
      'review', 'memory', 'mindmap', 'daily', 'games', 'drawing',
      'competition', 'progress', 'analytics', 'badges', 'leaderboard',
      'achievements', 'avatar', 'parent', 'tts', 'audio', 'offline',
      'theme', 'data', 'profiles',
    ]));
    expect(entries.where((e) => e.id == 'games').single.available, isTrue);
    expect(entries.where((e) => e.id == 'daily').single.available, isTrue);
    for (final id in ['drawing', 'memory', 'mindmap', 'avatar']) {
      expect(entries.where((e) => e.id == id).single.available, isTrue);
    }
    expect(entries.where((e) => e.id == 'review').single.available, isTrue);
    expect(entries.where((e) => e.id == 'audio').single.available, isTrue);
  });

  testWidgets('the drawer opens a real migrated feature', (tester) async {
    LegacyMenuItem? choice;
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: const Text('Nội dung'),
      drawer: LegacyFeatureDrawer(profileName:'Học sinh 1',grade:3,
        onSelect:(item)=>choice=item),
      appBar: AppBar(),
    )));
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ôn tập thông minh'));
    await tester.pumpAndSettle();
    expect(choice?.id,'review');
  });
}
