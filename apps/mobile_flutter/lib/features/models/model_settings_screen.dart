import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../core/api.dart';
import '../../design/theme.dart';
import '../../design/widgets.dart';

class ModelSettingsScreen extends StatefulWidget {
  final KakaApi api;
  const ModelSettingsScreen({super.key, required this.api});
  @override
  State<ModelSettingsScreen> createState() => _ModelSettingsScreenState();
}

class _ModelSettingsScreenState extends State<ModelSettingsScreen> {
  List<Map<String, dynamic>> credentials = [];
  List<Map<String, dynamic>> catalog = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() { loading = true; error = null; });
    try {
      final response = await Future.wait([
        widget.api.rpc('models/credentials'),
        widget.api.rpc('models/list'),
      ]);
      if (!mounted) return;
      setState(() {
        credentials = (response[0] as List).whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m)).toList();
        catalog = (response[1] as List).whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m)).toList();
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _openConnection() async {
    final url = TextEditingController();
    final key = TextEditingController();
    final model = TextEditingController();
    final label = TextEditingController();
    var probing = false;
    var saving = false;
    var suggested = <String>[];
    String? localError;
    try {
      await kakaSheet<void>(context, StatefulBuilder(
        builder: (ctx, update) => SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Connect a model', style: Theme.of(ctx).textTheme.headlineMedium),
              const SizedBox(height: 7),
              const Text('OpenAI-compatible API',style:TextStyle(
                fontSize:13,color:KColors.muted)),
              const SizedBox(height: 22),
              KakaField(controller: url, label: 'Base URL',
                hint: 'https://api.example.com/v1',keyboardType:TextInputType.url),
              const SizedBox(height: 15),
              KakaField(controller: key, label: 'API key', obscure: true),
              const SizedBox(height: 15),
              KakaButton(title: 'Fetch available models', filled: false,
                busy: probing, onPressed: () async {
                  if (url.text.trim().isEmpty) {
                    update(()=>localError='Enter an API base URL');
                    return;
                  }
                  update(() { probing=true; localError=null; });
                  try {
                    final result=await widget.api.rpc('models/probeOpenAiCompatible',{
                      'baseUrl':url.text.trim(),
                      if(key.text.isNotEmpty) 'apiKey':key.text.trim(),
                    });
                    if(!ctx.mounted)return;
                    update(() {
                      suggested=(result is Map && result['models'] is List)
                        ? (result['models'] as List).map((e)=>e.toString()).toList() : [];
                      if(model.text.isEmpty && suggested.isNotEmpty) model.text=suggested.first;
                    });
                  } catch (e) {
                    if(ctx.mounted)update(()=>localError=e.toString());
                  } finally { if(ctx.mounted)update(()=>probing=false); }
                }),
              if(suggested.isNotEmpty) ...[
                const SizedBox(height:12),
                Container(
                  constraints:const BoxConstraints(maxHeight:170),
                  decoration:BoxDecoration(color:KColors.soft,
                    borderRadius:BorderRadius.circular(20)),
                  child:ListView(shrinkWrap:true,children:[
                    for(final id in suggested) GestureDetector(
                      onTap:()=>update(()=>model.text=id),
                      child:Padding(
                        padding:const EdgeInsets.symmetric(vertical:10,horizontal:13),
                        child:Text(id,style:const TextStyle(fontSize:13))),
                    )
                  ]),
                ),
              ],
              const SizedBox(height:15),
              KakaField(controller:model,label:'Model ID',hint:'provider/model-name'),
              const SizedBox(height:15),
              KakaField(controller:label,label:'Display label',hint:'Optional'),
              if(localError!=null) Padding(
                padding:const EdgeInsets.symmetric(vertical:12),
                child:Text(localError!,style:const TextStyle(
                  fontSize:13,color:KColors.error))),
              const SizedBox(height:20),
              KakaButton(title:'Save connection',busy:saving,onPressed:() async {
                if(url.text.trim().isEmpty||model.text.trim().isEmpty) {
                  update(()=>localError='Enter a base URL and model ID');
                  return;
                }
                update(() { saving=true; localError=null; });
                try {
                  await widget.api.rpc('models/connect',{
                    'provider':'openai-compatible',
                    'baseUrl':url.text.trim(),
                    'modelId':model.text.trim(),
                    if(key.text.trim().isNotEmpty) 'apiKey':key.text.trim(),
                    if(label.text.trim().isNotEmpty) 'label':label.text.trim(),
                  });
                  if(ctx.mounted)Navigator.of(ctx).pop();
                  await _refresh();
                } catch(e) {
                  if(ctx.mounted)update(()=>localError=e.toString());
                } finally { if(ctx.mounted)update(()=>saving=false); }
              }),
            ],
          ),
        ),
      ));
    } finally {
      // Controllers may be referenced during the closing animation.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        url.dispose();key.dispose();model.dispose();label.dispose();
      });
    }
  }

  Future<void> _setDefault(Map<String,dynamic> credential) async {
    final provider=credential['provider']?.toString()??'';
    final model=credential['modelId']?.toString()??'';
    if(provider.isEmpty||model.isEmpty){
      kakaNotice(context,'Choose a model first');
      return;
    }
    try {
      await widget.api.rpc('models/setDefault',{
        'provider':provider,'modelId':model,
      });
      await _refresh();
    }catch(e){if(mounted)kakaNotice(context,e.toString());}
  }

  Future<void> _disconnect(Map<String,dynamic> credential) async {
    final name=credential['label']?.toString()??'Model';
    final confirmed=await kakaSheet<bool>(context,Column(
      mainAxisSize:MainAxisSize.min,
      crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Text('Disconnect $name?',style:Theme.of(context).textTheme.titleLarge),
        const SizedBox(height:12),
        const Text('This removes the credential from your server.',
          style:TextStyle(fontSize:13,color:KColors.muted)),
        const SizedBox(height:22),
        KakaButton(title:'Disconnect',onPressed:()=>Navigator.pop(context,true)),
        const SizedBox(height:10),
        KakaButton(title:'Cancel',filled:false,onPressed:()=>Navigator.pop(context,false)),
      ]));
    if(confirmed!=true||!mounted)return;
    try{
      await widget.api.rpc('models/disconnect',{
        'provider':credential['provider']?.toString()??'',
      });
      await _refresh();
    }catch(e){if(mounted)kakaNotice(context,e.toString());}
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor:KColors.bg,
    body:SafeArea(child:Column(children:[
      Padding(padding:const EdgeInsets.fromLTRB(14,12,18,17),
        child:Row(children:[
          KakaIconButton(icon:LucideIcons.arrowLeft,
            onTap:()=>Navigator.pop(context)),
          const SizedBox(width:10),
          Expanded(child:Text('Models',style:Theme.of(context).textTheme.headlineMedium)),
          KakaIconButton(icon:LucideIcons.plus,filled:true,onTap:_openConnection),
        ])),
      Expanded(child:RefreshIndicator(onRefresh:_refresh,color:KColors.ink,
        child:ListView(padding:const EdgeInsets.fromLTRB(22,10,22,30),children:[
          if(loading) const KakaLoadingRail(),
          if(error!=null) Padding(padding:const EdgeInsets.only(bottom:15),
            child:Text(error!,style:const TextStyle(color:KColors.error,fontSize:13))),
          KakaSection(title:'CONNECTED MODELS',child:credentials.isEmpty
            ? const Padding(padding:EdgeInsets.all(19),child:Text('No models connected',
              style:TextStyle(fontSize:14,color:KColors.muted)))
            :Column(children:[
              for(final c in credentials) KakaRow(
                title:'${c['label'] ?? c['provider'] ?? 'Model'}',
                subtitle:'${c['modelId'] ?? c['provider'] ?? ''}',
                icon:c['isDefault']==true?LucideIcons.circleCheck:LucideIcons.cpu,
                trailing:KakaIconButton(icon:LucideIcons.ellipsis,size:35,
                  onTap:()=>kakaSheet<void>(context,Column(
                    mainAxisSize:MainAxisSize.min,children:[
                      KakaRow(title:'Use as default',icon:LucideIcons.check,
                        onTap:(){Navigator.pop(context);_setDefault(c);}),
                      KakaRow(title:'Disconnect',icon:LucideIcons.trash2,
                        onTap:(){Navigator.pop(context);_disconnect(c);}),
                    ]))),
                onTap:()=>_setDefault(c)),
            ])),
          const SizedBox(height:22),
          KakaSection(title:'AVAILABLE PROVIDERS',child:Column(children:[
            if(catalog.isEmpty) const Padding(padding:EdgeInsets.all(19),
              child:Text('Connect a model to get started',style:TextStyle(color:KColors.muted))),
            for(final provider in {
              for(final row in catalog)
                if(row['provider']!=null)
                  row['provider'].toString(): row['providerName']?.toString()??row['provider'].toString(),
            }.entries) KakaRow(title:provider.value,icon:LucideIcons.cpu),
          ])),
        ]))),
    ])),
  );
}
