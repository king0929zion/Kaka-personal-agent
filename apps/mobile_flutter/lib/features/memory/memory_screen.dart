import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../core/api.dart';
import '../../design/theme.dart';
import '../../design/widgets.dart';

/// Memory files belong to the authenticated Space. Never cache them on disk.
class MemoryScreen extends StatefulWidget {
  final KakaApi api;
  final String? botId;
  const MemoryScreen({super.key,required this.api,this.botId});
  @override
  State<MemoryScreen> createState()=>_MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  List<Map<String,dynamic>> docs=[];
  String? error;
  bool loading=true,exporting=false;
  int _generation=0;
  @override
  void initState(){super.initState();_refresh();}
  Future<void> _refresh() async {
    final generation=++_generation;
    if(mounted)setState(()=>loading=true);
    try {
      final data=await widget.api.rpc('memory/list',{
        if(widget.botId!=null)'botId':widget.botId,
      });
      if(!mounted || generation!=_generation)return;
      setState((){
        docs=(data as List).whereType<Map>()
          .map((m)=>Map<String,dynamic>.from(m)).toList();
        error=null;
      });
    }catch(e) {
      if(mounted&&generation==_generation)setState(()=>error=e.toString());
    }finally{
      if(mounted&&generation==_generation)setState(()=>loading=false);
    }
  }

  Future<void> _edit(Map<String,dynamic> doc) async {
    final content=TextEditingController(text:doc['content']?.toString()??'');
    var saving=false;
    String? localError;
    try {
      await kakaSheet<void>(context,StatefulBuilder(builder:(ctx,update)=>
        SingleChildScrollView(child:Column(
          mainAxisSize:MainAxisSize.min,
          crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            Text(doc['path']?.toString()??'Memory',
              style:Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height:9),
            Text('Revision ${doc['revision']??'–'} · ${doc['scope']??'private'}',
              style:const TextStyle(color:KColors.muted,fontSize:12)),
            const SizedBox(height:15),
            KakaField(controller:content,label:'Memory content',maxLines:12),
            if(localError!=null)Padding(padding:const EdgeInsets.only(top:12),
              child:Text(localError!,style:const TextStyle(color:KColors.error,fontSize:12))),
            const SizedBox(height:16),
            KakaButton(title:'Save changes',busy:saving,onPressed:() async {
              if(saving)return;
              if(content.text==doc['content']){Navigator.pop(ctx);return;}
              update(()=>saving=true);
              try{
                await widget.api.rpc('memory/update',{
                  'documentId':doc['id'],
                  'content':content.text,
                });
                if(ctx.mounted)Navigator.pop(ctx);
                await _refresh();
              }catch(e){if(ctx.mounted)update(()=>localError=e.toString());}
              finally{if(ctx.mounted)update(()=>saving=false);}
            }),
          ]),
        )));
    }finally {
      WidgetsBinding.instance.addPostFrameCallback((_){content.dispose();});
    }
  }

  Future<void> _export() async {
    if(exporting)return;
    setState(()=>exporting=true);
    try{
      final text=await widget.api.rpc('memory/exportMarkdown',{
        if(widget.botId!=null)'botId':widget.botId,
      });
      if(!mounted)return;
      final value=text?.toString()??'';
      if(value.isEmpty){kakaNotice(context,'There is no memory to export');return;}
      await Clipboard.setData(ClipboardData(text:value));
      if(mounted)kakaNotice(context,'Memory Markdown copied to clipboard');
    }catch(e){if(mounted)kakaNotice(context,e.toString());}
    finally{if(mounted)setState(()=>exporting=false);}
  }

  @override
  void dispose(){++_generation;super.dispose();}
  @override
  Widget build(BuildContext context)=>Scaffold(
    backgroundColor:KColors.bg,
    body:SafeArea(child:Column(children:[
      Padding(padding:const EdgeInsets.fromLTRB(13,12,16,15),child:Row(children:[
        KakaIconButton(icon:LucideIcons.arrowLeft,
          onTap:()=>Navigator.pop(context)),
        const SizedBox(width:9),
        Expanded(child:Text('Memory',
          style:Theme.of(context).textTheme.headlineMedium)),
        KakaIconButton(icon:LucideIcons.copy,
          tooltip:'Copy Markdown',onTap:exporting?null:_export),
      ])),
      if(loading)const KakaLoadingRail(),
      Expanded(child:RefreshIndicator(onRefresh:_refresh,color:KColors.ink,
        child:ListView.builder(
          padding:const EdgeInsets.fromLTRB(22,9,22,30),
          itemCount:docs.isEmpty?1:docs.length+1,
          itemBuilder:(context,i){
            if(i==0)return Padding(padding:const EdgeInsets.only(bottom:16),
              child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                const Text('Agent memory and workspace memory',
                  style:TextStyle(fontSize:13,color:KColors.muted)),
                if(error!=null)Padding(padding:const EdgeInsets.only(top:10),
                  child:Text(error!,style:const TextStyle(color:KColors.error))),
                if(docs.isEmpty&&!loading)const Padding(
                  padding:EdgeInsets.symmetric(vertical:46),
                  child:Center(child:Text('No memory documents',
                    style:TextStyle(color:KColors.muted)))),
              ]));
            final doc=docs[i-1];
            final preview=doc['content']?.toString()??'';
            return GestureDetector(onTap:()=>_edit(doc),child:Container(
              margin:const EdgeInsets.only(bottom:9),
              padding:const EdgeInsets.all(17),
              decoration:BoxDecoration(color:KColors.surface,
                borderRadius:BorderRadius.circular(26)),
              child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
                const Icon(LucideIcons.notebookText,size:21,color:KColors.ink),
                const SizedBox(width:12),
                Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Text(doc['path']?.toString()??'Memory',
                    style:const TextStyle(fontSize:14,fontWeight:FontWeight.w600),
                    maxLines:1,overflow:TextOverflow.ellipsis),
                  const SizedBox(height:5),
                  Text(preview,maxLines:3,overflow:TextOverflow.ellipsis,
                    style:const TextStyle(fontSize:12,color:KColors.muted,height:1.55)),
                ])),
                const Icon(LucideIcons.chevronRight,size:16,color:KColors.muted),
              ]),
            ));
          },
        ))),
    ])),
  );
}
