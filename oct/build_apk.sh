#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JAVA_HOME="/usr/lib/jvm/java-26-openjdk"
ANDROID_HOME="/home/parv/Android/Sdk"
GRADLE_USER_HOME="/tmp/oct-gradle-home"

export JAVA_HOME ANDROID_HOME GRADLE_USER_HOME
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$PATH"

cd "$PROJECT_DIR"

# This project keeps large temporary build output outside the main disk.
if [[ -L build ]]; then
  mkdir -p "$(readlink -f build)"
fi
mkdir -p "$GRADLE_USER_HOME"

echo "Using $(java -version 2>&1 | head -n 1)"
flutter pub get
flutter build apk --release

SOURCE_APK="$PROJECT_DIR/build/app/outputs/flutter-apk/app-release.apk"
OUTPUT_APK="$PROJECT_DIR/OCT-Sort-release.apk"
cp -f "$SOURCE_APK" "$OUTPUT_APK"

echo
echo "APK ready: $OUTPUT_APK"
sha256sum "$OUTPUT_APK"
