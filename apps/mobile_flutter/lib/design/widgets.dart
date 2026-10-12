import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/physics.dart';
import '../core/performance_prefs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'motion.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'theme.dart';

/// Responsive press feedback without underdamped spring overshoot.
/// An AnimationController is idle outside actual pointer interactions.
class KakaPress extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool haptic;
  const KakaPress({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.haptic = false,
  });

  @override
  State<KakaPress> createState() => _KakaPressState();
}

class _KakaPressState extends State<KakaPress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scale = AnimationController(
    vsync: this,
    lowerBound: .985,
    upperBound: 1,
    value: 1,
  );

  void _press(bool down) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    if (kakaReduceMotion(context)) {
      _scale.value = 1;
      return;
    }
    _scale.animateTo(
      down ? .985 : 1,
      duration: down
          ? const Duration(milliseconds: 95)
          : const Duration(milliseconds: 160),
      curve: KakaMotion.arrive,
    );
  }

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap == null
            ? null
            : () {
                if (widget.haptic) HapticFeedback.selectionClick();
                widget.onTap!();
              },
        onLongPress: widget.onLongPress,
        onTapDown: (_) => _press(true),
        onTapUp: (_) => _press(false),
        onTapCancel: () => _press(false),
        child: AnimatedBuilder(
          animation: _scale,
          child: widget.child,
          builder: (context, child) =>
              Transform.scale(scale: _scale.value, child: child),
        ),
      );
}

/// Icon graphics may be compact, but the hit area is never below 48 dp.
class KakaIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;
  final double size;
  final String? tooltip;

  const KakaIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.filled = false,
    this.size = 48,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final hitSize = math.max(KLayout.minTouchTarget, size);
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: tooltip,
      child: KakaPress(
        onTap: onTap,
        haptic: true,
        child: SizedBox(
          width: hitSize,
          height: hitSize,
          child: Center(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 140),
              opacity: onTap == null ? .45 : 1,
              child: Container(
                height: size,
                width: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: filled ? KColors.ink : KColors.surface,
                  borderRadius: BorderRadius.circular(size / 2),
                ),
                child: Icon(
                  icon,
                  size: size <= 40 ? 19 : 21,
                  color: filled ? Colors.white : KColors.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A common optical header: all back arrows use the same physical anchor,
/// titles share the same text baseline and actions retain 48 dp hit areas.
class KakaPageHeader extends StatelessWidget {
  final Widget title;
  final List<Widget> actions;
  final VoidCallback? onBack;

  const KakaPageHeader({
    super.key,
    required this.title,
    this.actions = const [],
    this.onBack,
  });

  @override
  Widget build(BuildContext context) => KakaContentWidth(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(
        children: [
          KakaIconButton(
            icon: LucideIcons.arrowLeft,
            tooltip: 'Back',
            onTap: onBack ?? () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DefaultTextStyle(
              style: Theme.of(context).textTheme.titleLarge ??
                  const TextStyle(fontSize: 17, color: KColors.ink),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              child: title,
            ),
          ),
          if (actions.isNotEmpty) const SizedBox(width: 8),
          ...actions,
        ],
      ),
    ),
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
          ? KakaLoadingDots(color:filled?Colors.white:KColors.ink)
          : Text(title,style:TextStyle(
              fontSize:15,fontWeight:FontWeight.w600,
              color:filled?Colors.white:KColors.ink)),
      ),
    )),
  );
}

