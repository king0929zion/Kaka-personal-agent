import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../design/theme.dart';
import '../../design/widgets.dart';

/// Remote noVNC accepts text, individual key events and limited backspaces.
/// Diff by Unicode scalar, not UTF-16 units (emoji must count once).
/// Edits in the middle are replayed from their first divergence because the
/// remote cursor is anchored to the end of this local compose buffer.
List<Map<String,dynamic>> computerKeyboardCommands(
  String oldText,String newText,{bool control=false}) {
  final old=oldText.runes.toList();
  final next=newText.replaceAll('\r\n','\n').replaceAll('\r','\n').runes.toList();
  var common=0;
  while(common<old.length && common<next.length &&
      old[common]==next[common]) {common++;}
  final commands=<Map<String,dynamic>>[];
  var deleted=old.length-common;
  var ctrl=control;
  if(deleted>0 && ctrl) {
    commands.add({'type':'key','name':'Backspace','control':true});
    ctrl=false;
    deleted--;
  }
  while(deleted>0){
    final count=deleted>500?500:deleted;
    commands.add({'type':'backspace','count':count});
    deleted-=count;
  }
  var plain=StringBuffer();
  void flush(){
    if(plain.isEmpty)return;
    commands.add({'type':'text','text':plain.toString()});
    plain=StringBuffer();
  }
  for(var i=common;i<next.length;i++) {
    final char=String.fromCharCode(next[i]);
    if(char=='\n'){
      flush();
      commands.add({'type':'key','name':'Return',if(ctrl)'control':true});
      ctrl=false;
    }else if(ctrl){
      flush();
      commands.add({'type':'char','text':char,'control':true});
      ctrl=false;
    }else{plain.write(char);}
  }
  flush();
  return commands;
}

/// Explicitly defined command shapes, matching mobile-keyboard.js. A command
/// is never evaluated as JavaScript source supplied by the user.
Map<String,dynamic> computerNamedKey(String name,{bool control=false})=>
  {'type':'key','name':name,if(control)'control':true};

class ComputerKeyboardBar extends StatefulWidget {
  final bool enabled;
  final Future<void> Function(Map<String,dynamic>) send;
  const ComputerKeyboardBar({super.key,required this.enabled,required this.send});
  @override
  State<ComputerKeyboardBar> createState()=>_ComputerKeyboardBarState();
}

class _ComputerKeyboardBarState extends State<ComputerKeyboardBar> {
  final _field=TextEditingController();
  final _focus=FocusNode();
  String _previous='';
  Future<void> _pending=Future<void>.value();
  bool _control=false;
  bool _focused=false;
  bool _error=false;
  int _generation=0;

  @override
  void initState(){
    super.initState();
    _focus.addListener(_onFocus);
  }
  void _onFocus(){if(mounted)setState(()=>_focused=_focus.hasFocus);}

  @override
  void didUpdateWidget(covariant ComputerKeyboardBar oldWidget){
    super.didUpdateWidget(oldWidget);
    if(!widget.enabled && oldWidget.enabled){
      _generation++;
      _focus.unfocus();
      _resetLocalDraft();
      _control=false;
    }
  }
  void _resetLocalDraft(){
    _previous='';
    _field.value=const TextEditingValue();
  }
  void _enqueue(List<Map<String,dynamic>> commands) {
    if(!widget.enabled || commands.isEmpty)return;
    final generation=_generation;
    _pending=_pending.catchError((Object _){}).then((_) async {
      for(final command in commands) {
        if(!mounted || !widget.enabled || generation!=_generation)return;
        try {
          await widget.send(command);
        }catch(_) {
          if(mounted)setState(()=>_error=true);
          return;
        }
      }
    });
  }
  void _onTextChanged(String value){
    if(!widget.enabled)return;
    final previous=_previous;
    final changes=computerKeyboardCommands(previous,value,control:_control);
    if(changes.isNotEmpty){
      _enqueue(changes);
      if(_control)setState(()=>_control=false);
    }
    _previous=value;
    // A long IME compose history wastes memory and slows every diff. Reset
    // locally only; remote text is already committed.
    if(value.runes.length>180){_resetLocalDraft();}
    else if(_field.selection.baseOffset!=value.length ||
            _field.selection.extentOffset!=value.length) {
      _field.selection=TextSelection.collapsed(offset:value.length);
    }
  }
  void _key(String name){
    if(!widget.enabled)return;
    if(name=='Control'){setState(()=>_control=!_control);return;}
    _enqueue([computerNamedKey(name,control:_control)]);
    // Explicit remote keys also move the remote caret. The next IME
    // edit must start from an empty local compose buffer.
    _resetLocalDraft();
    if(_control)setState(()=>_control=false);
  }
  Future<void> _paste()async{
    if(!widget.enabled)return;
    final data=await Clipboard.getData(Clipboard.kTextPlain);
    if(!mounted || !widget.enabled)return;
    final text=data?.text??'';
    if(text.isEmpty)return;
    // Do not append to local composing history; paste is a remote action.
    _enqueue(computerKeyboardCommands('',text,control:_control));
    if(_control)setState(()=>_control=false);
    _resetLocalDraft();
  }
  void _toggleKeyboard(){
    if(!widget.enabled)return;
    if(_focus.hasFocus){
      _focus.unfocus();
    }else{
      _focus.requestFocus();
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    }
  }
  Widget _keyButton(String label,String key,{bool selected=false,
      double width=45})=>
    Padding(padding:const EdgeInsets.only(right:5),
      child:KakaPress(onTap:widget.enabled?()=>_key(key):null,haptic:true,
        child:AnimatedContainer(
          duration:const Duration(milliseconds:185),
          width:width,height:39,
          alignment:Alignment.center,
          decoration:BoxDecoration(
            color:selected?KColors.ink:KColors.soft,
            borderRadius:BorderRadius.circular(15)),
          child:Text(label,style:TextStyle(fontSize:13,
            fontWeight:FontWeight.w600,
            color:selected?Colors.white:
              widget.enabled?KColors.ink:KColors.muted)),
        )));

