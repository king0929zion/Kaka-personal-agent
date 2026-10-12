import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaka_flutter/core/performance_prefs.dart';
import 'package:kaka_flutter/design/motion.dart';

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: 320, height: 120, child: child),
        ),
      ),
    );

void main() {
  setUp(() => PerformancePrefs.lowPower.value = false);
  tearDown(() => PerformancePrefs.lowPower.value = false);

  testWidgets('progressive chrome uses one backdrop pass, not five bands',
      (tester) async {
    await tester.pumpWidget(_host(const KakaProgressiveBlur()));
    expect(find.byType(BackdropFilter), findsOneWidget);
  });

  testWidgets('progressive chrome drops the filter in low-power mode',
      (tester) async {
    PerformancePrefs.lowPower.value = true;
    await tester.pumpWidget(_host(const KakaProgressiveBlur()));
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('rounded glass surface caps repeated high-sigma samples',
      (tester) async {
    await tester.pumpWidget(_host(
      const KakaGlassSurface(sigma: 24, child: Text('Navigation')),
    ));
    final filter = tester.widget<BackdropFilter>(
      find.byType(BackdropFilter),
    );
    expect(filter.enabled, isTrue);
  });

  testWidgets('rounded glass surface has zero filters in low-power mode',
      (tester) async {
    PerformancePrefs.lowPower.value = true;
    await tester.pumpWidget(_host(
      const KakaGlassSurface(child: Text('Navigation')),
    ));
    expect(find.byType(BackdropFilter), findsNothing);
  });
}
