import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kaka_flutter/core/api.dart';
import 'package:kaka_flutter/core/models.dart';
import 'package:kaka_flutter/features/thread/thread_controller.dart';

void main(){
  test('thread cleared event resets pagination cursor and messages',(){
    final controller=ThreadController(KakaApi(),'bot-1');
    controller.snapshot=const KakaThread(threadId:'t-1',cursor:7,
      olderCursor:3,messages:[
        KakaMessage(id:'m-1',role:'bot',
          blocks:[{'kind':'text','text':'old'}]),
      ]);
    controller.apply(KakaThreadEvent({
      'id':'evt-8','type':'thread.cleared','seq':8,
      'payload':<String,dynamic>{},
    }));
    expect(controller.snapshot!.olderCursor,isNull);
    expect(controller.messages,isEmpty);
    controller.dispose();
  });

  test('partial message updates do not delete blocks or reply metadata',(){
    final controller=ThreadController(KakaApi(),'bot-1');
    controller.snapshot=const KakaThread(threadId:'t-1',cursor:1,messages:[
      KakaMessage(id:'m-1',role:'bot',runId:'r-1',
        replyQuote:'previous reply',replyToMessageId:'m-0',
        blocks:[{'kind':'text','text':'original'}]),
    ]);
    controller.apply(KakaThreadEvent({
      'id':'evt-2','type':'thread.message.updated','seq':2,
      'runId':'r-1','payload':{'messageId':'m-1','callId':'call-ended'},
    }));
    expect(controller.messages.single.text,'original');
    expect(controller.messages.single.replyQuote,'previous reply');
    expect(controller.messages.single.replyToMessageId,'m-0');
    expect(controller.messages.single.runId,'r-1');
    controller.dispose();
  });

  test('stale post-send snapshot cannot rewind a newer SSE cursor',() async {
    final delayed=Completer<http.Response>();
    final began=Completer<void>();
    final client=MockClient((request) async {
      if(request.url.path=='/rpc/threads/send'){
        return http.Response(jsonEncode({'json':{
          'taskId':'task-1','runId':'run-1','seq':6,
        }}),200);
      }
      if(request.url.path=='/rpc/threads/get'){
        began.complete();
        return delayed.future;
      }
      return http.Response(jsonEncode({'json':{'ok':true}}),200);
    });
    final api=KakaApi(client:client)..baseUrl='https://example.com';
    final controller=ThreadController(api,'bot-1')
      ..snapshot=const KakaThread(threadId:'t-1',cursor:5,messages:[]);
    final sending=controller.send('hello');
    await began.future;
    controller.apply(KakaThreadEvent({
      'id':'evt-9','type':'thread.message.created','seq':9,
      'payload':{'messageId':'m-9','role':'bot',
        'blocks':[{'kind':'text','text':'newer reply'}]},
    }));
    delayed.complete(http.Response(jsonEncode({'json':{
      'threadId':'t-1','cursor':6,'olderCursor':null,
      'run':null,'messages':[{
        'id':'m-6','role':'user','blocks':[{'kind':'text','text':'hello'}],
      }],
    }}),200));
    await sending;
    expect(controller.snapshot!.cursor,9);
    expect(controller.messages.map((m)=>m.id),containsAll(['m-6','m-9']));
    expect(controller.error,isNull);
    controller.dispose();
    api.dispose();
  });
}
