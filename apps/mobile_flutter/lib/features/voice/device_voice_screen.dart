import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../core/api.dart';
import '../../core/models.dart';
import '../../design/theme.dart';
import '../../design/widgets.dart';
import '../avatar/avatar_settings.dart';
import '../thread/thread_controller.dart';

/// On-device turn-based voice chat. Speech stays within the foreground route;
/// audio and recognition sessions are stopped on dispose/background.
class DeviceVoiceScreen extends StatefulWidget {
  final KakaApi api;
  final KakaBot bot;
  final bool group;
  const DeviceVoiceScreen({super.key,required this.api,required this.bot,
    this.group=false});
  @override
  State<DeviceVoiceScreen> createState()=>_DeviceVoiceScreenState();
}
class _DeviceVoiceScreenState extends State<DeviceVoiceScreen>
    with WidgetsBindingObserver {
  final stt.SpeechToText speech=stt.SpeechToText();
  final FlutterTts tts=FlutterTts();
  late final ThreadController thread=ThreadController(widget.api,widget.bot.id,
    group:widget.group);
  final draft=TextEditingController();
  final Set<String> spoken=<String>{};
  bool initializing=true,canRecognize=false,listening=false;
  bool speaking=false,autoRead=true,sending=false,foreground=true;
  bool didSend=false;
  String? error;
  String? lastReply;
  int _generation=0;

  @override
  void initState(){
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    thread.addListener(_handleThread);
    unawaited(_init());
  }

  Future<void> _init() async {
    try {
      await tts.awaitSpeakCompletion(true);
      if(!mounted)return;
      final tag=Localizations.localeOf(context).toLanguageTag();
      await tts.setLanguage(tag.startsWith('zh')?'zh-CN':'en-US');
      final available=await speech.initialize(
        onStatus:(status) {
          if(mounted)setState(()=>listening=status=='listening');
        },
        onError:(err) {
          if(mounted)setState((){
            error=err.errorMsg;
            listening=false;
          });
        });
      await thread.load();
      if(!mounted)return;
      spoken.addAll(thread.messages.map((m)=>m.id));
      setState(()=>canRecognize=available);
    }catch(e) {
      if(mounted)setState(()=>error=e.toString());
    }finally{
      if(mounted)setState(()=>initializing=false);
    }
  }

  void _handleThread(){
    if(!mounted || !foreground || !didSend)return;
    // Announce only completed agent responses and never old history.
    final status=thread.snapshot?.runStatus;
    if(status!='completed' && status!='failed' && status!='cancelled')return;
    for(final message in thread.messages.reversed){
      if(message.role=='user' || message.text.trim().isEmpty ||
          spoken.contains(message.id))continue;
      spoken.add(message.id);
      lastReply=message.text;
      if(autoRead)unawaited(_speak(message.text));
      if(mounted)setState((){});
      break;
    }
  }

  Future<void> _listen()async{
    if(initializing || sending || speaking || !canRecognize)return;
    try {
      if(speech.isListening){
        await speech.stop();
        return;
      }
      if(!mounted)return;
      setState(()=>error=null);
      await speech.listen(
        onResult:(result){
          if(!mounted)return;
          draft.text=result.recognizedWords;
          draft.selection=TextSelection.collapsed(offset:draft.text.length);
          setState((){});
        },
        listenFor:const Duration(seconds:45),
        pauseFor:const Duration(seconds:3),
        localeId:Localizations.localeOf(context).toLanguageTag(),
      );
    }catch(e){if(mounted)setState(()=>error=e.toString());}
  }

  Future<void> _send() async {
    final text=draft.text.trim();
    if(text.isEmpty || sending)return;
    if(speech.isListening)await speech.stop();
    setState(()=>sending=true);
    draft.clear();
    spoken.addAll(thread.messages.map((m)=>m.id));
    try{
      didSend=true;
      await thread.send(text);
      if(thread.error!=null)throw KakaApiException(thread.error!);
    }catch(e){
      if(mounted)setState((){draft.text=text;error=e.toString();});
    }finally{if(mounted)setState(()=>sending=false);}
  }

  Future<void> _speak(String text)async{
    if(!mounted || !foreground || text.trim().isEmpty)return;
    final generation=++_generation;
    if(speech.isListening)await speech.stop();
    setState(()=>speaking=true);
    try{
      await tts.stop();
      await tts.speak(text.length>3800?text.substring(0,3800):text);
    }catch(e){
      if(mounted && generation==_generation)setState(()=>error=e.toString());
    }finally{
      if(mounted && generation==_generation)setState(()=>speaking=false);
    }
  }
  Future<void> _stopAudio()async{
    ++_generation;
    await Future.wait<dynamic>([speech.stop(),tts.stop()]);
    if(mounted)setState((){listening=false;speaking=false;});
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state){
    foreground=state==AppLifecycleState.resumed;
    if(!foreground){
      unawaited(_stopAudio());
      thread.pauseRealtime();
    }else{
      unawaited(thread.load());
    }
  }
  @override
  void dispose(){
    WidgetsBinding.instance.removeObserver(this);
    thread.removeListener(_handleThread);
    thread.dispose();
    unawaited(speech.cancel());
    unawaited(tts.stop());
    draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    backgroundColor:KColors.bg,
    body:SafeArea(child:Column(children:[
      Padding(padding:const EdgeInsets.fromLTRB(13,11,17,12),child:Row(children:[
        KakaIconButton(icon:LucideIcons.arrowLeft,
          onTap:()=>Navigator.pop(context)),
        const SizedBox(width:12),
        Expanded(child:Text('Voice chat',
          style:Theme.of(context).textTheme.headlineMedium)),
        KakaIconButton(icon:LucideIcons.volume2,
          tooltip:'Toggle spoken responses',
          filled:autoRead,onTap:()=>setState(()=>autoRead=!autoRead)),
      ])),
      Expanded(child:SingleChildScrollView(
        padding:const EdgeInsets.fromLTRB(23,45,23,18),
        child:Column(children:[
          AgentAvatar(botId:widget.bot.id,size:148,
            working:thread.canStop || listening || speaking),
          const SizedBox(height:26),
          Text(widget.bot.name,style:Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height:10),
          Text(initializing?'Initializing voice…':
            !canRecognize?'Speech recognition is unavailable on this device':
            listening?'Listening…':speaking?'Speaking…':
            thread.canStop?'Agent is responding…':'Tap microphone to speak',
            textAlign:TextAlign.center,
            style:const TextStyle(color:KColors.muted,fontSize:14)),
          const SizedBox(height:35),
          if(lastReply!=null)Container(
            width:double.infinity,
            padding:const EdgeInsets.all(18),
            decoration:BoxDecoration(color:KColors.surface,
              borderRadius:BorderRadius.circular(25)),
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              const Text('AGENT REPLY',style:TextStyle(
                color:KColors.muted,fontSize:11)),
              const SizedBox(height:11),
              Text(lastReply!,style:const TextStyle(
                fontSize:14,height:1.55,color:KColors.ink)),
              const SizedBox(height:10),
              KakaButton(title:speaking?'Stop reading':'Read aloud',
                filled:false,onPressed:()=>speaking?_stopAudio():_speak(lastReply!)),
            ]),
          ),
          if(error!=null)Padding(padding:const EdgeInsets.only(top:20),
            child:Text(error!,textAlign:TextAlign.center,
              style:const TextStyle(color:KColors.error,fontSize:13))),
        ]),
      )),
      Padding(padding:EdgeInsets.fromLTRB(19,12,19,
          MediaQuery.paddingOf(context).bottom+18),
        child:Column(children:[
          Container(padding:const EdgeInsets.fromLTRB(17,6,7,6),
            decoration:BoxDecoration(color:KColors.surface,
              borderRadius:BorderRadius.circular(29)),
            child:Row(children:[
              Expanded(child:TextField(controller:draft,
                minLines:1,maxLines:4,onChanged:(_)=>setState((){}),
                decoration:const InputDecoration(
                  border:InputBorder.none,hintText:'Your message',
                  isDense:true))),
              KakaIconButton(icon:LucideIcons.arrowUp,filled:true,size:43,
                onTap:sending||draft.text.trim().isEmpty?null:_send),
            ]),
          ),
          const SizedBox(height:15),
          Row(mainAxisAlignment:MainAxisAlignment.center,children:[
            if(speaking)KakaIconButton(icon:LucideIcons.square,
              size:50,onTap:_stopAudio),
            const SizedBox(width:13),
            KakaIconButton(icon:listening?LucideIcons.micOff:LucideIcons.mic,
              size:66,filled:listening,
              onTap:initializing||!canRecognize?null:_listen),
            const SizedBox(width:13),
            if(thread.canStop)KakaIconButton(icon:LucideIcons.circleStop,
              size:50,onTap:thread.stop),
          ]),
        ]),
      ),
    ])),
  );
}
