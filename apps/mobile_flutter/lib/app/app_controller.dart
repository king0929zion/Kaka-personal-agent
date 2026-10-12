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

  Future<void> refresh() async {
    final epoch = ++_epoch;
    busy = true;
    error = null;
    notifyListeners();
    try {
      // The canonical spaces/list response is the shared navigation envelope.
      final navigation = await api.rpc('spaces/list');
      final me = await api.rpc('me');
      if (epoch != _epoch) return;
      final nav = Map<String, dynamic>.from(navigation as Map);
      final profile = Map<String, dynamic>.from(me as Map);
      accountName = '${profile['name'] ?? ''}';
      spaces = (nav['spaces'] is List ? nav['spaces'] as List : const [])
        .whereType<Map>().map((m) => KakaSpace.fromJson(Map<String, dynamic>.from(m))).toList();
      var spaceId = api.spaceId;
      final available = spaces.any((s) => s.id == spaceId);
      if (!available) {
        spaceId = '${profile['spaceId'] ?? ''}';
        if (!spaces.any((s) => s.id == spaceId) && spaces.isNotEmpty) spaceId = spaces.first.id;
        if (spaceId.isNotEmpty) await api.selectSpace(spaceId);
      }
      // Use the current Space's authoritative lists when available.
      final selected = spaces.where((s) => s.id == spaceId).firstOrNull;
      final raw = nav['spaces'] is List ? (nav['spaces'] as List).whereType<Map>()
        .where((s) => '${s['id']}' == selected?.id).firstOrNull : null;
      final entries = raw ?? nav;
      bots = (entries['bots'] is List ? entries['bots'] as List : const [])
        .whereType<Map>().map((m) => KakaBot.fromJson(Map<String, dynamic>.from(m))).toList();
      groups = (entries['groups'] is List ? entries['groups'] as List : const [])
        .whereType<Map>().map((m) => KakaGroup.fromJson(Map<String, dynamic>.from(m))).toList();
      bots.sort((a,b) => a.pinned != b.pinned
        ? (a.pinned ? -1 : 1) : b.updatedAt.compareTo(a.updatedAt));
    } on KakaApiException catch (e) {
      if (e.status == 401) {
        state = StartupState.login;
        await api.signOut();
      }
      error = e.message;
    } catch (e) {
      error = e.toString();
    } finally {
      if (epoch == _epoch) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> chooseSpace(String id) async {
    ++_epoch;
    await api.selectSpace(id);
    bots = []; groups = [];
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
