#!/usr/bin/env python3
"""Patch Flutter's generated Android Gradle build to use Kaka's stable key.

Generated Android sources are intentionally not committed to this repository.
This patch is applied immediately after `flutter create` and is idempotent.

Never write keystore passwords to files tracked by Git. Signed builds read
keystore path and password values only from their process environment.
"""
from pathlib import Path

APP_GRADLE = Path(__file__).resolve().parents[1] / "android/app/build.gradle.kts"
PATCH_MARKER = "// KAKA_STABLE_RELEASE_SIGNING_V1"
SIGNING_CONFIG = '''
    // Use the developer-owned Kaka certificate, never a transient runner key.
    signingConfigs {
        if (kakaHasReleaseKey) {
            create("kakaRelease") {
                storeFile = file(kakaKeystorePath!!)
                storePassword = kakaStorePassword
                keyAlias = kakaKeyAlias
                keyPassword = kakaKeyPassword
            }
        }
    }
'''
SIGNING_VARIABLES = '''
// KAKA_STABLE_RELEASE_SIGNING_V1
// A GitHub runner's debug key must NEVER sign a distributed Kaka update.
val kakaKeystorePath = System.getenv("KAKA_ANDROID_KEYSTORE_PATH")
val kakaStorePassword = System.getenv("KAKA_ANDROID_STORE_PASSWORD")
val kakaKeyPassword = System.getenv("KAKA_ANDROID_KEY_PASSWORD")
val kakaKeyAlias = System.getenv("KAKA_ANDROID_KEY_ALIAS") ?: "kaka-release"
val kakaHasReleaseKey = listOf(
    kakaKeystorePath, kakaStorePassword, kakaKeyPassword, kakaKeyAlias
).all { !it.isNullOrBlank() }
val kakaReleaseRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}
val kakaTestingOnly = System.getenv("KAKA_ALLOW_DEBUG_RELEASE_SIGNING") == "1"
if (kakaReleaseRequested && !kakaHasReleaseKey && !kakaTestingOnly) {
    throw GradleException(
        "Kaka Release signing is not configured. " +
        "Provide KAKA_ANDROID_KEYSTORE_PATH, KAKA_ANDROID_STORE_PASSWORD, " +
        "KAKA_ANDROID_KEY_PASSWORD, and KAKA_ANDROID_KEY_ALIAS. " +
        "Debug signing for a release-mode build is allowed only with " +
        "KAKA_ALLOW_DEBUG_RELEASE_SIGNING=1 (CI testing only)."
    )
}
'''


def main() -> None:
    if not APP_GRADLE.is_file():
        raise SystemExit(f"Missing generated Android Gradle file: {APP_GRADLE}")
    source = APP_GRADLE.read_text()
    if PATCH_MARKER in source:
        print("Kaka stable signing patch is already applied.")
        return

    # Fail closed if the installed Flutter SDK changes the generated template.
    debug_line = 'signingConfig = signingConfigs.getByName("debug")'
    android_anchor = "android {"
    if source.count(debug_line) != 1 or source.count(android_anchor) != 1:
        raise SystemExit(
            "Flutter's Android Gradle template changed. Refusing to produce "
            "a release APK until Kaka's signing patch is reviewed."
        )
    source = source.replace(
        android_anchor,
        SIGNING_VARIABLES + "\n" + android_anchor + "\n" + SIGNING_CONFIG,
        1,
    )
    source = source.replace(
        debug_line,
        'signingConfig = if (kakaHasReleaseKey) '
        'signingConfigs.getByName("kakaRelease") '
        'else signingConfigs.getByName("debug")',
        1,
    )
    APP_GRADLE.write_text(source)
    print("Generated Gradle app configured for Kaka's stable Release key.")


if __name__ == "__main__":
    main()
