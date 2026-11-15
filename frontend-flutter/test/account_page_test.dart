import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hhk_cap01/features/account/account_page.dart';

void main() {
  testWidgets('account screen offers login and registration, not local fake auth', (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AccountPage())));
    expect(find.text('Tài khoản & key'), findsOneWidget);
    expect(find.text('Đăng nhập'), findsWidgets);
    expect(find.text('Chưa có tài khoản? Đăng ký'), findsOneWidget);
    await tester.tap(find.text('Chưa có tài khoản? Đăng ký'));
    await tester.pump();
    expect(find.text('Tạo tài khoản & đăng nhập'), findsOneWidget);
    expect(find.text('Mở camera quét QR'), findsNothing);
    expect(find.textContaining('tối thiểu 12 ký tự'), findsOneWidget);
  });
}
