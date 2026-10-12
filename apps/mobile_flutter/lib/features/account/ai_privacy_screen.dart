import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api.dart';
import '../../design/theme.dart';
import '../../design/widgets.dart';

class AiPrivacyScreen extends StatefulWidget {
  final KakaApi api;
  const AiPrivacyScreen({super.key,required this.api});
  @override
  State<AiPrivacyScreen> createState()=>_AiPrivacyScreenState();
}
class _AiPrivacyScreenState extends State<AiPrivacyScreen> {
  Map<String,dynamic>? status;
  bool loading=true,busy=false;
  String? error;
  @override
  void initState(){super.initState();_load();}
  Future<void> _load()async{
    if(mounted)setState(()=>loading=true);
    try{
      final value=await widget.api.rpc('aiConsent/status');
      if(mounted)setState((){
        status=Map<String,dynamic>.from(value as Map);error=null;
      });
    }catch(e){if(mounted)setState(()=>error=e.toString());}
    finally{if(mounted)setState(()=>loading=false);}
  }
  Future<void> _set(Map<String,dynamic> recipient,bool allowed) async {
    final old=status;
    if(old==null||busy)return;
    if(allowed){
      final confirmed=await kakaSheet<bool>(context,Column(
        mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,
        children:[
          Text('Allow ${recipient['name']}?',
            style:Theme.of(context).textTheme.titleLarge),
          const SizedBox(height:12),
          Text(recipient['detail']?.toString()??'External service data sharing',
            style:const TextStyle(fontSize:13,height:1.5,color:KColors.muted)),
          const SizedBox(height:16),
          KakaButton(title:'Allow data sharing',
            onPressed:()=>Navigator.pop(context,true)),
          const SizedBox(height:8),
          KakaButton(title:'Cancel',filled:false,
            onPressed:()=>Navigator.pop(context,false)),
        ]));
      if(confirmed!=true)return;
    }
    setState(()=>busy=true);
    try{
      final result=await widget.api.rpc(
        allowed?'aiConsent/allow':'aiConsent/revoke',
        allowed?{
          'scope':old['scope'],'version':old['version'],
          'keys':[recipient['key']],
        }:{'key':recipient['key']},
      );
      if(mounted)setState(()=>status=Map<String,dynamic>.from(result as Map));
    }catch(e){if(mounted)kakaNotice(context,e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> _withdrawAll()async{
    final yes=await kakaSheet<bool>(context,Column(
      mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,
      children:[
        Text('Withdraw all permissions?',style:Theme.of(context).textTheme.titleLarge),
        const SizedBox(height:12),
        const Text('Existing running tasks may need to be stopped separately.',
          style:TextStyle(color:KColors.muted,fontSize:13)),
        const SizedBox(height:17),
        KakaButton(title:'Withdraw permissions',onPressed:()=>Navigator.pop(context,true)),
        const SizedBox(height:8),
        KakaButton(title:'Cancel',filled:false,onPressed:()=>Navigator.pop(context,false)),
      ]));
    if(yes!=true)return;
    setState(()=>busy=true);
    try{
      final value=await widget.api.rpc('aiConsent/revoke',{'key':null});
      if(mounted)setState(()=>status=Map<String,dynamic>.from(value as Map));
    }catch(e){if(mounted)kakaNotice(context,e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override
  Widget build(BuildContext context){
    final rows=(status?['recipients'] as List?)??const [];
    return Scaffold(backgroundColor:KColors.bg,
      body:SafeArea(child:Column(children:[
        Padding(padding:const EdgeInsets.fromLTRB(12,12,15,16),child:Row(children:[
          KakaIconButton(icon:LucideIcons.arrowLeft,onTap:()=>Navigator.pop(context)),
          const SizedBox(width:9),
          Expanded(child:Text('AI data sharing',
            style:Theme.of(context).textTheme.headlineMedium)),
          KakaIconButton(icon:LucideIcons.refreshCw,onTap:_load),
        ])),
        if(loading||busy)const KakaLoadingRail(),
        Expanded(child:ListView(padding:const EdgeInsets.fromLTRB(22,14,22,40),
          children:[
            const Text('Manage which third-party services can receive your data for model responses, voice and memory.',
              style:TextStyle(color:KColors.muted,fontSize:13,height:1.5)),
            const SizedBox(height:20),
            if(error!=null)Text(error!,style:const TextStyle(color:KColors.error)),
            KakaSection(title:'SERVICE PERMISSIONS',child:Column(children:[
              for(final raw in rows.whereType<Map>())
                Builder(builder:(ctx){
                  final recipient=Map<String,dynamic>.from(raw);
                  return KakaRow(title:recipient['name']?.toString()??'Service',
                    subtitle:'${recipient['use']??''} · ${recipient['detail']??''}',
                    icon:LucideIcons.shield,
                    trailing:KakaSwitch(value:recipient['allowed']==true,
                      onChanged:busy?null:(v)=>_set(recipient,v)));
                }),
              if(rows.isEmpty)const Padding(padding:EdgeInsets.all(20),
                child:Text('No external recipients reported',
                  style:TextStyle(color:KColors.muted,fontSize:13))),
            ])),
            const SizedBox(height:18),
            KakaButton(title:'Withdraw all',filled:false,
              onPressed:busy?null:_withdrawAll),
            if(status?['privacyUrl'] is String)Padding(
              padding:const EdgeInsets.only(top:15),
              child:KakaButton(title:'Privacy policy',filled:false,onPressed:()async{
                final url=Uri.tryParse(status!['privacyUrl'].toString());
                if(url!=null&&url.scheme=='https')await launchUrl(url,
                  mode:LaunchMode.externalApplication);
              })),
          ])),
      ])),
    );
  }
}
