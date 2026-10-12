import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../../core/api.dart';
import '../../core/models.dart';

class PendingAttachment {
  final String name;
  final String mimeType;
  final Uint8List bytes;
  const PendingAttachment(this.name,this.mimeType,this.bytes);
}

class ThreadController extends ChangeNotifier {
  final KakaApi api;
  final String botId;
  final bool group;
  ThreadController(this.api, this.botId, {this.group = false});
  Map<String, dynamic> get target => group ? {'groupId':botId} : {'botId':botId};

  KakaThread? snapshot;
  String? error;
  bool sending = false;
  bool stopping = false;
  bool get canStop => ['running','started','queued','waiting_input','waiting_takeover'].contains(snapshot?.runStatus);
  bool fetchingMore = false;
  StreamSubscription<KakaThreadEvent>? _events;
  Timer? _renderDebounce;
  int _epoch = 0;
  bool _disposed = false;

  List<KakaMessage> get messages => snapshot?.messages ?? const [];

  // Coalesce high-frequency progress/token events into one repaint per 80 ms.
  void _publish({bool streaming = false}) {
    if (_disposed) return;
    if (!streaming) {
      _renderDebounce?.cancel();
      _renderDebounce = null;
      notifyListeners();
      return;
    }
    _renderDebounce ??= Timer(const Duration(milliseconds: 80), () {
      _renderDebounce = null;
      if (!_disposed) notifyListeners();
    });
  }

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

  void pauseRealtime() {
    ++_epoch; // discard events arriving after unsubscribe
    _events?.cancel();
    _events=null;
    _renderDebounce?.cancel();
    _renderDebounce=null;
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
    final isContentEvent = e.type == 'thread.cleared' ||
        e.type == 'thread.message.created' ||
        e.type == 'thread.message.updated' ||
        e.type == 'thread.progress' ||
        e.type == 'agent.tool.called' ||
        e.type == 'run.waiting_input' ||
        e.type == 'computer.takeover.requested' ||
        e.type.startsWith('run.');
    if (!isContentEvent) {
      if (seq != old.cursor) {
        snapshot = KakaThread(threadId: old.threadId, cursor: seq,
          olderCursor: old.olderCursor, runStatus: old.runStatus,
          messages: old.messages);
      }
      return;
    }
    var messages = List<KakaMessage>.from(old.messages);
    var olderCursor = old.olderCursor;
    var runStatus = old.runStatus;
    if (e.type == 'thread.cleared') {
      messages = [];
      olderCursor = null;
      runStatus = null;
    } else if (e.type == 'thread.message.created' || e.type == 'thread.message.updated') {
      final id = '${e.payload['messageId'] ?? e.id ?? 'event:$seq'}';
      messages.removeWhere((m)=>m.id == 'progress:${e.runId ?? botId}');
      final existing = messages.where((m) => m.id == id).firstOrNull;
      final data = <String, dynamic>{
        ...e.payload,
        'id': id,
        // Updates can be partial, e.g. to close a voice-call card.
        if (e.payload['blocks'] == null && existing != null) 'blocks': existing.blocks,
        if (e.payload['role'] == null && existing != null) 'role':existing.role,
        if (e.payload['replyQuote'] == null && existing != null &&
            existing.replyQuote != null) 'replyQuote':existing.replyQuote,
        if (e.payload['replyToMessageId'] == null && existing != null &&
            existing.replyToMessageId != null)
          'replyToMessageId':existing.replyToMessageId,
        'runId':e.runId ?? e.payload['runId'] ?? existing?.runId,
        'botId':e.botId ?? e.payload['botId'] ?? existing?.botId,
      };
      final message = KakaMessage.fromJson(data);
      final idx = messages.indexWhere((m) => m.id == id);
      if (idx < 0) { messages.add(message); }
      else { messages[idx] = message; }
    } else if(e.type == 'run.waiting_input' || e.type == 'computer.takeover.requested') {
      runStatus=e.type=='run.waiting_input'?'waiting_input':'waiting_takeover';
      messages.removeWhere((m)=>m.id == 'progress:${e.runId ?? botId}');
    } else if (e.type == 'thread.progress' || e.type == 'agent.tool.called') {
      final id = 'progress:${e.runId ?? botId}';
      final text=e.type=='agent.tool.called'
          ? '${e.payload['name'] ?? 'Using a tool'}'
          : '${e.payload['text'] ?? e.payload['message'] ?? 'Working…'}';
      final progress = KakaMessage(
        id:id, role:'bot', botId:e.botId, runId:e.runId,
        blocks:[{'kind':'progress','text':text, 'activity':true}]);
      messages.removeWhere((m) => m.id == id);
      messages.add(progress);
      runStatus = 'running';
    } else if (e.type.startsWith('run.')) {
      runStatus = e.type == 'run.started' ? 'running' : e.type.substring(4);
      if (e.type == 'run.completed' || e.type == 'run.failed' ||
          e.type == 'run.cancelled') {
        messages.removeWhere((m) => m.id == 'progress:${e.runId ?? botId}');
      }
    }
    snapshot = KakaThread(threadId:old.threadId, cursor:seq,
      olderCursor:olderCursor, messages:messages, runStatus:runStatus);
    _publish(streaming: e.type == 'thread.progress' ||
      e.type == 'agent.tool.called' ||
      e.type == 'thread.message.updated');
  }

