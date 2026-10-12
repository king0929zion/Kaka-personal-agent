#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
command -v flutter >/dev/null 2>&1 || { echo "Flutter SDK is required" >&2; exit 1; }
flutter create --platforms android --org com.kaka --project-name kaka_flutter .
# Flutter's stock test/widget_test.dart targets MyApp, not this custom app.
rm -f test/widget_test.dart
python3 - <<'PY'
from pathlib import Path
import re
path = Path('android/app/src/main/AndroidManifest.xml')
text = path.read_text()
if 'android.permission.RECORD_AUDIO' not in text:
    text = text.replace('<application', '<uses-permission android:name="android.permission.RECORD_AUDIO" />\n    <application', 1)
if 'android.permission.INTERNET' not in text:
    text = text.replace('<application', '<uses-permission android:name="android.permission.INTERNET" />\n    <application', 1)
if 'android.speech.RecognitionService' not in text:
    text = text.replace('<application', '<queries>\n'
        '        <intent><action android:name="android.speech.RecognitionService" /></intent>\n'
        '        <intent><action android:name="android.intent.action.TTS_SERVICE" /></intent>\n'
        '    </queries>\n    <application', 1)
if 'android:usesCleartextTraffic' not in text:
    text = text.replace('<application', '<application android:usesCleartextTraffic="true"', 1)
text = re.sub(r'android:icon="[^"]*"', 'android:icon="@drawable/kaka_launcher"', text)
text = re.sub(r'android:label="[^"]*"', 'android:label="Kaka"', text)
path.write_text(text)
icon = Path('android/app/src/main/res/drawable/kaka_launcher.xml')
icon.parent.mkdir(parents=True,exist_ok=True)
icon.write_text('''<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
  android:width="108dp" android:height="108dp"
  android:viewportWidth="108" android:viewportHeight="108">
  <path android:fillColor="#FAFAFA" android:pathData="M0,0h108v108h-108z" />
  <path android:fillColor="#161616"
    android:pathData="M54,17 C72,12 91,28 91,53 C92,76 73,92 53,91 C32,92 16,76 17,55 C17,33 33,19 54,17Z" />
  <path android:fillColor="#FFFFFF"
    android:pathData="M38,38 C41,38 42,40 42,44 L42,64 C42,68 39,70 36,68 C35,67 35,65 35,64 L35,44 C35,40 36,38 38,38Z" />
  <path android:fillColor="#FFFFFF"
    android:pathData="M65,38 C68,38 69,40 69,44 L69,64 C69,68 66,70 63,68 C62,67 62,65 62,64 L62,44 C62,40 63,38 65,38Z" />
</vector>''')
PY
# Flutter regenerates native files. Re-apply the stable signing configuration
# on every bootstrap so release builds never silently use a new debug key.
python3 scripts/configure_release_signing.py
flutter pub get
echo "Android Flutter embedding generated. Run flutter run or flutter build apk."
