#!/usr/bin/env bash
# 手动构建 APK（无需 Gradle）。需要：JDK17 + Android SDK(build-tools;34.0.0, platforms;android-34)
# 用法： ANDROID_HOME=/path/to/sdk JAVA_HOME=/path/to/jdk ./build-apk.sh
set -e
SDK=${ANDROID_HOME:?请设置 ANDROID_HOME 指向 Android SDK}
JAVA=${JAVA_HOME:?请设置 JAVA_HOME 指向 JDK17}

BT=$(ls -d "$SDK"/build-tools/*/ | sort | tail -1)
PLAT=$(ls -d "$SDK"/platforms/*/ | sort | tail -1)
AJAR="$PLAT/android.jar"
AAPT2="$BT/aapt2"
D8="$BT/d8"
ZIPALIGN="$BT/zipalign"
APKSIGNER="$BT/apksigner"

ROOT=$(cd "$(dirname "$0")" && pwd)
SRC="$ROOT/app/src/main"
OUT="$ROOT/build"
mkdir -p "$OUT/gen" "$OUT/classes"

echo ">> compile resources"
"$AAPT2" compile --dir "$SRC/res" -o "$OUT/res.zip"

echo ">> link resources + manifest + assets"
"$AAPT2" link -o "$OUT/base.apk" -I "$AJAR" \
  --manifest "$SRC/AndroidManifest.xml" \
  -R "$OUT/res.zip" \
  --assets "$SRC/assets" \
  --java "$OUT/gen" --auto-add-overlay

echo ">> javac"
"$JAVA/bin/javac" -source 17 -target 17 -cp "$AJAR" -d "$OUT/classes" \
  "$SRC/java/com/example/clipboardstepper/MainActivity.java" \
  "$OUT/gen/com/example/clipboardstepper/R.java"

echo ">> d8 -> classes.dex"
"$D8" --release --output "$OUT/classes.dex" -cp "$AJAR" "$OUT/classes"

echo ">> 注入 classes.dex 到 APK"
cd "$OUT"
python3 - "$OUT" <<'PY'
import zipfile, sys, os
out=sys.argv[1]
src=os.path.join(out,"base.apk"); dst=os.path.join(out,"app-unsigned.apk")
with zipfile.ZipFile(src,'r') as zin, zipfile.ZipFile(dst,'w',zipfile.ZIP_STORED) as zout:
    for it in zin.infolist():
        zout.writestr(it, zin.read(it.filename))
    zout.writestr("classes.dex", open(os.path.join(out,"classes.dex"),"rb").read())
PY

echo ">> zipalign"
"$ZIPALIGN" -p 4 "$OUT/app-unsigned.apk" "$OUT/app-unsigned-aligned.apk"

echo ">> 签名"
KEY="$OUT/debug.keystore"
if [ ! -f "$KEY" ]; then
  "$JAVA/bin/keytool" -genkey -v -keystore "$KEY" -alias android \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -storepass android -keypass android -dname "CN=ClipboardStepper"
fi
"$APKSIGNER" sign --ks "$KEY" --ks-key-alias android \
  --ks-pass pass:android --key-pass pass:android \
  --out "$OUT/app-release.apk" "$OUT/app-unsigned-aligned.apk"

echo "APK 已生成: $OUT/app-release.apk"
