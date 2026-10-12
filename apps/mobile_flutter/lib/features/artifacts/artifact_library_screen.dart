import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../core/api.dart';
import '../../design/theme.dart';
import '../../design/widgets.dart';

class ArtifactLibraryScreen extends StatefulWidget {
  final KakaApi api;
  final String? botId;
  const ArtifactLibraryScreen({super.key,required this.api,this.botId});
  @override
  State<ArtifactLibraryScreen> createState()=>_ArtifactLibraryScreenState();
}
class _ArtifactLibraryScreenState extends State<ArtifactLibraryScreen> {
  final entries=<Map<String,dynamic>>[];
  String? cursor,error;
  bool loading=false,ended=false,opening=false;
  int _generation=0;
  @override
  void initState(){super.initState();_load(reset:true);}
  Future<void> _load({bool reset=false}) async {
    if(loading)return;
    if(!reset && ended)return;
    final generation=++_generation;
    if(mounted)setState(()=>loading=true);
    try{
      final data=await widget.api.rpc('artifacts/listSpace',{
        if(widget.botId!=null)'botId':widget.botId,
        if(!reset&&cursor!=null)'cursor':cursor,
        'limit':30,
      });
      if(!mounted||generation!=_generation)return;
      final page=Map<String,dynamic>.from(data as Map);
      final more=(page['items'] as List).whereType<Map>()
        .map((e)=>Map<String,dynamic>.from(e)).toList();
      setState((){
        if(reset){entries.clear();}
        final existing={for(final e in entries)e['id']?.toString():e};
        for(final item in more)existing[item['id']?.toString()]=item;
        entries..clear()..addAll(existing.values);
        cursor=page['nextCursor']?.toString();
        ended=cursor==null;
        error=null;
      });
    }catch(e){if(mounted&&generation==_generation)setState(()=>error=e.toString());}
    finally{if(mounted&&generation==_generation)setState(()=>loading=false);}
  }
  Future<void> _open(Map<String,dynamic> item) async {
    if(opening)return;
    final size=(item['size'] as num?)?.toInt()??0;
    if(size>6*1024*1024){
      kakaNotice(context,'Preview is limited to files of 6 MB');
      return;
    }
    setState(()=>opening=true);
    try{
      final data=await widget.api.rpc('artifacts/getById',{
        'artifactId':item['id'],
      });
      final m=Map<String,dynamic>.from(data as Map);
      final encoded=m['contentBase64']?.toString()??'';
      if(encoded.length>9*1024*1024){
        throw const KakaApiException('Preview exceeds memory safety limit');
      }
      final bytes=await compute<String,Uint8List>(base64Decode,encoded);
      if(!mounted)return;
      final mime=item['mimeType']?.toString()??'';
      final name=item['name']?.toString()??'Attachment';
      await kakaSheet<void>(context,Column(
        mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,
        children:[
          Text(name,style:Theme.of(context).textTheme.titleLarge,
            maxLines:2,overflow:TextOverflow.ellipsis),
          const SizedBox(height:8),
          Text('$mime · ${bytes.lengthInBytes} bytes',
            style:const TextStyle(color:KColors.muted,fontSize:12)),
          const SizedBox(height:17),
          Flexible(child:SingleChildScrollView(child:
            mime.startsWith('image/')
              ?Image.memory(bytes,fit:BoxFit.contain,
                 cacheWidth:1100,gaplessPlayback:false,
                 errorBuilder:(_,__,___)=>const Text('Image preview unavailable'))
              :mime.startsWith('text/')||
                ['application/json','application/xml'].contains(mime)
                ?SelectableText(utf8.decode(bytes.length>128*1024
                    ?bytes.sublist(0,128*1024):bytes,
                  allowMalformed:true),
                  style:const TextStyle(fontSize:13,height:1.5))
                :const Text('Preview not supported for this file type.',
                  style:TextStyle(color:KColors.muted,fontSize:13)))),
          const SizedBox(height:14),
          KakaButton(title:'Copy file name',filled:false,onPressed:()async{
            await Clipboard.setData(ClipboardData(text:name));
            if(context.mounted)Navigator.pop(context);
          }),
        ]));
    }catch(e){if(mounted)kakaNotice(context,e.toString());}
    finally{if(mounted)setState(()=>opening=false);}
  }
  @override
  void dispose(){++_generation;super.dispose();}
  @override
  Widget build(BuildContext context)=>Scaffold(
    backgroundColor:KColors.bg,
    body:SafeArea(child:Column(children:[
      Padding(padding:const EdgeInsets.fromLTRB(12,12,16,13),child:Row(children:[
        KakaIconButton(icon:LucideIcons.arrowLeft,
          onTap:()=>Navigator.pop(context)),
        const SizedBox(width:9),
        Expanded(child:Text('Files',style:Theme.of(context).textTheme.headlineMedium)),
        KakaIconButton(icon:LucideIcons.refreshCw,
          onTap:()=>_load(reset:true)),
      ])),
      if(loading||opening)const KakaLoadingRail(),
      Expanded(child:RefreshIndicator(color:KColors.ink,
        onRefresh:()=>_load(reset:true),
        child:ListView.builder(
          padding:const EdgeInsets.fromLTRB(20,10,20,40),
          itemCount:entries.isEmpty?1:entries.length+(ended?0:1),
          itemBuilder:(ctx,index){
            if(entries.isEmpty)return Padding(
              padding:const EdgeInsets.only(top:64),
              child:Center(child:Text(error??(loading?'Loading files…':'No files yet'),
                style:TextStyle(color:error==null?KColors.muted:KColors.error))));
            if(index==entries.length)return Padding(
              padding:const EdgeInsets.symmetric(vertical:14),
              child:KakaButton(title:loading?'Loading…':'Load more',
                filled:false,onPressed:loading?null:()=>_load()));
            final entry=entries[index];
            final mime=entry['mimeType']?.toString()??'';
            return GestureDetector(onTap:()=>_open(entry),
              child:Container(margin:const EdgeInsets.only(bottom:9),
                padding:const EdgeInsets.all(17),
                decoration:BoxDecoration(color:KColors.surface,
                  borderRadius:BorderRadius.circular(24)),
                child:Row(children:[
                  Icon(mime.startsWith('image/')?LucideIcons.image:LucideIcons.file,
                    size:22,color:KColors.ink),
                  const SizedBox(width:13),
                  Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    Text(entry['name']?.toString()??'Attachment',
                      maxLines:2,overflow:TextOverflow.ellipsis,
                      style:const TextStyle(fontSize:14,fontWeight:FontWeight.w600)),
                    const SizedBox(height:4),
                    Text('$mime · ${entry['size']??0} bytes',
                      style:const TextStyle(color:KColors.muted,fontSize:12)),
                  ])),
                  const Icon(LucideIcons.chevronRight,size:17,color:KColors.muted),
                ]),
              ));
          }))),
    ])),
  );
}
