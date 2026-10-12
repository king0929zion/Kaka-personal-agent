import 'package:flutter/foundation.dart';
import '../core/api.dart';
import '../core/models.dart';

enum StartupState { starting, server, login, ready }

class AppController extends ChangeNotifier {
  final KakaApi api;
  AppController(this.api);

  StartupState state = StartupState.starting;
  List<KakaBot> bots = [];
  List<KakaGroup> groups = [];
  List<KakaSpace> spaces = [];
  String accountName = '';
  String? error;
  bool busy = false;
  int tab = 0;
  int _epoch = 0;
  Future<void>? _activeRefresh;
  String? _refreshSpace;

  Future<void> initialize() async {
    try {
      await api.restore();
      if (api.baseUrl.isEmpty) {
        state = StartupState.server;
      } else if (api.token.isEmpty) {
        state = StartupState.login;
      } else {
        state = StartupState.ready;
        notifyListeners();
        await refresh();
      }
    } catch (e) {
      error = e.toString();
      state = StartupState.server;
    }
    notifyListeners();
  }

  Future<void> connect(String url) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      await api.changeServer(url);
      state = StartupState.login;
    } catch (e) {
      error = e.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      await api.signIn(email, password);
      state = StartupState.ready;
      await refresh();
    } catch (e) {
      error = e.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Keep identical refreshes from flashing/spawning a new home tree.
  /// Concurrent requests for the same Space share one operation; switching
  /// Spaces always supersedes an older response.
  Future<void> refresh() {
    if (_activeRefresh != null && _refreshSpace == api.spaceId) {
      return _activeRefresh!;
    }
    final scope=api.spaceId;
    _refreshSpace=scope;
    final work=_performRefresh();
    _activeRefresh=work;
    work.whenComplete((){
      if(identical(_activeRefresh,work)){
        _activeRefresh=null;
        _refreshSpace=null;
      }
    });
    return work;
  }

  static bool _sameBots(List<KakaBot> a,List<KakaBot> b){
    if(a.length!=b.length)return false;
    for(var i=0;i<a.length;i++){
      final x=a[i],y=b[i];
      if(x.id!=y.id || x.name!=y.name || x.title!=y.title ||
        x.preview!=y.preview || x.color!=y.color || x.status!=y.status ||
        x.unread!=y.unread || x.pinned!=y.pinned ||
        x.updatedAt!=y.updatedAt || x.threadId!=y.threadId)return false;
    }
    return true;
  }
  static bool _sameGroups(List<KakaGroup> a,List<KakaGroup> b){
    if(a.length!=b.length)return false;
    for(var i=0;i<a.length;i++){
      if(a[i].id!=b[i].id || a[i].name!=b[i].name ||
          a[i].preview!=b[i].preview || a[i].unread!=b[i].unread)return false;
    }
    return true;
  }
  static bool _sameSpaces(List<KakaSpace> a,List<KakaSpace> b){
    if(a.length!=b.length)return false;
    for(var i=0;i<a.length;i++){
      if(a[i].id!=b[i].id || a[i].name!=b[i].name)return false;
    }
    return true;
  }
  Future<void> _performRefresh() async {
    final epoch=++_epoch;
    try {
      // The RPC contract is {current: {id,name,bots,groups,...},
      // spaces: Space[]}. Never look for bots at the root or on current's
      // sibling `spaces`: that silently produces an empty home screen.
      final results = await Future.wait<dynamic>([
        api.rpc('spaces/list'),
        api.rpc('me'),
      ]);
      if (epoch != _epoch) return;
      var navigation = Map<String, dynamic>.from(results[0] as Map);
      final profile = Map<String, dynamic>.from(results[1] as Map);
      final nextName = '${profile['name'] ?? ''}';
      final nextSpaces = (navigation['spaces'] is List ? navigation['spaces'] as List : const [])
        .whereType<Map>()
        .map((m) => KakaSpace.fromJson(Map<String, dynamic>.from(m))).toList();
      final serverCurrent = navigation['current'];
      if (serverCurrent is! Map) {
        throw const KakaApiException('Server sent invalid Space navigation');
      }
      var current = Map<String, dynamic>.from(serverCurrent);
      final existingId = api.spaceId;
      final currentId = current['id']?.toString() ?? '';
      if (existingId.isNotEmpty && existingId != currentId) {
        if (nextSpaces.any((space) => space.id == existingId)) {
          // Some older servers ignore the Space header on navigation requests;
          // use the matching Space entry instead of showing another Space.
          final matching = (navigation['spaces'] as List).whereType<Map>()
            .where((entry) => entry['id']?.toString() == existingId).firstOrNull;
          if (matching != null) current = Map<String, dynamic>.from(matching);
        } else {
          await api.selectSpace(currentId);
        }
      } else if (existingId.isEmpty && currentId.isNotEmpty) {
        await api.selectSpace(currentId);
      }
      if (epoch != _epoch) return;
      final selectedId = api.spaceId;
      if (selectedId.isNotEmpty && current['id']?.toString() != selectedId) {
        throw const KakaApiException('Space navigation could not be verified');
      }
      final nextBots = (current['bots'] is List ? current['bots'] as List : const [])
        .whereType<Map>()
        .map((m) => KakaBot.fromJson(Map<String, dynamic>.from(m))).toList();
      final nextGroups = (current['groups'] is List ? current['groups'] as List : const [])
        .whereType<Map>()
        .map((m) => KakaGroup.fromJson(Map<String, dynamic>.from(m))).toList();
      nextBots.sort((a,b)=>a.pinned!=b.pinned
        ? (a.pinned?-1:1):b.updatedAt.compareTo(a.updatedAt));
      final changed=nextName!=accountName ||
          !_sameSpaces(spaces,nextSpaces) ||
          !_sameBots(bots,nextBots) ||
          !_sameGroups(groups,nextGroups) || error!=null;
      accountName=nextName;
      if(!_sameSpaces(spaces,nextSpaces))spaces=nextSpaces;
      if(!_sameBots(bots,nextBots))bots=nextBots;
      if(!_sameGroups(groups,nextGroups))groups=nextGroups;
      error=null;
      if(changed)notifyListeners();
    } on KakaApiException catch (e) {
      if (e.status == 401) {
        state = StartupState.login;
        await api.signOut();
      }
      if(epoch==_epoch && error!=e.message){
        error=e.message;
        notifyListeners();
      }
    } catch (e) {
      if(epoch==_epoch && error!=e.toString()){
        error=e.toString();
        notifyListeners();
      }
    }
  }

  Future<void> chooseSpace(String id) async {
    ++_epoch;
    _activeRefresh=null;
    _refreshSpace=null;
    await api.selectSpace(id);
    bots=[];groups=[];
    notifyListeners();
    await refresh();
  }

  Future<KakaBot?> createBot(String name, String title, String description) async {
    busy = true; notifyListeners();
    try {
      final data = await api.rpc('bots/create', {
        'name':name.trim(), 'title':title.trim(), 'description':description.trim(),
        'computerMode':'team', 'notifyOnFinish':true,
      });
      final bot = KakaBot.fromJson(Map<String, dynamic>.from(data as Map));
      await refresh();
      return bot;
    } catch (e) {
      error = e.toString(); notifyListeners(); return null;
    } finally {
      busy = false; notifyListeners();
    }
  }

  void showServerSelection() {
    state = StartupState.server;
    error = null;
    notifyListeners();
  }

  Future<KakaGroup?> createGroup(String name, List<String> botIds) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      final data = await api.rpc('groups/create', {
        'name': name.trim(), 'botIds': botIds,
      });
      final group = KakaGroup.fromJson(Map<String, dynamic>.from(data as Map));
      await refresh();
      return group;
    } catch(e) {
      error = e.toString();
      notifyListeners();
      return null;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    ++_epoch;
    _activeRefresh=null;
    _refreshSpace=null;
    await api.signOut();
    bots = []; groups = []; spaces = [];
    state = StartupState.login;
    notifyListeners();
  }

  void switchTab(int value) {
    if (tab == value) return;
    tab = value;
    notifyListeners();
  }

  @override
  void dispose() { api.dispose(); super.dispose(); }
}
