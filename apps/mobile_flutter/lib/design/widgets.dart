import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'motion.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'theme.dart';

/// A velocity-aware press spring shared by all custom controls.
class KakaPress extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool haptic;
  const KakaPress({super.key,required this.child,this.onTap,
    this.onLongPress,this.haptic=false});
  @override
  State<KakaPress> createState()=>_KakaPressState();
}
class _KakaPressState extends State<KakaPress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scale=AnimationController.unbounded(
    vsync:this,value:1);
  void _press(bool down) {
    if(widget.onTap==null && widget.onLongPress==null)return;
    if(kakaReduceMotion(context)) {
      _scale.value=1;
      return;
    }
    _scale.animateWith(SpringSimulation(
      KakaMotion.pressSpring,_scale.value,down?.963:1,0));
  }
  @override
  void dispose(){_scale.dispose();super.dispose();}
  @override
  Widget build(BuildContext context)=>GestureDetector(
    behavior:HitTestBehavior.opaque,
    onTap:widget.onTap==null?null:(){
      if(widget.haptic)HapticFeedback.selectionClick();
      widget.onTap!();
    },
    onLongPress:widget.onLongPress,
    onTapDown:(_)=>_press(true),
    onTapUp:(_)=>_press(false),
    onTapCancel:()=>_press(false),
    child:AnimatedBuilder(animation:_scale,child:widget.child,
      builder:(context,child)=>Transform.scale(
        scale:_scale.value,child:child)),
  );
}

class KakaIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;
  final double size;
  final String? tooltip;
  const KakaIconButton({super.key, required this.icon, this.onTap,
    this.filled = false, this.size = 48, this.tooltip});
  @override
  Widget build(BuildContext context)=>Semantics(
    button:true,enabled:onTap!=null,label:tooltip,
    child:KakaPress(onTap:onTap,haptic:true,child:AnimatedOpacity(
      duration:const Duration(milliseconds:140),
      opacity:onTap==null ? .45 : 1,
      child:Container(
        height:size,width:size,
        decoration:BoxDecoration(
          color:filled?KColors.ink:KColors.surface,
          borderRadius:BorderRadius.circular(size/2)),
        alignment:Alignment.center,
        child:Icon(icon,size:21,color:filled?Colors.white:KColors.ink),
      ),
    )),
  );
}

class KakaButton extends StatelessWidget {
  final String title;
  final VoidCallback? onPressed;
  final bool filled;
  final bool busy;
  const KakaButton({super.key,required this.title,this.onPressed,
    this.filled=true,this.busy=false});
  @override
  Widget build(BuildContext context)=>Semantics(
    button:true,enabled:onPressed!=null&&!busy,label:title,
    child:KakaPress(onTap:busy?null:onPressed,haptic:true,child:AnimatedOpacity(
      duration:const Duration(milliseconds:140),
      opacity:onPressed==null||busy ? .55 : 1,
      child:Container(
        height:54,alignment:Alignment.center,
        decoration:BoxDecoration(
          color:filled?KColors.ink:KColors.soft,
          borderRadius:BorderRadius.circular(KRadius.button)),
        child:busy
          ? SizedBox(width:19,height:19,child:CircularProgressIndicator(
              strokeWidth:2,color:filled?Colors.white:KColors.ink))
          : Text(title,style:TextStyle(
              fontSize:15,fontWeight:FontWeight.w600,
              color:filled?Colors.white:KColors.ink)),
      ),
    )),
  );
}

class KakaField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool obscure;
  final int maxLines;
  final TextInputType? keyboardType;
  const KakaField({super.key, required this.controller, required this.label,
    this.hint = '', this.obscure = false, this.maxLines = 1, this.keyboardType});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: KColors.muted)),
      const SizedBox(height: 9),
      TextField(
        controller: controller, obscureText: obscure, maxLines: maxLines, keyboardType: keyboardType,
        style: const TextStyle(fontSize: 16, color: KColors.ink),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: KColors.muted),
          filled: true, fillColor: KColors.soft,
          contentPadding: const EdgeInsets.symmetric(vertical: 17, horizontal: 18),
          border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(21)),
        ),
      ),
    ],
  );
}

class KakaSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  const KakaSwitch({super.key,required this.value,this.onChanged});
  @override
  Widget build(BuildContext context)=>Semantics(
    toggled:value,
    enabled:onChanged!=null,
    onTap:onChanged==null?null:()=>onChanged!(!value),
    child:GestureDetector(onTap:onChanged==null?null:()=>onChanged!(!value),
      child:AnimatedContainer(
        duration:KakaMotion.standard,
        curve:KakaMotion.arrive,
        width:52,height:32,padding:const EdgeInsets.all(4),
        decoration:BoxDecoration(
          color:value?KColors.ink:KColors.line,
          borderRadius:BorderRadius.circular(20)),
        child:AnimatedAlign(
          duration:KakaMotion.standard,
          curve:KakaMotion.arrive,
          alignment:value?Alignment.centerRight:Alignment.centerLeft,
          child:Container(width:24,height:24,
            decoration:const BoxDecoration(color:Colors.white,shape:BoxShape.circle)),
        ),
      ),
    ),
  );
}

