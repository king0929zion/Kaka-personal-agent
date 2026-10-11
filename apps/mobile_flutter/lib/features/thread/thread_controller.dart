import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/api.dart';
import '../../core/models.dart';

class ThreadController extends ChangeNotifier {
  final KakaApi api;
  final String botId;
  final bool group;
  ThreadController(this.api, this.botId, {this.group = false});
  Map<String, dynamic> get target => group ? {'groupId':botId} : {'botId':botId};

  KakaThread? snapshot;
  String? error;
  bool sending = false;
  bool fetchingMore = false;
  StreamSubscription<KakaThreadEvent>? _events;
  int _epoch = 0;
  bool _disposed = false;

  List<KakaMessage> get messages => snapshot?.messages ?? const [];

  Future<void> load() async {
    final epoch = ++_epoch;
    _events?.cancel();
    error = null;
    notifyListeners();
    try {
      final next = await api.thread(botId,group:group);
      if (_disposed || epoch != _epoch) return;
      snapshot = next;
      notifyListeners();
      _listen(next.cursor, epoch);
      unawaited(api.rpc('threads/markRead', {...target}).catchError((Object _) => null));
    } catch (e) {
      if (_disposed || epoch != _epoch) return;
      error = e.toString();
      notifyListeners();
    }
  }

  void _listen(int fromCursor, int epoch) {
    _events = api.events(botId, fromCursor, group:group).listen((event) {
      if (_disposed || epoch != _epoch) return;
      apply(event);
    }, onError: (Object e) {
      if (_disposed || epoch != _epoch) return;
      error = 'Live updates disconnected: $e';
      notifyListeners();
    });
  }

  void apply(KakaThreadEvent e) {
    final old = snapshot;
    if (old == null) return;
    final seq = e.seq ?? old.cursor;
    if (e.seq != null && seq <= old.cursor) return;
    var messages = List<KakaMessage>.from(old.messages);
    var runStatus = old.runStatus;
    if (e.type == 'thread.cleared') {
      messages = [];
      runStatus = null;
    } else if (e.type == 'thread.message.created' || e.type == 'thread.message.updated') {
      final id = '${e.payload['messageId'] ?? e.id ?? 'event:$seq'}';
      final data = <String, dynamic>{...e.payload,'id':id,
        'botId':e.botId ?? e.payload['botId']};
      final message = KakaMessage.fromJson(data);
      final idx = messages.indexWhere((m) => m.id == id);
      if (idx < 0) { messages.add(message); }
      else { messages[idx] = message; }
    } else if (e.type == 'thread.progress') {
      final id = 'progress:${e.runId ?? botId}';
      final text = '${e.payload['text'] ?? e.payload['message'] ?? 'Working…'}';
      final progress = KakaMessage(
        id:id, role:'bot', botId:e.botId, runId:e.runId,
        blocks:[{'kind':'progress','text':text, 'activity':true}]);
      messages.removeWhere((m) => m.id == id);
      messages.add(progress);
      runStatus = 'running';
    } else if (e.type.startsWith('run.')) {
      runStatus = e.type.substring(4);
      if (e.type == 'run.completed' || e.type == 'run.failed' ||
          e.type == 'run.cancelled') {
        messages.removeWhere((m) => m.id == 'progress:${e.runId ?? botId}');
      }
    }
    snapshot = KakaThread(threadId:old.threadId, cursor:seq,
      olderCursor:old.olderCursor, messages:messages, runStatus:runStatus);
    notifyListeners();
  }

  Future<void> send(String text) async {
    if (text.trim().isEmpty || sending) return;
    sending = true; error = null; notifyListeners();
    try {
      await api.send(botId, text.trim(),group:group);
      // Refresh ensures optimistic/committed delivery agrees with server.
      final next = await api.thread(botId,group:group);
      if (_disposed) return;
      final existing = snapshot?.messages ?? const <KakaMessage>[];
      final combined = {for(final m in existing) m.id:m, for(final m in next.messages) m.id:m};
      snapshot = KakaThread(threadId:next.threadId,
        cursor:next.cursor, olderCursor:next.olderCursor,
        runStatus:next.runStatus, messages:combined.values.toList());
    } catch (e) {
      error = e.toString();
    } finally {
      if (!_disposed) { sending = false; notifyListeners(); }
    }
  }

  Future<void> loadOlder() async {
    final old = snapshot;
    if (old == null || old.olderCursor == null || fetchingMore) return;
    fetchingMore = true;
    notifyListeners();
    try {
      final data = await api.rpc('threads/messages', {
        ...target, 'before':old.olderCursor, 'includePeerReceipts':true,
      });
      final m = Map<String, dynamic>.from(data as Map);
      final page = (m['messages'] is List ? m['messages'] as List : const [])
        .whereType<Map>().map((r) => KakaMessage.fromJson(Map<String,dynamic>.from(r))).toList();
      if (_disposed) return;
      final merged = {for(final item in page) item.id:item, for(final item in snapshot!.messages) item.id:item};
      snapshot = KakaThread(threadId:old.threadId, cursor:snapshot!.cursor,
        olderCursor:(m['olderCursor'] as num?)?.toInt(),
        runStatus:snapshot!.runStatus,messages:merged.values.toList());
    } catch (e) {
      error = e.toString();
    } finally {
      if (!_disposed) { fetchingMore = false; notifyListeners(); }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_epoch;
    _events?.cancel();
    super.dispose();
  }
}
