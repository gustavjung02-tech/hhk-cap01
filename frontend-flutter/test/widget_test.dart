import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hhk_cap01/data/catalog_repository.dart';
void main(){
 test('empty grade pack is safe',(){
   final pack=GradePack.fromJson({'grade':3,'subjects':[],'lessons':[],'cards':[],'questions':[]});
   expect(pack.grade,3);
   expect(pack.lessonsFor('math'),isEmpty);
 });
 testWidgets('simple Flutter Material app mounts',(tester) async {
   await tester.pumpWidget(const MaterialApp(home:Scaffold(body:Text('HHK CAP-01'))));
   expect(find.text('HHK CAP-01'),findsOneWidget);
 });
}
