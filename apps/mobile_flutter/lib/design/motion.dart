import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/performance_prefs.dart';

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

/// A bounded, single-pass blurred backdrop with a smooth tint falloff.
///
/// A genuine spatially varying Gaussian blur needs a GPU shader / composited
/// texture and must be benchmarked per device. Five independent, high-sigma
/// BackdropFilters here previously produced visible bands and costly redraws.
/// This lightweight approximation has just ONE backdrop sample, with the
/// softness fading visually through the overlay gradient. Keep it confined
/// to small chrome areas, never as a full-screen scrolling backdrop.
class KakaProgressiveBlur extends StatelessWidget {
  final bool fromTop;
  final Color tint;

  const KakaProgressiveBlur({
    super.key,
    this.fromTop = false,
    this.tint = const Color(0xFFF7F7F6),
  });

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: PerformancePrefs.lowPower,
        builder: (context, lowPower, _) {
          final reducedEffects =
              lowPower || MediaQuery.disableAnimationsOf(context);
          final start = fromTop ? Alignment.topCenter : Alignment.bottomCenter;
          final end = fromTop ? Alignment.bottomCenter : Alignment.topCenter;

          return IgnorePointer(
            child: ClipRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (!reducedEffects)
                    BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: const SizedBox.expand(),
                    ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: start,
                        end: end,
                        stops: const [0, .26, .55, .78, 1],
                        colors: [
                          tint.withValues(
                            alpha: reducedEffects ? .98 : .87,
                          ),
                          tint.withValues(alpha: .73),
                          tint.withValues(alpha: .44),
                          tint.withValues(alpha: .17),
                          tint.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
}

/// Floating surfaces use one clipped blur at most. In low-power / reduced
/// effects mode we remove the filter layer entirely. The notifier ensures
/// that a settings toggle updates the visible chrome in the same frame.
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
    this.sigma = 10,
  });

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: PerformancePrefs.lowPower,
        builder: (context, lowPower, _) {
          final reducedEffects =
              lowPower || MediaQuery.disableAnimationsOf(context);
          final surface = DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(
                alpha: reducedEffects ? .97 : .87,
              ),
            ),
            child: Padding(padding: padding, child: child),
          );

          return ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: reducedEffects || sigma <= 0
                ? surface
                : BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: sigma.clamp(0.0, 10.0).toDouble(),
                      sigmaY: sigma.clamp(0.0, 10.0).toDouble(),
                    ),
                    child: surface,
                  ),
          );
        },
      );
}
