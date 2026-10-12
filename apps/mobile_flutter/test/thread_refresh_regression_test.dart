import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaka_flutter/core/api.dart';
import 'package:kaka_flutter/core/models.dart';
import 'package:kaka_flutter/features/thread/thread_controller.dart';

class _FakeThreadApi extends KakaApi {
  final requests = <Completer<KakaThread>>[];
  int subscriptions = 0;

  @override
  Future<KakaThread> thread(String targetId, {bool group = false}) {
    final request = Completer<KakaThread>();
    requests.add(request);
    return request.future;
  }

  @override
  Stream<KakaThreadEvent> events(String targetId, int fromCursor,
      {bool group = false}) {
    subscriptions++;
    return const Stream<KakaThreadEvent>.empty();
  }

  @override
  Future<dynamic> rpc(String path,
      [Map<String, dynamic> input = const {}]) async => null;
}

KakaMessage _message(String id) => KakaMessage(
      id: id,
      role: 'bot',
      blocks: [
        {'kind': 'text', 'text': id},
      ],
    );

KakaThread _thread(int cursor, List<String> ids,
        {int? olderCursor, String? status}) =>
    KakaThread(
      threadId: 'thread-1',
      cursor: cursor,
      olderCursor: olderCursor,
      runStatus: status,
      messages: ids.map(_message).toList(),
    );

void main() {
  test('simultaneous refreshes share one fetch and one subscription', () async {
    final api = _FakeThreadApi();
    final controller = ThreadController(api, 'bot-1');
    var updates = 0;
    controller.addListener(() => updates++);

    final a = controller.load();
    final b = controller.load();
    expect(identical(a, b), isTrue);
    expect(api.requests.length, 1);
    api.requests.single.complete(_thread(4, ['m1']));
    await Future.wait([a, b]);
    expect(controller.snapshot?.cursor, 4);
    expect(api.subscriptions, 1);
    expect(updates, 1);
    controller.dispose();
    api.dispose();
  });

  test('no-op refresh preserves message identity and avoids list rebuilds',
      () async {
    final api = _FakeThreadApi();
    final controller = ThreadController(api, 'bot-1');
    var updates = 0;
    controller.addListener(() => updates++);
    final first = controller.load();
    api.requests[0].complete(_thread(9, ['m1', 'm2']));
    await first;
    final snapshot = controller.snapshot!;
    final message = snapshot.messages.first;
    final previousUpdates = updates;

    final second = controller.load();
    api.requests[1].complete(_thread(9, ['m1', 'm2']));
    await second;
    expect(identical(controller.snapshot, snapshot), isTrue);
    expect(identical(controller.messages.first, message), isTrue);
    expect(updates, previousUpdates);
    controller.dispose();
    api.dispose();
  });

  test('resume invalidates stale in-flight response', () async {
    final api = _FakeThreadApi();
    final controller = ThreadController(api, 'bot-1');
    final old = controller.load();
    controller.pauseRealtime();
    final fresh = controller.load();
    expect(api.requests.length, 2);

    api.requests.first.complete(_thread(1, ['stale']));
    await old;
    expect(controller.snapshot, isNull);
    api.requests.last.complete(_thread(2, ['fresh']));
    await fresh;
    expect(controller.messages.single.id, 'fresh');
    expect(api.subscriptions, 1);
    controller.dispose();
    api.dispose();
  });

  test('refresh keeps paginated history when new snapshot overlaps', () async {
    final api = _FakeThreadApi();
    final controller = ThreadController(api, 'bot-1');
    final initial = controller.load();
    api.requests.first.complete(_thread(
      12, ['old1', 'old2', 'm1', 'm2'], olderCursor: 5));
    await initial;

    final refresh = controller.load();
    api.requests.last.complete(_thread(
      13, ['m1', 'm2', 'm3'], olderCursor: 10));
    await refresh;
    expect(controller.messages.map((m) => m.id),
        ['old1', 'old2', 'm1', 'm2', 'm3']);
    expect(controller.snapshot?.olderCursor, 5);
    controller.dispose();
    api.dispose();
  });

  test('cleared timeline does not restore old messages', () async {
    final api = _FakeThreadApi();
    final controller = ThreadController(api, 'bot-1');
    final initial = controller.load();
    api.requests.first.complete(_thread(1, ['m1', 'm2']));
    await initial;
    final refresh = controller.load();
    api.requests.last.complete(_thread(2, []));
    await refresh;
    expect(controller.messages, isEmpty);
    controller.dispose();
    api.dispose();
  });

  test('HTTP response cannot rewind live event cursor', () async {
    final api = _FakeThreadApi();
    final controller = ThreadController(api, 'bot-1');
    final initial = controller.load();
    api.requests.first.complete(_thread(10, ['m1']));
    await initial;
    final refresh = controller.load();
    controller.apply(KakaThreadEvent({
      'type': 'thread.message.created',
      'seq': 12,
      'id': 'm2',
      'payload': {
        'messageId': 'm2',
        'role': 'bot',
        'blocks': [
          {'kind': 'text', 'text': 'm2'},
        ],
      },
    }));
    api.requests.last.complete(_thread(11, ['m1']));
    await refresh;
    expect(controller.snapshot?.cursor, 12);
    expect(controller.messages.map((m) => m.id), ['m1', 'm2']);
    controller.dispose();
    api.dispose();
  });
}
