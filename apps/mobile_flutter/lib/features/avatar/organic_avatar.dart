import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../design/theme.dart';

/// Shapes, palettes and expressions ported from the supplied BLOUB HTML.
abstract final class OrganicPresets {
  static const shapes = <String>['Circle', 'Pebble', 'Squircle', 'Capsule',
    'Triangle', 'Hexagon', 'Cloud', 'Droplet'];
  static const expressions = <String>['Neutral', 'Attentive', 'Surprised', 'Excited',
    'Happy', 'Laughing', 'Angry', 'Sad', 'Scared', 'Suspicious',
    'Confused', 'Curious', 'Proud', 'Shy', 'Bored', 'Sleepy'];
  static const states = <String>['idle', 'thinking', 'wink', 'wide', 'alert', 'notify',
    'exclaim', 'sleep', 'egg', 'hexagon', 'play', 'orbit', 'burst', 'comet', 'swirl'];
  static const colors = <Color>[
    Color(0xFF0A0A0C), Color(0xFF8B5E3C), Color(0xFFE8483F),
    Color(0xFFF08A24), Color(0xFFF0B429), Color(0xFF3ECF8E),
    Color(0xFF2FBFA0), Color(0xFF3B93F0), Color(0xFF8B5CF6),
    Color(0xFFE152B0), Color(0xFFA3A3A3), Color(0xFFF1EFE9),
  ];
}

class OrganicAvatar extends StatefulWidget {
  final double size;
  final int shapeIndex;
  final int expressionIndex;
  final Color color;
  final bool working;
  const OrganicAvatar({super.key, this.size = 52, this.shapeIndex = 0,
    this.expressionIndex = 0, this.color = KColors.ink, this.working = false});
  @override
  State<OrganicAvatar> createState() => _OrganicAvatarState();
}
class _OrganicAvatarState extends State<OrganicAvatar> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this, duration: const Duration(seconds: 9))..repeat();
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: SizedBox(width: widget.size, height: widget.size,
      child: AnimatedBuilder(animation: _controller,
        builder: (context, child) => CustomPaint(
          painter: _AvatarPainter(
            t: _controller.value * 9, shapeIndex: widget.shapeIndex,
            expressionIndex: widget.expressionIndex, color: widget.color,
            working: widget.working,
            reducedMotion: MediaQuery.disableAnimationsOf(context)),
        )),
    ),
  );
}

class _AvatarPainter extends CustomPainter {
  final double t;
  final int shapeIndex, expressionIndex;
  final Color color;
  final bool working, reducedMotion;
  static const count = 64;
  _AvatarPainter({required this.t, required this.shapeIndex,
    required this.expressionIndex, required this.color,
    required this.working, required this.reducedMotion});

  double _radius(double angle) {
    final c = math.cos(angle), s = math.sin(angle);
    switch(shapeIndex % 8) {
      case 1: return (1 + .075 * math.cos(2 * angle + .5) +
          .035 * math.cos(3 * angle + 2.1)) / 1.10;
      case 2:
        final a = math.pow(c.abs(), 4.2).toDouble() + math.pow(s.abs(), 4.2).toDouble();
        return math.pow(a, -1 / 4.2).toDouble() / 1.15;
      case 3:
        // A capsule represented by the radial boundary of two circles.
        return _circleUnion(angle, const [[-.36, 0, .60], [.36, 0, .60]]) / .96;
      case 4:
        return _regularPolygon(angle, 3, -.5 * math.pi, .20);
      case 5:
        return _regularPolygon(angle, 6, 0, .12);
      case 6:
        return _circleUnion(angle, const [
          [-.44, .2, .54], [.46, .2, .5], [.02, .3, .6],
          [-.24, -.3, .48], [.3, -.24, .44]]) / 1.18;
      case 7:
        return _circleUnion(angle, const [[0, .26, .66], [0, -.85, .10]]) / 1.03;
      default: return 1;
    }
  }

