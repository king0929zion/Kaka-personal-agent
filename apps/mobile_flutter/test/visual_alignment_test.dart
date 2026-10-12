import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:kaka_flutter/design/theme.dart';
import 'package:kaka_flutter/design/widgets.dart';

Widget _app(Widget child) => MaterialApp(
      theme: kakaTheme(),
      home: Scaffold(body: SafeArea(child: child)),
    );

void main() {
  testWidgets('icon artwork stays compact but its touch target is 48dp',
      (tester) async {
    await tester.pumpWidget(_app(KakaIconButton(
      icon: LucideIcons.x, size: 32, onTap: () {},
    )));
    expect(tester.getSize(find.byType(KakaIconButton)),
        const Size(48, 48));
    final icon = tester.widget<Icon>(find.byIcon(LucideIcons.x));
    expect(icon.size, 19);
  });

  testWidgets('switch has at least 48dp vertical hit area', (tester) async {
    await tester.pumpWidget(_app(
      KakaSwitch(value: true, onChanged: (_) {}),
    ));
    expect(tester.getSize(find.byType(KakaSwitch)).height, 48);
  });

  testWidgets('page title baseline stays aligned with varying actions',
      (tester) async {
    Widget page({bool action = false}) => _app(
      Column(children: [
        KakaPageHeader(
          title: const Text('Account'),
          actions: action
              ? [KakaIconButton(icon: LucideIcons.refreshCw, onTap: () {})]
              : [],
        ),
      ]),
    );

    await tester.pumpWidget(page());
    final original = tester.getTopLeft(find.text('Account')).dx;
    await tester.pumpWidget(page(action: true));
    final withAction = tester.getTopLeft(find.text('Account')).dx;
    expect(withAction, original);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tablet content maxes out at 720dp instead of stretching',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(
      const KakaContentWidth(
        child: ColoredBox(
          key: ValueKey('readable'),
          color: Colors.white,
          child: SizedBox(height: 80),
        ),
      ),
    ));
    expect(tester.getSize(find.byKey(const ValueKey('readable'))).width, 720);
    expect(tester.takeException(), isNull);
  });

  testWidgets('320dp viewport and large text scale do not overflow controls',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
        child: Column(children: [
          KakaPageHeader(
            title: const Text('Agent settings for a long conversation'),
            actions: [
              KakaIconButton(icon: LucideIcons.check, onTap: () {}),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 22),
            child: KakaSection(
              title: 'PREFERENCES',
              child: Column(children: [
                KakaRow(
                  title: 'Very long settings option on a small mobile screen',
                  subtitle: 'A secondary description that wraps naturally',
                  icon: LucideIcons.settings,
                ),
              ]),
            ),
          ),
        ]),
      ),
    ));
    expect(tester.takeException(), isNull);
  });
}
