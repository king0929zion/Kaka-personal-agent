import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../core/api.dart';
import '../../design/theme.dart';
import '../../design/widgets.dart';

/// MCP servers are managed on the backend. App never runs arbitrary stdio
/// processes locally or receives a stored credential from the server.
class McpScreen extends StatefulWidget {
  final KakaApi api;
  final String? botId;
  const McpScreen({super.key,required this.api,this.botId});
  @override
  State<McpScreen> createState()=>_McpScreenState();
}
class _McpScreenState extends State<McpScreen> {
  List<Map<String,dynamic>> servers=[],assignments=[];
  bool loading=true,busy=false;
  String? error;
  @override
  void initState(){super.initState();_refresh();}
  Future<void> _refresh() async {
    if(mounted)setState(()=>loading=true);
    try {
      final replies=await Future.wait<dynamic>([
        widget.api.rpc('mcp/servers/list'),
        if(widget.botId!=null)widget.api.rpc(
          'mcp/assignments/list',{'botId':widget.botId}),
      ]);
      if(!mounted)return;
      setState((){
        servers=(replies[0] as List).whereType<Map>()
          .map((m)=>Map<String,dynamic>.from(m)).toList();
        assignments=widget.botId==null?[]:(replies[1] as List).whereType<Map>()
          .map((m)=>Map<String,dynamic>.from(m)).toList();
        error=null;
      });
    }catch(e){if(mounted)setState(()=>error=e.toString());}
    finally{if(mounted)setState(()=>loading=false);}
  }

