import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../app/app_controller.dart';
import '../../core/models.dart';
import '../../design/theme.dart';
import '../../design/widgets.dart';
import '../avatar/organic_avatar.dart';
import '../avatar/avatar_settings.dart';
import '../avatar/avatar_editor.dart';
import '../thread/thread_screen.dart';
import '../models/model_settings_screen.dart';
import '../agents/agent_settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppController app;
  const HomeScreen({super.key, required this.app});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final query = TextEditingController();
  bool searching = false;
  @override
  void dispose() { query.dispose(); super.dispose(); }

  void open(KakaBot bot) => Navigator.of(context).push(
    PageRouteBuilder<void>(
      pageBuilder: (context,a,b) => ThreadScreen(api: widget.app.api, bot:bot),
      transitionsBuilder: (context,a,b,child) => FadeTransition(
        opacity: CurvedAnimation(parent:a,curve:Curves.easeOut),child:child),
      transitionDuration: const Duration(milliseconds: 250),
    ),
  ).then((_) => widget.app.refresh());

  void openGroup(KakaGroup group) {
    final presentation = KakaBot(id:group.id,name:group.name,title:'Group chat',
      preview:group.preview,color:'#181818',status:'',unread:group.unread,
      pinned:false,updatedAt:'');
    Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>
      ThreadScreen(api:widget.app.api,bot:presentation,group:true)))
      .then((_){widget.app.refresh();});
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
      final tab=widget.app.tab;
      return Scaffold(
        backgroundColor:KColors.bg,
        body:SafeArea(child:Stack(children:[
          Column(children:[
            Padding(padding:const EdgeInsets.fromLTRB(22,24,22,15),child:Row(
              mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
                Text(['Chats','Agents','Settings'][tab],
                  style:Theme.of(context).textTheme.headlineLarge),
                Row(children:[
                  if(tab!=2) KakaIconButton(icon:LucideIcons.search,onTap:(){
                    setState(()=>searching=!searching);
                    if(!searching)query.clear();
                  }),
                  const SizedBox(width:8),
                  if(tab!=2) KakaIconButton(icon:LucideIcons.refreshCw,onTap:widget.app.refresh),
                ]),
              ])),
            if(tab!=2) Padding(padding:const EdgeInsets.fromLTRB(22,0,22,14),
              child:Row(children:[
                GestureDetector(onTap:selectSpace,child:Row(children:[
                  Text(widget.app.spaces.where((s)=>s.id==widget.app.api.spaceId)
                    .map((s)=>s.name).firstOrNull ?? 'Personal space',
                    style:const TextStyle(fontSize:14,fontWeight:FontWeight.w600,color:KColors.ink)),
                  const SizedBox(width:5),
                  const Icon(LucideIcons.chevronDown,size:16,color:KColors.muted),
                ])),
                const Spacer(),
                if(widget.app.busy) const SizedBox(width:14,height:14,
                  child:CircularProgressIndicator(strokeWidth:1.6,color:KColors.ink)),
              ])),
            if(searching&&tab!=2) Padding(padding:const EdgeInsets.fromLTRB(22,0,22,15),
              child:TextField(controller:query,onChanged:(_)=>setState((){}),
                decoration:InputDecoration(prefixIcon:const Icon(LucideIcons.search,size:18),
                  hintText:'Search agents',filled:true,fillColor:KColors.soft,
                  border:OutlineInputBorder(borderRadius:BorderRadius.circular(23),
                    borderSide:BorderSide.none)))),
            Expanded(child:tab==2?_settings():_list(tab)),
          ]),
          Positioned(left:0,right:0,bottom:14,child:_bottomNav(tab)),
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
    return ListView.builder(
      cacheExtent: 120,
      addAutomaticKeepAlives: false,
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 125),
      itemCount: count,
      itemBuilder: (context, index) {
        var cursor = index;
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
    );
  }

  Widget _botTile(KakaBot bot, int tab) => Padding(
    key: ValueKey('agent-${bot.id}'),
    padding: const EdgeInsets.only(bottom: 9),
    child: GestureDetector(
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
          KakaRow(title: 'Customize avatar', icon: LucideIcons.smile, onTap: () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute<void>(
              builder: (_) => AvatarEditor(bot: bot)));
          }),
        ])),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: KColors.surface,
          borderRadius: BorderRadius.circular(25)),
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
    padding: const EdgeInsets.only(bottom: 9),
    child: GestureDetector(
      onTap: () => openGroup(group),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: KColors.surface,
          borderRadius: BorderRadius.circular(25)),
        child: Row(children: [
          const Icon(LucideIcons.users, size: 24, color: KColors.ink),
          const SizedBox(width: 14),
          Expanded(child: Text(group.name, style: const TextStyle(fontSize: 16))),
          const Icon(LucideIcons.chevronRight, size: 17, color: KColors.muted),
        ]),
      ),
    ));

  Widget _bottomNav(int tab) => Padding(
    padding:const EdgeInsets.symmetric(horizontal:22),
    child:Row(children:[
      Expanded(child:Align(alignment:Alignment.centerLeft,child:Container(
        height:66,padding:const EdgeInsets.all(7),
        decoration:BoxDecoration(color:KColors.surface,
          border:Border.all(color:KColors.line,width:.7),
          borderRadius:BorderRadius.circular(38)),
        child:Row(mainAxisSize:MainAxisSize.min,children:[
          _navButton(0,LucideIcons.messageCircle,tab),
          _navButton(1,LucideIcons.bot,tab),
          _navButton(2,LucideIcons.settings2,tab),
        ])))),
      const SizedBox(width:14),
      KakaIconButton(icon:LucideIcons.plus,size:64,filled:true,
        onTap: tab==2?null:createBot),
    ]),
  );
  Widget _navButton(int index,IconData icon,int current) =>
    GestureDetector(onTap:()=>widget.app.switchTab(index),
      child:AnimatedContainer(duration:const Duration(milliseconds:210),
        width:52,height:52,
        decoration:BoxDecoration(color:index==current?KColors.ink:Colors.transparent,
          borderRadius:BorderRadius.circular(30)),
        child:Icon(icon,size:22,color:index==current?Colors.white:KColors.muted)));

  Widget _settings()=>ListView(padding:const EdgeInsets.fromLTRB(21,0,21,125),children:[
    const SizedBox(height:7),
    const KakaSection(title:'ACCOUNT',child:Column(children:[
      KakaRow(title:'Personal workspace',icon:LucideIcons.user),
    ])),
    const SizedBox(height:20),
    KakaSection(title:'CONNECTION',child:Column(children:[
      KakaRow(title:'Server',subtitle:widget.app.api.baseUrl,
        icon:LucideIcons.server,onTap:()=>kakaNotice(context,'Sign out before changing servers')),
      KakaRow(title:'Models',icon:LucideIcons.cpu,onTap:()=>_showModels()),
      KakaRow(title:'Spaces',icon:LucideIcons.layers,onTap:selectSpace),
    ])),
    const SizedBox(height:20),
    KakaSection(title:'APP',child:Column(children:[
      const KakaRow(title:'Appearance',subtitle:'Minimal monochrome',icon:LucideIcons.palette),
      const KakaRow(title:'About Kaka',subtitle:'Flutter preview 0.1',icon:LucideIcons.info),
      KakaRow(title:'Sign out',icon:LucideIcons.logOut,
        onTap:()=>widget.app.logout()),
    ])),
  ]);

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
