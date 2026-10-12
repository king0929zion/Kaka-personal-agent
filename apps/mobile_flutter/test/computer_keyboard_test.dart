import 'package:flutter_test/flutter_test.dart';
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
}
