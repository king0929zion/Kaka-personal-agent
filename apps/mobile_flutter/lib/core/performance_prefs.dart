import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persistent override for resource-constrained Android devices.
class PerformancePrefs {
  static const _storage=FlutterSecureStorage();
  static const _key='kaka.flutter.low_power';
  static final lowPower=ValueNotifier<bool>(false);

  static Future<void> restore() async {
    try {
      final value=await _storage.read(key:_key);
      _apply(value=='true');
    } catch (_) {
      _apply(false);
    }
  }

  static Future<void> setLowPower(bool value) async {
    _apply(value);
    try {
      await _storage.write(key:_key,value:value.toString());
    } catch (_) {
      // A storage failure should not undo an in-memory preference.
    }
  }

  static void _apply(bool value) {
    lowPower.value=value;
    final cache=PaintingBinding.instance.imageCache;
    cache.maximumSizeBytes=(value?12:32)*1024*1024;
    cache.maximumSize=value?36:80;
    if(value) cache.clear();
  }
}
