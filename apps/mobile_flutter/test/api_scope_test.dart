import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kaka_flutter/core/api.dart';

class _TrackedRealtimeClient extends http.BaseClient {
  bool closed = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final heartbeat={'json':{
      'id':'heartbeat','type':'heartbeat','seq':0,'payload':{},
    }};
    final event={'json':{
      'id':'event-4','type':'thread.message.created','seq':4,
      'payload':{'messageId':'m-4','role':'bot',
        'blocks':[{'kind':'text','text':'Hello'}]},
    }};
    return http.StreamedResponse(Stream<List<int>>.fromIterable([
      utf8.encode('data: ${jsonEncode(heartbeat)}\n\n'),
      utf8.encode('data: ${jsonEncode(event)}\n\n'),
    ]),200);
  }
  @override
  void close(){closed=true;super.close();}
}

void main(){
  test('response from a previous session/Space cannot cross the boundary',() async {
    final pending=Completer<http.Response>();
    final client=MockClient((request) async=>pending.future);
    final api=KakaApi(client:client)
      ..baseUrl='https://server.example'
      ..token='account-a'
      ..spaceId='space-a';
    final operation=api.rpc('bots/list');
    // Token/Space may switch while the request is in flight.
    api.token='account-b';
    api.spaceId='space-b';
    pending.complete(http.Response(jsonEncode({'json':[]}),200));
    await expectLater(operation,throwsA(isA<KakaApiException>()));
    api.dispose();
  });

  test('bots reads canonical current Space envelope',() async {
    final client=MockClient((request) async=>http.Response(jsonEncode({
      'json':{
        'current':{'bots':[{
          'id':'b','name':'Scoped Agent','title':'','preview':'',
          'status':'idle','unread':false,'pinned':false,
          'updatedAt':'','color':'#161616',
        }]},
        'spaces':[],
      }
    }),200));
    final api=KakaApi(client:client)..baseUrl='https://server.example';
    final bots=await api.bots();
    expect(bots.single.name,'Scoped Agent');
    api.dispose();
  });

  test('SSE ignores heartbeat and disposes its dedicated client on cancel',() async {
    late _TrackedRealtimeClient tracked;
    final api=KakaApi(
      realtimeClientFactory:()=>tracked=_TrackedRealtimeClient())
      ..baseUrl='https://server.example'
      ..token='test-session'
      ..spaceId='space-a';
    final event=await api.events('bot-1',3).first;
    expect(event.type,'thread.message.created');
    expect(event.seq,4);
    // Stream.first cancels the async generator, triggering finally/close.
    await Future<void>.delayed(const Duration(milliseconds:40));
    expect(tracked.closed,isTrue);
    api.dispose();
  });
}
