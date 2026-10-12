import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:kaka_flutter/design/kinetic_interactions.dart';
import 'package:kaka_flutter/design/theme.dart';
import 'package:kaka_flutter/design/widgets.dart';

Widget _host(Widget child) => MaterialApp(
  theme:kakaTheme(),
  home:Scaffold(body:SafeArea(child:child)),
);

void main() {
  test('resisted pull follows a diminishing-return drag curve', () {
    expect(kakaResistedPull(0), 0);
    expect(kakaResistedPull(100), inInclusiveRange(49, 52));
    expect(kakaResistedPull(200)-kakaResistedPull(100),
        lessThan(kakaResistedPull(100)));
  });

  testWidgets('liquid nav exposes four accessible tabs and switches selection',
    (tester) async {
    var selected=0;
    await tester.pumpWidget(_host(StatefulBuilder(
      builder:(ctx,update)=>Center(child:SizedBox(width:296,
        child:KakaLiquidNav(
          selected:selected,
          onSelected:(index)=>update(()=>selected=index),
          labels:const ['Chats','Agents','Activity','Settings'],
          icons:const [
            LucideIcons.messageCircle,LucideIcons.bot,
            LucideIcons.activity,LucideIcons.settings2,
          ],
        ),
      )),
    )));
    expect(find.byType(KakaLiquidNav),findsOneWidget);
    expect(find.text('Activity'),findsOneWidget);
    await tester.tap(find.text('Activity'));
    await tester.pump(const Duration(milliseconds:500));
    expect(selected,2);
    expect(tester.takeException(),isNull);
  });

  testWidgets('short feed remains pullable and refresh inserts fresh content',
    (tester) async {
    tester.view.physicalSize=const Size(390,760);
    tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var updated=false;
    var refreshed=0;
    await tester.pumpWidget(_host(StatefulBuilder(
      builder:(ctx,update)=>KakaPullToRefresh(
        minimumLoading:const Duration(milliseconds:1200),
        onRefresh:() async{
          refreshed++;
          update(()=>updated=true);
        },
        child:ListView(
          physics:const AlwaysScrollableScrollPhysics(
            parent:ClampingScrollPhysics()),
          children:[
            if(updated)const ListTile(title:Text('New update')),
            const ListTile(title:Text('Existing item')),
          ],
        ),
      ),
    )));
    await tester.drag(find.text('Existing item'),const Offset(0,340));
    await tester.pump();
    expect(refreshed,1);
    expect(find.text('New update'),findsOneWidget);
    await tester.pump(const Duration(milliseconds:1300));
    await tester.pump(const Duration(milliseconds:700));
    expect(tester.takeException(),isNull);
  });

  testWidgets('sheet elevation reduces background scale when opened',
    (tester) async {
    await tester.pumpWidget(_host(Builder(
      builder:(context)=>KakaDepthStage(child:Center(
        child:ElevatedButton(
          onPressed:()=>kakaSheet<void>(context,
            const Text('Draggable sheet')),
          child:const Text('Open'),
        ),
      )),
    )));
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds:300));
    expect(find.text('Draggable sheet'),findsOneWidget);
    expect(KakaSheetDepth.progress.value, greaterThan(0));
    await tester.pump(const Duration(milliseconds:200));
    expect(tester.takeException(),isNull);
    await tester.tapAt(const Offset(10,10));
    await tester.pump(const Duration(milliseconds:450));
    expect(KakaSheetDepth.progress.value,closeTo(0,.02));
  });
}
