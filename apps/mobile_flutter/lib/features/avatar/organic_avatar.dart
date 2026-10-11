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
  final String stateId;
  const OrganicAvatar({super.key, this.size = 52, this.shapeIndex = 0,
    this.expressionIndex = 0, this.color = KColors.ink, this.working = false,
    this.stateId = 'idle'});
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
            working: widget.working, stateId: widget.stateId,
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
  final String stateId;
  static const count = 64;
  _AvatarPainter({required this.t, required this.shapeIndex,
    required this.expressionIndex, required this.color,
    required this.working, required this.reducedMotion,
    required this.stateId});

  double _radius(double angle, [int? overrideShape]) {
    final c = math.cos(angle), s = math.sin(angle);
    switch((overrideShape ?? shapeIndex) % 8) {
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
    final side=math.min(size.width,size.height);
    final scale=side*.42;
    final clock=reducedMotion?0.0:t;
    final state=working?'thinking':stateId;
    final inMotion=!reducedMotion;
    final bob=(working?math.sin(clock*3)*side*.014:math.sin(clock*1.2)*side*.003);
    final bodyPaint=Paint()..color=color..isAntiAlias=true;
    final faceColor=color.computeLuminance()<.48?Colors.white:KColors.ink;
    final eyePaint=Paint()..color=faceColor..isAntiAlias=true;
    canvas.save();
    canvas.translate(size.width/2,size.height/2+bob);
    final breath=1+.005*math.sin(clock*math.pi*2/3.4);
    canvas.scale(breath,breath);
    final bodyOnly = state == 'thinking' || state == 'alert' ||
      state == 'exclaim' || state == 'sleep';
    if(!bodyOnly) {
      final forced=state=='hexagon'?5:state=='egg'?7:null;
      final points=List<Offset>.generate(count,(i) {
        final a=2*math.pi*i/count;
        final r=_radius(a,forced)*scale;
        return Offset(math.cos(a)*r,math.sin(a)*r);
      });
      final silhouette=Path()..moveTo(points[0].dx,points[0].dy);
      for(var i=0;i<count;i++){
        final a=points[(i-1+count)%count],b=points[i];
        final c=points[(i+1)%count],d=points[(i+2)%count];
        silhouette.cubicTo(
          b.dx+(c.dx-a.dx)/6,b.dy+(c.dy-a.dy)/6,
          c.dx-(d.dx-b.dx)/6,c.dy-(d.dy-b.dy)/6,
          c.dx,c.dy);
      }
      silhouette.close();
      canvas.drawPath(silhouette,bodyPaint);
    }

    if(state=='thinking'){
      for(var i=0;i<3;i++){
        final pulse=(math.sin(clock*math.pi*1.5-i*1.35)+1)/2;
        final r=scale*(.12+.07*pulse);
        canvas.drawCircle(Offset((i-1)*scale*.38,0),r,bodyPaint);
      }
    }else if(state=='exclaim'||state=='alert'){
      canvas.save();
      if(state=='alert')canvas.rotate(.26);
      final wobble=inMotion?math.sin(clock*13)*.028*scale:0.0;
      canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center:Offset(wobble,-scale*.20),
          width:scale*.30,height:scale*1.20),
        Radius.circular(scale*.13)),bodyPaint);
      canvas.restore();
      canvas.drawCircle(Offset(0,scale*.62),scale*.135,bodyPaint);
    }else if(state=='sleep'){
      canvas.drawCircle(Offset(0,scale*.13+
        (inMotion?math.sin(clock*2)*scale*.16:0)),scale*.17,bodyPaint);
    }else{
      final expr=expressionIndex%OrganicPresets.expressions.length;
      double width=.186,height=.412,tilt=-.13;
      if([2,3,8].contains(expr)){width=.34;height=.56;tilt=0;}
      if([4,5,6,12,14].contains(expr)){width=.27;height=.15;tilt=.18;}
      if(expr==13){width=.17;height=.30;tilt=-.12;}
      if(expr==15){width=.18;height=.22;tilt=-.07;}
      if(expr==7)tilt=-.4;
      if(state=='wide'){width=.36;height=.88;}
      if(state=='wink'){width=.30;height=.46;}
      final wander=math.sin(clock*.73)*.05;
      final blink=(inMotion && math.sin(clock*2.9)+math.sin(clock*.63)>1.79)? .09:1.0;
      for(final dir in [-1,1]){
        canvas.save();
        canvas.translate(dir*scale*.35+wander*scale*.34,
          -scale*.10+wander*scale);
        canvas.rotate(tilt*dir);
        final w=math.max(2.0,scale*width);
        final eyesClosed=state=='wink'&&dir>0;
        final h=math.max(2.0,scale*height*(eyesClosed ? .16 : blink));
        canvas.drawRRect(RRect.fromRectAndRadius(
          Rect.fromCenter(center:Offset.zero,width:w,height:h),
          Radius.circular(math.min(w,h)/2)),eyePaint);
        canvas.restore();
      }
      if(state=='notify'){
        canvas.drawCircle(Offset(scale*.84,-scale*.85),scale*.25,
          Paint()..color=KColors.bg..isAntiAlias=true);
        canvas.drawCircle(Offset(scale*.84,-scale*.85),
          scale*(.18+.015*math.sin(clock*5)),bodyPaint);
      }
      if(state=='play'){
        final tri=Path()..moveTo(-scale*.12,-scale*.27)
          ..lineTo(scale*.33,0)..lineTo(-scale*.12,scale*.27)..close();
        canvas.drawPath(tri,eyePaint);
      }
      if(state=='orbit'){
        canvas.save();
        canvas.rotate(clock*.55);
        final ring=Paint()..color=bodyPaint.color.withValues(alpha:.75)
          ..style=PaintingStyle.stroke..strokeWidth=scale*.055;
        canvas.drawOval(Rect.fromCenter(center:Offset.zero,
          width:scale*2.45,height:scale*.78),ring);
        canvas.restore();
      }
      if(state=='burst'){
        for(var i=0;i<12;i++){
          final a=i*math.pi/6;
          final dist=scale*(1.12+.10*math.sin(clock*3+a*3));
          canvas.drawCircle(Offset(math.cos(a)*dist,math.sin(a)*dist),
            scale*.035,bodyPaint);
        }
      }
      if(state=='comet'){
        final tail=Paint()..color=bodyPaint.color.withValues(alpha:.6)
          ..style=PaintingStyle.stroke..strokeCap=StrokeCap.round
          ..strokeWidth=scale*.07;
        for(var i=0;i<3;i++){
          final dy=(i-1)*scale*.35;
          canvas.drawLine(Offset(-scale*1.30,dy),
            Offset(-scale*(.98+.14*i),dy),tail);
        }
      }
      if(state=='swirl'){
        final spiral=Path();
        for(var i=0;i<90;i++){
          final p=i/89;
          final a=clock*.6 + p*math.pi*3;
          final radius=scale*.8*p;
          final pt=Offset(math.cos(a)*radius,math.sin(a)*radius);
          if(i==0){spiral.moveTo(pt.dx,pt.dy);}
          else{spiral.lineTo(pt.dx,pt.dy);}
        }
        canvas.drawPath(spiral,Paint()..color=faceColor.withValues(alpha:.72)
          ..style=PaintingStyle.stroke..strokeWidth=scale*.035
          ..strokeCap=StrokeCap.round);
      }
    }
    canvas.restore();
  }
  @override
  bool shouldRepaint(covariant _AvatarPainter oldDelegate) =>
    oldDelegate.t != t || oldDelegate.shapeIndex!=shapeIndex ||
      oldDelegate.expressionIndex!=expressionIndex || oldDelegate.color!=color ||
      oldDelegate.working!=working || oldDelegate.reducedMotion!=reducedMotion ||
      oldDelegate.stateId!=stateId;
}
