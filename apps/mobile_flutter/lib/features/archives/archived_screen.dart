import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../app/app_controller.dart';
import '../../design/theme.dart';
import '../../design/widgets.dart';

class ArchivedScreen extends StatefulWidget {
  final AppController app;
  const ArchivedScreen({super.key,required this.app});
  @override
  State<ArchivedScreen> createState()=>_ArchivedScreenState();
}
class _ArchivedScreenState extends State<ArchivedScreen>{
  List<Map<String,dynamic>> bots=[],groups=[];
  bool busy=false;
  String? error;
  @override
  void initState(){super.initState();_load();}
  Future<void> _load() async {
    if(mounted)setState(()=>busy=true);
    try {
      final result=await Future.wait<dynamic>([
        widget.app.api.rpc('bots/listArchived'),
        widget.app.api.rpc('groups/listArchived'),
      ]);
      if(!mounted)return;
      setState((){
        bots=(result[0] as List).whereType<Map>()
          .map((e)=>Map<String,dynamic>.from(e)).toList();
        groups=(result[1] as List).whereType<Map>()
          .map((e)=>Map<String,dynamic>.from(e)).toList();
        error=null;
      });
    }catch(e){if(mounted)setState(()=>error=e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> _action(String kind,Map<String,dynamic> entry) async {
    final name=entry['name']?.toString()??'';
    await kakaSheet<void>(context,Column(
      mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,
      children:[
        Text(name,style:Theme.of(context).textTheme.titleLarge),
        const SizedBox(height:14),
        KakaRow(title:'Restore',icon:LucideIcons.archiveRestore,onTap:(){
          Navigator.pop(context);
          _run('$kind/restore',entry);
        }),
        KakaRow(title:'Delete permanently',icon:LucideIcons.trash2,onTap:(){
          Navigator.pop(context);
          _confirmDelete(kind,entry);
        }),
      ]));
  }
  Future<void> _confirmDelete(String kind,Map<String,dynamic> entry) async {
    final confirmed=await kakaSheet<bool>(context,Column(
      mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,
      children:[
        Text('Permanently delete?',style:Theme.of(context).textTheme.titleLarge),
        const SizedBox(height:12),
        Text('"${entry['name']}" and its conversation cannot be recovered.',
          style:const TextStyle(color:KColors.muted,fontSize:13,height:1.5)),
        const SizedBox(height:17),
        KakaButton(title:'Delete permanently',onPressed:()=>Navigator.pop(context,true)),
        const SizedBox(height:8),
        KakaButton(title:'Cancel',filled:false,
          onPressed:()=>Navigator.pop(context,false)),
      ]));
    if(confirmed==true)await _run('$kind/remove',entry);
  }
  Future<void> _run(String rpc,Map<String,dynamic> entry) async {
    if(busy)return;
    setState(()=>busy=true);
    try{
      await widget.app.api.rpc(rpc,{
        (rpc.startsWith('bots/')?'botId':'groupId'):entry['id'],
        if(rpc=='bots/remove')'deleteMemories':false,
      });
      await widget.app.refresh();
      await _load();
    }catch(e){if(mounted)kakaNotice(context,e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override
  Widget build(BuildContext context)=>Scaffold(
    backgroundColor:KColors.bg,
    body:SafeArea(child:Column(children:[
      Padding(padding:const EdgeInsets.fromLTRB(13,12,16,18),
        child:Row(children:[
          KakaIconButton(icon:LucideIcons.arrowLeft,
            onTap:()=>Navigator.pop(context)),
          const SizedBox(width:10),
          Expanded(child:Text('Archive',style:Theme.of(context).textTheme.headlineMedium)),
          KakaIconButton(icon:LucideIcons.refreshCw,onTap:_load),
        ])),
      if(busy)const KakaLoadingRail(),
      Expanded(child:RefreshIndicator(onRefresh:_load,color:KColors.ink,
        child:ListView(padding:const EdgeInsets.fromLTRB(22,13,22,40),children:[
          if(error!=null)Text(error!,
            style:const TextStyle(color:KColors.error,fontSize:13)),
          if(bots.isEmpty&&groups.isEmpty&&!busy)
            const Padding(padding:EdgeInsets.only(top:65),child:Center(
              child:Text('No archived conversations',
                style:TextStyle(color:KColors.muted)))),
          if(bots.isNotEmpty)const Padding(
            padding:EdgeInsets.fromLTRB(5,4,0,12),
            child:Text('AGENTS',style:TextStyle(color:KColors.muted,fontSize:12))),
          for(final bot in bots)_tile('bots',bot),
          if(groups.isNotEmpty)const Padding(
            padding:EdgeInsets.fromLTRB(5,20,0,12),
            child:Text('GROUPS',style:TextStyle(color:KColors.muted,fontSize:12))),
          for(final group in groups)_tile('groups',group),
        ]))),
    ])),
  );
  Widget _tile(String kind,Map<String,dynamic> entry)=>Container(
    margin:const EdgeInsets.only(bottom:9),
    decoration:BoxDecoration(color:KColors.surface,
      borderRadius:BorderRadius.circular(25)),
    child:KakaRow(title:entry['name']?.toString()??'Archived',
      subtitle:kind=='bots'?'Agent':'Group',
      icon:kind=='bots'?LucideIcons.bot:LucideIcons.users,
      onTap:()=>_action(kind,entry)),
  );
}