  double _circleUnion(double angle, List<List<double>> circles) {
    final dx = math.cos(angle), dy = math.sin(angle);
    double result = 0;
    for (final circle in circles) {
      final x = circle[0], y = circle[1], r = circle[2];
      final b = dx * x + dy * y;
      final discriminant = b*b - (x*x + y*y - r*r);
      if (discriminant >= 0) {
        result = math.max(result, b + math.sqrt(discriminant));
      }
    }
    return result;
  }
  double _regularPolygon(double angle, int sides, double rotation, double round) {
    final sector = 2 * math.pi / sides;
    final normalized = (angle - rotation + sector / 2 + 20 * math.pi) % sector - sector/2;
    return ((math.cos(math.pi / sides) / math.cos(normalized)) * (1-round) + round);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    final scale = side * .42;
    final clock = reducedMotion ? 0.0 : t;
    final breath = 1 + .005 * math.sin(clock * math.pi * 2 / 3.4);
    final bob = working ? math.sin(clock * 3) * side * .014 : math.sin(clock * 1.2) * side * .003;
    canvas.save();
    canvas.translate(size.width/2, size.height/2 + bob);
    canvas.scale(breath, breath);
    final points = List<Offset>.generate(count, (i) {
      final angle = 2 * math.pi * i / count;
      final radius = _radius(angle) * scale;
      return Offset(math.cos(angle)*radius, math.sin(angle)*radius);
    });
    final shape = Path()..moveTo(points[0].dx, points[0].dy);
    // Same closed Catmull-Rom to cubic technique and tension=1/6 as the HTML.
    for (var i = 0; i < count; i++) {
      final p0=points[(i-1+count)%count], p1=points[i];
      final p2=points[(i+1)%count], p3=points[(i+2)%count];
      shape.cubicTo(
        p1.dx + (p2.dx-p0.dx)/6, p1.dy + (p2.dy-p0.dy)/6,
        p2.dx - (p3.dx-p1.dx)/6, p2.dy - (p3.dy-p1.dy)/6,
        p2.dx, p2.dy);
    }
    shape.close();
    canvas.drawPath(shape, Paint()..color=color..isAntiAlias=true);
    final eyePaint = Paint();
    eyePaint.color = color.computeLuminance() < .48 ? Colors.white : KColors.ink;
    eyePaint.isAntiAlias = true;
    if (working) {
      for (var i=0;i<3;i++) {
        final pulse=(math.sin(clock*3.3+i*1.3)+1)/2;
        canvas.drawCircle(Offset((i-1)*scale*.35,0),
          scale*(.08+.07*pulse), eyePaint);
      }
    } else {
      final expr = expressionIndex % OrganicPresets.expressions.length;
      double width = .16, height = .41, tilt = -.13;
      if ([2,3,8].contains(expr)) { width=.28; height=.56; tilt=0; }
      if ([4,5,6,12,14].contains(expr)) { width=.27; height=.15; tilt=.18; }
      if (expr==13) { width=.17; height=.30; tilt=-.12; }
      if (expr==15) { width=.18; height=.22; tilt=-.07; }
      if (expr==7) tilt=-.4;
      final wander=math.sin(clock*.73)*.055;
      final blink=(math.sin(clock*2.9)+math.sin(clock*.63)>1.79) ? .12 : 1.0;
      final eyeY = -scale*.10 + wander*scale;
      final eyeSpacing = scale*.35;
      for (final dir in [-1,1]) {
        canvas.save();
        canvas.translate(dir*eyeSpacing + wander*scale*.35, eyeY);
        canvas.rotate(tilt * dir);
        final w=math.max(2.0,scale*width), h=math.max(2.0,scale*height*blink);
        canvas.drawRRect(RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width:w, height:h),
          Radius.circular(math.min(w,h)*.5)),eyePaint);
        canvas.restore();
      }
    }
    canvas.restore();
  }
  @override
  bool shouldRepaint(covariant _AvatarPainter oldDelegate) =>
    oldDelegate.t != t || oldDelegate.shapeIndex!=shapeIndex ||
      oldDelegate.expressionIndex!=expressionIndex || oldDelegate.color!=color ||
      oldDelegate.working!=working || oldDelegate.reducedMotion!=reducedMotion;
}