class KakaField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool obscure;
  final int maxLines;
  final TextInputType? keyboardType;
  const KakaField({super.key,required this.controller,required this.label,
    this.hint='',this.obscure=false,this.maxLines=1,this.keyboardType});
  @override
  State<KakaField> createState()=>_KakaFieldState();
}
class _KakaFieldState extends State<KakaField> {
  final FocusNode _focus=FocusNode();
  bool _focused=false;
  @override
  void initState(){
    super.initState();
    _focus.addListener(_updateFocus);
  }
  void _updateFocus(){
    if(mounted)setState(()=>_focused=_focus.hasFocus);
  }
  @override
  void dispose(){
    _focus.removeListener(_updateFocus);
    _focus.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context)=>Column(
    crossAxisAlignment:CrossAxisAlignment.start,children:[
      Padding(padding:const EdgeInsets.only(left:3,bottom:10),
        child:Text(widget.label,style:const TextStyle(
          fontSize:12.5,fontWeight:FontWeight.w600,color:KColors.muted))),
      AnimatedContainer(
        duration:kakaReduceMotion(context)?Duration.zero:KakaMotion.standard,
        curve:KakaMotion.arrive,
        decoration:BoxDecoration(
          color:_focused?const Color(0xFFECECEB):KColors.soft,
          borderRadius:BorderRadius.circular(23)),
        child:TextField(
          focusNode:_focus,
          controller:widget.controller,
          obscureText:widget.obscure,
          maxLines:widget.maxLines,
          keyboardType:widget.keyboardType,
          cursorColor:KColors.ink,
          cursorRadius:const Radius.circular(3),
          style:const TextStyle(fontSize:16,color:KColors.ink,height:1.36),
          decoration:InputDecoration(
            hintText:widget.hint,
            hintStyle:const TextStyle(color:KColors.muted,fontSize:15),
            filled:false,
            contentPadding:const EdgeInsets.symmetric(
              vertical:18,horizontal:18),
            border:InputBorder.none,
            enabledBorder:InputBorder.none,
            focusedBorder:InputBorder.none,
          ),
        ),
      ),
    ],
  );
}

/// Three quiet, custom-painted loading beats instead of Android/Material spinners.
class KakaLoadingDots extends StatefulWidget {
  final Color color;
  const KakaLoadingDots({super.key,this.color=KColors.ink});
  @override
  State<KakaLoadingDots> createState()=>_KakaLoadingDotsState();
}
class _KakaLoadingDotsState extends State<KakaLoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller=AnimationController(
    vsync:this,duration:const Duration(milliseconds:1180));
  @override
  void initState(){
    super.initState();
    PerformancePrefs.lowPower.addListener(_syncMotion);
    _controller.repeat();
  }
  void _syncMotion(){
    if(!mounted)return;
    if(kakaReduceMotion(context))_controller.stop();
    else if(!_controller.isAnimating)_controller.repeat();
  }
  @override
  void didChangeDependencies(){super.didChangeDependencies();_syncMotion();}
  @override
  void dispose(){
    PerformancePrefs.lowPower.removeListener(_syncMotion);
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context)=>RepaintBoundary(
    child:SizedBox(width:37,height:17,
      child:AnimatedBuilder(animation:_controller,
        builder:(_,__)=>CustomPaint(painter:_DotsPainter(
          color:widget.color,phase:_controller.value))),
    ),
  );
}

class _DotsPainter extends CustomPainter {
  final Color color;
  final double phase;
  _DotsPainter({required this.color,required this.phase});
  @override
  void paint(Canvas canvas,Size size){
    final radius=math.min(3.2,size.width/13);
    final spacing=size.width/4;
    for(var i=0;i<3;i++){
      final wave=math.sin((phase*2*math.pi)-(i*.75));
      final y=size.height/2-wave*2.1;
      final alpha=(.44+(wave+1)*.28).clamp(.35,1.0).toDouble();
      canvas.drawCircle(Offset(spacing*(i+1),y),
        radius*(.84+.13*(wave+1)),
        Paint()..color=color.withValues(alpha:alpha));
    }
  }
  @override
  bool shouldRepaint(covariant _DotsPainter old)=>
    old.phase!=phase || old.color!=color;
}

/// A thin sliding capsule that preserves low visual weight in page headers.
class KakaLoadingRail extends StatefulWidget {
  final Color color;
  const KakaLoadingRail({super.key,this.color=KColors.ink});
  @override
  State<KakaLoadingRail> createState()=>_KakaLoadingRailState();
}
class _KakaLoadingRailState extends State<KakaLoadingRail>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller=AnimationController(
    vsync:this,duration:const Duration(milliseconds:1250));
  @override
  void initState(){
    super.initState();
    _controller.repeat();
    PerformancePrefs.lowPower.addListener(_sync);
  }
  void _sync(){
    if(!mounted)return;
    if(kakaReduceMotion(context))_controller.stop();
    else if(!_controller.isAnimating)_controller.repeat();
  }
  @override
  void didChangeDependencies(){super.didChangeDependencies();_sync();}
  @override
  void dispose(){
    PerformancePrefs.lowPower.removeListener(_sync);
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context)=>LayoutBuilder(builder:(ctx,c)=>
    SizedBox(height:3,child:AnimatedBuilder(animation:_controller,
      builder:(ctx,_) {
        final length=c.maxWidth.isFinite?c.maxWidth:120.0;
        final segment=math.max(12.0,length*.27);
        final start=_controller.isAnimating
          ?_controller.value*(length+segment)-segment:0.0;
        return Stack(clipBehavior:Clip.hardEdge,children:[
          Positioned.fill(child:DecoratedBox(decoration:BoxDecoration(
            color:KColors.soft,borderRadius:BorderRadius.circular(5)))),
          Positioned(left:start,top:0,width:segment,height:3,
            child:DecoratedBox(decoration:BoxDecoration(
              color:widget.color,borderRadius:BorderRadius.circular(5)))),
        ]);
      }),
    ));
}