class KakaSection extends StatelessWidget {
  final String title;
  final Widget child;
  const KakaSection({super.key, required this.title, required this.child});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(padding: const EdgeInsets.only(left: 4, bottom: 11),
        child: Text(title, style: const TextStyle(fontSize: 13, color: KColors.muted))),
      Container(width: double.infinity,
        decoration: BoxDecoration(color: KColors.surface, borderRadius: BorderRadius.circular(KRadius.card)),
        child: child),
    ],
  );
}

class KakaRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final Widget? trailing;
  const KakaRow({super.key,required this.title,this.subtitle,
    required this.icon,this.onTap,this.trailing});
  @override
  Widget build(BuildContext context) => KakaPress(onTap:onTap,
    child:Padding(
      padding:const EdgeInsets.symmetric(vertical:12,horizontal:14),
      child:Row(children:[
        Container(width:42,height:42,alignment:Alignment.center,
          decoration:BoxDecoration(color:KColors.soft,
            borderRadius:BorderRadius.circular(16)),
          child:Icon(icon,size:19,color:KColors.ink)),
        const SizedBox(width:13),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(title,style:const TextStyle(fontSize:14.5,
            fontWeight:FontWeight.w500,color:KColors.ink)),
          if(subtitle!=null)Padding(padding:const EdgeInsets.only(top:4),
            child:Text(subtitle!,maxLines:2,overflow:TextOverflow.ellipsis,
              style:const TextStyle(fontSize:12,color:KColors.muted,height:1.35))),
        ])),
        const SizedBox(width:8),
        trailing ?? Icon(LucideIcons.chevronRight,
          size:17,color:KColors.muted.withValues(alpha:.75)),
      ]),
    ),
  );
}

/// Custom, spring-like bottom sheet with blur and no Material surface border.
Future<T?> kakaSheet<T>(BuildContext context, Widget content, {double? height}) =>
  showGeneralDialog<T>(
    context:context,
    barrierDismissible:true,
    barrierLabel:'Dismiss',
    barrierColor:const Color(0x62000000),
    transitionDuration:kakaReduceMotion(context)
      ?const Duration(milliseconds:150):KakaMotion.sheet,
    pageBuilder:(ctx,a,b)=>Align(alignment:Alignment.bottomCenter,
      child:Material(type:MaterialType.transparency,
        child:SafeArea(top:false,child:ClipRRect(
          borderRadius:const BorderRadius.vertical(
            top:Radius.circular(KRadius.sheet)),
          child:BackdropFilter(
            filter:ImageFilter.blur(sigmaX:16,sigmaY:16),
            child:Container(
              width:double.infinity,
              height:height,
              constraints:BoxConstraints(
                maxHeight:MediaQuery.sizeOf(ctx).height*.90),
              padding:const EdgeInsets.fromLTRB(21,13,21,25),
              color:Colors.white.withValues(alpha:.94),
              child:Column(mainAxisSize:MainAxisSize.min,children:[
                Container(width:32,height:4,
                  decoration:BoxDecoration(
                    color:KColors.ink.withValues(alpha:.11),
                    borderRadius:BorderRadius.circular(9))),
                const SizedBox(height:22),
                Flexible(child:content),
              ]),
            ),
          ),
        )),
      ),
    ),
    transitionBuilder:(ctx,animation,secondary,child){
      if(kakaReduceMotion(ctx))return FadeTransition(
        opacity:animation,child:child);
      final value=CurvedAnimation(parent:animation,
        curve:KakaMotion.arrive,reverseCurve:KakaMotion.depart);
      return FadeTransition(
        opacity:Tween<double>(begin:.42,end:1).animate(value),
        child:SlideTransition(
          position:Tween<Offset>(
            begin:const Offset(0,.22),end:Offset.zero).animate(value),
          child:ScaleTransition(
            scale:Tween<double>(begin:.975,end:1).animate(value),
            alignment:Alignment.bottomCenter,
            child:child,
          ),
        ),
      );
    },
  );

void kakaNotice(BuildContext context, String message) {
  final entry = OverlayEntry(builder: (ctx) => Positioned(
    left: 24, right: 24, bottom: MediaQuery.paddingOf(ctx).bottom + 26,
    child: IgnorePointer(child: Material(type: MaterialType.transparency,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        decoration: BoxDecoration(color: KColors.ink, borderRadius: BorderRadius.circular(22)),
        child: Text(message, textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 13)),
      ))),
  ));
  Overlay.of(context).insert(entry);
  Future<void>.delayed(const Duration(seconds: 3), entry.remove);
}
