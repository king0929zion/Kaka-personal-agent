import 'package:flutter_test/flutter_test.dart';
import 'package:kaka_flutter/app/app_controller.dart';
import 'package:kaka_flutter/core/api.dart';

class FakeNavigationApi extends KakaApi {
  @override
  Future<dynamic> rpc(String path, [Map<String, dynamic> input = const {}]) async {
    if(path=='me')return {'id':'user-1','name':'Zion'};
    if(path=='spaces/list')return {
      'current': {
        'id': spaceId.isEmpty ? 's1' : spaceId,
        'name': 'Selected space',
        'bots':[
          {'id':'bot-1','name':'Kaka','title':'Assistant','color':'#161616',
           'status':'idle','preview':'Hi','pinned':true,'unread':true,
           'updatedAt':'2026-10-12'}
        ],
        'groups':[
          {'id':'group-1','name':'Project','preview':'Plan',
           'unread':false},
        ],
      },
      'spaces':[
        {'id':'s1','name':'Personal','bots':[],'groups':[]},
        {'id':'s2','name':'Team','bots':[],'groups':[]},
      ],
    };
    throw ArgumentError('Unexpected rpc: $path');
  }

  @override
  Future<void> selectSpace(String id) async { spaceId=id; }
}

void main(){
  test('navigation reads current.bots/groups, not root or spaces collection',() async {
    final api=FakeNavigationApi();
    final app=AppController(api);
    await app.refresh();
    expect(app.bots.map((x)=>x.id),['bot-1']);
    expect(app.groups.map((x)=>x.id),['group-1']);
    expect(app.spaces.length,2);
    expect(api.spaceId,'s1');
    expect(app.accountName,'Zion');
    app.dispose();
  });

  test('changing spaces preserves the correct navigation scope',() async {
    final api=FakeNavigationApi();
    final app=AppController(api);
    await app.refresh();
    await app.chooseSpace('s2');
    expect(api.spaceId,'s2');
    expect(app.bots.length,1);
    app.dispose();
  });
}
