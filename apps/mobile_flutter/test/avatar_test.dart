import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaka_flutter/features/avatar/organic_avatar.dart';

void main(){
  testWidgets('organic avatar renders all preset silhouettes', (tester) async {
    for(var shape=0; shape<OrganicPresets.shapes.length; shape++){
      await tester.pumpWidget(MaterialApp(home:Center(
        child:OrganicAvatar(key:ValueKey(shape),shapeIndex:shape,size:80))));
      expect(find.byType(OrganicAvatar),findsOneWidget);
      expect(tester.takeException(),isNull);
    }
  });
  test('preserves palette and expressions from supplied reference',(){
    expect(OrganicPresets.colors.length,12);
    expect(OrganicPresets.shapes.length,8);
    expect(OrganicPresets.expressions.length,16);
    expect(OrganicPresets.states.length,15);
  });
}
