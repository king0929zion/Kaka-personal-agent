# Kaka Flutter Android (preview)

This is a separate **Flutter Android client** for the existing Kaka / Rakazo backend. It does not replace `apps/mobile`.

## Status

Functional preview: custom monochrome screens, floating pill navigation, server probe, Better Auth sign-in, Space navigation, bot list/create, basic realtime text chat via oRPC + SSE, generic message block presentation, and the first Dart CustomPainter organic avatar editor.

**Not yet feature-equivalent to Expo.** Group chat, media upload/download, voice calls, Computer controls, background notifications, complete Markdown/actions, model credential editing and pixel-identical BLOUB timelines remain migration work. The avatar editor currently persists per-agent overrides **only on this device**. Do not replace a production APK with this preview.

## Build

Requirements: Flutter stable, Dart >=3.8, Java, Android SDK, and a reachable Kaka server.

```sh
cd apps/mobile_flutter
bash scripts/bootstrap_android.sh
flutter analyze
flutter test
flutter build apk --debug
```

`bootstrap_android.sh` generates the Android embedding for your installed Flutter SDK and adds the INTERNET permission. It is safe to rerun. No credentials or APK signing keys are checked in.

## API

The client speaks the existing server's oRPC POST JSON envelopes, password login via Better Auth, and authenticated SSE on `/rpc/threads/subscribe`. `apps/mobile/lib/api.ts` is the protocol behavior reference. Production migration requires parity tests before replacing Expo.

## Directories

`lib/core`: models and API, `lib/app`: application state, `lib/design`: flat UI primitives, `lib/features`: screens and organic avatar.

See `docs/FLUTTER_MIGRATION.md` for release blockers.
