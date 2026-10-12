import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaka_flutter/app/app_controller.dart';
import 'package:kaka_flutter/core/api.dart';

class StableNavigationApi extends KakaApi {
  int listCalls=0;
  bool changed=false;
  Completer<void>? hold;
  @override
  Future<dynamic> rpc(String path,[Map<String,dynamic> input=const {}]) async {
    if(path=='me')return {'name':'Kaka tester'};
    if(path!='spaces/list')throw StateError('Unexpected $path');
    listCalls++;
    if(hold!=null)await hold!.future;
    return {
      'current':{
        'id':spaceId.isEmpty?'s1':spaceId,
        'name':'My Space',
        'bots':[
          {'id':'bot-1','name':'Assistant','title':'Helper',
           'preview':changed?'Updated preview':'Same preview',
           'color':'#161616','status':'idle','unread':false,
           'pinned':true,'updatedAt':changed?'2026-10-13':'2026-10-12'},
        ],
        'groups':[],
      },
      'spaces':[{'id':'s1','name':'My Space','bots':[],'groups':[]}],
    };
  }
  @override
  Future<void> selectSpace(String id)async{spaceId=id;}
}

void main(){
  test('unchanged navigation refresh preserves model instances and notifies nobody',
    ()async{
      final api=StableNavigationApi();
      final app=AppController(api);
      await app.refresh();
      var repaintCount=0;
      app.addListener(()=>repaintCount++);
      final before=app.bots;
      await app.refresh();
      expect(identical(app.bots,before),true);
      expect(repaintCount,0);
      expect(app.busy,false);
      api.changed=true;
      await app.refresh();
      expect(repaintCount,1);
      expect(app.bots.first.preview,'Updated preview');
      await app.refresh();
      expect(repaintCount,1);
      app.dispose();
    });

  test('parallel identical Agent refresh requests share a single API read',
    ()async{
      final api=StableNavigationApi();
      final app=AppController(api);
      final wait=Completer<void>();
      api.hold=wait;
      final first=app.refresh(),second=app.refresh();
      expect(api.listCalls,1);
      wait.complete();
      await Future.wait([first,second]);
      expect(api.listCalls,1);
      app.dispose();
    });
}
