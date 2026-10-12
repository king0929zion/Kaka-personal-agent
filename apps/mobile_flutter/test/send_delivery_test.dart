import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kaka_flutter/core/api.dart';
import 'package:kaka_flutter/core/models.dart';
import 'package:kaka_flutter/features/thread/thread_controller.dart';

void main() {
  test('an accepted send is not reported as failed when snapshot refresh fails',() async {
    var sends=0;
    final client=MockClient((request) async {
      if(request.url.path=='/rpc/threads/send'){
        sends++;
        return http.Response(jsonEncode({'json':{
          'taskId':'t1','runId':'r1','seq':5,
        }}),200);
      }
      if(request.url.path=='/rpc/threads/get'){
        return http.Response(jsonEncode({'error':{'message':'Network problem'}}),503);
      }
      return http.Response(jsonEncode({'json':{'ok':true}}),200);
    });
    final api=KakaApi(client:client)..baseUrl='https://example.com';
    final thread=ThreadController(api,'agent-one');
    thread.snapshot=const KakaThread(threadId:'thread-one',cursor:1,messages:[]);
    await thread.send('Test');
    expect(sends,1);
    expect(thread.error,isNull);
    expect(thread.sending,isFalse);
    thread.dispose();
    api.dispose();
  });
}
