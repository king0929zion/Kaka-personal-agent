import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaka_flutter/design/motion.dart';
import 'package:kaka_flutter/design/theme.dart';
import 'package:kaka_flutter/design/widgets.dart';

void main(){
  test('Android route transitions use the Kaka motion contract',(){
    expect(kakaTheme().pageTransitionsTheme.builders[TargetPlatform.android],
      isA<KakaPageTransitionsBuilder>());
  });

  testWidgets('spring control handles tap and long-press independently',(tester)async{
    var taps=0,longPresses=0;
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:Center(
      child:KakaPress(
        onTap:()=>taps++,
        onLongPress:()=>longPresses++,
        child:const SizedBox(width:90,height:65,
          child:Text('Tap here')),
      ),
    ))));
    await tester.tap(find.text('Tap here'));
    await tester.pumpAndSettle();
    expect(taps,1);
    await tester.longPress(find.text('Tap here'));
    await tester.pumpAndSettle();
    expect(longPresses,1);
  });

  testWidgets('glass surfaces are clipped, with a backdrop filter',(tester)async{
    await tester.pumpWidget(const MaterialApp(home:Scaffold(body:Center(
      child:SizedBox(width:200,height:70,
        child:KakaGlassSurface(child:Text('Navigation'))),
    ))));
    expect(find.byType(ClipRRect),findsWidgets);
    expect(find.byType(BackdropFilter),findsOneWidget);
  });

  testWidgets('progressive blur downgrades under reduced motion',(tester)async{
    await tester.pumpWidget(const MaterialApp(home:
      MediaQuery(data:MediaQueryData(disableAnimations:true),
        child:Scaffold(body:SizedBox(height:120,
          child:KakaProgressiveBlur())))));
    expect(find.byType(BackdropFilter),findsNothing);
    expect(find.byType(DecoratedBox),findsWidgets);
  });
}
