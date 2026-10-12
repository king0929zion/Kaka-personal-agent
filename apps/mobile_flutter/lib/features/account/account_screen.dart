import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../app/app_controller.dart';
import '../../design/theme.dart';
import '../../design/widgets.dart';
import 'ai_privacy_screen.dart';

class AccountScreen extends StatefulWidget {
  final AppController app;
  const AccountScreen({super.key,required this.app});
  @override
  State<AccountScreen> createState()=>_AccountScreenState();
}
class _AccountScreenState extends State<AccountScreen> {
  Map<String,dynamic> me={};
  String? error;
  bool loading=true;
  @override
  void initState(){super.initState();_refresh();}
  Future<void> _refresh()async{
    if(mounted)setState(()=>loading=true);
    try{
      final user=await widget.app.api.rpc('me');
      if(mounted)setState((){
        me=Map<String,dynamic>.from(user as Map);error=null;
      });
    }catch(e){if(mounted)setState(()=>error=e.toString());}
    finally{if(mounted)setState(()=>loading=false);}
  }
  Future<void> _changePassword()async{
    final old=TextEditingController(),password=TextEditingController(),
      repeat=TextEditingController();
    String? validation;
    bool saving=false;
    try{
      await kakaSheet<void>(context,StatefulBuilder(builder:(ctx,update)=>
        SingleChildScrollView(child:Column(
          mainAxisSize:MainAxisSize.min,
          crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            Text('Change password',style:Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height:19),
            KakaField(controller:old,label:'Current password',obscure:true),
            const SizedBox(height:12),
            KakaField(controller:password,label:'New password',obscure:true),
            const SizedBox(height:12),
            KakaField(controller:repeat,label:'Confirm password',obscure:true),
            if(validation!=null)Padding(padding:const EdgeInsets.only(top:12),
              child:Text(validation!,style:const TextStyle(color:KColors.error,fontSize:13))),
            const SizedBox(height:17),
            KakaButton(title:'Update password',busy:saving,onPressed:()async{
              if(saving)return;
              if(password.text.length<8 ||password.text!=repeat.text ||
                  old.text.isEmpty){
                update(()=>validation='Passwords must match and contain at least 8 characters');
                return;
              }
              update(()=>saving=true);
              try{
                await widget.app.api.changePassword(old.text,password.text);
                if(ctx.mounted)Navigator.pop(ctx);
                if(mounted)kakaNotice(context,'Password updated');
              }catch(e){if(ctx.mounted)update(()=>validation=e.toString());}
              finally{if(ctx.mounted)update(()=>saving=false);}
            }),
          ]),
        )));
    }finally{
      WidgetsBinding.instance.addPostFrameCallback((_){
        old.dispose();password.dispose();repeat.dispose();
      });
    }
  }
  Future<void> _deleteAccount()async{
    final password=TextEditingController();
    bool saving=false;
    String? validation;
    try {
      await kakaSheet<void>(context,StatefulBuilder(builder:(ctx,update)=>
        SingleChildScrollView(child:Column(
          mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,
          children:[
            Text('Permanently delete account?',
              style:Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height:11),
            const Text('Your account and associated data may be permanently deleted. This cannot be undone.',
              style:TextStyle(color:KColors.muted,fontSize:13,height:1.5)),
            const SizedBox(height:15),
            KakaField(controller:password,label:'Confirm your password',obscure:true),
            if(validation!=null)Padding(padding:const EdgeInsets.only(top:12),
              child:Text(validation!,style:const TextStyle(color:KColors.error,fontSize:13))),
            const SizedBox(height:18),
            KakaButton(title:'Delete account permanently',busy:saving,onPressed:()async{
              if(saving || password.text.isEmpty)return;
              update(()=>saving=true);
              try{
                await widget.app.api.deleteAccount(password:password.text);
                if(ctx.mounted)Navigator.pop(ctx);
                await widget.app.logout();
              }catch(e){if(ctx.mounted)update(()=>validation=e.toString());}
              finally{if(ctx.mounted)update(()=>saving=false);}
            }),
            const SizedBox(height:9),
            KakaButton(title:'Cancel',filled:false,
              onPressed:()=>Navigator.pop(ctx)),
          ]),
        )));
    }finally{
      WidgetsBinding.instance.addPostFrameCallback((_)=>password.dispose());
    }
  }
  @override
  Widget build(BuildContext context)=>Scaffold(
    backgroundColor:KColors.bg,
    body:SafeArea(child:Column(children:[
      KakaPageHeader(
        title:Text('Account',
          style:Theme.of(context).textTheme.titleLarge),
        actions:[
          KakaIconButton(icon:LucideIcons.refreshCw,
            tooltip:'Refresh account',onTap:_refresh),
        ],
      ),
      if(loading)const KakaLoadingRail(),
      Expanded(child:KakaContentWidth(child:ListView(padding:const EdgeInsets.fromLTRB(KLayout.pageGutter,12,KLayout.pageGutter,36),children:[
        if(error!=null)Text(error!,
          style:const TextStyle(color:KColors.error,fontSize:13)),
        Container(
          padding:const EdgeInsets.all(24),
          decoration:BoxDecoration(color:KColors.surface,
            borderRadius:BorderRadius.circular(29)),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(me['name']?.toString()??widget.app.accountName,
              style:Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height:8),
            Text(me['email']?.toString()??'',
              style:const TextStyle(color:KColors.muted,fontSize:13)),
          ]),
        ),
        const SizedBox(height:23),
        KakaSection(title:'SECURITY',child:Column(children:[
          KakaRow(title:'Change password',icon:LucideIcons.keyRound,
            onTap:_changePassword),
          KakaRow(title:'AI data sharing',icon:LucideIcons.shieldCheck,
            onTap:()=>Navigator.push(context,MaterialPageRoute<void>(
              builder:(_)=>AiPrivacyScreen(api:widget.app.api)))),
        ])),
        const SizedBox(height:23),
        KakaSection(title:'ACCOUNT ACTIONS',child:Column(children:[
          KakaRow(title:'Sign out',icon:LucideIcons.logOut,
            onTap:()=>widget.app.logout()),
          KakaRow(title:'Delete account',icon:LucideIcons.trash2,
            onTap:_deleteAccount),
        ])),
      ]))),
    ])),
  );
}
