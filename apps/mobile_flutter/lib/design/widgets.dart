import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'theme.dart';

/// Fast, self-drawn press feedback without Material ink/splash effects.
class _KakaPress extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _KakaPress({required this.child,this.onTap});
  @override
  State<_KakaPress> createState()=>_KakaPressState();
}
class _KakaPressState extends State<_KakaPress> {
  bool pressed=false;
  void _setPressed(bool value){
    if(widget.onTap==null||pressed==value)return;
    setState(()=>pressed=value);
  }
  @override
  Widget build(BuildContext context)=>GestureDetector(
    behavior:HitTestBehavior.opaque,
    onTap:widget.onTap,
    onTapDown:widget.onTap==null?null:(_)=>_setPressed(true),
    onTapUp:widget.onTap==null?null:(_)=>_setPressed(false),
    onTapCancel:()=>_setPressed(false),
    child:AnimatedScale(
      scale:pressed ? .965 : 1,
      duration:const Duration(milliseconds:130),
      curve:Curves.easeOutCubic,
      child:widget.child),
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
    child:_KakaPress(onTap:onTap,child:AnimatedOpacity(
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
    child:_KakaPress(onTap:busy?null:onPressed,child:AnimatedOpacity(
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
        duration:const Duration(milliseconds:220),
        curve:Curves.easeOutCubic,
        width:52,height:32,padding:const EdgeInsets.all(4),
        decoration:BoxDecoration(
          color:value?KColors.ink:KColors.line,
          borderRadius:BorderRadius.circular(20)),
        child:AnimatedAlign(
          duration:const Duration(milliseconds:220),
          curve:Curves.easeOutCubic,
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
  const KakaRow({super.key, required this.title, this.subtitle, required this.icon, this.onTap, this.trailing});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap, behavior: HitTestBehavior.opaque,
    child: Padding(padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 17),
      child: Row(children: [
        Icon(icon, size: 20, color: KColors.ink),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 15, color: KColors.ink)),
          if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 3),
            child: Text(subtitle!, style: const TextStyle(fontSize: 12, color: KColors.muted))),
        ])),
        trailing ?? const Icon(LucideIcons.chevronRight, size: 18, color: KColors.muted),
      ])),
  );
}

/// Custom in-app sheet; does not use platform menus or native dialogs.
Future<T?> kakaSheet<T>(BuildContext context, Widget content, {double? height}) =>
  showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: const Color(0x55000000),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (ctx, a, b) => Align(alignment: Alignment.bottomCenter,
      child: Material(type: MaterialType.transparency,
        child: SafeArea(top: false,
          child: Container(
            width: double.infinity,
            height: height,
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * .90),
            padding: const EdgeInsets.fromLTRB(20, 13, 20, 24),
            decoration: const BoxDecoration(color: KColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(KRadius.sheet))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 34, height: 4,
                decoration: BoxDecoration(color: KColors.line, borderRadius: BorderRadius.circular(8))),
              const SizedBox(height: 20),
              Flexible(child: content),
            ]),
          ),
        ),
      ),
    ),
    transitionBuilder: (ctx, animation, secondary, child) =>
      SlideTransition(position: Tween(begin: const Offset(0, 1), end: Offset.zero)
        .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)), child: child),
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
