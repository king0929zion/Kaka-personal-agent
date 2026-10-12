import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../app/app_controller.dart';
import '../../core/models.dart';
import '../../design/theme.dart';
import '../../design/widgets.dart';

class MessagingScreen extends StatefulWidget {
  final AppController app;
  const MessagingScreen({super.key,required this.app});
  @override
  State<MessagingScreen> createState()=>_MessagingScreenState();
}
class _MessagingScreenState extends State<MessagingScreen> {
  Map<String,dynamic> status={};
  List<Map<String,dynamic>> identities=[],channels=[],connections=[];
  String? error;
  bool loading=true,busy=false;
  @override
  void initState(){super.initState();_refresh();}
  Future<void> _refresh() async {
    if(mounted)setState(()=>loading=true);
    try{
      final values=await Future.wait<dynamic>([
        widget.app.api.rpc('messaging/status'),
        widget.app.api.rpc('messaging/channels/list'),
        widget.app.api.rpc('messaging/connections/list'),
      ]);
      if(!mounted)return;
      final state=Map<String,dynamic>.from(values[0] as Map);
      setState((){
        status=state;
        identities=(state['identities'] is List?state['identities'] as List:const [])
          .whereType<Map>().map((m)=>Map<String,dynamic>.from(m)).toList();
        channels=(values[1] as List).whereType<Map>()
          .map((m)=>Map<String,dynamic>.from(m)).toList();
        connections=(values[2] as List).whereType<Map>()
          .map((m)=>Map<String,dynamic>.from(m)).toList();
        error=null;
      });
    }catch(e){if(mounted)setState(()=>error=e.toString());}
    finally{if(mounted)setState(()=>loading=false);}
  }
  Future<void> _startLink()async{
    final bots=widget.app.bots;
    if(bots.isEmpty){
      kakaNotice(context,'Create an agent before linking a messaging app');
      return;
    }
    final bot=await kakaSheet<KakaBot>(context,Column(
      mainAxisSize:MainAxisSize.min,children:[
        Text('Choose an agent',style:Theme.of(context).textTheme.titleLarge),
        const SizedBox(height:13),
        Flexible(child:ListView(shrinkWrap:true,children:[
          for(final bot in bots)KakaRow(title:bot.name,icon:LucideIcons.bot,
            onTap:()=>Navigator.pop(context,bot)),
        ])),
      ]));
    if(bot==null||!mounted)return;
    try{
      final value=await widget.app.api.rpc('messaging/link/start',{
        'botId':bot.id,
      });
      final data=Map<String,dynamic>.from(value as Map);
      if(!mounted)return;
      final code=data['code']?.toString()??'';
      await kakaSheet<void>(context,Column(
        mainAxisSize:MainAxisSize.min,
        crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          Text('Link your chat app',
            style:Theme.of(context).textTheme.titleLarge),
          const SizedBox(height:13),
          const Text('Send this one-time code to the Kaka bot in your supported chat app.',
            style:TextStyle(color:KColors.muted,fontSize:13,height:1.5)),
          const SizedBox(height:15),
          Container(alignment:Alignment.center,
            padding:const EdgeInsets.all(19),
            decoration:BoxDecoration(color:KColors.soft,
              borderRadius:BorderRadius.circular(22)),
            child:SelectableText(code,style:const TextStyle(
              fontSize:22,fontWeight:FontWeight.w700,letterSpacing:2))),
          const SizedBox(height:14),
          KakaButton(title:'Copy pairing code',onPressed:()async{
            await Clipboard.setData(ClipboardData(text:code));
            if(context.mounted)Navigator.pop(context);
          }),
        ]));
      await _refresh();
    }catch(e){if(mounted)kakaNotice(context,e.toString());}
  }
  Future<void> _setBot(Map<String,dynamic> identity)async{
    final bot=await kakaSheet<KakaBot>(context,Column(
      mainAxisSize:MainAxisSize.min,children:[
        Text('Route messages to',style:Theme.of(context).textTheme.titleLarge),
        const SizedBox(height:12),
        Flexible(child:ListView(shrinkWrap:true,children:[
          for(final bot in widget.app.bots)
            KakaRow(title:bot.name,icon:LucideIcons.bot,
              onTap:()=>Navigator.pop(context,bot)),
        ])),
      ]));
    if(bot==null)return;
    await _mutate('messaging/identities/setBot',{
      'identityId':identity['id'],'botId':bot.id,
    });
  }
  Future<void> _unlink(Map<String,dynamic> identity)async{
    final yes=await _confirm('Unlink chat app?',
      'This app will no longer deliver messages to your agent.');
    if(yes)await _mutate('messaging/identities/unlink',{
      'identityId':identity['id'],
    });
  }
  Future<bool> _confirm(String title,String explanation)async{
    return await kakaSheet<bool>(context,Column(
      mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Text(title,style:Theme.of(context).textTheme.titleLarge),
        const SizedBox(height:13),
        Text(explanation,style:const TextStyle(
          color:KColors.muted,fontSize:13,height:1.5)),
        const SizedBox(height:19),
        KakaButton(title:'Confirm',onPressed:()=>Navigator.pop(context,true)),
        const SizedBox(height:9),
        KakaButton(title:'Cancel',filled:false,
          onPressed:()=>Navigator.pop(context,false)),
      ]))??false;
  }
  Future<void> _mutate(String rpc,Map<String,dynamic> args)async{
    if(busy)return;
    setState(()=>busy=true);
    try{
      await widget.app.api.rpc(rpc,args);
      await _refresh();
    }catch(e){if(mounted)kakaNotice(context,e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }
  void _identityMenu(Map<String,dynamic> identity){
    kakaSheet<void>(context,Column(mainAxisSize:MainAxisSize.min,children:[
      KakaRow(title:'Change agent',icon:LucideIcons.bot,onTap:(){
        Navigator.pop(context);_setBot(identity);
      }),
      KakaRow(title:'Unlink',icon:LucideIcons.unlink,onTap:(){
        Navigator.pop(context);_unlink(identity);
      }),
    ]));
  }
  void _channelMenu(Map<String,dynamic> channel){
    final invited=channel['status']=='invited';
    kakaSheet<void>(context,Column(mainAxisSize:MainAxisSize.min,children:[
      if(invited)KakaRow(title:'Accept invitation',icon:LucideIcons.check,
        onTap:(){
          Navigator.pop(context);_mutate('messaging/channels/respond',{
            'membershipId':channel['id'],'accept':true,
          });
        }),
      if(invited)KakaRow(title:'Decline invitation',icon:LucideIcons.x,
        onTap:(){
          Navigator.pop(context);_mutate('messaging/channels/respond',{
            'membershipId':channel['id'],'accept':false,
          });
        }),
      if(!invited)KakaRow(title:'Leave channel',icon:LucideIcons.logOut,
        onTap:(){
          Navigator.pop(context);_mutate('messaging/channels/leave',{
            'membershipId':channel['id'],
          });
        }),
    ]));
  }
  void _connectionMenu(Map<String,dynamic> connection){
    final pending=connection['status']=='pending';
    final id=connection['id'];
    kakaSheet<void>(context,Column(mainAxisSize:MainAxisSize.min,children:[
      if(pending)KakaRow(title:'Approve Agent connection',
        icon:LucideIcons.check,onTap:(){
          Navigator.pop(context);_mutate('messaging/connections/respond',{
            'connectionId':id,'accept':true,
          });
        }),
      if(pending)KakaRow(title:'Decline connection',
        icon:LucideIcons.x,onTap:(){
          Navigator.pop(context);_mutate('messaging/connections/respond',{
            'connectionId':id,'accept':false,
          });
        }),
      if(!pending)KakaRow(title:'Revoke connection',
        icon:LucideIcons.unlink,onTap:(){
          Navigator.pop(context);_mutate('messaging/connections/revoke',{
            'connectionId':id,
          });
        }),
    ]));
  }
  @override
  Widget build(BuildContext context)=>Scaffold(
    backgroundColor:KColors.bg,
    body:SafeArea(child:Column(children:[
      Padding(padding:const EdgeInsets.fromLTRB(12,12,16,14),child:Row(children:[
        KakaIconButton(icon:LucideIcons.arrowLeft,
          onTap:()=>Navigator.pop(context)),
        const SizedBox(width:9),
        Expanded(child:Text('Messaging',style:Theme.of(context).textTheme.headlineMedium)),
        KakaIconButton(icon:LucideIcons.refreshCw,onTap:_refresh),
      ])),
      if(loading||busy)const KakaLoadingRail(),
      Expanded(child:RefreshIndicator(onRefresh:_refresh,color:KColors.ink,
        child:ListView(padding:const EdgeInsets.fromLTRB(22,12,22,40),children:[
          if(error!=null)Padding(padding:const EdgeInsets.only(bottom:12),
            child:Text(error!,style:const TextStyle(color:KColors.error,fontSize:13))),
          KakaSection(title:'LINKED APPS',child:Column(children:[
            for(final id in identities)
              KakaRow(title:id['provider']?.toString()??'Chat app',
                subtitle:'${id['address']??''} · ${id['botName']??'Agent'}',
                icon:LucideIcons.messageCircle,
                onTap:()=>_identityMenu(id)),
            if(identities.isEmpty)const Padding(padding:EdgeInsets.all(18),
              child:Text('No chat apps linked',
                style:TextStyle(color:KColors.muted))),
            if(status['enabled']==true)KakaRow(title:'Link chat app',
              icon:LucideIcons.plus,onTap:_startLink),
          ])),
          const SizedBox(height:23),
          KakaSection(title:'CHANNELS',child:Column(children:[
            for(final channel in channels)
              KakaRow(title:channel['name']?.toString()??'Group chat',
                subtitle:'${channel['provider']??''} · ${channel['status']??''}',
                icon:LucideIcons.users,onTap:()=>_channelMenu(channel)),
            if(channels.isEmpty)const Padding(padding:EdgeInsets.all(18),
              child:Text('No group channels',
                style:TextStyle(color:KColors.muted))),
          ])),
          const SizedBox(height:23),
          KakaSection(title:'AGENT CONNECTIONS',child:Column(children:[
            for(final conn in connections)
              KakaRow(title:conn['peerBotName']?.toString()??'Agent',
                subtitle:'${conn['peerOwnerLabel']??''} · ${conn['status']??''}',
                icon:LucideIcons.bot,onTap:()=>_connectionMenu(conn)),
            if(connections.isEmpty)const Padding(padding:EdgeInsets.all(18),
              child:Text('No Agent connections',
                style:TextStyle(color:KColors.muted))),
          ])),
        ]))),
    ])),
  );
}
