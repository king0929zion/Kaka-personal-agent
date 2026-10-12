# Kaka Android: one permanent signing certificate

Kaka Android uses a single RSA-4096 release signing key with alias `kaka-release`.
**Never upload the .jks file or passwords to the public GitHub repository.**
The private signing kit must be backed up securely, separately from GitHub.

Public expected certificate SHA-256:

```text
6B:CE:F4:02:57:E8:EF:FF:C4:6A:69:5C:D8:67:01:7C:85:67:59:6B:5D:2F:6A:C3:03:E8:42:93:27:9C:2D:C4
```

## First-time GitHub setup (one-time)

Download your privately supplied `Kaka-Android-Signing-Kit.zip` and extract
`kaka-release-signing.jks` and
`Kaka-signing-credentials-KEEP-PRIVATE.txt`.
Do not share either file.

In the GitHub repository, open **Settings > Secrets and variables > Actions >
New repository secret**. Create all three secrets:

| Repository secret | Private value |
| --- | --- |
| `KAKA_ANDROID_KEYSTORE_BASE64` | The **entire keystore file** encoded as one line of base64 (not its path) |
| `KAKA_ANDROID_STORE_PASSWORD` | `STORE PASSWORD` from the private credential text file |
| `KAKA_ANDROID_KEY_PASSWORD` | `KEY PASSWORD` from the private credential text file |

To obtain the first value (Linux):

```sh
base64 -w 0 kaka-release-signing.jks
```

On macOS:

```sh
base64 < kaka-release-signing.jks | tr -d '\n'
```

Avoid pasting the base64 string or either password into GitHub issues, chat,
commit messages, workflow_dispatch inputs, build logs, or source files.

## Build signed Android APK

After all three secrets are saved:

1. Open **Actions > Kaka Android stable signed Release**.
2. Click **Run workflow**, selecting the **main** branch.
3. Wait until all steps pass, including **Verify APK signature and public
   certificate fingerprint**.
4. Under **Artifacts**, download `kaka-android-arm64-stable-SIGNED-<run>`.
   The archive contains `app-release.apk`.

The build uses the same saved keystore for every run, and sets an incrementing
Android `versionCode` based on the signed workflow's run number. It refuses
to publish if a different certificate is provided. The APK is signed with
modern APK Signature Scheme v2 and its digest is checked before upload.

The normal `Kaka Flutter verification` CI emits
`kaka-flutter-arm64-ci-test-EPHEMERAL-SIGNATURE`. That is a *testing*
artifact, **not** an upgradable stable release; it uses a temporary debug key.

## Build locally with the SAME certificate

Flutter stable, Android SDK, JDK 17+, and the Android tooling are required.
Do not check the keystore into Git. Pass its absolute path and both passwords
via environment variables:

```sh
export KAKA_ANDROID_KEYSTORE_PATH=/absolute/path/to/kaka-release-signing.jks
export KAKA_ANDROID_KEY_ALIAS=kaka-release
read -rsp 'Keystore password: ' KAKA_ANDROID_STORE_PASSWORD; echo
read -rsp 'Key password: ' KAKA_ANDROID_KEY_PASSWORD; echo
export KAKA_ANDROID_STORE_PASSWORD KAKA_ANDROID_KEY_PASSWORD

cd apps/mobile_flutter
bash scripts/bootstrap_android.sh
flutter analyze --no-fatal-infos
flutter test
flutter build apk --release --target-platform android-arm64 --build-number=10001
```

A locally built update must use a `--build-number` **higher than the version
already installed**. For CI-signed APKs, the workflow increments it.

A release-mode build without the stable keystore **fails closed**, except when
`KAKA_ALLOW_DEBUG_RELEASE_SIGNING=1` is explicitly set for CI testing.
Never use this opt-out for distributed builds.

## Android signing and upgrade limitations

Android in-place updates require the same `applicationId`, matching signing
certificate, and a higher `versionCode`. APKs built previously with another
runner's debug certificate cannot be overwritten by the new key: back up
local data, then uninstall the incompatible app before installing this signed
release. Future releases signed with this permanent key can update each other.

**Keep at least two secure offline/encrypted backups of the private keystore
and both passwords.** Losing the key means future builds cannot update
installed copies using this signing identity.

## Validation and security

The signed workflow:
- Validates all three secrets exist without printing their contents.
- Restores the keystore in the runner's temporary directory with permissions 600.
- Validates the keystore's SHA-256 public certificate fingerprint.
- Builds a Release-mode ARM64 APK using the configured keystore.
- Uses Android `apksigner verify` to verify the APK's v2 signature and signer fingerprint.
- Uploads only the signed APK. Deletes temporary signing files afterwards.

A successful CI build proves signing and compilation, **not** stable 60/120 FPS
or an upgrade path from an APK signed with a different certificate.
