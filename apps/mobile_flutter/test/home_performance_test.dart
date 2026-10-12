import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaka_flutter/app/app_controller.dart';
import 'package:kaka_flutter/core/api.dart';
import 'package:kaka_flutter/core/models.dart';
import 'package:kaka_flutter/design/theme.dart';
import 'package:kaka_flutter/features/avatar/avatar_settings.dart';
import 'package:kaka_flutter/features/home/home_screen.dart';

void main() {
  testWidgets('400 agents only mount visible avatar rows', (tester) async {
    final app = AppController(KakaApi());
    app.state = StartupState.ready;
    app.bots = List.generate(400, (index) => KakaBot(
      id: 'bot-$index', name: 'Agent $index', title: 'Helpful agent',
      preview: 'A previous conversation', color: '#161616',
      status: 'idle', unread: false, pinned: false,
      updatedAt: '2026-10-12',
    ));
    await tester.pumpWidget(MaterialApp(
      theme: kakaTheme(), home: HomeScreen(app: app)));
    await tester.pump();
    expect(find.byType(AgentAvatar).evaluate().length, lessThan(30));
    await tester.pumpWidget(const SizedBox.shrink());
    app.dispose();
  });
}