/// Compact visible toggle with an accessible 48 dp vertical target.
class KakaSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  const KakaSwitch({super.key, required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) => Semantics(
    toggled: value,
    enabled: onChanged != null,
    onTap: onChanged == null ? null : () => onChanged!(!value),
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: SizedBox(
        width: 52,
        height: KLayout.minTouchTarget,
        child: Center(
          child: AnimatedContainer(
            duration: kakaReduceMotion(context)
                ? Duration.zero : KakaMotion.standard,
            curve: KakaMotion.arrive,
            width: 52,
            height: 32,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: value ? KColors.ink : KColors.line,
              borderRadius: BorderRadius.circular(20),
            ),
            child: AnimatedAlign(
              duration: kakaReduceMotion(context)
                  ? Duration.zero : KakaMotion.standard,
              curve: KakaMotion.arrive,
              alignment: value
                  ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
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
      Padding(padding: const EdgeInsets.only(left: 5, bottom: 10),
        child: Text(title, style: const TextStyle(fontSize: 12, letterSpacing: .7, fontWeight: FontWeight.w600, color: KColors.muted))),
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
      padding:const EdgeInsets.symmetric(vertical:10,horizontal:15),
      child:Row(children:[
        Container(width:42,height:42,alignment:Alignment.center,
          decoration:BoxDecoration(color:KColors.soft,
            borderRadius:BorderRadius.circular(16)),
          child:Icon(icon,size:19,color:KColors.ink)),
        const SizedBox(width:14),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(title,style:const TextStyle(fontSize:15,
            fontWeight:FontWeight.w500,color:KColors.ink)),
          if(subtitle!=null)Padding(padding:const EdgeInsets.only(top:4),
            child:Text(subtitle!,maxLines:2,overflow:TextOverflow.ellipsis,
              style:const TextStyle(fontSize:13,color:KColors.muted,height:1.35))),
        ])),
        const SizedBox(width:8),
        trailing ?? (onTap==null?const SizedBox.shrink():
          Icon(LucideIcons.chevronRight,
            size:KLayout.trailingIcon,color:KColors.muted.withValues(alpha:.75))),
      ]),
    ),
  );
}

/// A single visual depth shared by Kaka's custom dialog routes and page
/// surfaces. The navigator stays unscaled, so sheets always remain crisp.
abstract final class KakaSheetDepth {
  static final ValueNotifier<double> progress = ValueNotifier<double>(0);
}

/// Underlay moves back 8%, rounds its corners, and dims without blurring
/// the whole live chat. The page subtree itself remains mounted.
class KakaDepthStage extends StatelessWidget {
  final Widget child;
  const KakaDepthStage({super.key,required this.child});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
    valueListenable:KakaSheetDepth.progress,
    child:child,
    builder:(context,progress,page) {
      if (progress<=.001) return page!;
      final t=progress.clamp(0.0,1.0);
      return ColoredBox(
        color:KColors.ink,
        child:Stack(children:[
          Positioned.fill(child:Transform.scale(
            scale:1-.08*t,
            child:ClipRRect(
              borderRadius:BorderRadius.circular(32*t),
              child:page!,
            ),
          )),
          Positioned.fill(child:IgnorePointer(child:ColoredBox(
            color:Colors.black.withValues(alpha:.16*t),
          ))),
        ]),
      );
    },
  );
}

class _KakaSheetSpringCurve extends Curve {
  const _KakaSheetSpringCurve();
  @override
  double transformInternal(double t) {
    if (t<=0) return 0;
    if (t>=1) return 1;
    return SpringSimulation(
      const SpringDescription(mass:1,stiffness:265,damping:23),
      0,1,0,
    ).x(t*.42);
  }
}

