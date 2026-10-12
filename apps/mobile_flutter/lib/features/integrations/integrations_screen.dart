import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api.dart';
import '../../design/theme.dart';
import '../../design/widgets.dart';

/// Authenticated, server-backed integrations. OAuth opens externally rather
/// than embedding provider login pages in an untrusted WebView.
class IntegrationsScreen extends StatefulWidget {
  final KakaApi api;
  const IntegrationsScreen({super.key,required this.api});
  @override
  State<IntegrationsScreen> createState()=>_IntegrationsScreenState();
}
class _IntegrationsScreenState extends State<IntegrationsScreen> {
  final search=TextEditingController();
  List<Map<String,dynamic>> catalog=[],connections=[];
  bool loading=true,busy=false;
  String? error;
  @override
  void initState(){super.initState();_refresh();}
  @override
  void dispose(){search.dispose();super.dispose();}
  Future<void> _refresh() async {
    if(mounted)setState(()=>loading=true);
    try{
      final results=await Future.wait<dynamic>([
        widget.api.rpc('connections/list'),
        widget.api.rpc('connections/catalog'),
      ]);
      if(!mounted)return;
      setState((){
        connections=(results[0] as List).whereType<Map>()
          .map((e)=>Map<String,dynamic>.from(e)).toList();
        catalog=(results[1] as List).whereType<Map>()
          .map((e)=>Map<String,dynamic>.from(e)).toList();
        error=null;
      });
    }catch(e){if(mounted)setState(()=>error=e.toString());}
    finally{if(mounted)setState(()=>loading=false);}
  }
  Future<void> _connect(Map<String,dynamic> item) async {
    final name=item['name']?.toString()??'Provider';
    final connectorId=item['connectorId']?.toString()??'composio';
    final provider=item['slug']?.toString()??'';
    if(provider.isEmpty)return;
    if(busy)return;
    setState(()=>busy=true);
    try{
      final data=await widget.api.rpc('connections/begin',{
        'connectorId':connectorId,'provider':provider,'displayName':name,
      });
      final result=Map<String,dynamic>.from(data as Map);
      final url=result['authorizationUrl']?.toString();
      if(url!=null&&url.isNotEmpty){
        final uri=Uri.tryParse(url);
        if(uri==null||uri.scheme!='https'||uri.host.isEmpty){
          throw const KakaApiException('Invalid authorization URL');
        }
        if(!await launchUrl(uri,mode:LaunchMode.externalApplication)){
          throw const KakaApiException('Could not open authorization');
        }
        if(mounted)kakaNotice(context,
          'Complete authorization in your browser, then refresh this page');
      }else{
        final id=result['connectionId']?.toString();
        if(id!=null&&id.isNotEmpty){
          await widget.api.rpc('connections/complete',{'connectionId':id});
        }
        await _refresh();
      }
    }catch(e){if(mounted)kakaNotice(context,e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> _revoke(Map<String,dynamic> item) async {
    final name=item['displayName']?.toString()??'integration';
    final confirmed=await kakaSheet<bool>(context,Column(
      mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,
      children:[
        Text('Disconnect $name?',style:Theme.of(context).textTheme.titleLarge),
        const SizedBox(height:12),
        const Text('This revokes the connection for your workspace.',
          style:TextStyle(fontSize:13,color:KColors.muted)),
        const SizedBox(height:19),
        KakaButton(title:'Disconnect',onPressed:()=>Navigator.pop(context,true)),
        const SizedBox(height:9),
        KakaButton(title:'Cancel',filled:false,onPressed:()=>Navigator.pop(context,false)),
      ]));
    if(confirmed!=true)return;
    try {
      await widget.api.rpc('connections/revoke',
        {'connectionId':item['id']?.toString()??''});
      await _refresh();
    }catch(e){if(mounted)kakaNotice(context,e.toString());}
  }
  @override
  Widget build(BuildContext context){
    final filter=search.text.trim().toLowerCase();
    final shown=catalog.where((item)=>item['name'].toString().toLowerCase().contains(filter)).toList();
    return Scaffold(backgroundColor:KColors.bg,
      body:SafeArea(child:Column(children:[
        Padding(padding:const EdgeInsets.fromLTRB(14,13,17,12),child:Row(children:[
          KakaIconButton(icon:LucideIcons.arrowLeft,onTap:()=>Navigator.pop(context)),
          const SizedBox(width:9),
          Expanded(child:Text('Integrations',style:Theme.of(context).textTheme.headlineMedium)),
          KakaIconButton(icon:LucideIcons.refreshCw,onTap:_refresh),
        ])),
        Padding(padding:const EdgeInsets.fromLTRB(22,7,22,15),
          child:TextField(controller:search,onChanged:(_)=>setState((){}),
            decoration:InputDecoration(
              hintText:'Find an integration',prefixIcon:const Icon(LucideIcons.search,size:19),
              filled:true,fillColor:KColors.soft,
              border:OutlineInputBorder(borderSide:BorderSide.none,
                borderRadius:BorderRadius.circular(25))))),
        if(loading||busy)const LinearProgressIndicator(color:KColors.ink),
        Expanded(child:RefreshIndicator(onRefresh:_refresh,color:KColors.ink,
          child:ListView(padding:const EdgeInsets.fromLTRB(22,8,22,36),
            children:[
              if(error!=null)Padding(padding:const EdgeInsets.only(bottom:18),
                child:Text(error!,style:const TextStyle(color:KColors.error,fontSize:13))),
              KakaSection(title:'YOUR CONNECTIONS',child:connections.isEmpty
                ?const Padding(padding:EdgeInsets.all(19),
                  child:Text('No connections yet',style:TextStyle(
                    color:KColors.muted,fontSize:14)))
                :Column(children:[
                  for(final item in connections)
                    KakaRow(title:item['displayName']?.toString()??item['provider']?.toString()??'Connection',
                      subtitle:item['status']?.toString()??'',
                      icon:LucideIcons.plug,
                      onTap:()=>_revoke(item)),
                ])),
              const SizedBox(height:23),
              KakaSection(title:'AVAILABLE',child:shown.isEmpty
                ?const Padding(padding:EdgeInsets.all(19),
                  child:Text('No matching integrations',style:TextStyle(color:KColors.muted)))
                :Column(children:[
                  for(final item in shown)
                    KakaRow(title:item['name']?.toString()??'Integration',
                      subtitle:item['connected']==true?'Connected':'Connect to Kaka',
                      icon:item['connected']==true?LucideIcons.circleCheck:LucideIcons.plus,
                      onTap:item['connected']==true?null:()=>_connect(item)),
                ])),
            ]))),
      ])),
    );
  }
}
