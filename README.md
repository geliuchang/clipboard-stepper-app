# 逐行复制助手（Clipboard Stepper）— Android 工程

导入一个文本文件（每行一组数字），界面显示当前行数字，点「复制」即复制并自动翻到下一行，直到全部复制完。

## 功能
- 📂 导入 .txt（每行一组数字，自动忽略空行）
- 📋 点「复制」= 复制当前行 + 自动翻下一页（走系统剪贴板，100% 可靠）
- ⏭ 跳过 / ← 上一条（复制错了可回退）
- 📊 进度条 + 第几行 / 剩余
- 🔤 也能直接粘贴文本
- 🔒 完全本地，不联网、不上传

## 工程结构
- `app/src/main/assets/index.html` — App 界面（HTML/JS）
- `app/src/main/java/.../MainActivity.java` — 原生 WebView 外壳（含文件选择 + 剪贴板桥）
- `build-apk.sh` — 无需 Gradle 的手动构建脚本
- `.github/workflows/build.yml` — GitHub Actions 云端自动构建

---

## 拿到 .apk 的三条路（任选其一）

### 路线 A：GitHub Actions 云端构建（推荐，最省事）
需要你有一个 GitHub 账号（免费）。
1. 新建一个 **公开** 仓库（如 `clipboard-stepper`）。
2. 把本工程全部文件推上去（含 `.github/` 目录）。
3. 仓库页 → Actions → 选 `Build APK` → `Run workflow`。
4. 跑完在 Artifacts 里下载 `clipboard-stepper-apk`（= `app-release.apk`）。
   - 若打 tag（如 `v1.0`）推上去，会自动发到 Releases，链接可直接下载。
> 云端 runner 自带 JDK+Android SDK，完全不用你装环境。

### 路线 B：在本机（能联网的电脑）一键本地构建
需要：JDK 17 + Android SDK（build-tools;34.0.0、platforms;android-34）。

#### 方式 1：命令行（最轻量，推荐）
**Windows（PowerShell）**
1. 安装 JDK 17，设置环境变量 `JAVA_HOME`（指向 JDK 目录）。
2. 安装 Android SDK 命令行工具，设置 `ANDROID_HOME`，执行：
   ```powershell
   sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"
   ```
3. 在工程目录打开 PowerShell，运行：
   ```powershell
   .\build-apk.ps1
   ```
   产物：`build\app-release.apk`

**Linux / macOS（bash）**
1. 安装 JDK 17，设置 `JAVA_HOME`。
2. 安装 Android SDK，设置 `ANDROID_HOME`，执行：
   ```bash
   sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"
   ```
3. 运行：
   ```bash
   ANDROID_HOME=... JAVA_HOME=... ./build-apk.sh
   ```
   产物：`build/app-release.apk`

#### 方式 2：Android Studio（图形界面，最省心）
1. 安装 Android Studio（自带 JDK + SDK Manager）。
2. 打开本工程目录，等待 Gradle 同步（会自动下载 AGP / Gradle）。
3. SDK Manager 里确认已装 **Android 14 (API 34)** 与 **build-tools 34.0.0**。
4. 菜单 Build → Build APK(s)。
5. 产物：`app/build/outputs/apk/debug/app-debug.apk`

### 路线 C：先当网页 App 用（零构建，立刻可用）
不想要 .apk 也能用：把 `clipboard-stepper.html`（工程外那份）传到安卓手机，
用 **Chrome** 打开 → 右上角 `⋮` → **「添加到主屏幕」**。
它就会像原生 App 一样全屏运行，功能完全一致。

---

## 安装到手机
把生成的 `app-release.apk` 传到安卓手机，点击安装。
若提示「未知来源」，在设置里允许该来源即可（这是未上架商店的自签名包，属正常）。
