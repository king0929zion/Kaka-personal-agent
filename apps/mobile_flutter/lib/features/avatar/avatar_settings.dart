import 'dart:async';
import 'dart:convert';
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
  // A per-Agent subscription avoids rebuilding every visible avatar when
  // one profile is loaded/edited. Only active widgets retain listeners.
  static final _listeners=<String,Set<VoidCallback>>{};
  static void subscribe(String id, VoidCallback listener) =>
      _listeners.putIfAbsent(id,()=> <VoidCallback>{}).add(listener);
  static void unsubscribe(String id, VoidCallback listener) {
    final listeners=_listeners[id];
    listeners?.remove(listener);
    if(listeners?.isEmpty??false)_listeners.remove(id);
  }
  static void _notify(String id) {
    for(final callback in List<VoidCallback>.from(
      _listeners[id]??const <VoidCallback>{})){
      callback();
    }
  }
  static final _cache=<String,AvatarProfile>{};
  static final _loading=<String,Future<AvatarProfile>>{};
  static const _cacheLimit = 96;

  static void _remember(String id, AvatarProfile profile) {
    _cache.remove(id);
    _cache[id] = profile;
    while (_cache.length > _cacheLimit) {
      _cache.remove(_cache.keys.first);
    }
  }

  static AvatarProfile? cached(String botId)=>_cache[botId];
  static Future<AvatarProfile> load(String botId) {
    if(_cache.containsKey(botId)){
      final value=_cache[botId]!;
      _remember(botId,value);
      return Future.value(value);
    }
    return _loading.putIfAbsent(botId,() async {
      try {
        // New installs need one secure-storage read per Agent. The old four-key
        // format is lazily migrated without losing saved customisations.
        final packed=await _store.read(key:'kaka.avatar.$botId.profile');
        if(packed!=null) {
          final value=Map<String,dynamic>.from(jsonDecode(packed) as Map);
          final profile=AvatarProfile(
            shape:(value['shape'] as num?)?.toInt()??0,
            expression:(value['expression'] as num?)?.toInt()??0,
            color:(value['color'] as num?)?.toInt()??-1,
            stateIndex:(value['stateIndex'] as num?)?.toInt()??0);
          _remember(botId,profile);
          _notify(botId);
          return profile;
        }
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
        _remember(botId,result);
        _notify(botId);
        return result;
      }catch(_){
        const result=AvatarProfile();
        _remember(botId,result);
        _notify(botId);
        return result;
      }finally{
        _loading.remove(botId);
      }
    });
  }
  static Future<void> save(String botId,AvatarProfile profile) async {
    final encoded=jsonEncode({
      'shape':profile.shape,
      'expression':profile.expression,
      'color':profile.color,
      'stateIndex':profile.stateIndex,
    });
    await _store.write(key:'kaka.avatar.$botId.profile',value:encoded);
    _remember(botId,profile);
    _notify(botId);
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
  void _onChanged(){if(mounted)setState((){});}
  @override
  void initState(){
    super.initState();
    AvatarRepository.subscribe(widget.botId,_onChanged);
    unawaited(AvatarRepository.load(widget.botId));
  }
  @override
  void didUpdateWidget(AgentAvatar oldWidget){
    super.didUpdateWidget(oldWidget);
    if(oldWidget.botId!=widget.botId){
      AvatarRepository.unsubscribe(oldWidget.botId,_onChanged);
      AvatarRepository.subscribe(widget.botId,_onChanged);
      unawaited(AvatarRepository.load(widget.botId));
    }
  }
  @override
  void dispose(){
    AvatarRepository.unsubscribe(widget.botId,_onChanged);
    super.dispose();
  }
  @override
  Widget build(BuildContext context){
    final profile=AvatarRepository.cached(widget.botId)??const AvatarProfile();
    final color=profile.color>=0
      ? OrganicPresets.colors[profile.color%OrganicPresets.colors.length]
      : widget.fallbackColor;
    return OrganicAvatar(size:widget.size,
      shapeIndex:profile.shape,expressionIndex:profile.expression,
      color:color,working:widget.working,
      stateId:OrganicPresets.states[profile.stateIndex%OrganicPresets.states.length]);
  }
}
