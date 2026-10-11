#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
command -v flutter >/dev/null 2>&1 || { echo "Flutter SDK is required" >&2; exit 1; }
flutter create --platforms android --org com.kaka --project-name kaka_flutter .
# Flutter's stock test/widget_test.dart targets MyApp, not this custom app.
rm -f test/widget_test.dart
python3 - <<'PY'
from pathlib import Path
path = Path('android/app/src/main/AndroidManifest.xml')
text = path.read_text()
if 'android.permission.INTERNET' not in text:
    text = text.replace('<application', '<uses-permission android:name="android.permission.INTERNET" />\n    <application', 1)
if 'android:usesCleartextTraffic' not in text:
    text = text.replace('<application', '<application android:usesCleartextTraffic="true"', 1)
path.write_text(text)
PY
flutter pub get
echo "Android Flutter embedding generated. Run flutter run or flutter build apk."
