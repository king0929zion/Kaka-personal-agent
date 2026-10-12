import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import 'motion.dart';
import 'theme.dart';

/// Approximately 50dp displacement for the first 100dp of finger movement,
/// with progressively less movement the farther the user pulls.
double kakaResistedPull(double fingerDistance) =>
    155 * (1 - math.exp(-fingerDistance.clamp(0, 1000) / 255));

const _spring = SpringDescription(
  mass: 1, stiffness: 280, damping: 22,
);

/// Custom pull-to-refresh keeps the existing list mounted and translates its
/// composited layer, instead of relaying out every message on each drag frame.
class KakaPullToRefresh extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final VoidCallback? onComplete;
  final Duration minimumLoading;
  const KakaPullToRefresh({
    super.key,
    required this.child,
    required this.onRefresh,
    this.onComplete,
    this.minimumLoading = const Duration(milliseconds: 1200),
  });
  @override
  State<KakaPullToRefresh> createState() => _KakaPullToRefreshState();
}

class _KakaPullToRefreshState extends State<KakaPullToRefresh>
    with TickerProviderStateMixin {
  late final AnimationController _offset =
      AnimationController.unbounded(vsync: this);
  late final AnimationController _spinner =
      AnimationController(vsync: this,
          duration: const Duration(milliseconds: 720));
  double _drag = 0;
  bool _refreshing = false;
  bool _dragging = false;
  int _epoch = 0;
  static const trigger = 70.0;
  static const hold = 60.0;

  bool get _reduced => kakaReduceMotion(context);

  bool _notification(ScrollNotification n) {
    if (n.depth != 0 || _refreshing) return false;
    if (n is OverscrollNotification &&
        n.dragDetails != null &&
        n.metrics.axis == Axis.vertical &&
        n.metrics.pixels <= n.metrics.minScrollExtent + 1 &&
        n.overscroll < 0) {
      _dragging = true;
      _offset.stop();
      _drag += -n.overscroll;
      _offset.value = kakaResistedPull(_drag);
    } else if (n is ScrollEndNotification && _dragging) {
      _dragging = false;
      if (_offset.value >= trigger) {
        unawaited(_refresh());
      } else {
        _springTo(0);
      }
      _drag = 0;
    }
    return false;
  }

  void _springTo(double target) {
    if (_reduced) {
      _offset.value = target;
      return;
    }
    _offset.animateWith(SpringSimulation(
      _spring, _offset.value, target, _offset.velocity,
    ));
  }

  Future<void> _refresh() async {
    if (_refreshing || !mounted) return;
    setState(() => _refreshing = true);
    final epoch = ++_epoch;
    _springTo(hold);
    if (!_reduced) _spinner.repeat();
    final started = DateTime.now();
    var succeeded = false;
    try {
      await widget.onRefresh();
      succeeded = true;
    } catch (_) {
      // The parent owns the user-facing error state; never leave the gesture
      // controller running or report an unsuccessful request as a new update.
    } finally {
      final remaining = widget.minimumLoading -
          DateTime.now().difference(started);
      if (remaining > Duration.zero) await Future<void>.delayed(remaining);
      if (mounted && epoch == _epoch) {
        if (succeeded) widget.onComplete?.call();
        _spinner.stop();
        setState(() => _refreshing = false);
        _springTo(0);
      }
    }
  }

  @override
  void dispose() {
    ++_epoch;
    _spinner.dispose();
    _offset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => NotificationListener<ScrollNotification>(
    onNotification: _notification,
    child: AnimatedBuilder(
      animation: _offset,
      child: widget.child,
      builder: (context, child) {
        final distance = _offset.value.clamp(0.0, 190.0);
        final ready = distance >= trigger && !_refreshing;
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            if (distance > .5)
              Positioned(
                left: 0, right: 0, top: 0, height: 60,
                child: Center(
                  child: Opacity(
                    opacity: (distance / 40).clamp(0.0, 1.0),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (_refreshing)
                        RepaintBoundary(child:RotationTransition(
                          turns: _spinner,
                          child: const Icon(LucideIcons.loaderCircle,
                              size: 22, color: KColors.ink),
                        ))
                      else
                        Transform.rotate(
                          angle: math.min(distance / trigger, 1) * math.pi,
                          child: const Icon(LucideIcons.arrowDown,
                              size: 22, color: KColors.ink),
                        ),
                      const SizedBox(width: 10),
                      Text(
                        _refreshing ? 'Refreshing…' :
                        ready ? 'Release to refresh' : 'Pull to refresh',
                        style: const TextStyle(
                          fontSize: 13, color: KColors.muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            Transform.translate(
              offset: Offset(0, distance),
              child: child,
            ),
          ],
        );
      },
    ),
  );
}

/// Four-tab liquid selection. The leading edge travels first; the trailing
/// edge catches up with a softer spring. Only the painted pill and icons
/// animate: the whole tab page is NOT relaid out on every spring frame.
class KakaLiquidNav extends StatefulWidget {
  final int selected;
  final ValueChanged<int> onSelected;
  final List<String> labels;
  final List<IconData> icons;
  const KakaLiquidNav({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.labels,
    required this.icons,
  });
  @override
  State<KakaLiquidNav> createState() => _KakaLiquidNavState();
}

class _KakaLiquidNavState extends State<KakaLiquidNav>
    with TickerProviderStateMixin {
  late final AnimationController _left =
      AnimationController.unbounded(vsync: this, value: widget.selected.toDouble());
  late final AnimationController _right =
      AnimationController.unbounded(vsync: this, value: widget.selected + 1.0);

  @override
  void didUpdateWidget(KakaLiquidNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected == widget.selected) return;
    if (kakaReduceMotion(context)) {
      _left.value = widget.selected.toDouble();
      _right.value = widget.selected + 1.0;
      return;
    }
    final forward = widget.selected > oldWidget.selected;
    final quick = const SpringDescription(
      mass: 1, stiffness: 420, damping: 23);
    final trailing = const SpringDescription(
      mass: 1, stiffness: 240, damping: 21);
    void animate(AnimationController controller, double target,
        SpringDescription spring) {
      controller.animateWith(SpringSimulation(
          spring, controller.value, target, controller.velocity));
    }
    if (forward) {
      animate(_right, widget.selected + 1.0, quick);
      animate(_left, widget.selected.toDouble(), trailing);
    } else {
      animate(_left, widget.selected.toDouble(), quick);
      animate(_right, widget.selected + 1.0, trailing);
    }
  }

  @override
  void dispose() {
    _left.dispose();
    _right.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    assert(widget.labels.length == widget.icons.length);
    return Container(
      height: 66,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: KColors.surface,
        borderRadius: BorderRadius.circular(36),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final count = widget.labels.length;
        return Stack(children: [
          // Paint-only physics: the pill no longer changes Stack layout
          // or rebuilds any of the four tab hit targets on each spring tick.
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _KakaLiquidPillPainter(
                    left: _left,
                    right: _right,
                    count: count,
                  ),
                ),
              ),
            ),
          ),
          Row(children: [
            for (var i = 0; i < count; i++)
              Expanded(child: Semantics(
                button: true,
                selected: widget.selected == i,
                label: widget.labels[i],
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => widget.onSelected(i),
                  child: SizedBox.expand(
                    child: _KakaNavGlyph(
                      selected: widget.selected == i,
                      icon: widget.icons[i],
                      label: widget.labels[i],
                    ),
                  ),
                ),
              )),
          ]),
        ]);
      }),
    );
  }
}

