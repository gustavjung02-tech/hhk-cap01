import 'package:material_ui/material_ui.dart';
import '../../data/account_api.dart';

class ChangePasswordPage extends StatefulWidget {
  final AccountApi api;
  final AccountSession session;
  const ChangePasswordPage({super.key,required this.api,required this.session});
  @override
  State<ChangePasswordPage> createState()=>_ChangePasswordPageState();
}
class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final current=TextEditingController(),next=TextEditingController(),confirm=TextEditingController();
  String? error;
  bool busy=false;
  @override
  void dispose(){current.dispose();next.dispose();confirm.dispose();super.dispose();}
  Future<void> submit() async {
    if(busy)return;
    if(next.text!=confirm.text || next.text.length<12){
      setState(()=>error='Mật khẩu mới phải có ít nhất 12 ký tự và nhập lại khớp.');
      return;
    }
    setState(() {busy=true;error=null;});
    try{
      final rotated=await widget.api.changePassword(widget.session,current.text,next.text);
      await widget.api.acceptRotatedSession(rotated);
      if (mounted) {
        Navigator.pop(context, rotated);
      }
    }on AccountApiException catch(e){
      if(mounted)setState(()=>error=e.message);
    }catch(_){
      if (mounted) {
        setState(() => error = 'Không thể lưu phiên mới. Hãy đăng nhập lại.');
      }
    }finally{
      if(mounted)setState(()=>busy=false);
    }
  }
  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Đổi mật khẩu')),
    body:ListView(padding:const EdgeInsets.all(20),children:[
      const Text('Máy hiện tại sẽ tiếp tục đăng nhập. Các máy khác sẽ phải đăng nhập lại.'),
      const SizedBox(height:20),
      TextField(key:const Key('change-current'),controller:current,obscureText:true,
        decoration:const InputDecoration(labelText:'Mật khẩu hiện tại',border:OutlineInputBorder())),
      const SizedBox(height:12),
      TextField(key:const Key('change-new'),controller:next,obscureText:true,
        decoration:const InputDecoration(labelText:'Mật khẩu mới (ít nhất 12 ký tự)',border:OutlineInputBorder())),
      const SizedBox(height:12),
      TextField(key:const Key('change-confirm'),controller:confirm,obscureText:true,
        decoration:const InputDecoration(labelText:'Nhập lại mật khẩu mới',border:OutlineInputBorder())),
      if(error!=null) Padding(padding:const EdgeInsets.symmetric(vertical:12),
        child:Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error))),
      const SizedBox(height:16),
      FilledButton(onPressed:busy?null:submit,child:const Text('Lưu mật khẩu mới')),
      if(busy)const LinearProgressIndicator(),
    ]),
  );
}

class AccountSessionsPage extends StatefulWidget {
  final AccountApi api;
  final AccountSession session;
  final Future<void> Function()? onSignedOut;
  const AccountSessionsPage({super.key,required this.api,required this.session,this.onSignedOut});
  @override
  State<AccountSessionsPage> createState()=>_AccountSessionsPageState();
}
class _AccountSessionsPageState extends State<AccountSessionsPage> {
  List<AccountDeviceSession>? devices;
  bool busy=false;
  String? error;
  @override
  void initState(){super.initState();load();}
  Future<void> load() async {
    setState(() {busy=true;error=null;});
    try{
      final items=await widget.api.sessions(widget.session);
      if(mounted)setState(()=>devices=items);
    }on AccountApiException catch(e){
      if(mounted)setState(()=>error=e.message);
    }finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> revoke(String id) async {
    if(busy)return;
    setState((){busy=true;error=null;});
    try{
      await widget.api.revokeSession(widget.session,id);
      final items=await widget.api.sessions(widget.session);
      if(mounted)setState(()=>devices=items);
    }on AccountApiException catch(e){
      if(mounted)setState(()=>error=e.message);
    }finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> logoutAll() async {
    if(busy)return;
    setState((){busy=true;error=null;});
    try{
      await widget.api.logoutAll(widget.session);
      await widget.onSignedOut?.call();
    }on AccountApiException catch(e){
      if(mounted)setState(()=>error=e.message);
    }catch(_){
      if(mounted)setState(()=>error='Không thể xóa phiên trên máy này.');
    }finally{if(mounted)setState(()=>busy=false);}
  }
  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Thiết bị đăng nhập'),
      actions:[IconButton(onPressed:busy?null:load,icon:const Icon(Icons.refresh),
        tooltip:'Làm mới')]),
    body:ListView(padding:const EdgeInsets.all(16),children:[
      const Text('Phiên không tự hết hạn theo ngày. Anh/chị có thể thu hồi các máy không còn sử dụng.'),
      if(busy)const LinearProgressIndicator(),
      if(error!=null)Padding(padding:const EdgeInsets.all(8),
        child:Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error))),
      for(final device in devices??<AccountDeviceSession>[])
        Card(child:ListTile(
          leading:Icon(device.current?Icons.phone_android:Icons.devices_outlined),
          title:Text(device.label),
          subtitle:Text('${device.current ? 'Máy hiện tại • ' : ''}Hoạt động: ${device.lastUsedAt.toLocal().toString().split('.').first}'),
          trailing:device.current
            ?const Icon(Icons.check_circle_outline)
            :TextButton(onPressed:busy?null:()=>revoke(device.id),child:const Text('Thu hồi')),
        )),
      const SizedBox(height:20),
      OutlinedButton.icon(onPressed:busy?null:logoutAll,
        icon:const Icon(Icons.logout),label:const Text('Đăng xuất tất cả thiết bị')),
    ]),
  );
}

