#!/bin/bash
# ==============================================
# 墨瞳 Flutter 工程修复 + 编译脚本
# 用法: chmod +x fix_and_build.sh && ./fix_and_build.sh
# ==============================================
set -e

ZIP_FILE="integrated_project_final.zip"
PROJECT_DIR="motong_flutter_rebuilt"
OUTPUT_DIR="motong_full"

echo "=== 墨瞳工程修复与编译 ==="

# 1. 检查前置条件
echo "[1/6] 检查前置条件..."
if ! command -v flutter &> /dev/null; then
  echo "❌ 未找到 flutter 命令，请先安装 Flutter SDK (>= 3.35.0)"
  exit 1
fi

FLUTTER_VERSION=$(flutter --version 2>/dev/null | head -1)
echo "   Flutter: $FLUTTER_VERSION"

# 2. 解压工程 zip
if [ ! -f "$ZIP_FILE" ]; then
  echo "❌ 未找到 $ZIP_FILE，请先下载工程 zip 放到当前目录"
  echo "   下载地址: https://github.com/MmLLaMA/motong-flutter/raw/main/integrated_project_final.zip"
  exit 1
fi

echo "[2/6] 解压工程 zip..."
unzip -qo "$ZIP_FILE"

# 3. 用 flutter create 生成完整构建系统
echo "[3/6] 用 flutter create 生成 Android 构建系统..."
rm -rf "$OUTPUT_DIR"
flutter create --org com.motong --project-name motong "$OUTPUT_DIR"

# 4. 替换 lib/ 为我们的六模块完整源码
echo "[4/6] 合并六模块源码..."
rm -rf "$OUTPUT_DIR/lib"
cp -r "$PROJECT_DIR/lib" "$OUTPUT_DIR/"

# 5. 修复 pubspec.yaml（intl 版本 + 合并依赖）
echo "[5/6] 修复依赖声明..."
cp "$PROJECT_DIR/pubspec.yaml" "$OUTPUT_DIR/pubspec.yaml"
# Flutter 3.35 要求 intl >= 0.20.0
sed -i 's/intl: \^0\.19\.0/intl: \^0.20.2/' "$OUTPUT_DIR/pubspec.yaml"

# 6. 合并 Android 端定制文件
echo "[6/6] 合并 Android 定制文件..."
# AndroidManifest
cp "$PROJECT_DIR/android/app/src/main/AndroidManifest.xml" \
   "$OUTPUT_DIR/android/app/src/main/AndroidManifest.xml"

# Kotlin 手机控制模块
mkdir -p "$OUTPUT_DIR/android/app/src/main/kotlin/com/motong/app/phonecontrol"
cp -r "$PROJECT_DIR/android/app/src/main/kotlin/com/motong/app/phonecontrol/"* \
   "$OUTPUT_DIR/android/app/src/main/kotlin/com/motong/app/phonecontrol/"

# XML 配置（无障碍服务 + 设备管理器）
mkdir -p "$OUTPUT_DIR/android/app/src/main/res/xml"
cp "$PROJECT_DIR/android/app/src/main/res/xml/accessibility_service_config.xml" \
   "$OUTPUT_DIR/android/app/src/main/res/xml/"
cp "$PROJECT_DIR/android/app/src/main/res/xml/device_admin_receiver.xml" \
   "$OUTPUT_DIR/android/app/src/main/res/xml/"

# strings.xml
mkdir -p "$OUTPUT_DIR/android/app/src/main/res/values"
cp "$PROJECT_DIR/android/app/src/main/res/values/strings.xml" \
   "$OUTPUT_DIR/android/app/src/main/res/values/"

# 确保 namespace / applicationId 一致
APP_BUILD="$OUTPUT_DIR/android/app/build.gradle.kts"
if [ -f "$APP_BUILD" ]; then
  sed -i 's/namespace = "com\.example\.motong"/namespace = "com.motong"/' "$APP_BUILD"
  sed -i 's/applicationId = "com\.example\.motong"/applicationId = "com.motong"/' "$APP_BUILD"
fi

# flutter create 生成的 minSdk 通常是 21，确认一下
if grep -q 'minSdk = flutter.minSdkVersion' "$APP_BUILD" 2>/dev/null; then
  echo "   minSdk 由 flutter.minSdkVersion 接管，无需手动设置"
fi

echo ""
echo "✅ 修复完成！工程在 $OUTPUT_DIR/"
echo ""
echo "开始编译 APK..."
cd "$OUTPUT_DIR"

# 获取依赖
echo "   flutter pub get..."
flutter pub get

# 编译 debug APK
echo "   flutter build apk --debug..."
flutter build apk --debug

APK_PATH="build/app/outputs/flutter-apk/app-debug.apk"
if [ -f "$APK_PATH" ]; then
  APK_SIZE=$(du -h "$APK_PATH" | cut -f1)
  echo ""
  echo "🎉 APK 编译成功！"
  echo "   路径: $(realpath "$APK_PATH")"
  echo "   大小: $APK_SIZE"
else
  echo ""
  echo "❌ APK 编译失败，请检查上方错误信息"
  exit 1
fi