/// Only the tiny selected capsule repaints as it moves. Text/icons remain
/// a separate static hit-test tree.
class _KakaLiquidPillPainter extends CustomPainter {
  final Animation<double> left;
  final Animation<double> right;
  final int count;
  _KakaLiquidPillPainter({
    required this.left,
    required this.right,
    required this.count,
  }) : super(repaint: Listenable.merge([left, right]));

  @override
  void paint(Canvas canvas, Size size) {
    if (count == 0 || size.isEmpty) return;
    final cell = size.width / count;
    final x1 = left.value.clamp(0.0, count.toDouble()) * cell;
    final x2 = right.value.clamp(0.0, count.toDouble()) * cell;
    final travel = (x2 - x1).abs();
    final flatten = math.min(5.0, math.max(0.0, travel - cell) * .10);
    final rect = Rect.fromLTWH(
      math.min(x1, x2),
      flatten / 2,
      math.max(cell * .78, travel),
      size.height - flatten,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(32)),
      Paint()..color = KColors.ink,
    );
  }

  @override
  bool shouldRepaint(covariant _KakaLiquidPillPainter oldDelegate) =>
      oldDelegate.left != left ||
      oldDelegate.right != right ||
      oldDelegate.count != count;
}

class _KakaNavGlyph extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String label;
  const _KakaNavGlyph({
    required this.selected,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween<double>(end: selected ? 1 : 0),
    duration: kakaReduceMotion(context)
        ? Duration.zero : const Duration(milliseconds: 340),
    curve: Curves.easeOutBack,
    builder: (context, position, child) {
      final t = position.clamp(0.0, 1.0);
      // The incoming icon briefly contracts, then settles with a tiny spring
      // bump; label and glyph colors share one continuous tween.
      final scale = selected ? (.84 + position * .16) : (1 + .04 * position);
      final foreground = Color.lerp(KColors.ink, Colors.white, t)!;
      final caption = Color.lerp(KColors.muted, Colors.white, t)!;
      return Transform.scale(
        scale: scale,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: foreground),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: caption,
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// A single inbound tab subtree: content slides in from the click direction,
/// rather than keeping two expensive live Agent lists mounted simultaneously.
class KakaTabEntrance extends StatefulWidget {
  final Widget child;
  final int direction;
  const KakaTabEntrance({
    super.key,
    required this.child,
    required this.direction,
  });
  @override
  State<KakaTabEntrance> createState() => _KakaTabEntranceState();
}

class _KakaTabEntranceState extends State<KakaTabEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _arrival = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  )..forward();

  @override
  void dispose() {
    _arrival.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kakaReduceMotion(context)) return widget.child;
    final animation = CurvedAnimation(
      parent: _arrival,
      curve: const Cubic(.18, .77, .23, 1),
    );
    return AnimatedBuilder(
      animation: animation,
      child: widget.child,
      builder: (context, child) {
        final t = animation.value;
        return Opacity(
          // Delicate entrance, not a full-page fade-out that makes text flash.
          opacity: (.88 + t * .12).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset((1 - t) * 12 * widget.direction, 0),
            child: child,
          ),
        );
      },
    );
  }
}