  Future<void> send(String text, {
    List<PendingAttachment> attachments = const [],
    String? replyToMessageId, String? replyQuote,
  }) async {
    if ((text.trim().isEmpty && attachments.isEmpty) || sending) return;
    sending = true; error = null; notifyListeners();
    final uploaded=<String>[];
    var delivered=false;
    try {
      for(final item in attachments) {
        uploaded.add(await api.createArtifact(botId,group:group,
          name:item.name,mimeType:item.mimeType,bytes:item.bytes));
      }
      await api.send(botId, text.trim(),group:group,artifactIds:uploaded,
        replyToMessageId:replyToMessageId,replyQuote:replyQuote);
      delivered=true;
      // The server has accepted the message. A subsequent snapshot failure
      // must not restore the composer and make users resend a duplicate.
      try {
        final next = await api.thread(botId,group:group);
        if (_disposed) return;
        final existing = snapshot?.messages ?? const <KakaMessage>[];
        final current=snapshot;
        // Never rewind a cursor (or reinsert cleared history) when an HTTP
        // response races with newer SSE updates.
        if (current != null && next.threadId != current.threadId) {
          snapshot=next;
        } else if (current != null && next.cursor < current.cursor) {
          final combined = {
            for (final m in next.messages) m.id:m,
            for (final m in existing) m.id:m,
          };
          snapshot=KakaThread(threadId:current.threadId,
            cursor:current.cursor,olderCursor:current.olderCursor,
            runStatus:current.runStatus,messages:combined.values.toList());
        } else {
          final combined = {
            for (final m in existing) m.id:m,
            for (final m in next.messages) m.id:m,
          };
          snapshot=KakaThread(threadId:next.threadId,
            cursor:next.cursor,olderCursor:next.olderCursor,
            runStatus:next.runStatus,messages:combined.values.toList());
        }
      } catch (_) {
        // Live SSE will converge to the accepted server state.
      }
    } catch (e) {
      error = e.toString();
      // Never delete artifacts after the server has accepted the message.
      if(!delivered) for(final id in uploaded) {
        unawaited(api.rpc('artifacts/remove', {'artifactId':id}).catchError((Object _) => null));
      }
    } finally {
      if (!_disposed) { sending = false; notifyListeners(); }
    }
  }

  Future<void> stop() async {
    if(stopping || !canStop)return;
    stopping=true; notifyListeners();
    try {
      await api.rpc('threads/stop',target);
      await load();
    }catch(e){
      error=e.toString();
    }finally{
      if(!_disposed){stopping=false;notifyListeners();}
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
      if (_disposed || snapshot?.threadId != old.threadId ||
          snapshot?.olderCursor != old.olderCursor) return;
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
    _renderDebounce?.cancel();
    super.dispose();
  }
}
