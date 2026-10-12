import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../app/app_controller.dart';
import '../../core/models.dart';
import '../../design/theme.dart';
import '../../design/widgets.dart';
import '../../design/kinetic_interactions.dart';
import '../thread/thread_screen.dart';

class ActivityScreen extends StatefulWidget {
  final AppController app;
  final bool embedded;
  const ActivityScreen({super.key,required this.app,this.embedded=false});
  @override
  State<ActivityScreen> createState()=>_ActivityScreenState();
}
class _ActivityScreenState extends State<ActivityScreen> {
  String filter='active';
  List<Map<String,dynamic>> runs=[];
  bool loading=true;
  String? error;
  @override
  void initState(){super.initState();_refresh();}
  Future<void> _refresh() async {
    setState(()=>loading=true);
    try{
      final data=await widget.app.api.rpc('runs/list',{'filter':filter});
      if(!mounted)return;
      final raw=data is Map?data['runs']:null;
      setState((){
        runs=(raw is List?raw:const []).whereType<Map>()
          .map((m)=>Map<String,dynamic>.from(m)).toList();
        error=null;
      });
    }catch(e){if(mounted)setState(()=>error=e.toString());}
    finally{if(mounted)setState(()=>loading=false);}
  }
  void _setFilter(String value){
    if(filter==value)return;
    setState(()=>filter=value);
    _refresh();
  }
  void _open(Map<String,dynamic> row){
    final groupId=row['groupId']?.toString();
    final group=groupId!=null&&groupId.isNotEmpty;
    final id=group?groupId:row['botId']?.toString();
    if(id==null||id.isEmpty)return;
    final bot=widget.app.bots.where((b)=>b.id==id).firstOrNull;
    final pseudo=bot??KakaBot(
      id:id,name:group?(row['groupName']?.toString()??'Group')
        :(row['botName']?.toString()??'Agent'),
      title:group?'Group conversation':'Personal agent',
      preview:row['promptSnippet']?.toString()??'',
      color:'#161616',status:'',pinned:false,unread:false,updatedAt:'');
    Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>
      ThreadScreen(api:widget.app.api,bot:pseudo,group:group)));
  }
  @override
  Widget build(BuildContext context) {
    final body=Column(children:[
      if(!widget.embedded) Padding(padding:const EdgeInsets.fromLTRB(14,11,16,16),
        child:Row(children:[
          KakaIconButton(icon:LucideIcons.arrowLeft,onTap:()=>Navigator.pop(context)),
          const SizedBox(width:10),
          Expanded(child:Text('Activity',
            style:Theme.of(context).textTheme.headlineMedium)),
          KakaIconButton(icon:LucideIcons.refreshCw,onTap:_refresh),
        ])),
      Padding(padding:const EdgeInsets.symmetric(horizontal:22),child:Row(children:[
        for(final value in ['active','recent'])Expanded(
          child:GestureDetector(onTap:()=>_setFilter(value),
            child:AnimatedContainer(duration:const Duration(milliseconds:160),
              margin:const EdgeInsets.only(right:8),height:43,
              alignment:Alignment.center,
              decoration:BoxDecoration(
                color:filter==value?KColors.ink:KColors.soft,
                borderRadius:BorderRadius.circular(22)),
              child:Text(value=='active'?'Active':'Recent',
                style:TextStyle(fontSize:14,
                  color:filter==value?Colors.white:KColors.ink,
                  fontWeight:FontWeight.w600))))),
      ])),
      const SizedBox(height:12),
      if(loading)const KakaLoadingRail(),
      Expanded(child:KakaPullToRefresh(onRefresh:_refresh,
        child:ListView.builder(
          physics:const AlwaysScrollableScrollPhysics(parent:ClampingScrollPhysics()),
          padding:const EdgeInsets.fromLTRB(22,8,22,widget.embedded?140:30),
          itemCount:runs.isEmpty?1:runs.length,
          itemBuilder:(context,index){
            if(runs.isEmpty)return Padding(padding:const EdgeInsets.only(top:70),
              child:Center(child:Text(error??'No ${filter=='active'?'active':'recent'} runs',
                textAlign:TextAlign.center,
                style:TextStyle(color:error==null?KColors.muted:KColors.error,
                  fontSize:14))));
            final run=runs[index];
            final status=run['status']?.toString()??'unknown';
            return GestureDetector(onTap:()=>_open(run),
              child:Container(
                margin:const EdgeInsets.only(bottom:9),
                padding:const EdgeInsets.all(17),
                decoration:BoxDecoration(color:KColors.surface,
                  borderRadius:BorderRadius.circular(25)),
                child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Icon(status=='completed'?LucideIcons.checkCircle2:
                      status=='failed'?LucideIcons.circleAlert:
                      LucideIcons.circleDot,size:21,color:KColors.ink),
                  const SizedBox(width:13),
                  Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,
                    children:[
                      Text(run['groupName']?.toString()??run['botName']?.toString()??'Agent',
                        style:const TextStyle(fontSize:15,fontWeight:FontWeight.w600)),
                      const SizedBox(height:4),
                      Text(run['promptSnippet']?.toString()??'',
                        maxLines:2,overflow:TextOverflow.ellipsis,
                        style:const TextStyle(color:KColors.muted,fontSize:13)),
                      const SizedBox(height:7),
                      Text('${run['trigger']??'user'} · $status',
                        style:const TextStyle(fontSize:11,color:KColors.muted)),
                    ])),
                  const Icon(LucideIcons.chevronRight,size:16,color:KColors.muted),
                ])),
            );
          }))),
    ]);
    return widget.embedded
        ? KakaContentWidth(child:body)
        : Scaffold(
            backgroundColor:KColors.bg,
            body:SafeArea(child:KakaContentWidth(child:body)),
          );
  }
}