class _KakaDraggableSheet extends StatefulWidget {
  final Animation<double> animation;
  final Widget child;
  final GlobalKey surfaceKey;
  const _KakaDraggableSheet({
    super.key,
    required this.animation,required this.child,required this.surfaceKey,
  });
  @override
  State<_KakaDraggableSheet> createState()=>_KakaDraggableSheetState();
}

class _KakaDraggableSheetState extends State<_KakaDraggableSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drag =
      AnimationController.unbounded(vsync:this);
  double get _height {
    final render=widget.surfaceKey.currentContext?.findRenderObject();
    if(render is RenderBox && render.hasSize) return render.size.height;
    return MediaQuery.sizeOf(context).height*.75;
  }

  @override
  void initState() {
    super.initState();
    widget.animation.addListener(_syncDepth);
    _drag.addListener(_syncDepth);
  }

  @override
  void didUpdateWidget(covariant _KakaDraggableSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if(oldWidget.animation!=widget.animation) {
      oldWidget.animation.removeListener(_syncDepth);
      widget.animation.addListener(_syncDepth);
    }
  }

  void _syncDepth() {
    final t=widget.animation.value.clamp(0.0,1.0);
    final route=kakaReduceMotion(context)
        ? t : const _KakaSheetSpringCurve().transform(t).clamp(0.0,1.0);
    final factor=(1-_drag.value/math.max(1,_height)).clamp(0.0,1.0);
    final next=(route*factor).clamp(0.0,1.0);
    if ((KakaSheetDepth.progress.value-next).abs()>.001) {
      KakaSheetDepth.progress.value=next;
    }
  }

  void _dragUpdate(DragUpdateDetails details) {
    if(kakaReduceMotion(context))return;
    _drag.stop();
    final delta=details.primaryDelta??0;
    // Pulling up is possible but deliberately more resistant.
    _drag.value=(_drag.value+(delta<0?delta*.22:delta)).clamp(-34.0,_height);
  }

  void _dragEnd(DragEndDetails details) {
    final velocity=details.primaryVelocity??0.0;
    if (_drag.value>_height/3 || velocity>950) {
      Navigator.of(context).pop();
      return;
    }
    if(kakaReduceMotion(context)) {
      _drag.value=0;
    } else {
      _drag.animateWith(SpringSimulation(
        const SpringDescription(mass:1,stiffness:310,damping:24),
        _drag.value,0,velocity,
      ));
    }
  }

  @override
  void dispose() {
    widget.animation.removeListener(_syncDepth);
    _drag.removeListener(_syncDepth);
    _drag.dispose();
    KakaSheetDepth.progress.value=0;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation:Listenable.merge([widget.animation,_drag]),
    child:widget.child,
    builder:(context,child) {
      final reduced=kakaReduceMotion(context);
      final progress=reduced
          ? widget.animation.value
          : const _KakaSheetSpringCurve().transform(widget.animation.value);
      final entry=math.min(_height,MediaQuery.sizeOf(context).height*.9);
      return Transform.translate(
        offset:Offset(0,(1-progress)*entry+_drag.value),
        child:AnimatedPadding(
          padding:EdgeInsets.only(
            bottom:MediaQuery.viewInsetsOf(context).bottom),
          duration:reduced?Duration.zero:KakaMotion.quick,
          curve:KakaMotion.arrive,
          child:child!,
        ),
      );
    },
  );
}

