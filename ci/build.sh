#!/usr/bin/env bash
# AloJ build: official Telegram for Android + AloJ patch -> signed APK in ./out
set -euo pipefail
BASE_REPO="https://github.com/DrKLO/Telegram.git"
BASE_COMMIT="21f7d109da6ab3506c9e9577f98c6a38771ab335"
ROOT="$(pwd)"
mkdir -p out

git clone --depth 1 "$BASE_REPO" src
cd src
git fetch --depth 1 origin "$BASE_COMMIT"
git checkout -q "$BASE_COMMIT"
git submodule update --init --recursive --depth 1 --jobs 8 || git submodule update --init --recursive --jobs 8
git apply "$ROOT/ci/aloj-telegram.patch"
echo "AloJ patch applied"

chmod +x gradlew
./gradlew --no-daemon -Dorg.gradle.jvmargs="-Xmx6g -XX:MaxMetaspaceSize=1g" \
  :TMessagesProj_App:assembleAfatRelease --stacktrace 2>&1 | tee "$ROOT/build.log"

APK=$(find TMessagesProj_App/build/outputs/apk -name '*.apk' | head -1)
cp "$APK" "$ROOT/out/AloJ.apk"
echo OK > "$ROOT/out/status"
