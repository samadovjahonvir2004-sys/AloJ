#!/usr/bin/env bash
# AloJ build: Nagram source + AloJ patch -> signed APKs in ./out
set -euo pipefail
BASE_REPO="https://github.com/NextAlone/Nagram.git"
BASE_COMMIT="8f2a8a03aa7aec599150b09d302bfd5023283344"
ROOT="$(pwd)"
mkdir -p out

git clone --depth 1 "$BASE_REPO" src
cd src
git fetch --depth 1 origin "$BASE_COMMIT"
git checkout -q "$BASE_COMMIT"
git submodule update --init --recursive --depth 1 --jobs 8 || git submodule update --init --recursive --jobs 8
git apply "$ROOT/ci/aloj-nagram.patch"
echo "AloJ patch applied"

{
  echo "sdk.dir=${ANDROID_HOME}"
  echo "ndk.dir=${ANDROID_HOME}/ndk/27.2.12479018"
  echo "TELEGRAM_APP_ID=37456841"
  echo "TELEGRAM_APP_HASH=${ALOJ_API_HASH}"
  echo "KEYSTORE_PASS=${ALOJ_KEY_PASSWORD}"
  echo "ALIAS_NAME=aloj"
  echo "ALIAS_PASS=${ALOJ_KEY_PASSWORD}"
} > local.properties
sed -i "s/2000000000000/$(date +%s%N | cut -c1-13)/g" gradle.properties

chmod +x gradlew
./gradlew --no-daemon -Dorg.gradle.jvmargs="-Xmx6g -XX:MaxMetaspaceSize=1g" \
  TMessagesProj:assembleRelease --stacktrace 2>&1 | tee "$ROOT/build.log"

ARM64=$(find TMessagesProj/build/outputs/apk -name '*arm64-v8a*.apk' | head -1)
ARM32=$(find TMessagesProj/build/outputs/apk -name '*armeabi-v7a*.apk' | head -1)
cp "$ARM64" "$ROOT/out/AloJ.apk"
[ -n "$ARM32" ] && cp "$ARM32" "$ROOT/out/AloJ-old-phones.apk"
echo OK > "$ROOT/out/status"