  Future<void> _create() async {
    final name=TextEditingController(),slug=TextEditingController(),
      endpoint=TextEditingController(),secret=TextEditingController();
    var transport='streamable_http';
    String? validation;
    var creating=false;
    try{
      await kakaSheet<void>(context,StatefulBuilder(builder:(ctx,update)=>
        SingleChildScrollView(child:Column(
          mainAxisSize:MainAxisSize.min,
          crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            Text('New MCP server',style:Theme.of(ctx).textTheme.headlineMedium),
            const SizedBox(height:17),
            KakaField(controller:name,label:'Server name',hint:'My MCP server'),
            const SizedBox(height:13),
            KakaField(controller:slug,label:'Unique ID',hint:'my-mcp-server'),
            const SizedBox(height:13),
            KakaField(controller:endpoint,label:'HTTPS endpoint',
              hint:'https://example.com/mcp',keyboardType:TextInputType.url),
            const SizedBox(height:13),
            KakaField(controller:secret,label:'Secret (optional)',obscure:true),
            const SizedBox(height:17),
            Row(children:[
              for(final value in ['streamable_http','sse'])
                Expanded(child:GestureDetector(onTap:()=>update(()=>transport=value),
                  child:Container(
                    alignment:Alignment.center,height:42,
                    margin:const EdgeInsets.only(right:8),
                    decoration:BoxDecoration(
                      color:transport==value?KColors.ink:KColors.soft,
                      borderRadius:BorderRadius.circular(21)),
                    child:Text(value=='sse'?'SSE':'Streamable HTTP',
                      style:TextStyle(fontSize:12,fontWeight:FontWeight.w600,
                        color:transport==value?Colors.white:KColors.ink))))),
            ]),
            if(validation!=null)Padding(padding:const EdgeInsets.only(top:12),
              child:Text(validation!,style:const TextStyle(
                color:KColors.error,fontSize:13))),
            const SizedBox(height:18),
            KakaButton(title:'Create MCP server',busy:creating,onPressed:() async {
              final uri=Uri.tryParse(endpoint.text.trim());
              if(name.text.trim().isEmpty||
                  !RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$').hasMatch(slug.text.trim())||
                  uri==null||uri.scheme!='https'||uri.host.isEmpty){
                update(()=>validation='Enter a name, valid ID and HTTPS endpoint');
                return;
              }
              update(()=>creating=true);
              try{
                await widget.api.rpc('mcp/servers/create',{
                  'slug':slug.text.trim(),
                  'name':name.text.trim(),
                  'transport':transport,
                  'endpoint':uri.toString(),
                  if(secret.text.isNotEmpty)'secret':secret.text,
                });
                if(ctx.mounted)Navigator.pop(ctx);
                await _refresh();
              }catch(e){if(ctx.mounted)update(()=>validation=e.toString());}
              finally{if(ctx.mounted)update(()=>creating=false);}
            }),
          ]),
        )));
    }finally{
      WidgetsBinding.instance.addPostFrameCallback((_){
        name.dispose();slug.dispose();endpoint.dispose();secret.dispose();
      });
    }
  }

  Future<void> _toggleAssignment(Map<String,dynamic> server) async {
    if(widget.botId==null||busy)return;
    final id=server['id']?.toString()??'';
    final existing=assignments.where((a)=>a['serverId']==id).firstOrNull;
    if(existing==null){
      final ok=await kakaSheet<bool>(context,Column(
        mainAxisSize:MainAxisSize.min,
        crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          Text('Give this agent MCP access?',
            style:Theme.of(context).textTheme.titleLarge),
          const SizedBox(height:10),
          Text('Allow all tools exposed by ${server['name']??'this server'}? Only connect servers you trust.',
            style:const TextStyle(fontSize:13,color:KColors.muted,height:1.5)),
          const SizedBox(height:18),
          KakaButton(title:'Allow tools',onPressed:()=>Navigator.pop(context,true)),
          const SizedBox(height:9),
          KakaButton(title:'Cancel',filled:false,onPressed:()=>Navigator.pop(context,false)),
        ]));
      if(ok!=true)return;
    }
    setState(()=>busy=true);
    try{
      final choices=[
        for(final item in assignments)
          if(item['serverId']!=id){
            'serverId':item['serverId'],
            'allowAllTools':item['allowAllTools']==true,
            'allowedTools':item['allowedTools']??const <String>[],
          },
        if(existing==null){
          'serverId':id,'allowAllTools':true,'allowedTools':<String>[],
        },
      ];
      await widget.api.rpc('mcp/assignments/replace',{
        'botId':widget.botId,'assignments':choices,
      });
      await _refresh();
    }catch(e){if(mounted)kakaNotice(context,e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }

  Future<void> _remove(Map<String,dynamic> server) async {
    final id=server['id']?.toString()??'';
    final ok=await kakaSheet<bool>(context,Column(
      mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Text('Remove MCP server?',style:Theme.of(context).textTheme.titleLarge),
        const SizedBox(height:11),
        Text(server['name']?.toString()??'',
          style:const TextStyle(color:KColors.muted)),
        const SizedBox(height:19),
        KakaButton(title:'Remove server',onPressed:()=>Navigator.pop(context,true)),
        const SizedBox(height:9),
        KakaButton(title:'Cancel',filled:false,onPressed:()=>Navigator.pop(context,false)),
      ]));
    if(ok!=true)return;
    try{
      await widget.api.rpc('mcp/servers/remove',{'id':id});
      await _refresh();
    }catch(e){if(mounted)kakaNotice(context,e.toString());}
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    backgroundColor:KColors.bg,
    body:SafeArea(child:Column(children:[
      Padding(padding:const EdgeInsets.fromLTRB(13,12,17,15),child:Row(children:[
        KakaIconButton(icon:LucideIcons.arrowLeft,onTap:()=>Navigator.pop(context)),
        const SizedBox(width:9),
        Expanded(child:Text(widget.botId==null?'MCP servers':'Agent MCP tools',
          style:Theme.of(context).textTheme.headlineMedium)),
        if(widget.botId==null)KakaIconButton(
          icon:LucideIcons.plus,filled:true,onTap:_create)
        else KakaIconButton(icon:LucideIcons.refreshCw,onTap:_refresh),
      ])),
      if(loading||busy)const LinearProgressIndicator(color:KColors.ink),
      Expanded(child:RefreshIndicator(onRefresh:_refresh,color:KColors.ink,
        child:ListView(padding:const EdgeInsets.fromLTRB(22,12,22,32),children:[
          if(error!=null)Padding(padding:const EdgeInsets.only(bottom:14),
            child:Text(error!,style:const TextStyle(color:KColors.error,fontSize:13))),
          if(servers.isEmpty)Container(padding:const EdgeInsets.all(28),
            alignment:Alignment.center,
            decoration:BoxDecoration(color:KColors.surface,
              borderRadius:BorderRadius.circular(27)),
            child:const Column(children:[
              Icon(LucideIcons.plug,size:31),
              SizedBox(height:13),
              Text('No MCP servers',style:TextStyle(fontWeight:FontWeight.w600)),
              SizedBox(height:5),
              Text('Connect a server to extend your agents.',
                style:TextStyle(color:KColors.muted,fontSize:13)),
            ])),
          for(final server in servers)Padding(padding:const EdgeInsets.only(bottom:9),
            child:GestureDetector(
              onTap:widget.botId!=null?()=>_toggleAssignment(server):null,
              onLongPress:widget.botId==null?()=>_remove(server):null,
              child:Container(
                padding:const EdgeInsets.all(17),
                decoration:BoxDecoration(color:KColors.surface,
                  borderRadius:BorderRadius.circular(25)),
                child:Row(children:[
                  const Icon(LucideIcons.server,size:22,color:KColors.ink),
                  const SizedBox(width:13),
                  Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    Text(server['name']?.toString()??'MCP server',
                      style:const TextStyle(fontWeight:FontWeight.w600,fontSize:15)),
                    const SizedBox(height:4),
                    Text(server['endpoint']?.toString()??
                        server['transport']?.toString()??'',
                      maxLines:1,overflow:TextOverflow.ellipsis,
                      style:const TextStyle(fontSize:12,color:KColors.muted)),
                  ])),
                  if(widget.botId!=null)
                    Icon(assignments.any((x)=>x['serverId']==server['id'])
                      ?LucideIcons.circleCheck:LucideIcons.circle,
                      size:20,color:KColors.ink),
                ]),
              ),
            )),
          const SizedBox(height:12),
          Text(widget.botId==null?'Long-press a server to remove it.':
              'Tap a server to allow or revoke its tools for this agent.',
            style:const TextStyle(color:KColors.muted,fontSize:12,height:1.5)),
        ]))),
    ])),
  );
}
