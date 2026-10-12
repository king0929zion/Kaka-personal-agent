import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:kaka_flutter/features/computer/computer_keyboard_bar.dart';

void main(){
  test('append and delete map to supported noVNC keyboard commands',(){
    expect(computerKeyboardCommands('','hello'),[
      {'type':'text','text':'hello'},
    ]);
    expect(computerKeyboardCommands('hello','hel'),[
      {'type':'backspace','count':2},
    ]);
    expect(computerKeyboardCommands('hello','heLlo'),[
      {'type':'backspace','count':3},
      {'type':'text','text':'Llo'},
    ]);
  });

  test('Unicode backspaces count symbols rather than UTF-16 code units',(){
    expect(computerKeyboardCommands('😀',''),[
      {'type':'backspace','count':1},
    ]);
  });

  test('newlines become Return and Ctrl applies to only the first key',(){
    expect(computerKeyboardCommands('','go\nnext'),[
      {'type':'text','text':'go'},
      {'type':'key','name':'Return'},
      {'type':'text','text':'next'},
    ]);
    expect(computerKeyboardCommands('','c',control:true),[
      {'type':'char','text':'c','control':true},
    ]);
    expect(computerKeyboardCommands('','x\ny',control:true),[
      {'type':'char','text':'x','control':true},
      {'type':'key','name':'Return'},
      {'type':'text','text':'y'},
    ]);
  });
  test('Ctrl modifies a Backspace and large edits preserve all deletes',(){
    expect(computerKeyboardCommands('abcd','ab',control:true),[
      {'type':'key','name':'Backspace','control':true},
      {'type':'backspace','count':1},
    ]);
    expect(computerKeyboardCommands(List.filled(1001,'x').join(),''),[
      {'type':'backspace','count':500},
      {'type':'backspace','count':500},
      {'type':'backspace','count':1},
    ]);
    expect(computerNamedKey('Escape',control:true),
      {'type':'key','name':'Escape','control':true});
  });

  testWidgets('Android IME input sends actual remote text and dedicated keys',
    (tester)async{
      final commands=<Map<String,dynamic>>[];
      await tester.pumpWidget(MaterialApp(home:Scaffold(body:
        ComputerKeyboardBar(enabled:true,
          send:(command)async{commands.add(command);}),
      )));
      final input=find.byKey(const ValueKey('remote-computer-ime'));
      expect(input,findsOneWidget);
      await tester.enterText(input,'abc');
      await tester.pump();
      expect(commands,contains({'type':'text','text':'abc'}));
      await tester.tap(find.text('Esc'));
      await tester.pump();
      expect(commands.last,{'type':'key','name':'Escape'});
      await tester.enterText(input,'c');
      await tester.pump();
      expect(commands.last,{'type':'text','text':'c'});
      await tester.tap(find.text('Ctrl'));
      await tester.tap(find.text('Tab'));
      await tester.pump();
      expect(commands.last,{'type':'key','name':'Tab','control':true});
      await tester.tap(find.text('⌫'));
      await tester.pump();
      expect(commands.last,{'type':'key','name':'Backspace'});
      await tester.pumpWidget(const SizedBox());
    });

  testWidgets('offline keyboard disables input and remote key delivery',
    (tester)async{
      final commands=<Map<String,dynamic>>[];
      await tester.pumpWidget(MaterialApp(home:Scaffold(body:
        ComputerKeyboardBar(enabled:false,
          send:(command)async{commands.add(command);}),
      )));
      expect(tester.widget<TextField>(
        find.byKey(const ValueKey('remote-computer-ime'))).enabled,false);
      await tester.tap(find.text('Esc'));
      await tester.pump();
      expect(commands,isEmpty);
    });

}
