import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../core/models.dart';
import '../../design/theme.dart';
import '../../design/widgets.dart';
import 'organic_avatar.dart';

/// Local preview and persistence while the server-side avatar profile contract
/// is being added. Settings are intentionally namespaced by bot id.
class AvatarEditor extends StatefulWidget {
  final KakaBot bot;
  const AvatarEditor({super.key, required this.bot});
  @override
  State<AvatarEditor> createState()=>_AvatarEditorState();
}
class _AvatarEditorState extends State<AvatarEditor> {
  static const storage=FlutterSecureStorage();
  int shape=0, expression=0, color=0;
  @override
  void initState() {
    super.initState();
    _restore();
  }
  Future<void> _restore() async {
    try {
      final id=widget.bot.id;
      final v=await Future.wait([
        storage.read(key:'kaka.avatar.$id.shape'),
        storage.read(key:'kaka.avatar.$id.expression'),
        storage.read(key:'kaka.avatar.$id.color'),
      ]);
      if(!mounted)return;
      setState((){
        shape=int.tryParse(v[0]??'')??0;
        expression=int.tryParse(v[1]??'')??0;
        color=int.tryParse(v[2]??'')??0;
      });
    }catch(_){}
  }
  Future<void> _save() async {
    final id=widget.bot.id;
    try{
      await Future.wait([
        storage.write(key:'kaka.avatar.$id.shape',value:'$shape'),
        storage.write(key:'kaka.avatar.$id.expression',value:'$expression'),
        storage.write(key:'kaka.avatar.$id.color',value:'$color'),
      ]);
      if(mounted)kakaNotice(context,'Avatar saved on this device');
    }catch(e){if(mounted)kakaNotice(context,e.toString());}
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor:KColors.bg,
    body:SafeArea(child:Column(children:[
      Padding(padding:const EdgeInsets.fromLTRB(15,12,15,6),
        child:Row(children:[
          KakaIconButton(icon:LucideIcons.arrowLeft,onTap:()=>Navigator.pop(context)),
          const SizedBox(width:8),
          Expanded(child:Text('Avatar',style:Theme.of(context).textTheme.titleLarge)),
          KakaIconButton(icon:LucideIcons.check,onTap:_save,filled:true),
        ])),
      Expanded(child:ListView(padding:const EdgeInsets.fromLTRB(22,14,22,24),children:[
        Container(height:245,
          decoration:BoxDecoration(color:KColors.surface,
            borderRadius:BorderRadius.circular(32)),
          alignment:Alignment.center,
          child:OrganicAvatar(size:190,
            shapeIndex:shape,expressionIndex:expression,
            color:OrganicPresets.colors[color%OrganicPresets.colors.length])),
        const SizedBox(height:26),
        Text('Shape',style:Theme.of(context).textTheme.titleLarge),
        const SizedBox(height:12),
        _grid(OrganicPresets.shapes.length,4,(i)=>OrganicPresets.shapes[i],shape,(i)=>setState(()=>shape=i)),
        const SizedBox(height:23),
        Text('Expression',style:Theme.of(context).textTheme.titleLarge),
        const SizedBox(height:12),
        _grid(OrganicPresets.expressions.length,4,(i)=>OrganicPresets.expressions[i],
          expression,(i)=>setState(()=>expression=i)),
        const SizedBox(height:23),
        Text('Color',style:Theme.of(context).textTheme.titleLarge),
        const SizedBox(height:13),
        Wrap(spacing:13,runSpacing:13,
          children:List.generate(OrganicPresets.colors.length,(i)=>
            GestureDetector(onTap:()=>setState(()=>color=i),
              child:Container(width:43,height:43,padding:const EdgeInsets.all(4),
                decoration:BoxDecoration(shape:BoxShape.circle,
                  border:Border.all(color:color==i?KColors.ink:Colors.transparent,width:2)),
                child:DecoratedBox(decoration:BoxDecoration(shape:BoxShape.circle,
                  color:OrganicPresets.colors[i])))))),
        const SizedBox(height:25),
        const Text('Animation preview uses organic idle motion. The complete reference timeline is tracked for the next migration stage.',
          style:TextStyle(color:KColors.muted,fontSize:12,height:1.5)),
      ])),
    ])),
  );

  Widget _grid(int count,int columns,String Function(int) label,int active,void Function(int) choose) =>
    GridView.builder(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),
      itemCount:count,
      gridDelegate:SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:columns,crossAxisSpacing:8,mainAxisSpacing:8,
        childAspectRatio:count > 8 ? .92 : 1),
      itemBuilder:(context,index)=>GestureDetector(onTap:()=>choose(index),
        child:Container(
          decoration:BoxDecoration(
            color:index==active?KColors.ink:KColors.surface,
            borderRadius:BorderRadius.circular(19)),
          padding:const EdgeInsets.all(7),
          child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
            OrganicAvatar(size:count>8?33:40,
              shapeIndex:count==8?index:shape,
              expressionIndex:count>8?index:expression,
              color:index==active?Colors.white:KColors.ink),
            const SizedBox(height:5),
            Text(label(index),textAlign:TextAlign.center,maxLines:1,
              overflow:TextOverflow.ellipsis,
              style:TextStyle(fontSize:10,
                color:index==active?Colors.white:KColors.muted)),
          ]),
        )),
    );
}
