import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaka_flutter/core/performance_prefs.dart';
import 'package:kaka_flutter/design/motion.dart';

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(
        body: Center(child: child),
      ),
    );

void main() {
  setUp(() => PerformancePrefs.lowPower.value = false);
  tearDown(() => PerformancePrefs.lowPower.value = false);

  testWidgets('bottom feather uses background color, not backdrop glass',
      (tester) async {
    await tester.pumpWidget(_host(const KakaProgressiveBlur()));
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byType(ImageFiltered), findsNothing);
    expect(find.byType(ShaderMask), findsNothing);

    // Optical reach is 88dp, rather than the old 124dp blur band.
    expect(tester.getSize(find.byType(KakaProgressiveBlur)).height, 88);
    final box = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(KakaProgressiveBlur),
        matching: find.byType(DecoratedBox),
      ).single,
    );
    final gradient = (box.decoration as BoxDecoration).gradient!
        as LinearGradient;
    expect(gradient.colors.first, const Color(0xFFF7F7F6));
    expect(gradient.colors.last.alpha, 0);
    expect(gradient.stops, const [0, .22, .46, .69, .86, 1]);
  });

  testWidgets('mask never adds filtering under low power or live toggle',
      (tester) async {
    await tester.pumpWidget(_host(const KakaProgressiveBlur()));
    PerformancePrefs.lowPower.value = true;
    await tester.pump();
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byType(ImageFiltered), findsNothing);
    PerformancePrefs.lowPower.value = false;
    await tester.pump();
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('mask direction supports top edges without glass',
      (tester) async {
    await tester.pumpWidget(
      _host(const KakaProgressiveBlur(fromTop: true, height: 60)),
    );
    expect(tester.getSize(find.byType(KakaProgressiveBlur)).height, 60);
    final box = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(KakaProgressiveBlur),
        matching: find.byType(DecoratedBox),
      ).single,
    );
    final gradient = (box.decoration as BoxDecoration).gradient!
        as LinearGradient;
    expect(gradient.begin, Alignment.topCenter);
    expect(gradient.end, Alignment.bottomCenter);
  });

  testWidgets('floating surface is solid, even with legacy sigma configured',
      (tester) async {
    await tester.pumpWidget(
      _host(const KakaGlassSurface(
        sigma: 24,
        radius: 28,
        child: Text('Navigation'),
      )),
    );
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byType(ImageFiltered), findsNothing);
    expect(find.text('Navigation'), findsOneWidget);
    final surface = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(KakaGlassSurface),
        matching: find.byType(DecoratedBox),
      ).first,
    );
    final decoration = surface.decoration as BoxDecoration;
    expect(decoration.color, Colors.white);
    expect(decoration.borderRadius, BorderRadius.circular(28));
  });
}
