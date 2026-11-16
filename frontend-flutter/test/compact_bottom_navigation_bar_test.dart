import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hhk_cap01/widgets/compact_bottom_navigation_bar.dart';

void main() {
  Future<void> render(WidgetTester tester, double bottomInset, ValueChanged<int> onTab) async {
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          padding: EdgeInsets.only(bottom: bottomInset),
          viewPadding: EdgeInsets.only(bottom: bottomInset),
        ),
        child: Scaffold(
          body: const Text('Nội dung HHK'),
          bottomNavigationBar: CompactBottomNavigationBar(
            selectedIndex: 0,
            onDestinationSelected: onTab,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('iPhone home indicator: navigation uses exactly one bottom inset', (tester) async {
    await render(tester, 34, (_) {});
    expect(tester.getSize(find.byType(NavigationBar)).height,
        CompactBottomNavigationBar.contentHeight + 34);
    expect(find.text('Trang chủ'), findsOneWidget);
    expect(find.text('Môn học'), findsOneWidget);
    expect(find.text('Luyện tập'), findsOneWidget);
    expect(find.text('Cài đặt'), findsOneWidget);
  });

  testWidgets('without system inset bar stays compact and all tabs respond', (tester) async {
    var selected = -1;
    await render(tester, 0, (index) => selected = index);
    expect(tester.getSize(find.byType(NavigationBar)).height,
        CompactBottomNavigationBar.contentHeight);
    await tester.tap(find.text('Luyện tập'))
    await tester.pump();
    expect(selected, 2);
  });
}
