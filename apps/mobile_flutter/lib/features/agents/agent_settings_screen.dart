import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../core/api.dart';
import '../../core/models.dart';
import '../../design/theme.dart';
import '../../design/widgets.dart';
import '../avatar/avatar_editor.dart';
import '../routines/routines_screen.dart';
import '../mcp/mcp_screen.dart';
import '../memory/memory_screen.dart';
import '../artifacts/artifact_library_screen.dart';
import '../avatar/avatar_settings.dart';

class AgentSettingsScreen extends StatefulWidget {
  final KakaApi api;
  final KakaBot bot;
  const AgentSettingsScreen({super.key,required this.api,required this.bot});
  @override
  State<AgentSettingsScreen> createState()=>_AgentSettingsScreenState();
}

class _AgentSettingsScreenState extends State<AgentSettingsScreen> {
  final name=TextEditingController();
  final title=TextEditingController();
  final description=TextEditingController();
  final instructions=TextEditingController();
  bool loading=true, saving=false, pinned=false, notifyOnFinish=true;
  String? error;
  String? provider, modelId;
  List<Map<String,dynamic>> models=[];

  @override
  void initState(){super.initState();_load();}
  @override
  void dispose(){
    name.dispose();title.dispose();description.dispose();instructions.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try{
      final data=await Future.wait([
        widget.api.rpc('bots/get',{'botId':widget.bot.id}),
        widget.api.rpc('models/credentials').catchError((Object _)=><dynamic>[]),
      ]);
      if(!mounted)return;
      final agent=Map<String,dynamic>.from(data[0] as Map);
      name.text=agent['name']?.toString()??'';
      title.text=agent['title']?.toString()??'';
      description.text=agent['description']?.toString()??'';
      instructions.text=agent['instructions']?.toString()??'';
      setState((){
        pinned=agent['pinned']==true;
        notifyOnFinish=agent['notifyOnFinish']!=false;
        provider=agent['modelProvider']?.toString();
        modelId=agent['modelId']?.toString();
        models=(data[1] as List).whereType<Map>()
          .map((m)=>Map<String,dynamic>.from(m)).toList();
      });
    }catch(e){if(mounted)setState(()=>error=e.toString());}
    finally{if(mounted)setState(()=>loading=false);}
  }

  Future<void> _save() async {
    if(name.text.trim().isEmpty){kakaNotice(context,'Name is required');return;}
    setState((){saving=true;error=null;});
    try {
      await widget.api.rpc('bots/update',{
        'botId':widget.bot.id,
        'name':name.text.trim(),
        'title':title.text.trim(),
        'description':description.text.trim(),
        'instructions':instructions.text.trim(),
        'pinned':pinned,
        'notifyOnFinish':notifyOnFinish,
        if(provider!=null && modelId!=null)...{
          'modelProvider':provider,'modelId':modelId,
        },
      });
      if(mounted){kakaNotice(context,'Agent updated');Navigator.of(context).pop(true);}
    }catch(e){if(mounted)setState(()=>error=e.toString());}
    finally{if(mounted)setState(()=>saving=false);}
  }

