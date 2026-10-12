import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../design/theme.dart';
import '../../design/widgets.dart';

/// Translate Flutter IME edits to the existing noVNC keyboard bridge's
/// command protocol. Compare Unicode scalars rather than UTF-16 code units.
List<Map<String,dynamic>> computerKeyboardCommands(
    String oldText, String newText, {bool control=false}) {
  final previous=oldText.runes.toList();
  final next=newText.replaceAll('\r\n','\n').replaceAll('\r','\n').runes.toList();
  var prefix=0;
  while(prefix<previous.length && prefix<next.length &&
      previous[prefix]==next[prefix]) {
    prefix++;
  }
  final result=<Map<String,dynamic>>[];
  final deleted=previous.length-prefix;
  if(deleted>0) {
    result.add({'type':'backspace','count':deleted.clamp(1,500)});
  }
  var pendingCtrl=control;
  var plain=StringBuffer();
  void flush(){
    if(plain.isNotEmpty){
      result.add({'type':'text','text':plain.toString()});
      plain=StringBuffer();
    }
  }
  for(var i=prefix;i<next.length;i++){
    final char=String.fromCharCode(next[i]);
    if(char=='\n') {
      flush();
      result.add({
        'type':'key','name':'Return',
        if(pendingCtrl)'control':true,
      });
      pendingCtrl=false;
    } else if(pendingCtrl) {
      flush();
      result.add({'type':'char','text':char,'control':true});
      pendingCtrl=false;
    } else {
      plain.write(char);
    }
  }
  flush();
  return result;
}

class ComputerKeyboardBar extends StatefulWidget {
  final bool enabled;
  final Future<void> Function(Map<String,dynamic>) send;
  const ComputerKeyboardBar({super.key,required this.enabled,required this.send});
  @override
  State<ComputerKeyboardBar> createState()=>_ComputerKeyboardBarState();
}

class _ComputerKeyboardBarState extends State<ComputerKeyboardBar> {
  final _field=TextEditingController(),_focus=FocusNode();
  String _previous='';
  Future<void> _pending=Future<void>.value();
  bool _control=false;
  bool _keyboardVisible=false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  void _onFocus() {
    if(mounted)setState(()=>_keyboardVisible=_focus.hasFocus);
  }

  void _enqueue(List<Map<String,dynamic>> commands) {
    if(!widget.enabled || commands.isEmpty)return;
    _pending=_pending.then((_) async {
      for(final command in commands) {
        if(!mounted || !widget.enabled)return;
        await widget.send(command);
      }
    }).catchError((Object _){
      // Navigating away from the remote page may invalidate a queued command.
    });
  }

  void _onText(String value) {
    if(!widget.enabled)return;
    final changes=computerKeyboardCommands(
      _previous,value,control:_control);
    if(changes.isNotEmpty){
      _enqueue(changes);
      if(_control)setState(()=>_control=false);
    }
    _previous=value;
    if(value.runes.length>180) {
      _previous='';
      _field.clear();
    } else if(_field.selection.baseOffset!=value.length ||
              _field.selection.extentOffset!=value.length) {
      _field.selection=TextSelection.collapsed(offset:value.length);
    }
  }

  void _key(String name) {
    if(!widget.enabled)return;
    if(name=='Control') {
      setState(()=>_control=!_control);
      return;
    }
    _enqueue([{
      'type':'key','name':name,
      if(_control)'control':true,
    }]);
    if(_control)setState(()=>_control=false);
  }

  Widget _keyButton(String title,String name,{bool selected=false})=>
    Expanded(child:GestureDetector(
      onTap:widget.enabled?()=>_key(name):null,
      child:AnimatedContainer(
        duration:const Duration(milliseconds:170),
        height:38,alignment:Alignment.center,
        margin:const EdgeInsets.symmetric(horizontal:2),
        decoration:BoxDecoration(
          color:selected?KColors.ink:KColors.soft,
          borderRadius:BorderRadius.circular(16)),
        child:Text(title,style:TextStyle(
          color:selected?Colors.white:widget.enabled?KColors.ink:KColors.muted,
          fontWeight:FontWeight.w600,fontSize:12)),
      ),
    ));

  @override
  void dispose(){
    _focus.removeListener(_onFocus);
    _focus.dispose();
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context)=>Container(
    padding:const EdgeInsets.fromLTRB(8,7,8,9),
    decoration:const BoxDecoration(color:KColors.surface,
      border:Border(top:BorderSide(color:KColors.line,width:.7))),
    child:Stack(children:[
      Positioned(left:0,bottom:0,width:1,height:1,child:Opacity(
        opacity:0,child:TextField(
          controller:_field,focusNode:_focus,onChanged:_onText,
          enableSuggestions:false,autocorrect:false,
          maxLines:null,keyboardType:TextInputType.multiline,
          textInputAction:TextInputAction.newline,
        ),
      )),
      Row(children:[
        KakaIconButton(icon:LucideIcons.keyboard,size:38,
          filled:_keyboardVisible,
          tooltip:'Toggle remote keyboard',onTap:widget.enabled?(){
            if(_focus.hasFocus){_focus.unfocus();}
            else{_focus.requestFocus();}
          }:null),
        const SizedBox(width:4),
        _keyButton('Esc','Escape'),
        _keyButton('Tab','Tab'),
        _keyButton('Ctrl','Control',selected:_control),
        _keyButton('←','ArrowLeft'),
        _keyButton('↓','ArrowDown'),
        _keyButton('↑','ArrowUp'),
        _keyButton('→','ArrowRight'),
      ]),
    ]),
  );
}
