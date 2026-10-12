import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import '../core/performance_prefs.dart';

/// One language for motion across routes, buttons, sheets and navigation.
/// Uses custom opacity/offset/scale transitions instead of Android platform defaults.
abstract final class KakaMotion {
  static const route = Duration(milliseconds: 410);
  static const sheet = Duration(milliseconds: 470);
  static const quick = Duration(milliseconds: 190);
  static const standard = Duration(milliseconds: 320);
  static const Curve arrive = Cubic(.16, 1, .30, 1);
  static const Curve depart = Cubic(.55, 0, 1, .45);
  static const Curve flourish = Cubic(.18, 1.15, .38, 1);
  static const SpringDescription pressSpring =
      SpringDescription(mass: 1, stiffness: 330, damping: 29);
}

/// Respect OS reduced-motion and app low-power mode.
bool kakaReduceMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context) || PerformancePrefs.lowPower.value;

class KakaPageTransitionsBuilder extends PageTransitionsBuilder {
  const KakaPageTransitionsBuilder();
  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context,
      Animation<double> animation, Animation<double> secondaryAnimation,
      Widget child) {
    if (kakaReduceMotion(context)) {
      return FadeTransition(opacity: animation, child: child);
    }
    final incoming = CurvedAnimation(parent: animation,
      curve: KakaMotion.arrive, reverseCurve: KakaMotion.depart);
    final outgoing = CurvedAnimation(parent: secondaryAnimation,
      curve: KakaMotion.arrive, reverseCurve: KakaMotion.depart);
    return FadeTransition(
      opacity: Tween<double>(begin: .72, end: 1).animate(incoming),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(.07, .018), end: Offset.zero).animate(incoming),
        child: ScaleTransition(
          scale: Tween<double>(begin: .985, end: 1).animate(incoming),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset.zero, end: const Offset(-.032, 0)).animate(outgoing),
            child: child,
          ),
        ),
      ),
    );
  }
}

class KakaRoute<T> extends PageRouteBuilder<T> {
  KakaRoute({required WidgetBuilder builder, super.settings})
    : super(
      transitionDuration: KakaMotion.route,
      reverseTransitionDuration: const Duration(milliseconds: 340),
      pageBuilder: (context, animation, secondary) => builder(context),
      transitionsBuilder: (context, animation, secondary, child) {
        if(kakaReduceMotion(context))return FadeTransition(
          opacity: animation,child:child);
        final curved=CurvedAnimation(parent:animation,
          curve:KakaMotion.arrive,reverseCurve:KakaMotion.depart);
        return FadeTransition(
          opacity:Tween(begin:.76,end:1.0).animate(curved),
          child:SlideTransition(
            position:Tween(begin:const Offset(.09,.012),
              end:Offset.zero).animate(curved),
            child:ScaleTransition(
              scale:Tween(begin:.985,end:1.0).animate(curved),
              child:child,
            ),
          ),
        );
      },
    );
}

/// Four narrow, non-overlapping backdrop bands produce a smooth stepped
/// progressive blur. Restricted to a small chrome region (not scroll content).
/// In low-power mode this becomes a cheap translucent gradient.
class KakaProgressiveBlur extends StatelessWidget {
  final bool fromTop;
  final Color tint;
  const KakaProgressiveBlur({super.key,this.fromTop=false,
    this.tint=const Color(0xFFFAFAFA)});
  @override
  Widget build(BuildContext context) {
    final reduce=kakaReduceMotion(context);
    return IgnorePointer(child:LayoutBuilder(builder:(context,size){
      final width=size.maxWidth, height=size.maxHeight;
      if(!width.isFinite || !height.isFinite || height<=0)return const SizedBox.shrink();
      if(reduce)return DecoratedBox(decoration:BoxDecoration(
        gradient:LinearGradient(
          begin:fromTop?Alignment.topCenter:Alignment.bottomCenter,
          end:fromTop?Alignment.bottomCenter:Alignment.topCenter,
          colors:[tint.withValues(alpha:.94),tint.withValues(alpha:0)])));
      final blurs=<double>[2,5,9,15,21];
      final bandHeight=height/blurs.length;
      return Stack(fit:StackFit.expand,children:[
        for(var i=0;i<blurs.length;i++)
          Positioned(
            left:0,right:0,
            top:fromTop?i*bandHeight:null,
            bottom:fromTop?null:i*bandHeight,
            height:bandHeight+.5,
            child:ClipRect(child:BackdropFilter(
              filter:ImageFilter.blur(sigmaX:blurs[i],sigmaY:blurs[i]),
              child:const SizedBox.expand(),
            )),
          ),
        DecoratedBox(decoration:BoxDecoration(
          gradient:LinearGradient(
            begin:fromTop?Alignment.topCenter:Alignment.bottomCenter,
            end:fromTop?Alignment.bottomCenter:Alignment.topCenter,
            stops:const [0,.22,.52,.79,1],
            colors:[
              tint.withValues(alpha:.78),
              tint.withValues(alpha:.62),
              tint.withValues(alpha:.35),
              tint.withValues(alpha:.12),
              tint.withValues(alpha:0),
            ],
          ),
        )),
      ]);
    }));
  }
}

/// Rounded translucent control surface, with no outline or heavy shadow.
class KakaGlassSurface extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final double sigma;
  const KakaGlassSurface({super.key,required this.child,
    this.radius=34,this.padding=EdgeInsets.zero,this.sigma=18});
  @override
  Widget build(BuildContext context) {
    final low=kakaReduceMotion(context);
    return ClipRRect(
      borderRadius:BorderRadius.circular(radius),
      child:BackdropFilter(
        filter:ImageFilter.blur(sigmaX:low?0:sigma,sigmaY:low?0:sigma),
        child:DecoratedBox(
          decoration:BoxDecoration(
            color:Colors.white.withValues(alpha:low ? .94 : .77)),
          child:Padding(padding:padding,child:child),
        ),
      ),
    );
  }
}
