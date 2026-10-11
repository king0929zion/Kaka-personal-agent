import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../core/api.dart';
import '../../core/models.dart';
import '../../design/theme.dart';
import '../../design/widgets.dart';
import '../avatar/organic_avatar.dart';
import '../avatar/avatar_editor.dart';
import 'thread_controller.dart';

class ThreadScreen extends StatefulWidget {
  final KakaApi api;
  final KakaBot bot;
  const ThreadScreen({super.key, required this.api, required this.bot});
  @override
  State<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends State<ThreadScreen> {
  late final ThreadController thread = ThreadController(widget.api, widget.bot.id);
  final draft = TextEditingController();
  final scroll = ScrollController();
  int lastCount = 0;
  bool focused = false;

  @override
  void initState() {
    super.initState();
    thread.addListener(_onUpdate);
    unawaited(thread.load());
  }
  void _onUpdate() {
    final count = thread.messages.length;
    if (count != lastCount) {
      lastCount = count;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !scroll.hasClients) return;
        if (scroll.position.maxScrollExtent-scroll.position.pixels < 260) {
          scroll.animateTo(scroll.position.maxScrollExtent,
            duration:const Duration(milliseconds:220),curve:Curves.easeOutCubic);
        }
      });
    }
  }
  @override
  void dispose() {
    thread.removeListener(_onUpdate);
    thread.dispose(); draft.dispose(); scroll.dispose();
    super.dispose();
  }
  Future<void> send() async {
    final text = draft.text.trim();
    if (text.isEmpty) return;
    draft.clear();
    await thread.send(text);
    if (!mounted) return;
    if (thread.error != null && draft.text.isEmpty) {
      draft.text = text;
      kakaNotice(context, thread.error!);
    }
  }
  Future<void> answer(KakaMessage message,String value) async {
    try {
      await widget.api.rpc('threads/answer', {
        'botId':widget.bot.id,
        'runId':message.runId,
        'messageId':message.id,
        'answer':value,
      });
      await thread.load();
    } catch (e) {
      if(mounted)kakaNotice(context,e.toString());
    }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor:KColors.bg,
    resizeToAvoidBottomInset:true,
    body:SafeArea(child:Column(children:[
      _header(),
      Expanded(child:AnimatedBuilder(animation:thread,builder:(context,_) =>
        thread.snapshot == null
          ? Center(child:thread.error!=null
              ? Column(mainAxisSize:MainAxisSize.min,children:[
                  Text(thread.error!,textAlign:TextAlign.center),
                  const SizedBox(height:16),
                  KakaButton(title:'Try again',onPressed:thread.load),
                ]) : const CircularProgressIndicator(color:KColors.ink))
          : ListView.builder(
              controller:scroll,
              padding:const EdgeInsets.fromLTRB(20,9,20,24),
              itemCount:thread.messages.length+1,
              itemBuilder:(ctx,i) {
                if(i==0) {
                  return Column(children:[
                    if(thread.snapshot?.olderCursor!=null)
                      Padding(padding:const EdgeInsets.only(bottom:20),
                        child:GestureDetector(onTap:thread.loadOlder,
                          child:Text(thread.fetchingMore?'Loading…':'Load earlier messages',
                            style:const TextStyle(color:KColors.muted,fontSize:13)))),
                    if(thread.messages.isEmpty) Padding(padding:const EdgeInsets.only(top:90),
                      child:Column(children:[
                        OrganicAvatar(size:105,color:_botColor()),
                        const SizedBox(height:18),
                        Text(widget.bot.name,style:Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height:7),
                        Text(widget.bot.title,style:const TextStyle(color:KColors.muted,fontSize:14)),
                      ])),
                  ]);
                }
                return _message(thread.messages[i-1]);
              },
            ))),
      AnimatedBuilder(animation:thread,builder:(context,_) =>
        thread.error==null?const SizedBox.shrink():
          Padding(padding:const EdgeInsets.fromLTRB(20,0,20,6),
            child:Text(thread.error!,maxLines:2,overflow:TextOverflow.ellipsis,
              style:const TextStyle(fontSize:12,color:KColors.error)))),
      _composer(),
    ])),
  );

  Color _botColor() {
    try {
      final v=widget.bot.color.replaceFirst('#','');
      if(v.length==6)return Color(int.parse('FF$v',radix:16));
    }catch(_){}
    return KColors.ink;
  }

  Widget _header() => Container(
    padding:const EdgeInsets.fromLTRB(13,6,16,9),
    child:Row(children:[
      KakaIconButton(icon:LucideIcons.arrowLeft,onTap:()=>Navigator.pop(context)),
      const SizedBox(width:6),
      OrganicAvatar(size:38,color:_botColor(),working:
        ['running','leased'].contains(thread.snapshot?.runStatus)),
      const SizedBox(width:10),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(widget.bot.name,maxLines:1,overflow:TextOverflow.ellipsis,
          style:const TextStyle(fontSize:16,fontWeight:FontWeight.w600)),
        Text(thread.snapshot?.runStatus=='running'?'Working…':
          widget.bot.title.isEmpty?'Personal agent':widget.bot.title,
          maxLines:1,overflow:TextOverflow.ellipsis,
          style:const TextStyle(fontSize:12,color:KColors.muted)),
      ])),
      KakaIconButton(icon:LucideIcons.ellipsis,
        onTap:()=>kakaSheet<void>(context,Column(mainAxisSize:MainAxisSize.min,children:[
          KakaRow(title:'Customize avatar',icon:LucideIcons.smile,onTap:(){
            Navigator.pop(context);
            Navigator.push(context,MaterialPageRoute<void>(
              builder:(_)=>AvatarEditor(bot:widget.bot)));}),
          KakaRow(title:'Refresh chat',icon:LucideIcons.refreshCw,onTap:(){
            Navigator.pop(context);thread.load();}),
          KakaRow(title:'Clear conversation',icon:LucideIcons.trash2,onTap:(){
            Navigator.pop(context);
            _confirmClear();
          }),
        ]))),
    ]),
  );

  Future<void> _confirmClear() async {
    final confirmed = await kakaSheet<bool>(context,Column(
      mainAxisSize:MainAxisSize.min,
      crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Text('Clear this conversation?',style:Theme.of(context).textTheme.titleLarge),
        const SizedBox(height:8),
        const Text('Messages will be removed from the server.',
          style:TextStyle(color:KColors.muted,fontSize:14)),
        const SizedBox(height:20),
        KakaButton(title:'Clear messages',onPressed:()=>Navigator.pop(context,true)),
        const SizedBox(height:10),
        KakaButton(title:'Cancel',filled:false,onPressed:()=>Navigator.pop(context,false)),
      ]));
    if(confirmed==true){
      try{await widget.api.rpc('threads/clear',{'botId':widget.bot.id}); await thread.load();}
      catch(e){if(mounted)kakaNotice(context,e.toString());}
    }
  }

  Widget _message(KakaMessage message) {
    if(message.blocks.isEmpty)return const SizedBox.shrink();
    final user=message.role=='user';
    return Padding(padding:const EdgeInsets.only(bottom:21),
      child:Row(crossAxisAlignment:CrossAxisAlignment.start,
        mainAxisAlignment:user?MainAxisAlignment.end:MainAxisAlignment.start,
        children:[
          if(!user)...[OrganicAvatar(size:27,color:_botColor()),const SizedBox(width:10)],
          Flexible(child:GestureDetector(
            onLongPress:()=>_messageMenu(message),
            child:Container(
              padding:user?const EdgeInsets.symmetric(horizontal:17,vertical:13):EdgeInsets.zero,
              decoration:user?BoxDecoration(color:KColors.soft,
                borderRadius:BorderRadius.circular(25)):null,
              child:Column(crossAxisAlignment:CrossAxisAlignment.start,
                children:message.blocks.map((block)=>_renderBlock(message,block)).toList()),
            ),
          )),
        ]),
    );
  }

  Widget _renderBlock(KakaMessage message, Map<String,dynamic> block) {
    final kind='${block['kind'] ?? ''}';
    if(kind=='text') {
      final text='${block['text'] ?? ''}';
      if(text.trim().isEmpty)return const SizedBox.shrink();
      return Padding(padding:const EdgeInsets.only(bottom:5),
        child:SelectableText(text,style:const TextStyle(
          fontSize:15.5,height:1.54,color:KColors.ink)));
    }
    if(kind=='image'||kind=='file')return _blockCard(
      kind=='image'?LucideIcons.image:LucideIcons.file,
      '${block['name'] ?? (kind=='image'?'Image':'File')}',
      kind=='file'?'Attachment':'Image attachment');
    if(kind=='chart')return _blockCard(LucideIcons.chartColumn,
      '${block['name'] ?? 'Chart'}','Chart output');
    if(kind=='computer')return _blockCard(LucideIcons.monitor,
      'Computer','Tap to review computer activity');
    if(kind=='voice_call')return _blockCard(LucideIcons.audioLines,
      'Voice call','${block['status'] ?? 'Call activity'}');
    if(kind=='progress'||kind=='steps'){
      return _blockCard(LucideIcons.loaderCircle,'Working',
        '${block['text'] ?? block['state'] ?? 'Agent is working'}');
    }
    if(kind=='ask'||kind=='choice'||kind=='mcp_approval'){
      final raw=block['options'] is List ? block['options'] as List : const [];
      final actions=raw.whereType<Map>().map((opt)=>
        (id:'${opt['id'] ?? ''}',label:'${opt['label'] ?? opt['title'] ?? opt['id'] ?? ''}')).toList();
      final askActions=block['actions'] is List?block['actions'] as List:const [];
      final effective=actions.isNotEmpty?actions:askActions.whereType<Map>().map((a)=>
        (id:'${a['id'] ?? ''}',label:'${a['label'] ?? a['id'] ?? ''}')).toList();
      return Container(margin:const EdgeInsets.symmetric(vertical:6),
        padding:const EdgeInsets.all(16),
        decoration:BoxDecoration(color:KColors.surface,
          borderRadius:BorderRadius.circular(24)),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('${block['question'] ?? block['text'] ?? 'Approval required'}',
            style:const TextStyle(fontWeight:FontWeight.w600,fontSize:14)),
          const SizedBox(height:10),
          for(final action in effective)
            Padding(padding:const EdgeInsets.only(bottom:7),
              child:KakaButton(title:action.label,onPressed:()=>answer(message,action.id),
                filled:false)),
          if(effective.isEmpty)
            const Text('Open in the existing client to complete this action.',
              style:TextStyle(fontSize:12,color:KColors.muted)),
        ]));
    }
    if(kind=='meta')return const SizedBox.shrink();
    return _blockCard(_iconFor(kind),_labelFor(kind),
      '${block['title'] ?? block['text'] ?? block['state'] ?? block['status'] ?? 'Agent activity'}');
  }

  IconData _iconFor(String kind) {
    if(kind.contains('bot')||kind.contains('agent'))return LucideIcons.bot;
    if(kind.contains('skill'))return LucideIcons.sparkles;
    if(kind.contains('handoff'))return LucideIcons.arrowLeftRight;
    if(kind.contains('connect'))return LucideIcons.plug;
    return LucideIcons.activity;
  }
  String _labelFor(String kind) => kind.replaceAll('_',' ').replaceAll('-', ' ').toUpperCase();

  Widget _blockCard(IconData icon,String title,String description) =>
    Container(margin:const EdgeInsets.symmetric(vertical:5),padding:const EdgeInsets.all(15),
      decoration:BoxDecoration(color:KColors.surface,
        border:Border.all(color:KColors.line,width:.6),
        borderRadius:BorderRadius.circular(23)),
      child:Row(mainAxisSize:MainAxisSize.min,children:[
        Icon(icon,size:18,color:KColors.ink),
        const SizedBox(width:11),
        Flexible(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(title,maxLines:2,overflow:TextOverflow.ellipsis,
            style:const TextStyle(fontSize:13,fontWeight:FontWeight.w600)),
          Text(description,maxLines:3,overflow:TextOverflow.ellipsis,
            style:const TextStyle(fontSize:12,color:KColors.muted)),
        ])),
      ]));

  void _messageMenu(KakaMessage message) {
    final text=message.text;
    kakaSheet<void>(context,Column(mainAxisSize:MainAxisSize.min,children:[
      KakaRow(title:'Reply with quote',icon:LucideIcons.reply,onTap:(){
        Navigator.pop(context);
        draft.text='> ${text.length>180?text.substring(0,180):text}\n\n';
      }),
      KakaRow(title:'Select text',icon:LucideIcons.textSelect,onTap:(){
        Navigator.pop(context);
        kakaSheet<void>(context,SingleChildScrollView(
          child:SelectableText(text.isEmpty?'No text':text)));
      }),
    ]));
  }

  Widget _composer() => AnimatedBuilder(animation:thread,builder:(context,_) =>
    Padding(padding:EdgeInsets.fromLTRB(16,5,16,
      MediaQuery.viewInsetsOf(context).bottom>0?8:17),
      child:Container(
        decoration:BoxDecoration(color:KColors.surface,
          border:Border.all(color:KColors.line,width:.7),
          borderRadius:BorderRadius.circular(30)),
        padding:const EdgeInsets.fromLTRB(13,9,8,9),
        child:Row(crossAxisAlignment:CrossAxisAlignment.end,children:[
          KakaIconButton(icon:LucideIcons.plus,size:40,onTap:()=>
            kakaNotice(context,'File attachments are not connected yet')),
          const SizedBox(width:5),
          Expanded(child:TextField(controller:draft,
            minLines:1,maxLines:6,keyboardType:TextInputType.multiline,
            onChanged:(_)=>setState((){}),
            style:const TextStyle(fontSize:15,color:KColors.ink),
            decoration:const InputDecoration(
              hintText:'Message…',hintStyle:TextStyle(color:KColors.muted),
              border:InputBorder.none,isDense:true,
              contentPadding:EdgeInsets.symmetric(vertical:12,horizontal:3)))),
          const SizedBox(width:6),
          KakaIconButton(
            icon:thread.sending?LucideIcons.clock:LucideIcons.arrowUp,
            filled:true,size:42,
            onTap:thread.sending||draft.text.trim().isEmpty?null:send),
        ]),
      ),
    ));
}
