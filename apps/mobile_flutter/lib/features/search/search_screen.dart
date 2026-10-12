import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../app/app_controller.dart';
import '../../core/models.dart';
import '../../design/theme.dart';
import '../../design/widgets.dart';
import '../thread/thread_screen.dart';

class SearchScreen extends StatefulWidget {
  final AppController app;
  const SearchScreen({super.key,required this.app});
  @override
  State<SearchScreen> createState()=>_SearchScreenState();
}
class _SearchScreenState extends State<SearchScreen> {
  final query=TextEditingController();
  final focus=FocusNode();
  Timer? _debounce;
  int _generation=0;
  bool busy=false;
  String? error;
  List<Map<String,dynamic>> hits=[];
  @override
  void initState() {
    super.initState();
    query.addListener(_schedule);
    WidgetsBinding.instance.addPostFrameCallback((_){
      if(mounted)focus.requestFocus();
    });
  }
  void _schedule() {
    _debounce?.cancel();
    final generation=++_generation;
    if(query.text.trim().length<2) {
      setState((){hits=[];error=null;busy=false;});
      return;
    }
    _debounce=Timer(const Duration(milliseconds:320),() async {
      if(!mounted)return;
      setState(()=>busy=true);
      try{
        final rawQuery=query.text.trim();
        final safeQuery=rawQuery.length>200?rawQuery.substring(0,200):rawQuery;
        final result=await widget.app.api.rpc('search/query',{'q':safeQuery});
        if(!mounted||generation!=_generation)return;
        final raw=result is Map?result['hits']:null;
        setState((){
          hits=(raw is List?raw:const []).whereType<Map>()
            .map((m)=>Map<String,dynamic>.from(m)).toList();
          error=null;
        });
      }catch(e){
        if(mounted&&generation==_generation)setState(()=>error=e.toString());
      }finally{
        if(mounted&&generation==_generation)setState(()=>busy=false);
      }
    });
  }
  void _open(Map<String,dynamic> hit) {
    final botId=hit['botId']?.toString();
    final groupId=hit['groupId']?.toString();
    final group=groupId!=null && groupId.isNotEmpty;
    final id=group?groupId:botId;
    if(id==null||id.isEmpty)return;
    final bot=widget.app.bots.where((b)=>b.id==id).firstOrNull;
    final presentation=bot??KakaBot(id:id,
      name:'${group?hit['groupName']:hit['botName'] ?? hit['title']}',
      title:group?'Group chat':'Agent',
      preview:hit['snippet']?.toString()??'',color:'#161616',status:'',
      unread:false,pinned:false,updatedAt:'');
    Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>
      ThreadScreen(api:widget.app.api,bot:presentation,group:group)));
  }
  @override
  void dispose(){
    ++_generation;
    _debounce?.cancel();
    query.removeListener(_schedule);
    query.dispose();focus.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context)=>Scaffold(
    backgroundColor:KColors.bg,
    body:SafeArea(child:Column(children:[
      Padding(padding:const EdgeInsets.fromLTRB(12,14,18,18),
        child:Row(children:[
          KakaIconButton(icon:LucideIcons.arrowLeft,
            onTap:()=>Navigator.pop(context)),
          const SizedBox(width:8),
          Expanded(child:TextField(
            controller:query,focusNode:focus,
            style:const TextStyle(fontSize:16,color:KColors.ink),
            decoration:InputDecoration(
              hintText:'Search Kaka',hintStyle:const TextStyle(color:KColors.muted),
              prefixIcon:const Icon(LucideIcons.search,size:19),
              suffixIcon:query.text.isEmpty?null:GestureDetector(
                onTap:query.clear,
                child:const Icon(LucideIcons.x,size:17)),
              filled:true,fillColor:KColors.soft,
              border:OutlineInputBorder(borderSide:BorderSide.none,
                borderRadius:BorderRadius.circular(27)),
              contentPadding:const EdgeInsets.symmetric(vertical:15)))),
        ])),
      if(busy)const LinearProgressIndicator(color:KColors.ink),
      if(error!=null)Padding(padding:const EdgeInsets.fromLTRB(22,10,22,12),
        child:Text(error!,style:const TextStyle(fontSize:12,color:KColors.error))),
      Expanded(child:ListView.builder(
        keyboardDismissBehavior:ScrollViewKeyboardDismissBehavior.onDrag,
        padding:const EdgeInsets.fromLTRB(18,6,18,32),
        itemCount:hits.length+1,
        itemBuilder:(context,index){
          if(index==0) {
            if(query.text.trim().length<2)return const Padding(
              padding:EdgeInsets.symmetric(vertical:45),
              child:Center(child:Text('Search messages, conversations and files',
                style:TextStyle(color:KColors.muted,fontSize:13))));
            if(hits.isEmpty&&!busy&&error==null)return const Padding(
              padding:EdgeInsets.symmetric(vertical:45),
              child:Center(child:Text('No results found',
                style:TextStyle(color:KColors.muted,fontSize:13))));
            return const SizedBox(height:8);
          }
          final hit=hits[index-1];
          final kind=hit['kind']?.toString()??'message';
          final icon=switch(kind){
            'file'=>LucideIcons.file,
            'link'=>LucideIcons.link,
            'routine'=>LucideIcons.calendarClock,
            'conversation'=>LucideIcons.messageCircle,
            _=>LucideIcons.messageSquare,
          };
          return GestureDetector(onTap:()=>_open(hit),child:Container(
            margin:const EdgeInsets.only(bottom:9),
            padding:const EdgeInsets.all(17),
            decoration:BoxDecoration(color:KColors.surface,
              borderRadius:BorderRadius.circular(24)),
            child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Icon(icon,size:21,color:KColors.ink),
              const SizedBox(width:13),
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text(hit['title']?.toString()??'Result',maxLines:1,
                  overflow:TextOverflow.ellipsis,
                  style:const TextStyle(fontWeight:FontWeight.w600,fontSize:14)),
                const SizedBox(height:4),
                Text(hit['snippet']?.toString()??'',
                  maxLines:3,overflow:TextOverflow.ellipsis,
                  style:const TextStyle(color:KColors.muted,fontSize:13,height:1.45)),
              ])),
            ]),
          ));
        })),
    ])),
  );
}
