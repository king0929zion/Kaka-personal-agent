import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../app/app_controller.dart';
import '../../core/models.dart';
import '../../core/performance_prefs.dart';
import '../../design/theme.dart';
import '../../design/motion.dart';
import '../../design/widgets.dart';
import '../../design/kinetic_interactions.dart';
import '../avatar/organic_avatar.dart';
import '../avatar/avatar_settings.dart';
import '../avatar/avatar_editor.dart';
import '../thread/thread_screen.dart';
import '../models/model_settings_screen.dart';
import '../voice/voice_settings_screen.dart';
import '../integrations/integrations_screen.dart';
import '../mcp/mcp_screen.dart';
import '../search/search_screen.dart';
import '../activity/activity_screen.dart';
import '../spaces/spaces_screen.dart';
import '../archives/archived_screen.dart';
import '../account/account_screen.dart';
import '../messaging/messaging_screen.dart';
import '../usage/usage_screen.dart';
import '../artifacts/artifact_library_screen.dart';
import '../memory/memory_screen.dart';
import '../agents/agent_settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppController app;
  const HomeScreen({super.key, required this.app});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final query=TextEditingController();
  final _chatsScroll=ScrollController();
  final _agentsScroll=ScrollController();
  bool searching=false;
  int _previousTab=0;
  bool _flashUpdate=false;
  String? _refreshAnnouncement;
  String? _newAgentId;

  Future<void> _refreshHome() async {
    final before={for(final bot in widget.app.bots)bot.id};
    await widget.app.refresh();
    if (!mounted) return;
    _newAgentId=widget.app.bots
        .where((bot)=>!before.contains(bot.id)).map((bot)=>bot.id).firstOrNull;
  }

  void _finishRefresh() {
    if (!mounted) return;
    setState(() {
      _refreshAnnouncement=_newAgentId==null
          ? 'All caught up' : 'New agent added';
      _flashUpdate=true;
    });
    Future<void>.delayed(const Duration(milliseconds:550),(){
      if(mounted)setState(()=>_flashUpdate=false);
    });
  }

  @override
  void dispose(){
    query.dispose();
    _chatsScroll.dispose();
    _agentsScroll.dispose();
    super.dispose();
  }

  void open(KakaBot bot) => Navigator.of(context).push(
    KakaRoute<void>(builder:(context)=>ThreadScreen(
      api:widget.app.api,bot:bot)),
  ).then((_)=>widget.app.refresh());

  void openGroup(KakaGroup group) {
    final presentation = KakaBot(id:group.id,name:group.name,title:'Group chat',
      preview:group.preview,color:'#181818',status:'',unread:group.unread,
      pinned:false,updatedAt:'');
    Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>
      ThreadScreen(api:widget.app.api,bot:presentation,group:true)))
      .then((_){widget.app.refresh();});
  }

  Future<void> _newMenu() async {
    await kakaSheet<void>(context,Column(
      mainAxisSize:MainAxisSize.min,
      crossAxisAlignment:CrossAxisAlignment.start,
      children:[
        Text('New conversation',style:Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height:15),
        KakaRow(title:'New agent',subtitle:'Create a personal AI assistant',
          icon:LucideIcons.bot,onTap:(){
            Navigator.of(context).pop();
            createBot();
          }),
        KakaRow(title:'New group',subtitle:'Bring agents together',
          icon:LucideIcons.users,onTap:(){
            Navigator.of(context).pop();
            _createGroup();
          }),
      ]));
  }

  Future<void> _createGroup() async {
    final name=TextEditingController();
    final selected=<String>{};
    final agents=widget.app.bots.where((bot)=>bot.status!='archived').toList();
    if(agents.length < 2) {
      kakaNotice(context,'Create at least two agents before making a group');
      name.dispose();
      return;
    }
    try {
      final group=await kakaSheet<KakaGroup>(context,StatefulBuilder(
        builder:(ctx,rebuild)=>SingleChildScrollView(
          child:Column(
            mainAxisSize:MainAxisSize.min,
            crossAxisAlignment:CrossAxisAlignment.stretch,children:[
              Text('New group',style:Theme.of(ctx).textTheme.headlineMedium),
              const SizedBox(height:18),
              KakaField(controller:name,label:'Group name',
                hint:'Team discussion'),
              const SizedBox(height:20),
              const Text('SELECT 2–6 AGENTS',
                style:TextStyle(fontSize:12,color:KColors.muted)),
              const SizedBox(height:10),
              ...agents.map((bot)=>GestureDetector(
                onTap:()=>rebuild((){
                  if(selected.contains(bot.id)){selected.remove(bot.id);}
                  else if(selected.length<6){selected.add(bot.id);}
                }),
                child:Container(
                  margin:const EdgeInsets.only(bottom:7),
                  padding:const EdgeInsets.all(13),
                  decoration:BoxDecoration(
                    color:selected.contains(bot.id)?KColors.soft:KColors.surface,
                    borderRadius:BorderRadius.circular(19)),
                  child:Row(children:[
                    AgentAvatar(botId:bot.id,size:33,fallbackColor:_color(bot.color)),
                    const SizedBox(width:12),
                    Expanded(child:Text(bot.name,
                      style:const TextStyle(fontSize:14))),
                    Icon(selected.contains(bot.id)
                        ? LucideIcons.circleCheck : LucideIcons.circle,
                      size:21,color:KColors.ink),
                  ]),
                ))),
              const SizedBox(height:18),
              KakaButton(title:'Create group',
                busy:widget.app.busy,
                onPressed:() async {
                  if(name.text.trim().isEmpty || selected.length<2){
                    kakaNotice(ctx,'Enter a group name and choose 2–6 agents');
                    return;
                  }
                  final created=await widget.app.createGroup(
                    name.text,selected.toList());
                  if(!ctx.mounted)return;
                  if(created!=null){Navigator.of(ctx).pop(created);}
                  else{kakaNotice(ctx,widget.app.error??'Could not create group');}
                }),
            ]),
        )));
      if(group!=null&&mounted)openGroup(group);
    }finally {
      WidgetsBinding.instance.addPostFrameCallback((_)=>name.dispose());
    }
  }

  Future<void> createBot() async {
    final name=TextEditingController(), title=TextEditingController(), detail=TextEditingController();
    final result = await kakaSheet<KakaBot>(context, StatefulBuilder(builder:(ctx, rebuild) =>
      SingleChildScrollView(child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('New agent',style:Theme.of(ctx).textTheme.headlineMedium),
          const SizedBox(height:22),
          KakaField(controller:name,label:'Name',hint:'My assistant'),
          const SizedBox(height:14),
          KakaField(controller:title,label:'Title',hint:'What does this agent do?'),
          const SizedBox(height:14),
          KakaField(controller:detail,label:'Description',hint:'Optional',maxLines:3),
          const SizedBox(height:20),
          KakaButton(title:'Create agent',busy:widget.app.busy,
            onPressed: () async {
              if(name.text.trim().isEmpty){kakaNotice(ctx,'Enter an agent name');return;}
              final bot=await widget.app.createBot(name.text,title.text,detail.text);
              if (!ctx.mounted) return;
              if (bot == null) {kakaNotice(ctx,widget.app.error ?? 'Could not create agent');return;}
              Navigator.of(ctx).pop(bot);
            }),
        ]),
      )));
    name.dispose(); title.dispose(); detail.dispose();
    if (result != null && mounted) open(result);
  }

  Future<void> selectSpace() async {
    final selected = await kakaSheet<String>(context, Column(
      mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
      children:[
        Text('Choose space',style:Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height:16),
        ...widget.app.spaces.map((space) => KakaRow(
          title:space.name,
          icon:space.id==widget.app.api.spaceId?LucideIcons.circleCheck:LucideIcons.circle,
          onTap:()=>Navigator.pop(context,space.id))),
      ]));
    if (selected!=null) widget.app.chooseSpace(selected);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation:widget.app,
    builder:(context,_) {
      final tab=widget.app.tab.clamp(0,3);
      final direction=tab>=_previousTab ? 1 : -1;
      _previousTab=tab;
      return Scaffold(
        backgroundColor:KColors.bg,
        body:SafeArea(child:Stack(children:[
          Column(children:[
            KakaContentWidth(child:Padding(padding:const EdgeInsets.fromLTRB(22,18,22,14),child:Row(
              mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
                Text(['Chats','Agents','Activity','Settings'][tab],
                  style:Theme.of(context).textTheme.headlineLarge),
                Row(children:[
                  if(tab<2) KakaIconButton(icon:LucideIcons.search,tooltip:'Search',onTap:()=>
                    Navigator.push(context,MaterialPageRoute<void>(
                      builder:(_)=>SearchScreen(app:widget.app)))),
                  const SizedBox(width:8),
                  if(tab<2) KakaIconButton(icon:LucideIcons.refreshCw,tooltip:'Refresh',onTap:widget.app.refresh),
                ]),
              ]))),
            if(tab<2) KakaContentWidth(child:Padding(padding:const EdgeInsets.fromLTRB(22,0,22,14),
              child:Row(children:[
                Flexible(child:KakaPress(onTap:selectSpace,child:Container(
                  padding:const EdgeInsets.symmetric(horizontal:14,vertical:10),
                  constraints:const BoxConstraints(maxWidth:300),
                  decoration:BoxDecoration(color:KColors.soft,
                    borderRadius:BorderRadius.circular(24)),
                  child:Row(mainAxisSize:MainAxisSize.min,children:[
                  Flexible(child:Text(widget.app.spaces.where((s)=>s.id==widget.app.api.spaceId)
                    .map((s)=>s.name).firstOrNull ?? 'Personal space',
                    maxLines:1,overflow:TextOverflow.ellipsis,
                    style:const TextStyle(fontSize:14,fontWeight:FontWeight.w600,color:KColors.ink))),
                  const SizedBox(width:5),
                  const Icon(LucideIcons.chevronDown,size:16,color:KColors.muted),
                ])))),
                const Spacer(),
                if(widget.app.busy) const SizedBox(width:14,height:14,
                  child:KakaLoadingDots()),
              ]))),
            if(searching&&tab<2) KakaContentWidth(child:Padding(padding:const EdgeInsets.fromLTRB(22,0,22,15),
              child:TextField(controller:query,onChanged:(_)=>setState((){}),
                decoration:InputDecoration(prefixIcon:const Icon(LucideIcons.search,size:18),
                  hintText:'Search agents',filled:true,fillColor:KColors.soft,
                  border:OutlineInputBorder(borderRadius:BorderRadius.circular(23),
                    borderSide:BorderSide.none))))),
            // Avoid mounting TWO potentially long chat/agent lists during
            // tab crossfades. The floating navigation pill carries the motion.
            Expanded(child:KakaTabEntrance(
              key:ValueKey<int>(tab),
              direction:direction,
              child:tab==3?_settings():
                tab==2?ActivityScreen(app:widget.app,embedded:true):
                _list(tab),
            )),
          ]),
          const Positioned(left:0,right:0,bottom:0,height:124,
            child:KakaProgressiveBlur()),
          Positioned(left:0,right:0,bottom:13,child:_bottomNav(tab)),
        ])),
      );
    });

  // Lazily builds visible rows. Previously every agent (and every avatar ticker)
  // was mounted at once through ListView(children: ...).
  Widget _list(int tab) {
    final filter = query.text.trim().toLowerCase();
    final bots = widget.app.bots.where((b) =>
        b.name.toLowerCase().contains(filter) ||
        b.preview.toLowerCase().contains(filter)).toList();
    final groups = tab == 0
        ? widget.app.groups.where((g) =>
            g.name.toLowerCase().contains(filter) ||
            g.preview.toLowerCase().contains(filter)).toList()
        : <KakaGroup>[];
    final hasError = widget.app.error != null;
    final empty = bots.isEmpty && groups.isEmpty;
    final prefix = (hasError ? 1 : 0) + (empty ? 1 : 0);
    final groupHeader = groups.isNotEmpty ? 1 : 0;
    final count = prefix + bots.length + groupHeader + groups.length;
    return KakaContentWidth(child:KakaPullToRefresh(
      onRefresh:_refreshHome,
      onComplete:_finishRefresh,
      child:ListView.builder(
      key:PageStorageKey('kaka-home-list-$tab'),
      controller:tab==1?_agentsScroll:_chatsScroll,
      addAutomaticKeepAlives: false,
      padding: const EdgeInsets.fromLTRB(KLayout.pageGutter, 0, KLayout.pageGutter, 125),
      physics:const AlwaysScrollableScrollPhysics(parent:ClampingScrollPhysics()),
      itemCount: count + (_refreshAnnouncement==null?0:1),
      itemBuilder: (context, index) {
        if (_refreshAnnouncement!=null && index==0) {
          return AnimatedContainer(
            duration:const Duration(milliseconds:530),
            curve:Curves.easeOutCubic,
            margin:const EdgeInsets.only(bottom:KLayout.listGap),
            padding:const EdgeInsets.symmetric(horizontal:20,vertical:17),
            decoration:BoxDecoration(
              color:_flashUpdate?KColors.soft:KColors.surface,
              borderRadius:BorderRadius.circular(KRadius.card)),
            child:Row(children:[
              const Icon(LucideIcons.circleCheck,size:21,color:KColors.ink),
              const SizedBox(width:12),
              Expanded(child:Text(_refreshAnnouncement!,
                style:const TextStyle(fontSize:14,fontWeight:FontWeight.w600))),
            ]),
          );
        }
        var cursor = index - (_refreshAnnouncement==null?0:1);
        if (hasError) {
          if (cursor == 0) return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 5),
            child: Text(widget.app.error!,
              style: const TextStyle(color: KColors.error, fontSize: 13)));
          cursor--;
        }
        if (empty) {
          return Padding(
            padding: const EdgeInsets.only(top: 85),
            child: Column(children: [
              const OrganicAvatar(size: 78),
              const SizedBox(height: 22),
              Text('Nothing here yet', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text('Create an agent to get started.',
                style: TextStyle(color: KColors.muted, fontSize: 14)),
            ]));
        }
        if (cursor < bots.length) return _botTile(bots[cursor], tab);
        cursor -= bots.length;
        if (groups.isNotEmpty && cursor == 0) {
          return const Padding(padding: EdgeInsets.fromLTRB(7, 18, 0, 12),
            child: Text('GROUPS',
              style: TextStyle(fontSize: 12, color: KColors.muted)));
        }
        if (groups.isNotEmpty) return _groupTile(groups[cursor - 1]);
        return const SizedBox.shrink();
      },
    )));
  }

  Future<void> _duplicate(String kind,String id) async {
    final label=kind=='bot'?'Agent':'group';
    try{
      await widget.app.api.rpc(kind=='bot'?'bots/duplicate':'groups/duplicate',{
        if(kind=='bot')'botId':id else 'groupId':id,
      });
      await widget.app.refresh();
      if(mounted)kakaNotice(context,'$label duplicated');
    }catch(e){if(mounted)kakaNotice(context,e.toString());}
  }

  Widget _botTile(KakaBot bot, int tab) => Padding(
    key: ValueKey('agent-${bot.id}'),
    padding: const EdgeInsets.only(bottom: KLayout.listGap),
    child: KakaPress(
      onTap: () => open(bot),
      onLongPress: () => kakaSheet<void>(context, Column(
        mainAxisSize: MainAxisSize.min, children: [
          Text(bot.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          KakaRow(title: 'Open chat', icon: LucideIcons.messageCircle, onTap: () {
            Navigator.pop(context); open(bot);
          }),
          KakaRow(title: 'Agent settings', icon: LucideIcons.settings2, onTap: () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute<void>(
              builder: (_) => AgentSettingsScreen(api: widget.app.api, bot: bot)))
              .then((_) => widget.app.refresh());
          }),
          KakaRow(title: 'Duplicate agent', icon: LucideIcons.copy, onTap: () {
            Navigator.pop(context);
            _duplicate('bot',bot.id);
          }),
          KakaRow(title: 'Customize avatar', icon: LucideIcons.smile, onTap: () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute<void>(
              builder: (_) => AvatarEditor(bot: bot)));
          }),
        ])),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical:15,horizontal:17),
        decoration: BoxDecoration(color: KColors.surface,
          borderRadius: BorderRadius.circular(29)),
        child: Row(children: [
          AgentAvatar(botId: bot.id, size: 51, fallbackColor: _color(bot.color),
            working: ['running', 'leased', 'queued'].contains(bot.status)),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Flexible(child: Text(bot.name, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                    color: KColors.ink))),
                if (bot.unread) Container(
                  margin: const EdgeInsets.only(left: 7),
                  width: 6, height: 6,
                  decoration: const BoxDecoration(color: KColors.ink, shape: BoxShape.circle)),
              ]),
              const SizedBox(height: 4),
              Text(tab == 1 && bot.title.isNotEmpty ? bot.title
                : bot.preview.isEmpty ? 'Start a conversation' : bot.preview,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: KColors.muted)),
            ])),
          const SizedBox(width: 8),
          const Icon(LucideIcons.chevronRight, size: 17, color: KColors.muted),
        ]),
      ),
    ));

  Widget _groupTile(KakaGroup group) => Padding(
    key: ValueKey('group-${group.id}'),
    padding: const EdgeInsets.only(bottom: KLayout.listGap),
    child: KakaPress(
      onTap: () => openGroup(group),
      onLongPress:()=>kakaSheet<void>(context,Column(
        mainAxisSize:MainAxisSize.min,children:[
          Text(group.name,style:Theme.of(context).textTheme.titleLarge),
          const SizedBox(height:13),
          KakaRow(title:'Open group',icon:LucideIcons.messageCircle,onTap:(){
            Navigator.pop(context);openGroup(group);
          }),
          KakaRow(title:'Duplicate group',icon:LucideIcons.copy,onTap:(){
            Navigator.pop(context);_duplicate('group',group.id);
          }),
        ])),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical:15,horizontal:18),
        decoration: BoxDecoration(color: KColors.surface,
          borderRadius: BorderRadius.circular(29)),
        child: Row(children: [
          const Icon(LucideIcons.users, size: 24, color: KColors.ink),
          const SizedBox(width: 14),
          Expanded(child: Text(group.name, style: const TextStyle(fontSize: 16))),
          const Icon(LucideIcons.chevronRight, size: 17, color: KColors.muted),
        ]),
      ),
    ));

  Widget _bottomNav(int tab) => Center(
    child:ConstrainedBox(
      constraints:const BoxConstraints(maxWidth:480),
      child:Padding(
        padding:const EdgeInsets.symmetric(horizontal:KLayout.pageGutter),
        child:Row(children:[
          Expanded(child:KakaLiquidNav(
            selected:tab,
            onSelected:widget.app.switchTab,
            labels:const ['Chats','Agents','Activity','Settings'],
            icons:const [
              LucideIcons.messageCircle,
              LucideIcons.bot,
              LucideIcons.activity,
              LucideIcons.settings2,
            ],
          )),
          const SizedBox(width:10),
          KakaPress(onTap:tab>=2?null:_newMenu,haptic:true,
            child:Container(width:56,height:56,
              alignment:Alignment.center,
              decoration:BoxDecoration(color:tab>=2?KColors.soft:KColors.ink,
                shape:BoxShape.circle),
              child:Icon(LucideIcons.plus,size:24,
                color:tab>=2?KColors.muted:Colors.white))),
        ]),
      ),
    ),
  );

  Widget _settings()=>KakaContentWidth(child:ListView(padding:const EdgeInsets.fromLTRB(KLayout.pageGutter,0,KLayout.pageGutter,125),children:[
    const SizedBox(height:7),
    KakaSection(title:'ACCOUNT',child:Column(children:[
      KakaRow(title:'Personal account',icon:LucideIcons.user,
        onTap:()=>Navigator.push(context,MaterialPageRoute<void>(
          builder:(_)=>AccountScreen(app:widget.app)))),
    ])),
    const SizedBox(height:20),
    KakaSection(title:'CONNECTION',child:Column(children:[
      KakaRow(title:'Server',subtitle:widget.app.api.baseUrl,
        icon:LucideIcons.server,onTap:()=>kakaNotice(context,'Sign out before changing servers')),
      KakaRow(title:'Models',icon:LucideIcons.cpu,onTap:()=>_showModels()),
      KakaRow(title:'MCP servers',icon:LucideIcons.server,
        onTap:()=>Navigator.push(context,MaterialPageRoute<void>(
          builder:(_)=>McpScreen(api:widget.app.api)))),
      KakaRow(title:'Messaging',icon:LucideIcons.messagesSquare,
        onTap:()=>Navigator.push(context,MaterialPageRoute<void>(
          builder:(_)=>MessagingScreen(app:widget.app)))),
      KakaRow(title:'Integrations',icon:LucideIcons.plug,onTap:()=>Navigator.push(context,
        MaterialPageRoute<void>(builder:(_)=>IntegrationsScreen(api:widget.app.api)))),
      KakaRow(title:'Voice',icon:LucideIcons.audioLines,onTap:()=>Navigator.push(context,
        MaterialPageRoute<void>(builder:(_)=>VoiceSettingsScreen(api:widget.app.api)))),
      KakaRow(title:'Spaces',icon:LucideIcons.layers,
        onTap:()=>Navigator.push(context,MaterialPageRoute<void>(
          builder:(_)=>SpacesScreen(app:widget.app)))),
    ])),
    const SizedBox(height:20),
    KakaSection(title:'APP',child:Column(children:[
      KakaRow(title:'Files',icon:LucideIcons.folder,
        onTap:()=>Navigator.push(context,MaterialPageRoute<void>(
          builder:(_)=>ArtifactLibraryScreen(api:widget.app.api)))),
      KakaRow(title:'Memory',icon:LucideIcons.notebookText,
        onTap:()=>Navigator.push(context,MaterialPageRoute<void>(
          builder:(_)=>MemoryScreen(api:widget.app.api)))),
      KakaRow(title:'Archive',icon:LucideIcons.archive,
        onTap:()=>Navigator.push(context,MaterialPageRoute<void>(
          builder:(_)=>ArchivedScreen(app:widget.app)))),
      KakaRow(title:'Usage',icon:LucideIcons.chartNoAxesColumn,
        onTap:()=>Navigator.push(context,MaterialPageRoute<void>(
          builder:(_)=>UsageScreen(api:widget.app.api)))),
      KakaRow(title:'Activity',icon:LucideIcons.activity,
        onTap:()=>Navigator.push(context,MaterialPageRoute<void>(
          builder:(_)=>ActivityScreen(app:widget.app)))),
      const KakaRow(title:'Appearance',subtitle:'Minimal monochrome',icon:LucideIcons.palette),
      ValueListenableBuilder<bool>(
        valueListenable:PerformancePrefs.lowPower,
        builder:(context,enabled,_)=>KakaRow(
          title:'Low power mode',
          subtitle:'Pause decorative motion and reduce media cache',
          icon:LucideIcons.battery,
          onTap:()=>PerformancePrefs.setLowPower(!enabled),
          trailing:KakaSwitch(value:enabled,
            onChanged:PerformancePrefs.setLowPower),
        ),
      ),
      const KakaRow(title:'About Kaka',subtitle:'Flutter preview 0.1',icon:LucideIcons.info),
      KakaRow(title:'Sign out',icon:LucideIcons.logOut,
        onTap:()=>widget.app.logout()),
    ])),
  ]));

  Future<void> _showModels() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ModelSettingsScreen(api:widget.app.api)));
  }

  Color _color(String raw) {
    try {
      final value=raw.replaceFirst('#','');
      if(value.length==6)return Color(int.parse('FF$value',radix:16));
    }catch(_){}
    return KColors.ink;
  }
}
