#!/bin/bash
# Release builds for Google Play (efficiency, 2026-10-21).
#
#   tool/build_release.sh https://api.jiranichama.co.ke/api/v1 <platform-key-fingerprint>
#
# - An app bundle (.aab): Play sends each phone only its own processor's code, about a
#   third of the universal APK.
# - --obfuscate --split-debug-info: Dart symbols are stripped from the app (smaller, and
#   harder to read); they are kept in build/symbols to read crash reports in Play Console.
# - The platform key fingerprint is built in, so phones trust only the real signing key.
set -euo pipefail
API="${1:?API base URL}"
FP="${2:?platform key fingerprint (GET /platform-keys/ first entry)}"
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols \
  --dart-define=API_BASE_URL="$API" --dart-define=FLAVOR=prod \
  --dart-define=PLATFORM_KEY_FP="$FP"
echo "Upload build/app/outputs/bundle/release/app-release.aab to Play Console."
echo "Keep build/symbols safe: 'flutter symbolize' needs it to read crash stack traces."
