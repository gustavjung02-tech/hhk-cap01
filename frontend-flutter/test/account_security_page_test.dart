import 'dart:convert';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hhk_cap01/data/account_api.dart';
import 'package:hhk_cap01/features/account/account_security_page.dart';

void main(){
  testWidgets('change password validates confirm and stores rotated token before success',
      (tester)async{
    const prior=AccountSession('sess_old','a@example.test',emailVerified:true);
    final api=AccountApi(baseUrl:'https://api.example.test',
      client:MockClient((r)async{
        expect(r.url.path,'/api/v1/account/password/change');
        expect(r.headers['authorization'],'Bearer sess_old');
        return http.Response(jsonEncode({'ok':true,'sessionToken':'sess_rotated'}),200);
      }));
    AccountSession? saved;
    api.onSessionRotated=(next)async{saved=next;};
    await tester.pumpWidget(MaterialApp(home:ChangePasswordPage(api:api,session:prior)));
    await tester.enterText(find.byKey(const Key('change-current')),'old-secret-123');
    await tester.enterText(find.byKey(const Key('change-new')),'new-secret-123');
    await tester.enterText(find.byKey(const Key('change-confirm')),'mismatch-secret-123');
    await tester.tap(find.text('Lưu mật khẩu mới'));
    await tester.pump();
    expect(find.textContaining('nhập lại khớp'),findsOneWidget);
    await tester.enterText(find.byKey(const Key('change-confirm')),'new-secret-123');
    await tester.tap(find.text('Lưu mật khẩu mới'));
    await tester.pumpAndSettle();
    expect(saved?.token,'sess_rotated');
    api.close();
  });

  testWidgets('session list can revoke another device, never current device', (tester)async{
    final calls=<String>[];
    final api=AccountApi(baseUrl:'https://api.example.test',
      client:MockClient((r)async{
        calls.add(r.url.path);
        if(r.url.path.endsWith('/account/sessions')){
          return http.Response(jsonEncode({'ok':true,'sessions':[
            {'id':'self','label':'iPhone','current':true,'createdAt':'2026-11-01T00:00:00Z','lastUsedAt':'2026-11-01T00:00:00Z'},
            if(!calls.contains('/api/v1/account/sessions/revoke'))
              {'id':'other','label':'Android','current':false,'createdAt':'2026-11-01T00:00:00Z','lastUsedAt':'2026-11-01T00:00:00Z'}
          ]}),200);
        }
        expect(jsonDecode(r.body)['sessionId'],'other');
        return http.Response('{"ok":true,"revoked":true}',200);
      }));
    await tester.pumpWidget(MaterialApp(home:AccountSessionsPage(api:api,
      session:const AccountSession('sess_one','a@example.test'))));
    await tester.pumpAndSettle();
    expect(find.text('iPhone'),findsOneWidget);
    expect(find.text('Android'),findsOneWidget);
    expect(find.text('Thu hồi'),findsOneWidget);
    await tester.tap(find.text('Thu hồi'));
    await tester.pumpAndSettle();
    expect(find.text('Android'),findsNothing);
    expect(calls,contains('/api/v1/account/sessions/revoke'));
    api.close();
  });

  testWidgets('email link resets real password before returning login',(tester)async{
    final api=AccountApi(baseUrl:'https://api.example.test',client:MockClient((r)async{
      expect(r.url.path,'/api/v1/accounts/password/reset');
      expect(jsonDecode(r.body)['token'],'act_example');
      return http.Response('{"ok":true,"reset":true}',200);
    }));
    bool done=false;
    await tester.pumpWidget(MaterialApp(home:AccountEmailActionPage(api:api,
      action:'reset',token:'act_example',onCompleted:(reset)async{done=reset;})));
    await tester.enterText(find.byKey(const Key('reset-new')),'safe-new-password-123');
    await tester.enterText(find.byKey(const Key('reset-confirm')),'safe-new-password-123');
    await tester.tap(find.text('Đặt lại mật khẩu').last);
    await tester.pumpAndSettle();
    expect(done,true);
    api.close();
  });
}
