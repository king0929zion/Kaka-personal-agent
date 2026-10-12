import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/api.dart';
import '../../core/models.dart';
import '../../design/theme.dart';
import '../../design/widgets.dart';

/// Computer controls remain lightweight until the user explicitly opens the
/// desktop. The expensive embedded browser is never mounted inside chat cards.
class ComputerScreen extends StatefulWidget {
  final KakaApi api;
  final KakaBot bot;
  const ComputerScreen({super.key, required this.api, required this.bot});
  @override
  State<ComputerScreen> createState()=>_ComputerScreenState();
}

class _ComputerScreenState extends State<ComputerScreen>
    with WidgetsBindingObserver {
  Map<String,dynamic> status={};
  String? screenUrl, error;
  bool loading=true, actionBusy=false;
  Timer? _refreshTimer;
  bool _active=true;

  @override
  void initState(){
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _refreshTimer=Timer.periodic(const Duration(seconds:9),(_){
      if(_active&&!actionBusy&&!loading)_refresh(silent:true);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state){
    _active=state==AppLifecycleState.resumed;
    if(_active) _refresh(silent:true);
  }

  Future<void> _refresh({bool silent=false}) async {
    if(!silent && mounted)setState(()=>loading=true);
    try {
      final response=await widget.api.rpc('computer/status',{'botId':widget.bot.id});
      if(!mounted)return;
      setState((){
        status=Map<String,dynamic>.from(response as Map);
        error=null;
      });
    }catch(e){
      if(mounted&&!silent)setState(()=>error=e.toString());
    }finally{
      if(mounted)setState(()=>loading=false);
    }
  }

  Future<void> _operate(String method,{Map<String,dynamic> extra=const {}}) async {
    if(actionBusy)return;
    setState(()=>actionBusy=true);
    try{
      await widget.api.rpc('computer/$method',
        {'botId':widget.bot.id,...extra},
        timeout:const Duration(seconds:120));
      await _refresh(silent:true);
    }catch(e){
      if(mounted)kakaNotice(context,e.toString());
    }finally{
      if(mounted)setState(()=>actionBusy=false);
    }
  }

  Future<void> _openDesktop() async {
    if(actionBusy)return;
    setState(()=>actionBusy=true);
    try{
      final data=await widget.api.rpc('computer/screenUrl',{'botId':widget.bot.id});
      if(!mounted)return;
      final raw= data is Map ? data['url']?.toString() : null;
      if(raw==null||raw.isEmpty){
        kakaNotice(context,'The desktop stream is not ready yet');
        return;
      }
      final base=Uri.parse(widget.api.baseUrl);
      final url=base.resolve(raw);
      if(!['http','https'].contains(url.scheme)){
        kakaNotice(context,'Unsupported desktop stream URL');return;
      }
      screenUrl=url.toString();
      await Navigator.push<void>(context,MaterialPageRoute(
        builder:(_)=>_DesktopView(url:url,title:widget.bot.name)));
    }catch(e){
      if(mounted)kakaNotice(context,e.toString());
    }finally{
      if(mounted)setState(()=>actionBusy=false);
    }
  }

  @override
  void dispose(){
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context){
    final state=status['state']?.toString()??'unknown';
    final control=status['controlHolder']?.toString()??'none';
    final running=state=='running';
    final hasControl=control=='user';
    return Scaffold(
      backgroundColor:KColors.bg,
      body:SafeArea(child:Column(children:[
        Padding(padding:const EdgeInsets.fromLTRB(14,12,20,16),child:Row(children:[
          KakaIconButton(icon:LucideIcons.arrowLeft,onTap:()=>Navigator.pop(context)),
          const SizedBox(width:12),
          Expanded(child:Text('Computer',
            style:Theme.of(context).textTheme.headlineMedium)),
          KakaIconButton(icon:LucideIcons.refreshCw,onTap:()=>_refresh()),
        ])),
        Expanded(child:ListView(
          padding:const EdgeInsets.fromLTRB(22,16,22,32),children:[
          Container(
            padding:const EdgeInsets.symmetric(vertical:46,horizontal:18),
            alignment:Alignment.center,
            decoration:BoxDecoration(color:KColors.surface,
              borderRadius:BorderRadius.circular(32)),
            child:Column(children:[
              Icon(running?LucideIcons.monitor:LucideIcons.monitorOff,
                size:48,color:KColors.ink),
              const SizedBox(height:17),
              Text(widget.bot.name,
                style:Theme.of(context).textTheme.titleLarge),
              const SizedBox(height:8),
              Text(running?'Computer running':state.toUpperCase(),
                style:const TextStyle(color:KColors.muted,fontSize:13)),
            ]),
          ),
          if(loading) const Padding(padding:EdgeInsets.only(top:12),
            child:LinearProgressIndicator(color:KColors.ink)),
          if(error!=null) Padding(padding:const EdgeInsets.only(top:14),
            child:Text(error!,style:const TextStyle(color:KColors.error,fontSize:13))),
          const SizedBox(height:23),
          KakaSection(title:'DESKTOP',child:Column(children:[
            KakaRow(title:'Open screen',subtitle:running?'Load the desktop on demand':'Start the computer first',
              icon:LucideIcons.monitor,onTap:running?_openDesktop:null),
            KakaRow(title:'Control status',
              subtitle:hasControl?'You are in control':'Controlled by $control',
              icon:LucideIcons.mousePointer2),
          ])),
          const SizedBox(height:23),
          KakaSection(title:'ACTIONS',child:Column(children:[
            KakaRow(title:running?'Restart computer':'Start computer',
              icon:LucideIcons.power,onTap:actionBusy?null:()=>
                _operate(running?'reset':'boot')),
            if(running) KakaRow(title:'Stop computer',icon:LucideIcons.square,
              onTap:actionBusy?null:()=>_operate('stop')),
            if(running) KakaRow(title:hasControl?'Release control':'Take control',
              icon:LucideIcons.hand,
              onTap:actionBusy?null:()=>_operate(hasControl?'release':'takeover')),
          ])),
          if(actionBusy) const Padding(padding:EdgeInsets.only(top:17),
            child:Center(child:CircularProgressIndicator(color:KColors.ink))),
          const Padding(padding:EdgeInsets.only(top:20),
            child:Text('Desktop streaming is loaded only when opened, to keep normal conversations lightweight.',
              style:TextStyle(fontSize:12,height:1.5,color:KColors.muted))),
        ])),
      ])),
    );
  }
}

class _DesktopView extends StatefulWidget {
  final Uri url;
  final String title;
  const _DesktopView({required this.url,required this.title});
  @override
  State<_DesktopView> createState()=>_DesktopViewState();
}

class _DesktopViewState extends State<_DesktopView> {
  late final WebViewController controller;
  @override
  void initState(){
    super.initState();
    controller=WebViewController();
    controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    controller.loadRequest(widget.url);
  }
  @override
  Widget build(BuildContext context)=>Scaffold(
    backgroundColor:KColors.bg,
    body:SafeArea(child:Column(children:[
      Padding(padding:const EdgeInsets.fromLTRB(12,8,14,8),child:Row(children:[
        KakaIconButton(icon:LucideIcons.arrowLeft,
          onTap:()=>Navigator.pop(context)),
        const SizedBox(width:8),
        Expanded(child:Text(widget.title,maxLines:1,
          overflow:TextOverflow.ellipsis,
          style:Theme.of(context).textTheme.titleLarge)),
        KakaIconButton(icon:LucideIcons.refreshCw,
          onTap:()=>controller.reload()),
      ])),
      Expanded(child:WebViewWidget(controller:controller)),
    ])),
  );
}
