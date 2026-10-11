import 'package:flutter_test/flutter_test.dart';
import 'package:kaka_flutter/core/api.dart';
import 'package:kaka_flutter/core/models.dart';
import 'package:kaka_flutter/features/thread/thread_controller.dart';

void main() {
  test('does not duplicate a replayed message event', () {
    final c = ThreadController(KakaApi(), 'bot-1');
    c.snapshot = const KakaThread(threadId: 'thread-1', cursor: 2, messages: []);
    c.apply(KakaThreadEvent({
      'type': 'thread.message.created', 'seq': 3, 'id': 'evt-3',
      'payload': {'messageId': 'msg-1', 'role': 'bot',
        'blocks': [{'kind':'text','text':'Hello'}]},
    }));
    expect(c.snapshot!.messages.length, 1);
    expect(c.snapshot!.messages.first.text, 'Hello');
    c.apply(KakaThreadEvent({
      'type': 'thread.message.created', 'seq': 3,
      'payload': {'messageId': 'msg-1','role':'bot',
        'blocks':[{'kind':'text','text':'Duplicate'}]},
    }));
    expect(c.snapshot!.messages.length, 1);
    expect(c.snapshot!.messages.first.text, 'Hello');
    c.dispose();
  });

  test('updates an existing message and clears the thread', () {
    final c = ThreadController(KakaApi(), 'bot-1');
    c.snapshot = KakaThread(threadId: 'thread-1', cursor: 1,
      messages:[KakaMessage.fromJson({
        'id':'m', 'role':'bot', 'blocks':[{'kind':'text','text':'Old'}]})]);
    c.apply(KakaThreadEvent({
      'type':'thread.message.updated', 'seq':2,
      'payload':{'messageId':'m','role':'bot',
        'blocks':[{'kind':'text','text':'New'}]},
    }));
    expect(c.snapshot!.messages.single.text, 'New');
    c.apply(KakaThreadEvent({'type':'thread.cleared', 'seq':3}));
    expect(c.snapshot!.messages,isEmpty);
    c.dispose();
  });

  test('groups use the group id in the API request target', () {
    final controller = ThreadController(KakaApi(), 'group-1', group:true);
    expect(controller.target, {'groupId':'group-1'});
    controller.dispose();
  });
}
