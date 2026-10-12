import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../core/api.dart';
import '../../core/models.dart';
import '../../design/theme.dart';
import '../../design/widgets.dart';
import '../avatar/avatar_settings.dart';

class GroupSettingsScreen extends StatefulWidget {
  final KakaApi api;
  final String groupId;
  const GroupSettingsScreen({super.key,required this.api,required this.groupId});
  @override
  State<GroupSettingsScreen> createState()=>_GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  final name=TextEditingController();
  final selected=<String>{};
  List<KakaBot> bots=[];
  bool loading=true,busy=false,pinned=false;
  String? error;

  @override
  void initState(){super.initState();_load();}
  @override
  void dispose(){name.dispose();super.dispose();}
  Future<void> _load() async {
    setState(()=>loading=true);
    try{
      final results=await Future.wait<dynamic>([
        widget.api.rpc('groups/get',{'groupId':widget.groupId}),
        widget.api.rpc('bots/list'),
      ]);
      if(!mounted)return;
      final group=Map<String,dynamic>.from(results[0] as Map);
      final members=(group['members'] as List?)??const [];
      name.text=group['name']?.toString()??'';
      setState((){
        pinned=group['pinned']==true;
        selected.clear();
        selected.addAll(members.whereType<Map>().map((m)=>m['botId']?.toString()??'')
          .where((id)=>id.isNotEmpty));
        bots=(results[1] as List).whereType<Map>()
          .map((m)=>KakaBot.fromJson(Map<String,dynamic>.from(m))).toList();
        error=null;
      });
    }catch(e){if(mounted)setState(()=>error=e.toString());}
    finally{if(mounted)setState(()=>loading=false);}
  }

  Future<void> _save() async {
    if(name.text.trim().isEmpty || selected.length<2 || selected.length>6){
      kakaNotice(context,'Group needs a name and 2–6 members');
      return;
    }
    if(busy)return;
    setState(()=>busy=true);
    try{
      await widget.api.rpc('groups/update',{
        'groupId':widget.groupId,
        'name':name.text.trim(),
        'pinned':pinned,
        'botIds':selected.toList(),
      });
      if(mounted)Navigator.pop(context,true);
    }catch(e){if(mounted)setState(()=>error=e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }

  Future<void> _archive() async {
    final approved=await kakaSheet<bool>(context,Column(
      mainAxisSize:MainAxisSize.min,
      crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Text('Archive this group?',style:Theme.of(context).textTheme.titleLarge),
        const SizedBox(height:13),
        const Text('Group messages will remain available to restore later.',
          style:TextStyle(color:KColors.muted,fontSize:13)),
        const SizedBox(height:19),
        KakaButton(title:'Archive group',onPressed:()=>Navigator.pop(context,true)),
        const SizedBox(height:9),
        KakaButton(title:'Cancel',filled:false,onPressed:()=>Navigator.pop(context,false)),
      ]));
    if(approved!=true)return;
    try{
      await widget.api.rpc('groups/archive',{'groupId':widget.groupId});
      if(mounted)Navigator.pop(context,true);
    }catch(e){if(mounted)kakaNotice(context,e.toString());}
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    backgroundColor:KColors.bg,
    body:SafeArea(child:Column(children:[
      Padding(padding:const EdgeInsets.fromLTRB(13,12,16,15),
        child:Row(children:[
          KakaIconButton(icon:LucideIcons.arrowLeft,onTap:()=>Navigator.pop(context)),
          const SizedBox(width:10),
          Expanded(child:Text('Group settings',
            style:Theme.of(context).textTheme.headlineMedium)),
          KakaIconButton(icon:LucideIcons.check,onTap:busy?null:_save,filled:true),
        ])),
      Expanded(child:loading?const Center(child:CircularProgressIndicator(color:KColors.ink))
        :ListView(padding:const EdgeInsets.fromLTRB(22,10,22,36),children:[
          const SizedBox(height:8),
          KakaField(controller:name,label:'Group name',hint:'Team discussion'),
          const SizedBox(height:24),
          KakaSection(title:'PREFERENCES',child:KakaRow(
            title:'Pin conversation',icon:LucideIcons.pin,
            trailing:KakaSwitch(value:pinned,
              onChanged:(v)=>setState(()=>pinned=v)))),
          const SizedBox(height:23),
          Text('MEMBERS · ${selected.length}/6',
            style:const TextStyle(fontSize:12,color:KColors.muted)),
          const SizedBox(height:11),
          for(final bot in bots)GestureDetector(
            onTap:()=>setState((){
              if(selected.contains(bot.id)){if(selected.length>2)selected.remove(bot.id);}
              else if(selected.length<6){selected.add(bot.id);}
            }),
            child:Container(
              margin:const EdgeInsets.only(bottom:8),
              padding:const EdgeInsets.all(13),
              decoration:BoxDecoration(
                color:selected.contains(bot.id)?KColors.soft:KColors.surface,
                borderRadius:BorderRadius.circular(23)),
              child:Row(children:[
                AgentAvatar(botId:bot.id,size:37),
                const SizedBox(width:13),
                Expanded(child:Text(bot.name,style:const TextStyle(fontSize:14))),
                Icon(selected.contains(bot.id)
                  ?LucideIcons.circleCheck:LucideIcons.circle,
                  size:19,color:KColors.ink),
              ]),
            ),
          ),
          if(error!=null)Padding(padding:const EdgeInsets.only(top:12),
            child:Text(error!,style:const TextStyle(fontSize:13,color:KColors.error))),
          const SizedBox(height:22),
          KakaButton(title:'Save group',busy:busy,onPressed:_save),
          const SizedBox(height:11),
          KakaButton(title:'Archive group',filled:false,onPressed:_archive),
        ])),
    ])),
  );
}
