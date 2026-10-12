import 'package:flutter/material.dart';

import '../core/performance_prefs.dart';
import 'theme.dart';

/// Consistent, short, non-overshooting motion for Kaka's custom controls.
abstract final class KakaMotion {
  static const route = Duration(milliseconds: 280);
  static const sheet = Duration(milliseconds: 330);
  static const quick = Duration(milliseconds: 140);
  static const standard = Duration(milliseconds: 230);

  // Curves stay within the start/end values: no spring overshoot or rubber-band
  // motion when navigating between full-screen pages.
  static const Curve arrive = Cubic(.20, .78, .24, 1);
  static const Curve depart = Cubic(.45, 0, .80, .55);
  static const Curve flourish = Cubic(.22, .76, .20, 1);
}

bool kakaReduceMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context) || PerformancePrefs.lowPower.value;

/// Material routes and KakaRoute use the same visual language.
/// Do not scale the entire route or additionally translate the outgoing route:
/// those transforms combine badly with text, live blur, and gesture navigation.
class KakaPageTransitionsBuilder extends PageTransitionsBuilder {
  const KakaPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (kakaReduceMotion(context)) {
      return FadeTransition(opacity: animation, child: child);
    }
    final offset = Tween<Offset>(
      begin: const Offset(.035, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: KakaMotion.arrive,
      reverseCurve: KakaMotion.depart,
    ));
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(position: offset, child: child),
    );
  }
}

class KakaRoute<T> extends PageRouteBuilder<T> {
  KakaRoute({required WidgetBuilder builder, super.settings})
      : super(
          transitionDuration: KakaMotion.route,
          reverseTransitionDuration: const Duration(milliseconds: 230),
          pageBuilder: (context, animation, secondary) => builder(context),
          transitionsBuilder: (context, animation, secondary, child) {
            if (kakaReduceMotion(context)) {
              return FadeTransition(opacity: animation, child: child);
            }
            final offset = Tween<Offset>(
              begin: const Offset(.035, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: KakaMotion.arrive,
              reverseCurve: KakaMotion.depart,
            ));
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(position: offset, child: child),
            );
          },
        );
}

/// A short, background-colored opacity mask that *looks* softly feathered
/// but NEVER samples or blurs the scrolling content behind it.
///
/// This is intentionally NOT frosted glass and contains no BackdropFilter,
/// ImageFiltered, ShaderMask, or saveLayer. A nonlinear alpha gradient gives
/// the soft visual falloff at a fraction of the GPU cost of live backdrop blur.
class KakaProgressiveBlur extends StatelessWidget {
  final bool fromTop;
  final Color tint;
  final double height;

  const KakaProgressiveBlur({
    super.key,
    this.fromTop = false,
    this.tint = KColors.bg,
    this.height = 88,
  });

  @override
  Widget build(BuildContext context) {
    final begin = fromTop ? Alignment.topCenter : Alignment.bottomCenter;
    final end = fromTop ? Alignment.bottomCenter : Alignment.topCenter;
    return IgnorePointer(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: begin,
              end: end,
              stops: const [0, .22, .46, .69, .86, 1],
              colors: [
                tint.withValues(alpha: 1),
                tint.withValues(alpha: .96),
                tint.withValues(alpha: .72),
                tint.withValues(alpha: .33),
                tint.withValues(alpha: .08),
                tint.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compatibility surface: retain the existing widget API but draw a simple
/// solid monochrome background rather than sampling pixels behind the view.
/// The legacy sigma parameter is ignored; no live blur is ever allocated.
class KakaGlassSurface extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final double sigma;

  const KakaGlassSurface({
    super.key,
    required this.child,
    this.radius = 34,
    this.padding = EdgeInsets.zero,
    this.sigma = 0,
  });

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: KColors.surface,
      borderRadius: BorderRadius.circular(radius),
    ),
    child: Padding(padding: padding, child: child),
  );
}
