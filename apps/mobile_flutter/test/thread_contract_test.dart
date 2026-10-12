import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kaka_flutter/core/api.dart';
import 'package:kaka_flutter/core/models.dart';
import 'package:kaka_flutter/features/thread/thread_controller.dart';

void main(){
  test('thread send carries a structured reply and isolated Space header',() async {
    final sent=<Map<String,dynamic>>[];
    final client=MockClient((request) async {
      sent.add({
        'url':request.url.path,
        'space':request.headers['x-rakazo-space-id'],
        'authorization':request.headers['authorization'],
        'body':jsonDecode(request.body),
      });
      return http.Response(jsonEncode({'json':{'ok':true}}),200,
        headers:{'content-type':'application/json'});
    });
    final api=KakaApi(client:client);
    api.baseUrl='https://example.com';
    api.token='session-test';
    api.spaceId='space-2';
    await api.send('agent-1','Reply',replyToMessageId:'message-1',
      replyQuote:'Original text');
    expect(sent.single['space'],'space-2');
    expect(sent.single['authorization'],'Bearer session-test');
    final body=sent.single['body'] as Map;
    expect(body['json']['replyToMessageId'],'message-1');
    expect(body['json']['replyQuote'],'Original text');
    api.dispose();
  });

  test('runtime wait state clears progress and enables stop control',() {
    final controller=ThreadController(KakaApi(),'bot-1');
    controller.snapshot=const KakaThread(threadId:'thread-1',cursor:1,messages:[]);
    controller.apply(KakaThreadEvent({
      'type':'run.started','seq':2,'runId':'run-1','payload':{},
    }));
    expect(controller.canStop,isTrue);
    controller.apply(KakaThreadEvent({
      'type':'thread.progress','seq':3,'runId':'run-1',
      'payload':{'text':'Searching'},
    }));
    expect(controller.messages.length,1);
    controller.apply(KakaThreadEvent({
      'type':'run.waiting_input','seq':4,'runId':'run-1','payload':{},
    }));
    expect(controller.snapshot!.runStatus,'waiting_input');
    expect(controller.messages,isEmpty);
    controller.dispose();
  });

  test('message reply metadata survives decoding',(){
    final msg=KakaMessage.fromJson({
      'id':'m2','role':'bot','replyToMessageId':'m1',
      'replyQuote':'Quoted message','blocks':[{'kind':'text','text':'Result'}],
    });
    expect(msg.replyToMessageId,'m1');
    expect(msg.replyQuote,'Quoted message');
  });
}
