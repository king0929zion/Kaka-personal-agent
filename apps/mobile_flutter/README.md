# Kaka Flutter Android (preview)

This is a separate **Flutter Android client** for the existing Kaka / Rakazo backend. It does not replace `apps/mobile`.

## Status

Functional preview: custom monochrome screens, floating pill navigation, server probe, Better Auth sign-in, Space navigation, bot list/create, basic realtime text chat via oRPC + SSE, generic message block presentation, and the first Dart CustomPainter organic avatar editor.

**Not yet feature-equivalent to Expo.** Rich group management, complete media handling, voice calls, Computer controls, background notifications, complete interactive actions, model credential editing and pixel-identical BLOUB timelines remain migration work. The avatar editor currently persists per-agent overrides **only on this device**. Do not replace a production APK with this preview.

## Build

Requirements: Flutter stable, Dart >=3.8, Java, Android SDK, and a reachable Kaka server.

```sh
cd apps/mobile_flutter
bash scripts/bootstrap_android.sh
flutter analyze
flutter test
flutter build apk --release --split-per-abi
# Or: flutter build apk --debug (developer-only performance)
```

`bootstrap_android.sh` generates the Android embedding for your installed Flutter SDK and adds the INTERNET permission. It is safe to rerun. No credentials or APK signing keys are checked in.

## API

The client speaks the existing server's oRPC POST JSON envelopes, password login via Better Auth, and authenticated SSE on `/rpc/threads/subscribe`. `apps/mobile/lib/api.ts` is the protocol behavior reference. Production migration requires parity tests before replacing Expo.

## Directories

`lib/core`: models and API, `lib/app`: application state, `lib/design`: flat UI primitives, `lib/features`: screens and organic avatar.

See `docs/FLUTTER_MIGRATION.md` for release blockers.

## Fixed Android release signing

Kaka now supports a permanent RSA-4096 Android release signing identity
(`kaka-release`). **A release signed by a temporary CI runner's debug key
cannot be installed over another build with a different certificate.**

- Normal pull-request CI publishes a **test-only** release-mode APK, clearly
  marked `EPHEMERAL-SIGNATURE`; do not distribute it as a stable update.
- The manual **Kaka Android stable signed Release** GitHub Actions workflow
  uses the same fixed keystore on every run. It verifies the public
  signing-certificate SHA-256 and APK Signature Scheme v2 before publishing
  the signed APK.
- Set the three encrypted GitHub Actions repository secrets from your private
  `Kaka-Android-Signing-Kit.zip` before running this workflow. Never commit
  the JKS or passwords.
- Release builds without stable signing credentials are rejected unless the
  explicitly test-only `KAKA_ALLOW_DEBUG_RELEASE_SIGNING=1` override is used.

See **[ANDROID_RELEASE_SIGNING.md](docs/ANDROID_RELEASE_SIGNING.md)** for
step-by-step setup, local builds, certificate fingerprint, and upgrade rules.