  @override
  void dispose(){
    ++_generation;
    _focus.removeListener(_onFocus);
    _focus.dispose();
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context)=>Container(
    decoration:const BoxDecoration(color:KColors.surface,
      borderRadius:BorderRadius.vertical(top:Radius.circular(22))),
    padding:const EdgeInsets.fromLTRB(13,10,13,11),
    child:Column(mainAxisSize:MainAxisSize.min,children:[
      Row(children:[
        Expanded(child:Container(
          height:43,
          alignment:Alignment.center,
          decoration:BoxDecoration(color:KColors.soft,
            borderRadius:BorderRadius.circular(19)),
          padding:const EdgeInsets.symmetric(horizontal:14),
          child:TextField(
            key:const ValueKey('remote-computer-ime'),
            controller:_field,focusNode:_focus,
            enabled:widget.enabled,onChanged:_onTextChanged,
            keyboardType:TextInputType.multiline,
            textInputAction:TextInputAction.newline,
            minLines:1,maxLines:2,
            autocorrect:false,
            enableSuggestions:false,
            textCapitalization:TextCapitalization.none,
            style:const TextStyle(fontSize:14,color:KColors.ink),
            cursorColor:KColors.ink,
            decoration:InputDecoration(
              hintText:widget.enabled?'Type on remote desktop…':'Connecting keyboard…',
              hintStyle:const TextStyle(color:KColors.muted,fontSize:13),
              isDense:true,contentPadding:EdgeInsets.zero,
              border:InputBorder.none),
          ),
        )),
        const SizedBox(width:7),
        KakaIconButton(icon:_focused?LucideIcons.keyboardOff:LucideIcons.keyboard,
          size:40,filled:_focused,tooltip:'Toggle Android keyboard',
          onTap:widget.enabled?_toggleKeyboard:null),
        KakaIconButton(icon:LucideIcons.clipboardPaste,
          size:40,tooltip:'Paste to remote computer',
          onTap:widget.enabled?_paste:null),
      ]),
      if(_error)const Padding(padding:EdgeInsets.only(top:6),
        child:Text('Keyboard command failed; check desktop connection.',
          style:TextStyle(color:KColors.error,fontSize:11))),
      const SizedBox(height:8),
      SizedBox(height:39,child:ListView(
        scrollDirection:Axis.horizontal,
        physics:const BouncingScrollPhysics(),
        children:[
          _keyButton('Esc','Escape'),
          _keyButton('Tab','Tab'),
          _keyButton('Ctrl','Control',selected:_control),
          _keyButton('⌫','Backspace'),
          _keyButton('↵','Return'),
          _keyButton('←','ArrowLeft'),
          _keyButton('↓','ArrowDown'),
          _keyButton('↑','ArrowUp'),
          _keyButton('→','ArrowRight'),
        ],
      )),
    ]),
  );
}
