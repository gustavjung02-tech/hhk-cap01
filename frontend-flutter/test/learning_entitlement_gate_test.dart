import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hhk_cap01/features/learning_entitlement_gate.dart';

void main() {
  Widget build(Future<bool> access, {required VoidCallback onOpen,
      required VoidCallback onRefresh}) =>
      MaterialApp(home: Scaffold(body: LearningEntitlementGate(
        entitlement: access,
        grade: 3,
        onActivate: onOpen,
        onRefresh: onRefresh,
        onSwitchProfile: () {},
        onGrade: (_) {},
        child: const Text('Private lesson content', key: Key('private-lesson')),
      )));

  testWidgets('missing lease never builds learning content',
      (tester) async {
    var opened = false;
    var refreshed = false;
    await tester.pumpWidget(build(Future.value(false),
      onOpen: () => opened = true,
      onRefresh: () => refreshed = true));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('private-lesson')), findsNothing);
    expect(find.byKey(const Key('activate-learning-license')), findsOneWidget);
    await tester.tap(find.byKey(const Key('activate-learning-license')));
    expect(opened, isTrue);
    await tester.tap(find.byKey(const Key('retry-learning-license')));
    expect(refreshed, isTrue);
  });

  testWidgets('valid signed lease grants content',
      (tester) async {
    await tester.pumpWidget(build(Future.value(true),
      onOpen: () {}, onRefresh: () {}));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('private-lesson')), findsOneWidget);
    expect(find.byKey(const Key('activate-learning-license')), findsNothing);
  });

  testWidgets('corrupt vault check fails closed', (tester) async {
    final pending = Completer<bool>();
    await tester.pumpWidget(build(pending.future,
      onOpen: () {}, onRefresh: () {}));
    pending.completeError(StateError('corrupt'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('private-lesson')), findsNothing);
    expect(find.text('Không kiểm tra được quyền học'), findsOneWidget);
  });
}
