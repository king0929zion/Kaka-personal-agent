import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../core/api.dart';
import '../../design/theme.dart';
import '../../design/widgets.dart';

/// Read-only remote file explorer. Directory contents are virtualized and
/// file previews are deliberately bounded to protect device memory.
class ComputerFilesScreen extends StatefulWidget {
  final KakaApi api;
  final String botId;
  const ComputerFilesScreen({super.key,required this.api,required this.botId});
  @override
  State<ComputerFilesScreen> createState()=>_ComputerFilesScreenState();
}

class _ComputerFilesScreenState extends State<ComputerFilesScreen> {
  String path='/';
  List<Map<String,dynamic>> files=[];
  bool loading=true,opening=false;
  String? error;
  int _generation=0;
  static const _maxEntries=800;
  @override
  void initState(){super.initState();_browse('/');}

  Future<void> _browse(String target) async {
    final generation=++_generation;
    if(mounted)setState((){loading=true;path=target;error=null;});
    try {
      final data=await widget.api.rpc('computer/files',{
        'botId':widget.botId,'path':target,
      });
      if(!mounted||generation!=_generation)return;
      final entries=(data as List).whereType<Map>()
        .map((m)=>Map<String,dynamic>.from(m)).toList();
      entries.sort((a,b){
        final aDir=a['kind']=='dir',bDir=b['kind']=='dir';
        if(aDir!=bDir)return aDir?-1:1;
        return (a['path']?.toString()??'').toLowerCase()
          .compareTo((b['path']?.toString()??'').toLowerCase());
      });
      setState(()=>files=entries.take(_maxEntries).toList());
    }catch(e){if(mounted&&generation==_generation)setState(()=>error=e.toString());}
    finally{if(mounted&&generation==_generation)setState(()=>loading=false);}
  }

  String _parent(String value) {
    final trimmed=value.endsWith('/')&&value.length>1
      ?value.substring(0,value.length-1):value;
    final slash=trimmed.lastIndexOf('/');
    return slash<=0?'/':trimmed.substring(0,slash);
  }

  Future<void> _open(Map<String,dynamic> item) async {
    final filePath=item['path']?.toString()??'';
    if(filePath.isEmpty)return;
    if(item['kind']=='dir'){await _browse(filePath);return;}
    final size=(item['size'] as num?)?.toInt()??0;
    if(size>256*1024){
      kakaNotice(context,'Files larger than 256 KB are not previewed');
      return;
    }
    if(opening)return;
    setState(()=>opening=true);
    try {
      final response=await widget.api.rpc('computer/readFile',{
        'botId':widget.botId,'path':filePath,
      });
      if(!mounted)return;
      final result=Map<String,dynamic>.from(response as Map);
      final contents=result['content']?.toString()??'';
      await kakaSheet<void>(context,Column(
        mainAxisSize:MainAxisSize.min,
        crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(filePath.split('/').last,style:Theme.of(context).textTheme.titleLarge),
          const SizedBox(height:14),
          ConstrainedBox(
            constraints:BoxConstraints(
              maxHeight:MediaQuery.sizeOf(context).height*.58),
            child:SingleChildScrollView(child:SelectableText(
              contents.length>100000?contents.substring(0,100000):contents,
              style:const TextStyle(fontSize:13,height:1.5,
                fontFamily:'monospace'))),
          ),
          if(contents.length>100000)const Padding(
            padding:EdgeInsets.only(top:8),
            child:Text('Preview truncated to 100,000 characters.',
              style:TextStyle(fontSize:12,color:KColors.muted))),
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
      Padding(padding:const EdgeInsets.fromLTRB(12,12,16,10),child:Row(children:[
        KakaIconButton(icon:LucideIcons.arrowLeft,onTap:(){
          if(path=='/')Navigator.pop(context);
          else _browse(_parent(path));
        }),
        const SizedBox(width:9),
        Expanded(child:Text('Computer files',
          style:Theme.of(context).textTheme.titleLarge)),
        KakaIconButton(icon:LucideIcons.refreshCw,onTap:()=>_browse(path)),
      ])),
      Padding(padding:const EdgeInsets.fromLTRB(23,10,23,15),
        child:Text(path,maxLines:2,overflow:TextOverflow.ellipsis,
          style:const TextStyle(color:KColors.muted,fontSize:13))),
      if(loading||opening)const LinearProgressIndicator(color:KColors.ink),
      Expanded(child:ListView.builder(
        padding:const EdgeInsets.fromLTRB(20,8,20,30),
        itemCount:files.isEmpty?1:files.length,
        itemBuilder:(context,index){
          if(files.isEmpty)return Padding(padding:const EdgeInsets.only(top:65),
            child:Center(child:Text(error??(loading?'Loading files…':'Folder is empty'),
              style:TextStyle(fontSize:13,
                color:error==null?KColors.muted:KColors.error))));
          final item=files[index];
          final isDir=item['kind']=='dir';
          final p=item['path']?.toString()??'';
          final name=p.split('/').where((p)=>p.isNotEmpty).lastOrNull??p;
          return GestureDetector(onTap:()=>_open(item),
            child:Container(
              margin:const EdgeInsets.only(bottom:7),
              padding:const EdgeInsets.all(15),
              decoration:BoxDecoration(color:KColors.surface,
                borderRadius:BorderRadius.circular(23)),
              child:Row(children:[
                Icon(isDir?LucideIcons.folder:LucideIcons.file,
                  size:21,color:KColors.ink),
                const SizedBox(width:13),
                Expanded(child:Text(name,maxLines:2,
                  overflow:TextOverflow.ellipsis,
                  style:const TextStyle(fontSize:14,fontWeight:FontWeight.w500))),
                if(!isDir)Text('${item['size']??0} B',
                  style:const TextStyle(color:KColors.muted,fontSize:11)),
                const SizedBox(width:8),
                const Icon(LucideIcons.chevronRight,size:16,color:KColors.muted),
              ]),
            ));
        })),
      if(files.length==_maxEntries)const Padding(
        padding:EdgeInsets.fromLTRB(22,0,22,14),
        child:Text('Showing first 800 entries to limit memory use.',
          style:TextStyle(fontSize:12,color:KColors.muted))),
    ])),
  );
}