class EmailChangePage extends StatefulWidget {
  final AccountApi api;
  final AccountSession session;
  const EmailChangePage({super.key,required this.api,required this.session});
  @override
  State<EmailChangePage> createState()=>_EmailChangePageState();
}
class _EmailChangePageState extends State<EmailChangePage> {
  final email=TextEditingController(), password=TextEditingController();
  String? message;
  bool busy=false;
  @override
  void dispose(){email.dispose();password.dispose();super.dispose();}
  Future<void> submit() async {
    if(busy)return;
    setState((){busy=true;message=null;});
    try{
      await widget.api.requestEmailChange(widget.session,email.text,password.text);
      if (mounted) {
        setState(() => message = 'Đã gửi liên kết xác minh đến email mới.');
      }
    }on AccountApiException catch(e){
      if(mounted)setState(()=>message=e.message);
    }finally{if(mounted)setState(()=>busy=false);}
  }
  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Đổi email')),
    body:ListView(padding:const EdgeInsets.all(20),children:[
      const Text('Email mới chỉ được lưu sau khi xác minh liên kết gửi đến địa chỉ đó.'),
      const SizedBox(height:16),
      TextField(controller:email,keyboardType:TextInputType.emailAddress,
        decoration:const InputDecoration(labelText:'Email mới',border:OutlineInputBorder())),
      const SizedBox(height:12),
      TextField(controller:password,obscureText:true,
        decoration:const InputDecoration(labelText:'Mật khẩu hiện tại',border:OutlineInputBorder())),
      if(message!=null)Padding(padding:const EdgeInsets.all(12),child:Text(message!)),
      FilledButton(onPressed:busy?null:submit,child:const Text('Gửi xác minh email mới')),
      if(busy)const LinearProgressIndicator(),
    ]),
  );
}

/// Handles the HTTPS token delivered by email before the login gate.
class AccountEmailActionPage extends StatefulWidget {
  final AccountApi api;
  final String action;
  final String token;
  final Future<void> Function(bool reset) onCompleted;
  const AccountEmailActionPage({super.key,required this.api,required this.action,
    required this.token,required this.onCompleted});
  @override
  State<AccountEmailActionPage> createState()=>_AccountEmailActionPageState();
}
class _AccountEmailActionPageState extends State<AccountEmailActionPage>{
  final next=TextEditingController(),confirm=TextEditingController();
  String? message;
  bool busy=false;
  @override
  void dispose(){next.dispose();confirm.dispose();super.dispose();}
  Future<void> submit() async {
    if(busy)return;
    if(widget.action=='reset'&&(next.text.length<12||next.text!=confirm.text)){
      setState(()=>message='Mật khẩu cần ít nhất 12 ký tự và nhập lại khớp.');
      return;
    }
    setState((){busy=true;message=null;});
    try{
      if(widget.action=='reset'){
        await widget.api.resetPassword(widget.token,next.text);
      }else if(widget.action=='email_change'){
        await widget.api.confirmEmailChange(widget.token);
      }else{
        await widget.api.verifyEmail(widget.token);
      }
      await widget.onCompleted(widget.action=='reset');
    }on AccountApiException catch(e){
      if(mounted)setState(()=>message=e.message);
    }catch(_){
      if (mounted) {
        setState(() => message = 'Không thể hoàn tất. Vui lòng thử lại.');
      }
    }finally{if(mounted)setState(()=>busy=false);}
  }
  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:Text(widget.action=='reset'?'Đặt lại mật khẩu':'Xác minh email')),
    body:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:440),
      child:ListView(shrinkWrap:true,padding:const EdgeInsets.all(24),children:[
        Text(widget.action=='reset'
          ?'Nhập mật khẩu mới cho tài khoản HHK.'
          :'Nhấn xác nhận để hoàn tất xác minh địa chỉ email.',
          style:Theme.of(context).textTheme.titleMedium),
        if(widget.action=='reset')...[
          const SizedBox(height:16),
          TextField(key:const Key('reset-new'),controller:next,obscureText:true,
            decoration:const InputDecoration(labelText:'Mật khẩu mới',border:OutlineInputBorder())),
          const SizedBox(height:12),
          TextField(key:const Key('reset-confirm'),controller:confirm,obscureText:true,
            decoration:const InputDecoration(labelText:'Nhập lại mật khẩu mới',border:OutlineInputBorder())),
        ],
        if(message!=null)Padding(padding:const EdgeInsets.all(12),child:Text(message!)),
        const SizedBox(height:14),
        FilledButton(onPressed:busy?null:submit,
          child:Text(widget.action=='reset'?'Đặt lại mật khẩu':'Xác nhận email')),
        if(busy)const LinearProgressIndicator(),
        const SizedBox(height:8),
        TextButton(onPressed:busy?null:()=>widget.onCompleted(false),
          child:const Text('Quay về đăng nhập')),
      ])),
    ),
  );
}