  Future<void> _chooseModel() async {
    final choices=<({String provider,String modelId,String label})>[];
    for(final credential in models){
      final p=credential['provider']?.toString()??'';
      final m=credential['modelId']?.toString()??'';
      if(p.isNotEmpty&&m.isNotEmpty){
        choices.add((provider:p,modelId:m,label:'${credential['label']??m}'));
      }
    }
    final chosen=await kakaSheet<({String provider,String modelId})?>(context,Column(
      mainAxisSize:MainAxisSize.min,
      crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('Agent model',style:Theme.of(context).textTheme.titleLarge),
        const SizedBox(height:14),
        KakaRow(title:'Use workspace default',icon:LucideIcons.circle,
          onTap:()=>Navigator.pop(context,null)),
        for(final choice in choices)KakaRow(
          title:choice.label,subtitle:choice.modelId,icon:LucideIcons.cpu,
          onTap:()=>Navigator.pop(context,(provider:choice.provider,modelId:choice.modelId))),
      ]));
    if(!mounted)return;
    // null is also the default choice; an explicit selection is distinguishable
    // only via a sentinel in the modal payload, so use a separate default action.
    if(chosen!=null)setState((){
      provider=chosen.provider;modelId=chosen.modelId;
    });
  }

  Future<void> _archive() async {
    final yes=await kakaSheet<bool>(context,Column(
      mainAxisSize:MainAxisSize.min,
      crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Text('Archive ${widget.bot.name}?',style:Theme.of(context).textTheme.titleLarge),
        const SizedBox(height:13),
        const Text('The conversation can be restored later.',
          style:TextStyle(color:KColors.muted,fontSize:14)),
        const SizedBox(height:20),
        KakaButton(title:'Archive agent',onPressed:()=>Navigator.pop(context,true)),
        const SizedBox(height:9),
        KakaButton(title:'Cancel',filled:false,onPressed:()=>Navigator.pop(context,false)),
      ]));
    if(yes!=true)return;
    try{
      await widget.api.rpc('bots/archive',{'botId':widget.bot.id});
      if(mounted)Navigator.of(context).pop(true);
    }catch(e){if(mounted)kakaNotice(context,e.toString());}
  }

  @override
  Widget build(BuildContext context)=>KakaDepthStage(child:Scaffold(
    backgroundColor:KColors.bg,
    body:SafeArea(child:Column(children:[
      KakaPageHeader(
        title:Text('Agent settings',
          style:Theme.of(context).textTheme.titleLarge),
        actions:[
          KakaIconButton(icon:LucideIcons.check,filled:true,
            tooltip:'Save agent',onTap:saving?null:_save),
        ],
      ),
      Expanded(child:loading?const Center(child:KakaLoadingDots())
        :KakaContentWidth(child:ListView(padding:const EdgeInsets.fromLTRB(KLayout.pageGutter,12,KLayout.pageGutter,40),children:[
          Center(child:AgentAvatar(botId:widget.bot.id,size:94)),
          const SizedBox(height:12),
          Center(child:SizedBox(width:194,
            child:KakaButton(title:'Customize avatar',filled:false,
              onPressed:()=>Navigator.of(context).push(MaterialPageRoute<void>(
                builder:(_)=>AvatarEditor(bot:widget.bot)))))),
          const SizedBox(height:26),
          KakaField(controller:name,label:'Name'),
          const SizedBox(height:14),
          KakaField(controller:title,label:'Title'),
          const SizedBox(height:14),
          KakaField(controller:description,label:'Description',maxLines:3),
          const SizedBox(height:14),
          KakaField(controller:instructions,label:'Instructions',maxLines:6),
          const SizedBox(height:25),
          KakaSection(title:'PREFERENCES',child:Column(children:[
            KakaRow(title:'Files',icon:LucideIcons.folder,
              onTap:()=>Navigator.push(context,MaterialPageRoute<void>(
                builder:(_)=>ArtifactLibraryScreen(api:widget.api,botId:widget.bot.id)))),
            KakaRow(title:'Memory',icon:LucideIcons.notebookText,
              onTap:()=>Navigator.push(context,MaterialPageRoute<void>(
                builder:(_)=>MemoryScreen(api:widget.api,botId:widget.bot.id)))),
            KakaRow(title:'MCP tools',icon:LucideIcons.plug,
              onTap:()=>Navigator.push(context,MaterialPageRoute<void>(
                builder:(_)=>McpScreen(api:widget.api,botId:widget.bot.id)))),
            KakaRow(title:'Routines',icon:LucideIcons.calendarClock,
              onTap:()=>Navigator.push(context,MaterialPageRoute<void>(
                builder:(_)=>RoutinesScreen(api:widget.api,bot:widget.bot)))),
            KakaRow(title:'Model',subtitle:modelId ?? 'Workspace default',
              icon:LucideIcons.cpu,onTap:_chooseModel),
            KakaRow(title:'Pin agent',icon:LucideIcons.pin,
              onTap:()=>setState(()=>pinned=!pinned),
              trailing:KakaSwitch(value:pinned,
                onChanged:(v)=>setState(()=>pinned=v))),
            KakaRow(title:'Notify when finished',icon:LucideIcons.bell,
              onTap:()=>setState(()=>notifyOnFinish=!notifyOnFinish),
              trailing:KakaSwitch(value:notifyOnFinish,
                onChanged:(v)=>setState(()=>notifyOnFinish=v))),
          ])),
          if(error!=null)Padding(padding:const EdgeInsets.only(top:18),
            child:Text(error!,style:const TextStyle(color:KColors.error))),
          const SizedBox(height:26),
          KakaButton(title:'Save changes',busy:saving,onPressed:_save),
          const SizedBox(height:12),
          KakaButton(title:'Archive agent',filled:false,onPressed:_archive),
        ]))),
    ])),
  ));
}
