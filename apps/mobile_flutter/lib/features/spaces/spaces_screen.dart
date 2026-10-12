import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../app/app_controller.dart';
import '../../core/api.dart';
import '../../design/theme.dart';
import '../../design/widgets.dart';

class SpacesScreen extends StatefulWidget {
  final AppController app;
  const SpacesScreen({super.key,required this.app});
  @override
  State<SpacesScreen> createState()=>_SpacesScreenState();
}
class _SpacesScreenState extends State<SpacesScreen> {
  List<Map<String,dynamic>> spaces=[];
  bool busy=false;
  String? error;
  @override
  void initState(){super.initState();_load();}
  Future<void> _load() async {
    if(mounted)setState(()=>busy=true);
    try {
      final data=await widget.app.api.rpc('spaces/list');
      if(!mounted)return;
      setState((){
        spaces=((data as Map)['spaces'] as List).whereType<Map>()
          .map((m)=>Map<String,dynamic>.from(m)).toList();
        error=null;
      });
    }catch(e){if(mounted)setState(()=>error=e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<String?> _nameDialog(String title,String initial) async {
    final ctrl=TextEditingController(text:initial);
    try{
      return await kakaSheet<String>(context,SingleChildScrollView(
        child:Column(mainAxisSize:MainAxisSize.min,
          crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            Text(title,style:Theme.of(context).textTheme.titleLarge),
            const SizedBox(height:18),
            KakaField(controller:ctrl,label:'Workspace name',
              hint:'My workspace'),
            const SizedBox(height:16),
            KakaButton(title:'Save',onPressed:(){
              final value=ctrl.text.trim();
              if(value.isNotEmpty && value.length<=80)Navigator.pop(context,value);
              else kakaNotice(context,'Enter 1–80 characters');
            }),
          ])));
    }finally {
      WidgetsBinding.instance.addPostFrameCallback((_)=>ctrl.dispose());
    }
  }
  Future<void> _create() async {
    final name=await _nameDialog('New Space','');
    if(name==null||!mounted)return;
    setState(()=>busy=true);
    try {
      final created=await widget.app.api.rpc('spaces/create',{'name':name});
      final id=(created as Map)['id']?.toString();
      if(id==null||id.isEmpty)throw const KakaApiException('Missing Space ID');
      await widget.app.chooseSpace(id);
      if(mounted)Navigator.pop(context);
    }catch(e){if(mounted)kakaNotice(context,e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> _rename(Map<String,dynamic> space) async {
    final name=await _nameDialog('Rename Space',space['name']?.toString()??'');
    if(name==null||!mounted)return;
    try {
      await widget.app.api.rpc('spaces/rename',{'spaceId':space['id'],'name':name});
      await widget.app.refresh();
      await _load();
    }catch(e){if(mounted)kakaNotice(context,e.toString());}
  }
  Future<void> _remove(Map<String,dynamic> space) async {
    final ok=await kakaSheet<bool>(context,Column(
      mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,
      children:[
        Text('Delete ${space['name']}?',style:Theme.of(context).textTheme.titleLarge),
        const SizedBox(height:12),
        const Text('Only empty, non-default Spaces can be deleted.',
          style:TextStyle(color:KColors.muted,fontSize:13)),
        const SizedBox(height:18),
        KakaButton(title:'Delete Space',onPressed:()=>Navigator.pop(context,true)),
        const SizedBox(height:9),
        KakaButton(title:'Cancel',filled:false,
          onPressed:()=>Navigator.pop(context,false)),
      ]));
    if(ok!=true)return;
    try {
      final data=await widget.app.api.rpc('spaces/remove',{'spaceId':space['id']});
      final next=(data as Map)['activeSpaceId']?.toString();
      if(next!=null&&next.isNotEmpty)await widget.app.chooseSpace(next);
      else await widget.app.refresh();
      await _load();
    }catch(e){if(mounted)kakaNotice(context,e.toString());}
  }
  Future<void> _menu(Map<String,dynamic> space) async {
    await kakaSheet<void>(context,Column(
      mainAxisSize:MainAxisSize.min,children:[
        KakaRow(title:'Rename Space',icon:LucideIcons.pencil,
          onTap:(){
            Navigator.pop(context);
            _rename(space);
          }),
        if(space['canDelete']==true)
          KakaRow(title:'Delete Space',icon:LucideIcons.trash2,
            onTap:(){Navigator.pop(context);_remove(space);}),
      ]));
  }
  Future<void> _select(String id) async {
    await widget.app.chooseSpace(id);
    if(mounted)Navigator.pop(context);
  }
  @override
  Widget build(BuildContext context)=>Scaffold(
    backgroundColor:KColors.bg,
    body:SafeArea(child:Column(children:[
      Padding(padding:const EdgeInsets.fromLTRB(12,12,16,18),child:Row(children:[
        KakaIconButton(icon:LucideIcons.arrowLeft,onTap:()=>Navigator.pop(context)),
        const SizedBox(width:9),
        Expanded(child:Text('Spaces',style:Theme.of(context).textTheme.headlineMedium)),
        KakaIconButton(icon:LucideIcons.plus,filled:true,
          onTap:busy?null:_create),
      ])),
      if(busy)const KakaLoadingRail(),
      Expanded(child:RefreshIndicator(onRefresh:_load,color:KColors.ink,
        child:ListView.builder(
          padding:const EdgeInsets.fromLTRB(22,14,22,40),
          itemCount:spaces.isEmpty?1:spaces.length,
          itemBuilder:(context,index){
            if(spaces.isEmpty)return Padding(
              padding:const EdgeInsets.only(top:60),
              child:Center(child:Text(error??'No Spaces found',
                style:const TextStyle(color:KColors.muted))));
            final space=spaces[index];
            final id=space['id']?.toString()??'';
            final selected=id==widget.app.api.spaceId;
            final bots=(space['bots'] is List)?(space['bots'] as List).length:0;
            return Container(
              margin:const EdgeInsets.only(bottom:9),
              padding:const EdgeInsets.symmetric(vertical:9,horizontal:10),
              decoration:BoxDecoration(color:KColors.surface,
                borderRadius:BorderRadius.circular(25)),
              child:Row(children:[
                Expanded(child:GestureDetector(
                  onTap:()=>_select(id),
                  child:Padding(
                    padding:const EdgeInsets.symmetric(vertical:11,horizontal:10),
                    child:Row(children:[
                      Icon(selected?LucideIcons.circleCheck:LucideIcons.layers,
                        size:21,color:KColors.ink),
                      const SizedBox(width:12),
                      Expanded(child:Column(
                        crossAxisAlignment:CrossAxisAlignment.start,children:[
                          Text(space['name']?.toString()??'Space',
                            style:const TextStyle(fontSize:15,fontWeight:FontWeight.w600)),
                          const SizedBox(height:4),
                          Text('$bots agents${space['isDefault']==true?' · Default':''}',
                            style:const TextStyle(color:KColors.muted,fontSize:12)),
                        ])),
                    ]),
                  ))),
                if(space['canRename']==true || space['canDelete']==true)
                  KakaIconButton(icon:LucideIcons.ellipsis,size:38,
                    onTap:()=>_menu(space)),
              ]),
            );
          }))),
    ])),
  );
}
