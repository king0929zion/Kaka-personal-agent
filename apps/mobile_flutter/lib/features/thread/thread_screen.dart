import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api.dart';
import '../../core/models.dart';
import '../../design/theme.dart';
import '../../design/motion.dart';
import '../../design/widgets.dart';
import '../avatar/avatar_settings.dart';
import '../avatar/avatar_editor.dart';
import '../computer/computer_screen.dart';
import '../groups/group_settings_screen.dart';
import '../voice/device_voice_screen.dart';
import 'thread_controller.dart';

class ThreadScreen extends StatefulWidget {
  final KakaApi api;
  final KakaBot bot;
  final bool group;
  const ThreadScreen({super.key, required this.api, required this.bot, this.group = false});
  @override
  State<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends State<ThreadScreen> with WidgetsBindingObserver {
  late final ThreadController thread = ThreadController(widget.api, widget.bot.id, group:widget.group);
  final draft = TextEditingController();
  final attachments=<PendingAttachment>[];
  static const maxQueuedBytes=12*1024*1024;
  final scroll = ScrollController();
  int lastCount = 0;
  bool _scrollFramePending = false;
  bool _loadingOlderHistory = false;
  // Reuse existing Markdown widget subtrees when an unrelated SSE event arrives.
  // A changed message instance gets a new subtree automatically.
  final _messageCache =
      <String, ({KakaMessage message, Widget view})>{};
  bool focused=false;
  bool _realtimePaused=false;
  KakaMessage? replyingTo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    thread.addListener(_onUpdate);
    unawaited(thread.load());
  }
  void _onUpdate() {
    final count=thread.messages.length;
    final firstLoad=lastCount==0 && count>0 && !scroll.hasClients;
    final added=count>lastCount;
    // Measure the old viewport BEFORE it is laid out with incoming messages.
    // Measuring after a new message arrived made long replies appear to
    // randomly jump or stop following, especially during SSE token updates.
    final wasNearBottom=scroll.hasClients &&
      scroll.position.maxScrollExtent-scroll.position.pixels<145;
    lastCount=count;
    // Pagination adds items BEFORE the viewport. Never interpret that as a
    // reason to follow the bottom; the offset restoration owns this frame.
    if (_loadingOlderHistory || thread.fetchingMore) return;
    // A finger drag or fling owns the viewport. Do not let a token update
    // cancel that scroll activity or pull the reader back to the bottom.
    if (scroll.hasClients && scroll.position.isScrollingNotifier.value) return;
    if(!firstLoad && !wasNearBottom)return;
    // Multiple token events may arrive before layout. Schedule only one
    // correction and do not interrupt the viewport if it is already aligned.
    if (_scrollFramePending) return;
    _scrollFramePending = true;
    WidgetsBinding.instance.addPostFrameCallback((_){
      _scrollFramePending = false;
      if(!mounted||!scroll.hasClients)return;
      final end=scroll.position.maxScrollExtent;
      if ((end-scroll.position.pixels).abs()<1) return;
      if(firstLoad || !added){
        scroll.jumpTo(end);
      }else{
        scroll.animateTo(end,
          duration:const Duration(milliseconds:145),
          curve:KakaMotion.arrive);
      }
    });
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Keyboard overlays and permission dialogs often cause an
    // inactive/resumed pair. This must not reload all conversation messages.
    if(state==AppLifecycleState.paused ||
       state==AppLifecycleState.hidden ||
       state==AppLifecycleState.detached){
      if(!_realtimePaused){
        _realtimePaused=true;
        thread.pauseRealtime();
      }
    }else if(state==AppLifecycleState.resumed && _realtimePaused){
      _realtimePaused=false;
      unawaited(thread.load());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    thread.removeListener(_onUpdate);
    thread.dispose(); draft.dispose(); scroll.dispose();
    super.dispose();
  }
  Future<void> _olderPage() async {
    if (_loadingOlderHistory || thread.fetchingMore) return;
    _loadingOlderHistory = true;
    final attached = scroll.hasClients;
    final oldMax = attached ? scroll.position.maxScrollExtent : 0.0;
    final oldPixels = attached ? scroll.position.pixels : 0.0;
    try {
      await thread.loadOlder();
    } finally {
      if (!mounted || !attached || !scroll.hasClients) {
        _loadingOlderHistory = false;
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _loadingOlderHistory = false;
          if (!mounted || !scroll.hasClients) return;
          final delta = scroll.position.maxScrollExtent - oldMax;
          if (delta > 0) {
            scroll.jumpTo((oldPixels + delta).clamp(
              scroll.position.minScrollExtent,
              scroll.position.maxScrollExtent,
            ));
          }
        });
      }
    }
  }

  Future<void> send() async {
    final text = draft.text.trim();
    if (text.isEmpty && attachments.isEmpty) return;
    final files=List<PendingAttachment>.from(attachments);
    draft.clear();
    await thread.send(text,attachments:files,
      replyToMessageId:replyingTo?.id,replyQuote:replyingTo?.text);
    if (thread.error == null && mounted) setState(() {
      attachments.clear(); replyingTo=null;
    });
    if (!mounted) return;
    if (thread.error != null && draft.text.isEmpty) {
      draft.text = text;
      kakaNotice(context, thread.error!);
    }
  }

  String? _mime(String name) {
    final n=name.toLowerCase();
    const types={
      '.jpeg':'image/jpeg','.jpg':'image/jpeg','.png':'image/png',
      '.webp':'image/webp','.gif':'image/gif','.pdf':'application/pdf',
      '.txt':'text/plain','.md':'text/markdown','.csv':'text/csv',
      '.html':'text/html','.json':'application/json','.zip':'application/zip',
    };
    for (final item in types.entries) {
      if (n.endsWith(item.key)) return item.value;
    }
    return null;
  }

  Future<void> pickAttachment() async {
    try {
      final picked=await FilePicker.pickFiles();
      for(final file in picked) {
        if (attachments.length>=4) {
          if (mounted) kakaNotice(context,'Maximum 4 attachments per message');
          return;
        }
        final mime=_mime(file.name);
        if (mime==null) {
          if (mounted) kakaNotice(context,'Unsupported file type: ${file.name}');
          continue;
        }
        final len=file.lengthSync() ?? await file.length();
        if (len==null || len>10*1024*1024 || len==0) {
          if (mounted) kakaNotice(context,'File must be 1 byte to 10 MB');
          continue;
        }
        final alreadyQueued=attachments.fold<int>(0,
          (total,item)=>total+item.bytes.lengthInBytes);
        if(alreadyQueued+len>maxQueuedBytes){
          if(mounted)kakaNotice(context,'Total attachments cannot exceed 12 MB');
          continue;
        }
        final bytes=await file.readAsBytes();
        if (!mounted)return;
        setState(()=>attachments.add(PendingAttachment(file.name,mime,bytes)));
      }
    }catch(e){
      if(mounted)kakaNotice(context,e.toString());
    }
  }

  Future<void> previewArtifact(Map<String,dynamic> block) async {
    final id=block['artifactId']?.toString() ?? '';
    if(id.isEmpty)return;
    try {
      final data=await widget.api.readArtifact(widget.bot.id,id,group:widget.group);
      final encoded=data['contentBase64']?.toString()??'';
      if(encoded.length>14*1024*1024) {
        throw const KakaApiException('Attachment too large to preview');
      }
      // Decode off the UI isolate to avoid freezing the chat while opening media.
      final bytes=await compute<String,Uint8List>(base64Decode,encoded);
      if(!mounted)return;
      final mime=data['mimeType']?.toString()??'';
      if(mime.startsWith('image/')){
        await kakaSheet<void>(context,SingleChildScrollView(
          child:Column(mainAxisSize:MainAxisSize.min,children:[
            Text(data['name']?.toString()??'Image',
              style:Theme.of(context).textTheme.titleLarge),
            const SizedBox(height:14),
            Image.memory(bytes,fit:BoxFit.contain,
              cacheWidth:(MediaQuery.sizeOf(context).width *
                MediaQuery.devicePixelRatioOf(context)).round().clamp(1,1536),
              errorBuilder:(_,error,stack)=>const Text('Could not display image')),
          ])),height:MediaQuery.sizeOf(context).height*.65);
      }else if(mime.startsWith('text/')||mime=='application/json'){
        await kakaSheet<void>(context,ListView(shrinkWrap:true,children:[
          Text(data['name']?.toString()??'Text file',
            style:Theme.of(context).textTheme.titleLarge),
          const SizedBox(height:16),
          SelectableText(utf8.decode(
            bytes.lengthInBytes>128*1024 ? bytes.sublist(0,128*1024) : bytes,
            allowMalformed:true)),
          if(bytes.lengthInBytes>128*1024)const Padding(
            padding:EdgeInsets.only(top:12),
            child:Text('Preview limited to 128 KB to protect memory.',
              style:TextStyle(color:KColors.muted,fontSize:12))),
        ]),height:MediaQuery.sizeOf(context).height*.7);
      }else{
        kakaNotice(context,'Preview for this file type is not available yet');
      }
    }catch(e){if(mounted)kakaNotice(context,e.toString());}
  }

  Future<void> _connectApp(Map<String,dynamic> block) async {
    final provider=block['provider']?.toString()??'';
    if(provider.isEmpty)return;
    try {
      final data=await widget.api.rpc('connections/begin',{
        'connectorId':block['connectorId']?.toString()??'composio',
        'provider':provider,
        'displayName':block['name']?.toString()??provider,
      });
      final result=Map<String,dynamic>.from(data as Map);
      final authorizationUrl=result['authorizationUrl']?.toString();
      if(authorizationUrl!=null&&authorizationUrl.isNotEmpty){
        final uri=Uri.tryParse(authorizationUrl);
        if(uri==null || uri.scheme!='https' || uri.host.isEmpty){
          throw const KakaApiException('Invalid authorization URL');
        }
        if(!await launchUrl(uri,mode:LaunchMode.externalApplication)){
          throw const KakaApiException('Could not launch authorization');
        }
        if(mounted)kakaNotice(context,'Complete authorization in your browser');
      }else{
        final id=result['connectionId']?.toString()??'';
        if(id.isNotEmpty){
          await widget.api.rpc('connections/complete',{'connectionId':id});
        }
        await thread.load();
      }
    }catch(e){if(mounted)kakaNotice(context,e.toString());}
  }

  Future<void> _markUnread() async {
    try{
      await widget.api.rpc('threads/markUnread',widget.group?
        {'groupId':widget.bot.id}:{'botId':widget.bot.id});
      if(mounted)Navigator.pop(context);
    }catch(e){if(mounted)kakaNotice(context,e.toString());}
  }

  Future<void> answer(KakaMessage message,String value) async {
    try {
      await widget.api.rpc('threads/answer', {
        ...(widget.group ? {'groupId':widget.bot.id} : {'botId':widget.bot.id}),
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
      AnimatedBuilder(animation:thread,builder:(context,_)=>_header()),
      Expanded(child:KakaContentWidth(child:AnimatedBuilder(animation:thread,builder:(context,_) =>
        thread.snapshot == null
          ? Center(child:thread.error!=null
              ? Column(mainAxisSize:MainAxisSize.min,children:[
                  Text(thread.error!,textAlign:TextAlign.center),
                  const SizedBox(height:16),
                  KakaButton(title:'Try again',onPressed:thread.load),
                ]) : const KakaLoadingDots())
          : ListView.builder(
              controller:scroll,
              key:PageStorageKey('thread-${widget.bot.id}-${widget.group}'),
              findChildIndexCallback: (key) {
                if (key is! ValueKey<String>) return null;
                if (key.value == 'kaka-thread-header') return 0;
                final index = thread.messages.indexWhere(
                  (item) => item.id == key.value,
                );
                return index < 0 ? null : index + 1;
              },
              cacheExtent:170,
              padding:const EdgeInsets.fromLTRB(KLayout.pageGutter,9,KLayout.pageGutter,24),
              itemCount:thread.messages.length+1,
              itemBuilder:(ctx,i) {
                if(i==0) {
                  return Column(key:const ValueKey<String>('kaka-thread-header'),children:[
                    if(thread.snapshot?.olderCursor!=null)
                      Padding(padding:const EdgeInsets.only(bottom:20),
                        child:Center(child:Semantics(
                          button:true,
                          label:'Load earlier messages',
                          child:KakaPress(
                            onTap:thread.fetchingMore?null:_olderPage,
                            child:Container(
                              constraints:const BoxConstraints(minHeight:48),
                              padding:const EdgeInsets.symmetric(horizontal:20,vertical:12),
                              decoration:BoxDecoration(
                                color:KColors.soft,
                                borderRadius:BorderRadius.circular(24)),
                              child:Text(thread.fetchingMore?'Loading…':'Load earlier messages',
                                textAlign:TextAlign.center,
                                style:const TextStyle(
                                  color:KColors.ink,fontSize:13,
                                  fontWeight:FontWeight.w500)),
                            ),
                          ),
                        ))),
                    if(thread.messages.isEmpty) Padding(padding:const EdgeInsets.only(top:90),
                      child:Column(children:[
                        AgentAvatar(botId:widget.bot.id,size:105,fallbackColor:_botColor()),
                        const SizedBox(height:18),
                        Text(widget.bot.name,style:Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height:7),
                        Text(widget.bot.title,style:const TextStyle(color:KColors.muted,fontSize:14)),
                      ])),
                  ]);
                }
                final message=thread.messages[i-1];
                return _cachedMessageView(message);
              },
            )))),
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

  Widget _header() => KakaPageHeader(
    title:Row(children:[
      AgentAvatar(botId:widget.bot.id,size:38,fallbackColor:_botColor(),working:
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
    ]),
    actions:[
      if(MediaQuery.sizeOf(context).width >= 380)
        KakaIconButton(icon:LucideIcons.mic,size:40,tooltip:'Voice chat',
          onTap:_openVoice),
      if(thread.canStop)KakaIconButton(icon:LucideIcons.square,
        filled:true,size:40,tooltip:'Stop generation',onTap:thread.stop),
      KakaIconButton(icon:LucideIcons.ellipsis,tooltip:'More actions',
        onTap:()=>kakaSheet<void>(context,Column(mainAxisSize:MainAxisSize.min,children:[
          if(MediaQuery.sizeOf(context).width < 380)
            KakaRow(title:'Voice chat',icon:LucideIcons.mic,onTap:(){
              Navigator.pop(context);
              _openVoice();
            }),
          KakaRow(title:'Customize avatar',icon:LucideIcons.smile,onTap:(){
            Navigator.pop(context);
            Navigator.push(context,MaterialPageRoute<void>(
              builder:(_)=>AvatarEditor(bot:widget.bot)));}),
          if(widget.group)KakaRow(title:'Group settings',icon:LucideIcons.users,
            onTap:(){
              Navigator.pop(context);
              Navigator.push(context,MaterialPageRoute<bool>(builder:(_)=>
                GroupSettingsScreen(api:widget.api,groupId:widget.bot.id)))
                .then((changed){if(changed==true && mounted)Navigator.pop(context);});
            }),
          if(!widget.group)KakaRow(title:'Open computer',icon:LucideIcons.monitor,onTap:(){
            Navigator.pop(context);
            Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>
              ComputerScreen(api:widget.api,bot:widget.bot)));
          }),
          KakaRow(title:'Mark unread',icon:LucideIcons.mail,
            onTap:(){
              Navigator.pop(context);
              _markUnread();
            }),
          if(thread.canStop)KakaRow(title:'Follow up',icon:LucideIcons.messageSquarePlus,
            onTap:(){
              Navigator.pop(context);
              _followUp();
            }),
          KakaRow(title:'Refresh chat',icon:LucideIcons.refreshCw,onTap:(){
            Navigator.pop(context);thread.load();}),
          KakaRow(title:'Clear conversation',icon:LucideIcons.trash2,onTap:(){
            Navigator.pop(context);
            _confirmClear();
          }),
        ]))),
    ],
  );

  Future<void> _openVoice() async {
    thread.pauseRealtime();
    await Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>
      DeviceVoiceScreen(api:widget.api,bot:widget.bot,group:widget.group)));
    if(mounted)unawaited(thread.load());
  }

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
      try{await widget.api.rpc('threads/clear',widget.group ? {'groupId':widget.bot.id} : {'botId':widget.bot.id}); await thread.load();}
      catch(e){if(mounted)kakaNotice(context,e.toString());}
    }
  }

  Widget _cachedMessageView(KakaMessage message) {
    final entry = _messageCache[message.id];
    if (entry != null && identical(entry.message, message)) {
      return entry.view;
    }
    // Preserve the exact Widget instance for unchanged messages. A repaint
    // boundary alone does NOT avoid rebuilding expensive MarkdownBody trees.
    final view = RepaintBoundary(
      key: ValueKey(message.id),
      child: _message(message),
    );
    _messageCache.remove(message.id);
    _messageCache[message.id] = (message: message, view: view);
    // Keep this a bounded cache: long-lived chats must not accumulate every
    // visited message (and its render subtree) in memory.
    if (_messageCache.length > 80) {
      _messageCache.remove(_messageCache.keys.first);
    }
    return view;
  }

  Widget _message(KakaMessage message) {
    if(message.blocks.isEmpty)return const SizedBox.shrink();
    final user=message.role=='user';
    return Padding(padding:const EdgeInsets.only(bottom:17),
      child:Row(crossAxisAlignment:CrossAxisAlignment.start,
        mainAxisAlignment:user?MainAxisAlignment.end:MainAxisAlignment.start,
        children:[
          if(!user)...[AgentAvatar(botId:widget.bot.id,size:27,fallbackColor:_botColor()),const SizedBox(width:10)],
          Flexible(child:GestureDetector(
            onLongPress:()=>_messageMenu(message),
            child:Container(
              constraints:user
                ?BoxConstraints(maxWidth:math.min(
                    MediaQuery.sizeOf(context).width*.82,520))
                :null,
              padding:user?const EdgeInsets.symmetric(horizontal:17,vertical:13):EdgeInsets.zero,
              decoration:user?BoxDecoration(color:KColors.soft,
                borderRadius:BorderRadius.circular(25)):null,
              child:Column(crossAxisAlignment:CrossAxisAlignment.start,
                children:[
                  if(message.replyQuote!=null && message.replyQuote!.isNotEmpty)
                    Container(padding:const EdgeInsets.symmetric(horizontal:11,vertical:8),
                      margin:const EdgeInsets.only(bottom:8),
                      decoration:BoxDecoration(color:KColors.soft,
                        borderRadius:BorderRadius.circular(12)),
                      child:Text(message.replyQuote!,maxLines:3,
                        overflow:TextOverflow.ellipsis,
                        style:const TextStyle(color:KColors.muted,fontSize:12))),
                  ...message.blocks.map((block)=>_renderBlock(message,block)),
                ]),
            ),
          )),
        ]),
    );
  }

  static final _markdownStyles=MarkdownStyleSheet(
    p:const TextStyle(fontSize:15.5,height:1.54,color:KColors.ink),
    code:const TextStyle(fontSize:13,color:KColors.ink,fontFamily:'monospace'),
    codeblockDecoration:BoxDecoration(color:KColors.soft,
      borderRadius:BorderRadius.circular(16)),
    blockquoteDecoration:BoxDecoration(color:KColors.soft,
      borderRadius:BorderRadius.circular(10)),
  );

  Widget _renderBlock(KakaMessage message, Map<String,dynamic> block) {
    final kind='${block['kind'] ?? ''}';
    if(kind=='text') {
      final text='${block['text'] ?? ''}';
      if(text.trim().isEmpty)return const SizedBox.shrink();
      return Padding(padding:const EdgeInsets.only(bottom:5),
        child:MarkdownBody(
          data:text,
          selectable:true,
          styleSheet:_markdownStyles,
        ));
    }
    if(kind=='image'||kind=='file')return GestureDetector(
      onTap:()=>previewArtifact(block),
      child:_blockCard(
        kind=='image'?LucideIcons.image:LucideIcons.file,
        '${block['name'] ?? (kind=='image'?'Image':'File')}',
        kind=='file'?'Open attachment':'Preview image'));
    if(kind=='chart')return _blockCard(LucideIcons.chartColumn,
      '${block['name'] ?? 'Chart'}','Chart output');
    if(kind=='app_connect'){
      final connected=block['status']=='connected';
      return Container(
        margin:const EdgeInsets.symmetric(vertical:5),
        padding:const EdgeInsets.all(16),
        decoration:BoxDecoration(color:KColors.surface,
          borderRadius:BorderRadius.circular(24)),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[
            const Icon(LucideIcons.plug,size:19,color:KColors.ink),
            const SizedBox(width:10),
            Expanded(child:Text(block['name']?.toString()??'Connect app',
              style:const TextStyle(fontSize:15,fontWeight:FontWeight.w600))),
            if(connected)const Icon(LucideIcons.circleCheck,
              size:19,color:KColors.ink),
          ]),
          if(block['description']!=null)Padding(
            padding:const EdgeInsets.only(top:8,bottom:12),
            child:Text(block['description'].toString(),
              style:const TextStyle(fontSize:13,height:1.45,color:KColors.muted))),
          if(!connected)KakaButton(title:'Authorize',
            onPressed:()=>_connectApp(block)),
        ]),
      );
    }
    if(kind=='computer')return GestureDetector(
      onTap:widget.group?null:()=>Navigator.push(context,
        MaterialPageRoute<void>(builder:(_)=>ComputerScreen(
          api:widget.api,bot:widget.bot))),
      child:_blockCard(LucideIcons.monitor,
        'Computer','${block['text'] ?? 'Open computer controls'}'));
    if(kind=='voice_call')return _blockCard(LucideIcons.audioLines,
      'Voice call','${block['status'] ?? 'Call activity'}');
    if(kind=='card') {
      final lines=block['lines'] is List?block['lines'] as List:const [];
      return Container(
        margin:const EdgeInsets.symmetric(vertical:5),
        padding:const EdgeInsets.symmetric(horizontal:16,vertical:12),
        decoration:BoxDecoration(color:KColors.surface,
          borderRadius:BorderRadius.circular(25)),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          for(final line in lines.whereType<Map>()) Padding(
            padding:const EdgeInsets.symmetric(vertical:6),
            child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
              SizedBox(width:90,child:Text('${line['k'] ?? ''}',
                style:const TextStyle(color:KColors.muted,fontSize:12))),
              Expanded(child:Text('${line['v'] ?? ''}',
                style:const TextStyle(fontSize:13,color:KColors.ink))),
            ])),
        ]));
    }
    if(kind=='steps') {
      final steps=block['steps'] is List?block['steps'] as List:const [];
      final summary=steps.whereType<Map>().map((step)=>
        '${step['label'] ?? ''}' +
          ((step['count'] is num && step['count'] > 1)
            ? ' ×${step['count']}' : '')).join('  ·  ');
      return _blockCard(LucideIcons.listChecks,'Steps',summary);
    }
    if(kind=='progress')return _blockCard(LucideIcons.loaderCircle,
      'Working','${block['text'] ?? 'Agent is working'}');
    if(kind=='subagent'||kind=='cloud_agent'||kind=='child_bot'||kind=='handoff')
      return _blockCard(LucideIcons.bot,
        '${block['name'] ?? block['title'] ?? _labelFor(kind)}',
        '${block['progress'] ?? block['result'] ?? block['task'] ?? block['status'] ?? 'Agent activity'}');
    if(kind=='mcp_approval')return _blockCard(LucideIcons.shieldCheck,
      '${block['name'] ?? 'MCP connection'}',
      '${block['status'] ?? 'pending'} · Review in MCP settings');
    if(kind=='ask'||kind=='choice'){
      final raw=block['options'] is List ? block['options'] as List : const [];
      final actions=raw.whereType<Map>().map((opt)=>
        (id:'${opt['id'] ?? ''}',label:'${opt['label'] ?? opt['title'] ?? opt['id'] ?? ''}')).toList();
      final askActions=block['actions'] is List?block['actions'] as List:const [];
      final effective=actions.isNotEmpty?actions:askActions.whereType<Map>().map((a)=>
        (id:'${a['id'] ?? ''}',label:'${a['label'] ?? a['id'] ?? ''}')).toList();
      final answered=block['status']=='answered' || block['answerId']!=null;
      return Container(margin:const EdgeInsets.symmetric(vertical:6),
        padding:const EdgeInsets.all(16),
        decoration:BoxDecoration(color:KColors.surface,
          borderRadius:BorderRadius.circular(24)),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('${block['question'] ?? block['text'] ?? 'Approval required'}',
            style:const TextStyle(fontWeight:FontWeight.w600,fontSize:14)),
          const SizedBox(height:10),
          if(answered)
            const Padding(padding:EdgeInsets.only(top:5),
              child:Text('Answered',style:TextStyle(fontSize:12,color:KColors.muted)))
          else ...[
            for(final action in effective)
              Padding(padding:const EdgeInsets.only(bottom:7),
                child:KakaButton(title:action.label,
                  onPressed:()=>answer(message,action.id),filled:false)),
            if(effective.isEmpty)
              KakaButton(title:'Respond',filled:false,
                onPressed:()=>_answerInput(message,block)),
          ],
        ]));
    }
    if(kind=='meta')return const SizedBox.shrink();
    return _blockCard(_iconFor(kind),_labelFor(kind),
      '${block['title'] ?? block['text'] ?? block['state'] ?? block['status'] ?? 'Agent activity'}');
  }

  Future<void> _answerInput(KakaMessage message, Map<String,dynamic> block) async {
    final input=TextEditingController();
    final secret=block['input']=='secret';
    try {
      await kakaSheet<void>(context,SingleChildScrollView(
        child:Column(mainAxisSize:MainAxisSize.min,
          crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            Text('Your response',style:Theme.of(context).textTheme.titleLarge),
            const SizedBox(height:8),
            Text('${block['text'] ?? 'Provide a response'}',
              style:const TextStyle(color:KColors.muted,fontSize:13)),
            const SizedBox(height:18),
            KakaField(controller:input,label:secret?'Private response':'Answer',
              obscure:secret),
            const SizedBox(height:16),
            KakaButton(title:'Send response',onPressed:() async {
              if(input.text.trim().isEmpty)return;
              final response=input.text;
              Navigator.of(context).pop();
              await answer(message,response);
            }),
          ]),
      ));
    }finally {
      WidgetsBinding.instance.addPostFrameCallback((_){input.dispose();});
    }
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
        borderRadius:BorderRadius.circular(26)),
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

  Future<void> _react(KakaMessage message,String emoji) async {
    try {
      await widget.api.rpc('threads/react',{
        if(widget.group)'groupId':widget.bot.id
        else 'botId':widget.bot.id,
        'messageId':message.id,
        'reaction':emoji,
        'clientNonce':'flutter-react-${DateTime.now().microsecondsSinceEpoch}',
      });
      if(mounted)kakaNotice(context,'Reaction sent');
    }catch(e){if(mounted)kakaNotice(context,e.toString());}
  }
  Future<void> _reactionPicker(KakaMessage message) async {
    await kakaSheet<void>(context,Column(
      mainAxisSize:MainAxisSize.min,
      crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Text('React',style:Theme.of(context).textTheme.titleLarge),
        const SizedBox(height:18),
        Wrap(spacing:10,runSpacing:10,children:[
          for(final emoji in const ['👍','👎','❤️','😂','🎉','😮'])
            GestureDetector(onTap:(){
              Navigator.pop(context);
              _react(message,emoji);
            },child:Container(
              width:53,height:53,alignment:Alignment.center,
              decoration:BoxDecoration(color:KColors.soft,
                borderRadius:BorderRadius.circular(21)),
              child:Text(emoji,style:const TextStyle(fontSize:27)),
            )),
        ]),
      ]));
  }
  Future<void> _followUp() async {
    final input=TextEditingController();
    try{
      await kakaSheet<void>(context,SingleChildScrollView(
        child:Column(mainAxisSize:MainAxisSize.min,
          crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            Text('Follow up',style:Theme.of(context).textTheme.titleLarge),
            const SizedBox(height:14),
            KakaField(controller:input,label:'Instructions',maxLines:4,
              hint:'Add another instruction while the agent works'),
            const SizedBox(height:15),
            KakaButton(title:'Send follow-up',onPressed:()async{
              final content=input.text.trim();
              if(content.isEmpty)return;
              Navigator.pop(context);
              try{
                await widget.api.rpc('threads/followUp',{
                  if(widget.group)'groupId':widget.bot.id
                  else 'botId':widget.bot.id,
                  'text':content,
                });
              }catch(e){if(mounted)kakaNotice(context,e.toString());}
            }),
          ])));
    }finally{
      WidgetsBinding.instance.addPostFrameCallback((_)=>input.dispose());
    }
  }

  void _messageMenu(KakaMessage message) {
    final text=message.text;
    kakaSheet<void>(context,Column(mainAxisSize:MainAxisSize.min,children:[
      KakaRow(title:'Copy',icon:LucideIcons.copy,onTap:(){
        Clipboard.setData(ClipboardData(text:text));
        Navigator.pop(context);
        kakaNotice(context,'Copied');
      }),
      KakaRow(title:'Reply with quote',icon:LucideIcons.reply,onTap:(){
        Navigator.pop(context);
        setState(()=>replyingTo=message);
      }),
      KakaRow(title:'React',icon:LucideIcons.smile,onTap:(){
        Navigator.pop(context);
        _reactionPicker(message);
      }),
      KakaRow(title:'Select text',icon:LucideIcons.textSelect,onTap:(){
        Navigator.pop(context);
        kakaSheet<void>(context,SingleChildScrollView(
          child:SelectableText(text.isEmpty?'No text':text)));
      }),
    ]));
  }

  Widget _composer() => KakaContentWidth(child:Padding(padding:const EdgeInsets.fromLTRB(KLayout.compactGutter,5,KLayout.compactGutter,12),
      child:Column(mainAxisSize:MainAxisSize.min,children:[
        if(replyingTo!=null) Container(
          margin:const EdgeInsets.only(bottom:8),
          padding:const EdgeInsets.symmetric(horizontal:13,vertical:9),
          decoration:BoxDecoration(color:KColors.soft,borderRadius:BorderRadius.circular(16)),
          child:Row(children:[
            const Icon(LucideIcons.reply,size:17,color:KColors.muted),
            const SizedBox(width:9),
            Expanded(child:Text(replyingTo!.text.isEmpty?'Reply to message':replyingTo!.text,
              maxLines:1,overflow:TextOverflow.ellipsis,
              style:const TextStyle(fontSize:12,color:KColors.ink))),
            KakaIconButton(icon:LucideIcons.x,size:32,tooltip:'Remove reply',
              onTap:()=>setState(()=>replyingTo=null)),
          ])),
        if(attachments.isNotEmpty) SingleChildScrollView(
          scrollDirection:Axis.horizontal,
          child:Row(children:[
            for(var i=0;i<attachments.length;i++) Padding(
              padding:const EdgeInsets.only(right:7,bottom:8),
              child:GestureDetector(onTap:()=>setState(()=>attachments.removeAt(i)),
                child:Container(padding:const EdgeInsets.symmetric(horizontal:13,vertical:10),
                  decoration:BoxDecoration(color:KColors.soft,
                    borderRadius:BorderRadius.circular(19)),
                  child:Row(mainAxisSize:MainAxisSize.min,children:[
                    const Icon(LucideIcons.file,size:14,color:KColors.ink),
                    const SizedBox(width:7),
                    ConstrainedBox(constraints:const BoxConstraints(maxWidth:140),
                      child:Text(attachments[i].name,overflow:TextOverflow.ellipsis,
                        style:const TextStyle(fontSize:12))),
                    const SizedBox(width:9),
                    const Icon(LucideIcons.x,size:13,color:KColors.muted),
                  ])))),
          ])),
        KakaGlassSurface(
        radius:32,sigma:0,
        padding:const EdgeInsets.fromLTRB(13,9,8,9),
        child:Row(crossAxisAlignment:CrossAxisAlignment.end,children:[
          KakaIconButton(icon:LucideIcons.plus,size:40,tooltip:'Add attachment',onTap:pickAttachment),
          const SizedBox(width:5),
          Expanded(child:TextField(controller:draft,
            minLines:1,maxLines:6,keyboardType:TextInputType.multiline,
            style:const TextStyle(fontSize:16,height:1.35,color:KColors.ink),
            textCapitalization:TextCapitalization.sentences,
            decoration:const InputDecoration(
              hintText:'Message…',hintStyle:TextStyle(color:KColors.muted),
              border:InputBorder.none,isDense:true,
              contentPadding:EdgeInsets.symmetric(vertical:12,horizontal:3)))),
          const SizedBox(width:6),
          AnimatedBuilder(animation:thread,builder:(context,_) =>
            ValueListenableBuilder<TextEditingValue>(
              valueListenable:draft,
              builder:(context,value,_)=>KakaIconButton(
                icon:thread.sending?LucideIcons.clock:LucideIcons.arrowUp,
                filled:true,size:42,tooltip:thread.sending?'Sending':'Send message',
                onTap:thread.sending||(value.text.trim().isEmpty&&attachments.isEmpty)?null:send),
            )),
        ]),
      ),
      ]),
    ));
}
