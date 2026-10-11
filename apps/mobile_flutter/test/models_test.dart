import 'package:flutter_test/flutter_test.dart';
import 'package:kaka_flutter/core/api.dart';
import 'package:kaka_flutter/core/models.dart';

void main() {
  test('normalizes a secure public endpoint', () {
    expect(KakaApi.normalizeEndpoint('example.com/'), 'https://example.com');
  });
  test('does not send credentials or insecure public HTTP', () {
    expect(() => KakaApi.normalizeEndpoint('http://example.com'),
      throwsA(isA<KakaApiException>()));
    expect(() => KakaApi.normalizeEndpoint('https://u:p@example.com'),
      throwsA(isA<KakaApiException>()));
  });
  test('allows local development HTTP', () {
    expect(KakaApi.normalizeEndpoint('http://192.168.1.2:5173'),
      'http://192.168.1.2:5173');
  });
  test('retains unknown message kinds for future renderer versions', () {
    final msg=KakaMessage.fromJson({
      'id':'1','role':'bot',
      'blocks':[{'kind':'future_tool','custom':{'value':7}}],
    });
    expect(msg.blocks.single['kind'], 'future_tool');
  });
  test('decodes a thread with its replay cursor', () {
    final thread=KakaThread.fromJson({
      'threadId':'thread-1', 'cursor': 42, 'olderCursor':10,
      'messages':[{'id':'msg1','role':'user','blocks':[{'kind':'text','text':'Hi'}]}],
    });
    expect(thread.cursor,42);
    expect(thread.messages.single.text,'Hi');
  });
}
