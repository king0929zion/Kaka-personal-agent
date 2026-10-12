import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../core/api.dart';
import '../../design/theme.dart';
import '../../design/widgets.dart';

class UsageScreen extends StatefulWidget {
  final KakaApi api;
  const UsageScreen({super.key,required this.api});
  @override
  State<UsageScreen> createState()=>_UsageScreenState();
}
class _UsageScreenState extends State<UsageScreen> {
  Map<String,dynamic> summary={};
  List<Map<String,dynamic>> records=[];
  String? error;
  bool loading=true;
  @override
  void initState(){super.initState();_refresh();}
  Future<void> _refresh() async {
    if(mounted)setState(()=>loading=true);
    try{
      final data=await Future.wait<dynamic>([
        widget.api.rpc('usage/summary'),
        widget.api.rpc('usage/list'),
      ]);
      if(!mounted)return;
      final usage=(data[1] as List).whereType<Map>()
        .map((e)=>Map<String,dynamic>.from(e)).toList();
      usage.sort((a,b)=>(b['createdAt']?.toString()??'')
        .compareTo(a['createdAt']?.toString()??''));
      setState((){
        summary=Map<String,dynamic>.from(data[0] as Map);
        records=usage.take(500).toList();
        error=null;
      });
    }catch(e){if(mounted)setState(()=>error=e.toString());}
    finally{if(mounted)setState(()=>loading=false);}
  }
  String _number(dynamic n) {
    final value=n is num?n.toInt():null;
    if(value==null)return '—';
    if(value>=1000000)return '${(value/1000000).toStringAsFixed(2)}M';
    if(value>=1000)return '${(value/1000).toStringAsFixed(1)}K';
    return value.toString();
  }
  Widget _tile(String title,dynamic value,IconData icon)=>Expanded(
    child:Container(
      padding:const EdgeInsets.all(17),
      decoration:BoxDecoration(color:KColors.surface,
        borderRadius:BorderRadius.circular(25)),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Icon(icon,size:18,color:KColors.ink),
        const SizedBox(height:22),
        Text(_number(value),style:const TextStyle(
          fontSize:25,fontWeight:FontWeight.w700,color:KColors.ink)),
        const SizedBox(height:6),
        Text(title,style:const TextStyle(fontSize:12,color:KColors.muted)),
      ]),
    ));
  @override
  Widget build(BuildContext context)=>Scaffold(
    backgroundColor:KColors.bg,
    body:SafeArea(child:Column(children:[
      Padding(padding:const EdgeInsets.fromLTRB(12,12,16,14),child:Row(children:[
        KakaIconButton(icon:LucideIcons.arrowLeft,
          onTap:()=>Navigator.pop(context)),
        const SizedBox(width:9),
        Expanded(child:Text('Usage',style:Theme.of(context).textTheme.headlineMedium)),
        KakaIconButton(icon:LucideIcons.refreshCw,onTap:_refresh),
      ])),
      if(loading)const KakaLoadingRail(),
      Expanded(child:RefreshIndicator(onRefresh:_refresh,color:KColors.ink,
        child:ListView.builder(
          padding:const EdgeInsets.fromLTRB(20,12,20,35),
          itemCount:records.length+2,
          itemBuilder:(context,index){
            if(index==0)return Column(children:[
              if(error!=null)Padding(padding:const EdgeInsets.only(bottom:14),
                child:Text(error!,style:const TextStyle(color:KColors.error))),
              Row(children:[
                _tile('Model calls',summary['modelCalls'],LucideIcons.cpu),
                const SizedBox(width:10),
                _tile('Runs',summary['runs'],LucideIcons.activity),
              ]),
              const SizedBox(height:10),
              Row(children:[
                _tile('Input tokens',summary['inputTokens'],LucideIcons.arrowDownLeft),
                const SizedBox(width:10),
                _tile('Output tokens',summary['outputTokens'],LucideIcons.arrowUpRight),
              ]),
              const Padding(padding:EdgeInsets.fromLTRB(4,26,0,13),
                child:Align(alignment:Alignment.centerLeft,
                  child:Text('RECENT USAGE',style:TextStyle(
                    fontSize:12,color:KColors.muted)))),
            ]);
            if(index==records.length+1){
              return Padding(padding:const EdgeInsets.only(top:10),
                child:Text(records.isEmpty?'No usage recorded':
                  'Showing up to 500 most recent records.',
                  style:const TextStyle(color:KColors.muted,fontSize:12)));
            }
            final row=records[index-1];
            final cost=row['costUsd'] is num
              ?' · USD ${(row['costUsd'] as num).toStringAsFixed(4)}':'';
            return Container(
              margin:const EdgeInsets.only(bottom:8),
              padding:const EdgeInsets.all(16),
              decoration:BoxDecoration(color:KColors.surface,
                borderRadius:BorderRadius.circular(24)),
              child:Row(children:[
                const Icon(LucideIcons.cpu,size:20,color:KColors.ink),
                const SizedBox(width:12),
                Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Text(row['model']?.toString()??'Model',
                    maxLines:1,overflow:TextOverflow.ellipsis,
                    style:const TextStyle(fontWeight:FontWeight.w600,fontSize:14)),
                  const SizedBox(height:5),
                  Text('${row['provider']??''} · ${_number(row['inputTokens'])} in · '
                    '${_number(row['outputTokens'])} out$cost',
                    style:const TextStyle(color:KColors.muted,fontSize:12)),
                ])),
              ]),
            );
          }))),
    ])),
  );
}