/// Custom bottom sheet. A real spring samples the entering position while the
/// parent page retreats in sync; drag gestures can dismiss or spring back.
Future<T?> kakaSheet<T>(BuildContext context, Widget content, {double? height}) {
  final sheetSurfaceKey=GlobalKey();
  final transitionKey=GlobalKey<_KakaDraggableSheetState>();
  return showGeneralDialog<T>(
      context:context,
      barrierDismissible:true,
      barrierLabel:'Dismiss',
      barrierColor:const Color(0x62000000),
      transitionDuration:kakaReduceMotion(context)
          ? const Duration(milliseconds:180)
          : const Duration(milliseconds:400),
      pageBuilder:(ctx,a,b)=>Align(
        alignment:Alignment.bottomCenter,
        child:Material(
          type:MaterialType.transparency,
          child:SafeArea(
            top:false,
            child:GestureDetector(
              behavior:HitTestBehavior.opaque,
              onVerticalDragUpdate:(details)=>
                transitionKey.currentState?._dragUpdate(details),
              onVerticalDragEnd:(details)=>
                transitionKey.currentState?._dragEnd(details),
              child:ClipRRect(
                key:sheetSurfaceKey,
                borderRadius:const BorderRadius.vertical(
                  top:Radius.circular(KRadius.sheet)),
                child:Container(
                  width:double.infinity,
                  height:height,
                  constraints:BoxConstraints(
                    maxHeight:MediaQuery.sizeOf(ctx).height*.90),
                  padding:const EdgeInsets.fromLTRB(21,13,21,25),
                  color:Colors.white.withValues(alpha:.98),
                  child:Column(
                    mainAxisSize:MainAxisSize.min,
                    children:[
                      Semantics(
                        label:'Drag down to close',
                        child:Container(
                          width:54,height:28,
                          alignment:Alignment.topCenter,
                          child:Container(
                            width:34,height:4,
                            decoration:BoxDecoration(
                              color:KColors.ink.withValues(alpha:.15),
                              borderRadius:BorderRadius.circular(9)),
                          ),
                        ),
                      ),
                      const SizedBox(height:8),
                      Flexible(child:content),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      transitionBuilder:(ctx,animation,secondary,child)=>
        _KakaDraggableSheet(
          key:transitionKey,
          animation:animation,child:child,
          surfaceKey:sheetSurfaceKey),
    );
}

/// Lightweight animated notice; removes its OverlayEntry and ticker on exit.
void kakaNotice(BuildContext context,String message) {
  late OverlayEntry entry;
  var removed=false;
  void remove(){
    if(removed)return;
    removed=true;
    entry.remove();
    entry.dispose();
  }
  entry=OverlayEntry(builder:(ctx)=>_KakaNotice(
    message:message,onDismiss:remove));
  Overlay.of(context).insert(entry);
}

class _KakaNotice extends StatefulWidget {
  final String message;
  final VoidCallback onDismiss;
  const _KakaNotice({required this.message,required this.onDismiss});
  @override
  State<_KakaNotice> createState()=>_KakaNoticeState();
}
class _KakaNoticeState extends State<_KakaNotice>
    with SingleTickerProviderStateMixin {
  late final AnimationController animation=AnimationController(
    vsync:this,duration:KakaMotion.standard,reverseDuration:KakaMotion.quick);
  bool closing=false;
  @override
  void initState(){
    super.initState();
    animation.forward();
    _expire();
  }
  Future<void> _expire() async {
    await Future<void>.delayed(const Duration(milliseconds:2400));
    if(mounted)await _close();
  }
  Future<void> _close() async {
    if(closing)return;
    closing=true;
    try{await animation.reverse();}
    finally{if(mounted)widget.onDismiss();}
  }
  @override
  void dispose(){animation.dispose();super.dispose();}
  @override
  Widget build(BuildContext context) {
    final reduced=kakaReduceMotion(context);
    final curve=CurvedAnimation(parent:animation,
      curve:KakaMotion.arrive,reverseCurve:KakaMotion.depart);
    return Positioned(
      left:22,right:22,
      bottom:math.max(MediaQuery.viewInsetsOf(context).bottom,
          MediaQuery.viewPaddingOf(context).bottom)+26,
      child:FadeTransition(opacity:curve,
        child:SlideTransition(
          position:Tween<Offset>(
            begin:reduced?Offset.zero:const Offset(0,.32),
            end:Offset.zero).animate(curve),
          child:ScaleTransition(
            scale:Tween<double>(begin:reduced?1:.96,end:1).animate(curve),
            child:Center(child:KakaPress(
              onTap:()=>_close(),
              child:Material(type:MaterialType.transparency,
                child:Semantics(liveRegion:true,
                  child:Container(
                    constraints:const BoxConstraints(maxWidth:480),
                    padding:const EdgeInsets.symmetric(
                      horizontal:21,vertical:16),
                    decoration:BoxDecoration(color:KColors.ink,
                      borderRadius:BorderRadius.circular(25)),
                    child:Text(widget.message,
                      textAlign:TextAlign.center,
                      style:const TextStyle(color:Colors.white,
                        fontSize:13,height:1.45)),
                  ),
                ),
              ),
            )),
          ),
        ),
      ),
    );
  }
}
