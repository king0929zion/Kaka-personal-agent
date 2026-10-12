import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../core/api.dart';
import '../../design/theme.dart';
import '../../design/widgets.dart';

class VoiceSettingsScreen extends StatefulWidget {
  final KakaApi api;
  const VoiceSettingsScreen({super.key,required this.api});
  @override
  State<VoiceSettingsScreen> createState()=>_VoiceSettingsScreenState();
}

class _VoiceSettingsScreenState extends State<VoiceSettingsScreen> {
  Map<String,dynamic> status={};
  List<Map<String,dynamic>> catalog=[],credentials=[],voices=[];
  String? error;
  bool loading=true,busy=false;
  @override
  void initState(){super.initState();_refresh();}
  Future<void> _refresh() async {
    if(mounted)setState(()=>loading=true);
    try{
      final data=await Future.wait([
        widget.api.rpc('voice/status'),
        widget.api.rpc('voice/catalog'),
        widget.api.rpc('voice/credentials'),
        widget.api.rpc('voice/voices'),
      ]);
      if(!mounted)return;
      setState((){
        status=Map<String,dynamic>.from(data[0] as Map);
        catalog=(data[1] as List).whereType<Map>()
          .map((m)=>Map<String,dynamic>.from(m)).toList();
        credentials=(data[2] as List).whereType<Map>()
          .map((m)=>Map<String,dynamic>.from(m)).toList();
        voices=(data[3] as List).whereType<Map>()
          .map((m)=>Map<String,dynamic>.from(m)).toList();
        error=null;
      });
    }catch(e){if(mounted)setState(()=>error=e.toString());}
    finally{if(mounted)setState(()=>loading=false);}
  }

  Future<void> _connect(Map<String,dynamic> provider) async {
    final secret=TextEditingController(),voice=TextEditingController();
    final id=provider['id']?.toString()??'';
    var saving=false;
    String? localError;
    try {
      await kakaSheet<void>(context,StatefulBuilder(builder:(ctx,update)=>
        SingleChildScrollView(child:Column(
          mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,
          children:[
            Text('Connect ${provider['name'] ?? id}',
              style:Theme.of(ctx).textTheme.headlineMedium),
            const SizedBox(height:16),
            KakaField(controller:secret,label:'Provider API key',obscure:true),
            const SizedBox(height:13),
            KakaField(controller:voice,label:'Default voice ID',hint:'Optional'),
            if(localError!=null) Padding(padding:const EdgeInsets.only(top:12),
              child:Text(localError!,style:const TextStyle(color:KColors.error))),
            const SizedBox(height:18),
            KakaButton(title:'Connect',busy:saving,onPressed:() async {
              if(secret.text.trim().length<8){
                update(()=>localError='API key requires at least 8 characters');
                return;
              }
              update(()=>saving=true);
              try{
                await widget.api.rpc('voice/connect',{
                  'provider':id,'apiKey':secret.text.trim(),
                  if(voice.text.trim().isNotEmpty)'voiceId':voice.text.trim(),
                });
                if(ctx.mounted)Navigator.pop(ctx);
                await _refresh();
              }catch(e){if(ctx.mounted)update(()=>localError=e.toString());}
              finally{if(ctx.mounted)update(()=>saving=false);}
            }),
          ]),
        )));
    }finally{
      WidgetsBinding.instance.addPostFrameCallback((_){
        secret.dispose();voice.dispose();
      });
    }
  }

  Future<void> _chooseVoice() async {
    final choice=await kakaSheet<Map<String,dynamic>>(context,
      ListView(shrinkWrap:true,children:[
        Text('Voice selection',style:Theme.of(context).textTheme.titleLarge),
        const SizedBox(height:12),
        for(final voice in voices)KakaRow(
          title:voice['label']?.toString()??voice['id'].toString(),
          subtitle:voice['description']?.toString(),
          icon:LucideIcons.audioLines,onTap:()=>Navigator.pop(context,voice)),
      ]));
    if(choice==null||!mounted)return;
    setState(()=>busy=true);
    try{
      await widget.api.rpc('voice/setVoice',{'voiceId':choice['id'].toString()});
      await _refresh();
    }catch(e){if(mounted)kakaNotice(context,e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }

  Future<void> _disconnect(Map<String,dynamic> credential) async {
    final ok=await kakaSheet<bool>(context,Column(
      mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Text('Disconnect voice provider?',style:Theme.of(context).textTheme.titleLarge),
        const SizedBox(height:18),
        KakaButton(title:'Disconnect',onPressed:()=>Navigator.pop(context,true)),
        const SizedBox(height:9),
        KakaButton(title:'Cancel',filled:false,onPressed:()=>Navigator.pop(context,false)),
      ]));
    if(ok!=true)return;
    setState(()=>busy=true);
    try{
      await widget.api.rpc('voice/disconnect',
        {'provider':credential['provider']?.toString()??''});
      await _refresh();
    }catch(e){if(mounted)kakaNotice(context,e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    backgroundColor:KColors.bg,
    body:SafeArea(child:Column(children:[
      Padding(padding:const EdgeInsets.fromLTRB(14,12,20,14),child:Row(children:[
        KakaIconButton(icon:LucideIcons.arrowLeft,onTap:()=>Navigator.pop(context)),
        const SizedBox(width:10),
        Expanded(child:Text('Voice',style:Theme.of(context).textTheme.headlineMedium)),
        KakaIconButton(icon:LucideIcons.refreshCw,onTap:_refresh),
      ])),
      Expanded(child:ListView(padding:const EdgeInsets.fromLTRB(22,12,22,32),children:[
        if(loading||busy) const KakaLoadingRail(),
        if(error!=null)Padding(padding:const EdgeInsets.only(bottom:15),
          child:Text(error!,style:const TextStyle(fontSize:13,color:KColors.error))),
        KakaSection(title:'STATUS',child:Column(children:[
          KakaRow(title:status['ready']==true?'Ready for voice':'Voice not ready',
            subtitle:status['provider']?.toString()??'No provider configured',
            icon:LucideIcons.audioLines),
          KakaRow(title:'Speech-to-text',
            subtitle:status['transcribe']==true?'Available':'Not configured',
            icon:LucideIcons.mic),
          KakaRow(title:'Default voice',
            subtitle:status['voiceId']?.toString()??'None',
            icon:LucideIcons.volume2,
            onTap:voices.isEmpty?null:_chooseVoice),
        ])),
        const SizedBox(height:22),
        KakaSection(title:'CONNECTED PROVIDERS',
          child:credentials.isEmpty
            ?const Padding(padding:EdgeInsets.all(19),
              child:Text('No voice provider connected',
                style:TextStyle(color:KColors.muted,fontSize:14)))
            :Column(children:[
              for(final c in credentials)KakaRow(
                title:c['provider']?.toString()??'Provider',
                subtitle:c['isDefault']==true?'Default':'Connected',
                icon:LucideIcons.audioLines,
                onTap:()=>_disconnect(c)),
            ])),
        const SizedBox(height:22),
        KakaSection(title:'AVAILABLE PROVIDERS',child:Column(children:[
          for(final item in catalog)KakaRow(
            title:item['name']?.toString()??item['id']?.toString()??'Provider',
            subtitle:item['description']?.toString(),
            icon:LucideIcons.plus,onTap:()=>_connect(item)),
          if(catalog.isEmpty)const Padding(padding:EdgeInsets.all(19),
            child:Text('No voice providers listed',
              style:TextStyle(color:KColors.muted))),
        ])),
      ])),
    ])),
  );
}
