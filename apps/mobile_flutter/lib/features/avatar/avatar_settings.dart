import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../design/theme.dart';
import 'organic_avatar.dart';

class AvatarProfile {
  final int shape, expression, color, stateIndex;
  const AvatarProfile({this.shape=0,this.expression=0,this.color=-1,this.stateIndex=0});
  AvatarProfile copyWith({int? shape,int? expression,int? color,int? stateIndex}) =>
    AvatarProfile(shape:shape??this.shape,expression:expression??this.expression,
      color:color??this.color,stateIndex:stateIndex??this.stateIndex);
}
class AvatarRepository {
  static const _store=FlutterSecureStorage();
  static final changed=ValueNotifier<int>(0);
  static final _cache=<String,AvatarProfile>{};
  static final _loading=<String,Future<AvatarProfile>>{};

  static AvatarProfile? cached(String botId)=>_cache[botId];
  static Future<AvatarProfile> load(String botId) {
    if(_cache.containsKey(botId))return Future.value(_cache[botId]!);
    return _loading.putIfAbsent(botId,() async {
      try {
        final entries=await Future.wait([
          _store.read(key:'kaka.avatar.$botId.shape'),
          _store.read(key:'kaka.avatar.$botId.expression'),
          _store.read(key:'kaka.avatar.$botId.color'),
          _store.read(key:'kaka.avatar.$botId.state'),
        ]);
        final result=AvatarProfile(
          shape:int.tryParse(entries[0]??'')??0,
          expression:int.tryParse(entries[1]??'')??0,
          color:int.tryParse(entries[2]??'')??-1,
          stateIndex:int.tryParse(entries[3]??'')??0);
        _cache[botId]=result;
        changed.value++;
        return result;
      }catch(_){
        const result=AvatarProfile();
        _cache[botId]=result;
        changed.value++;
        return result;
      }finally{
        _loading.remove(botId);
      }
    });
  }
  static Future<void> save(String botId,AvatarProfile profile) async {
    await Future.wait([
      _store.write(key:'kaka.avatar.$botId.shape',value:'${profile.shape}'),
      _store.write(key:'kaka.avatar.$botId.expression',value:'${profile.expression}'),
      _store.write(key:'kaka.avatar.$botId.color',value:'${profile.color}'),
      _store.write(key:'kaka.avatar.$botId.state',value:'${profile.stateIndex}'),
    ]);
    _cache[botId]=profile;
    changed.value++;
  }
}

class AgentAvatar extends StatefulWidget {
  final String botId;
  final double size;
  final Color fallbackColor;
  final bool working;
  const AgentAvatar({super.key,required this.botId,this.size=52,
    this.fallbackColor=KColors.ink,this.working=false});
  @override
  State<AgentAvatar> createState()=>_AgentAvatarState();
}
class _AgentAvatarState extends State<AgentAvatar> {
  @override
  void initState(){super.initState();unawaited(AvatarRepository.load(widget.botId));}
  @override
  void didUpdateWidget(AgentAvatar oldWidget){
    super.didUpdateWidget(oldWidget);
    if(oldWidget.botId!=widget.botId)unawaited(AvatarRepository.load(widget.botId));
  }
  @override
  Widget build(BuildContext context)=>ValueListenableBuilder<int>(
    valueListenable:AvatarRepository.changed,
    builder:(context,revision,child){
      final profile=AvatarRepository.cached(widget.botId)??const AvatarProfile();
      final color=profile.color>=0
        ? OrganicPresets.colors[profile.color%OrganicPresets.colors.length]
        : widget.fallbackColor;
      return OrganicAvatar(size:widget.size,
        shapeIndex:profile.shape,expressionIndex:profile.expression,
        color:color,working:widget.working,
        stateId:OrganicPresets.states[profile.stateIndex%OrganicPresets.states.length]);
    },
  );
}
