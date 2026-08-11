# 手动构建 APK（Windows，无需 Gradle / Android Studio）
# 前置：安装 JDK 17（设置 JAVA_HOME）与 Android SDK（cmdline-tools + platforms;android-34 + build-tools;34.0.0，设置 ANDROID_HOME）
# 用法：在 PowerShell 中 cd 到本目录后执行  .\build-apk.ps1
$ErrorActionPreference = 'Stop'

function FindNewest($base) {
  if (-not (Test-Path $base)) { return $null }
  return Get-ChildItem $base -Directory | Sort-Object Name | Select-Object -Last 1
}

$SDK = if ($env:ANDROID_HOME) { $env:ANDROID_HOME }
       elseif ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT }
       else { throw "请先设置环境变量 ANDROID_HOME 指向 Android SDK" }

$JAVA = $env:JAVA_HOME
if (-not $JAVA) { throw "请先设置环境变量 JAVA_HOME 指向 JDK 17" }

$bt = FindNewest "$SDK\build-tools"
$plat = FindNewest "$SDK\platforms"
if (-not $bt) { throw "未找到 build-tools，请执行: sdkmanager `"build-tools;34.0.0`"" }
if (-not $plat) { throw "未找到 platforms，请执行: sdkmanager `"platforms;android-34`"" }

$AAPT2    = "$bt\aapt2.exe"
$D8       = "$bt\d8.bat"
$ZIPALIGN = "$bt\zipalign.exe"
$APKSIGNER= "$bt\apksigner.bat"
$AJAR     = "$plat\android.jar"
if (-not (Test-Path $AJAR)) { throw "未找到 $AJAR" }

$ROOT = Split-Path -Parent $MyInvocation.MyCommand.Definition
$SRC  = "$ROOT\app\src\main"
$OUT  = "$ROOT\build"
New-Item -ItemType Directory -Force -Path "$OUT\gen", "$OUT\classes" | Out-Null

Write-Host ">> 编译资源"
& $AAPT2 compile --dir "$SRC\res" -o "$OUT\res.zip"

Write-Host ">> 链接资源 + 清单 + assets"
& $AAPT2 link -o "$OUT\base.apk" -I "$AJAR" `
    --manifest "$SRC\AndroidManifest.xml" `
    -R "$OUT\res.zip" `
    --assets "$SRC\assets" `
    --java "$OUT\gen" --auto-add-overlay

Write-Host ">> javac 编译 MainActivity+R"
& "$JAVA\bin\javac.exe" -source 17 -target 17 -cp "$AJAR" -d "$OUT\classes" `
    "$SRC\java\com\example\clipboardstepper\MainActivity.java", `
    "$OUT\gen\com\example\clipboardstepper\R.java"

Write-Host ">> d8 生成 classes.dex"
& $D8 --release --lib "$AJAR" --classpath "$AJAR" --output "$OUT\classes.dex" "$OUT\classes"

Write-Host ">> 把 classes.dex 注入 APK（不压缩）"
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zin  = [System.IO.Compression.ZipFile]::Open("$OUT\base.apk", 'Read')
$zout = [System.IO.Compression.ZipFile]::Open("$OUT\app-unsigned.apk", 'Create')
foreach ($e in $zin.Entries) {
    $ne = $zout.CreateEntry($e.FullName)
    $ne.CompressionLevel = $e.CompressionLevel
    $s = $e.Open(); $t = $ne.Open(); $s.CopyTo($t); $s.Dispose(); $t.Dispose()
}
$dexEntry = $zout.CreateEntry("classes.dex")
$dexEntry.CompressionLevel = [System.IO.Compression.CompressionLevel]::NoCompression
$t = $dexEntry.Open()
$b = [System.IO.File]::ReadAllBytes("$OUT\classes.dex")
$t.Write($b, 0, $b.Length); $t.Dispose()
$zin.Dispose(); $zout.Dispose()

Write-Host ">> zipalign 对齐"
& $ZIPALIGN -p 4 "$OUT\app-unsigned.apk" "$OUT\app-unsigned-aligned.apk"

Write-Host ">> 签名"
$KEY = "$OUT\debug.keystore"
if (-not (Test-Path $KEY)) {
    & "$JAVA\bin\keytool.exe" -genkey -v -keystore "$KEY" -alias android `
        -keyalg RSA -keysize 2048 -validity 10000 `
        -storepass android -keypass android -dname "CN=ClipboardStepper"
}
& $APKSIGNER sign --ks "$KEY" --ks-key-alias android `
    --ks-pass pass:android --key-pass pass:android `
    --out "$OUT\app-release.apk" "$OUT\app-unsigned-aligned.apk"

Write-Host ""
Write-Host "✅ APK 已生成: $OUT\app-release.apk"
