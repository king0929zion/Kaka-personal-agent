import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../core/api.dart';
import '../../core/models.dart';
import '../../design/theme.dart';
import '../../design/widgets.dart';

class RoutinesScreen extends StatefulWidget {
  final KakaApi api;
  final KakaBot bot;
  const RoutinesScreen({super.key,required this.api,required this.bot});
  @override
  State<RoutinesScreen> createState()=>_RoutinesScreenState();
}

class _RoutinesScreenState extends State<RoutinesScreen> {
  List<Map<String,dynamic>> items=[];
  String? error;
  bool loading=true,busy=false;

  @override
  void initState(){super.initState();_refresh();}
  Future<void> _refresh() async {
    if(mounted)setState(()=>loading=true);
    try{
      final data=await widget.api.rpc('routines/list',{'botId':widget.bot.id});
      if(!mounted)return;
      setState((){
        items=(data as List).whereType<Map>()
          .map((m)=>Map<String,dynamic>.from(m)).toList();
        error=null;
      });
    }catch(e){if(mounted)setState(()=>error=e.toString());}
    finally{if(mounted)setState(()=>loading=false);}
  }

  Future<void> _create() async {
    final name=TextEditingController(),prompt=TextEditingController(),
      schedule=TextEditingController(text:'0 9 * * *'),
      timezone=TextEditingController(text:'UTC');
    String? validation;
    var isEnabled=true;
    var notify=true;
    var creating=false;
    try{
      await kakaSheet<void>(context,StatefulBuilder(builder:(ctx,update)=>
        SingleChildScrollView(child:Column(
          mainAxisSize:MainAxisSize.min,
          crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            Text('New routine',style:Theme.of(ctx).textTheme.headlineMedium),
            const SizedBox(height:18),
            KakaField(controller:name,label:'Name',hint:'Daily briefing'),
            const SizedBox(height:14),
            KakaField(controller:prompt,label:'Instructions',
              hint:'What should the agent do?',maxLines:4),
            const SizedBox(height:14),
            KakaField(controller:schedule,label:'Cron schedule (5 fields)',
              hint:'0 9 * * *'),
            const SizedBox(height:14),
            KakaField(controller:timezone,label:'Timezone',hint:'UTC'),
            const SizedBox(height:13),
            KakaRow(title:'Enable routine',icon:LucideIcons.clock,
              trailing:KakaSwitch(value:isEnabled,
                onChanged:(v)=>update(()=>isEnabled=v))),
            KakaRow(title:'Notify on completion',icon:LucideIcons.bell,
              trailing:KakaSwitch(value:notify,
                onChanged:(v)=>update(()=>notify=v))),
            if(validation!=null)Padding(padding:const EdgeInsets.symmetric(vertical:12),
              child:Text(validation!,style:const TextStyle(color:KColors.error,fontSize:13))),
            const SizedBox(height:17),
            KakaButton(title:'Create routine',busy:creating,onPressed:() async {
              final cron=schedule.text.trim();
              if(name.text.trim().isEmpty||prompt.text.trim().isEmpty||
                  cron.split(RegExp(r'\s+')).length!=5||timezone.text.trim().isEmpty){
                update(()=>validation='Enter a name, instructions, timezone and a 5-field cron');
                return;
              }
              update(()=>creating=true);
              try {
                await widget.api.rpc('routines/create',{
                  'botId':widget.bot.id,
                  'name':name.text.trim(),
                  'prompt':prompt.text.trim(),
                  'crons':[cron],
                  'timezone':timezone.text.trim(),
                  'active':isEnabled,
                  'notify':notify,
                });
                if(ctx.mounted)Navigator.pop(ctx);
                await _refresh();
              }catch(e){if(ctx.mounted)update(()=>validation=e.toString());}
              finally{if(ctx.mounted)update(()=>creating=false);}
            }),
          ]),
        )));
    }finally {
      WidgetsBinding.instance.addPostFrameCallback((_){
        name.dispose();prompt.dispose();schedule.dispose();timezone.dispose();
      });
    }
  }

  Future<void> _toggle(Map<String,dynamic> item) async {
    if(busy)return;
    setState(()=>busy=true);
    try{
      await widget.api.rpc('routines/update',{
        'routineId':item['id'],
        'active':item['active']!=true,
      });
      await _refresh();
    }catch(e){if(mounted)kakaNotice(context,e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }

  Future<void> _run(Map<String,dynamic> item) async {
    if(busy)return;
    setState(()=>busy=true);
    try {
      await widget.api.rpc('routines/testRun',{'routineId':item['id']});
      if(mounted)kakaNotice(context,'Test run started');
    }catch(e){if(mounted)kakaNotice(context,e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }

  Future<void> _remove(Map<String,dynamic> item) async {
    final confirmed=await kakaSheet<bool>(context,Column(
      mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,
      children:[
        Text('Delete routine?',style:Theme.of(context).textTheme.titleLarge),
        const SizedBox(height:9),
        Text(item['name']?.toString()??'',style:const TextStyle(color:KColors.muted)),
        const SizedBox(height:18),
        KakaButton(title:'Delete',onPressed:()=>Navigator.pop(context,true)),
        const SizedBox(height:9),
        KakaButton(title:'Cancel',filled:false,onPressed:()=>Navigator.pop(context,false)),
      ]));
    if(confirmed!=true)return;
    try {
      await widget.api.rpc('routines/remove',{'routineId':item['id']});
      await _refresh();
    }catch(e){if(mounted)kakaNotice(context,e.toString());}
  }

  void _details(Map<String,dynamic> item) {
    kakaSheet<void>(context,SingleChildScrollView(child:Column(
      mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,
      children:[
        Text(item['name']?.toString()??'Routine',
          style:Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height:12),
        Text(item['prompt']?.toString()??'',
          style:const TextStyle(fontSize:14,height:1.45)),
        const SizedBox(height:12),
        Text('Schedule: ${(item['crons'] as List?)?.join(', ')??'None'}',
          style:const TextStyle(fontSize:12,color:KColors.muted)),
        Text('Timezone: ${item['timezone']??'UTC'}',
          style:const TextStyle(fontSize:12,color:KColors.muted)),
        const SizedBox(height:16),
        KakaButton(title:'Run now',onPressed:(){
          Navigator.pop(context);
          _run(item);
        }),
        const SizedBox(height:9),
        KakaButton(title:item['active']==true?'Disable routine':'Enable routine',
          filled:false,onPressed:(){
            Navigator.pop(context);
            _toggle(item);
          }),
        const SizedBox(height:9),
        KakaButton(title:'Delete routine',filled:false,onPressed:(){
          Navigator.pop(context);
          _remove(item);
        }),
      ]),
    )));
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    backgroundColor:KColors.bg,
    body:SafeArea(child:Column(children:[
      Padding(padding:const EdgeInsets.fromLTRB(13,12,17,15),child:Row(children:[
        KakaIconButton(icon:LucideIcons.arrowLeft,onTap:()=>Navigator.pop(context)),
        const SizedBox(width:10),
        Expanded(child:Text('Routines',style:Theme.of(context).textTheme.headlineMedium)),
        KakaIconButton(icon:LucideIcons.plus,onTap:_create,filled:true),
      ])),
      if(loading||busy)const LinearProgressIndicator(color:KColors.ink),
      Expanded(child:RefreshIndicator(onRefresh:_refresh,color:KColors.ink,
        child:ListView(padding:const EdgeInsets.fromLTRB(22,13,22,30),children:[
          Text(widget.bot.name,style:const TextStyle(
            fontSize:13,color:KColors.muted)),
          const SizedBox(height:18),
          if(error!=null)Padding(padding:const EdgeInsets.only(bottom:13),
            child:Text(error!,style:const TextStyle(color:KColors.error))),
          if(items.isEmpty)Container(padding:const EdgeInsets.all(26),
            decoration:BoxDecoration(color:KColors.surface,
              borderRadius:BorderRadius.circular(28)),
            child:const Column(children:[
              Icon(LucideIcons.calendarClock,size:35,color:KColors.ink),
              SizedBox(height:16),
              Text('No routines yet',style:TextStyle(fontWeight:FontWeight.w600,fontSize:16)),
              SizedBox(height:6),
              Text('Schedule recurring actions for this agent.',
                style:TextStyle(fontSize:13,color:KColors.muted)),
            ])),
          for(final item in items)Padding(padding:const EdgeInsets.only(bottom:9),
            child:GestureDetector(onTap:()=>_details(item),child:Container(
              padding:const EdgeInsets.all(17),
              decoration:BoxDecoration(color:KColors.surface,
                borderRadius:BorderRadius.circular(25)),
              child:Row(children:[
                Icon(item['active']==true?LucideIcons.calendarCheck:LucideIcons.calendarClock,
                  color:KColors.ink,size:23),
                const SizedBox(width:13),
                Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Text(item['name']?.toString()??'Routine',
                    style:const TextStyle(fontWeight:FontWeight.w600,fontSize:15)),
                  const SizedBox(height:4),
                  Text(item['nextRunAt']?.toString()??'Not scheduled',
                    style:const TextStyle(color:KColors.muted,fontSize:12),
                    maxLines:1,overflow:TextOverflow.ellipsis),
                ])),
                Icon(item['active']==true?LucideIcons.check:LucideIcons.pause,
                  size:17,color:KColors.muted),
              ]),
            ))),
        ]))),
    ])),
  );
}
