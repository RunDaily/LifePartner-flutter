#!/bin/bash
# ══════════════════════════════════════════════════════
#  三端平台切换脚本
#  用法：
#    ./switch_platform.sh android   # 切换到 Android/iOS（默认）
#    ./switch_platform.sh ohos      # 切换到 HarmonyOS
#
#  前提：
#    - Android/iOS：已安装官方 Flutter SDK（/Users/botianwei/flutter/flutter）
#    - HarmonyOS：flutter_flutter/ 目录已克隆（首次执行鸿蒙模式时自动克隆）
#    - 已安装 DevEco Studio（/Applications/DevEco-Studio.app）
# ══════════════════════════════════════════════════════

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVICE_LOCATOR="$SCRIPT_DIR/lib/platform/service_locator.dart"
PUBSPEC="$SCRIPT_DIR/pubspec.yaml"
PUBSPEC_MOBILE="$SCRIPT_DIR/pubspec_mobile.yaml"
PUBSPEC_OHOS="$SCRIPT_DIR/pubspec_ohos.yaml"
FLUTTER_MOBILE="/Users/botianwei/flutter/flutter/bin/flutter"
FLUTTER_OHOS="$SCRIPT_DIR/flutter_flutter/bin/flutter"

# DevEco Studio 工具路径
DEVECO_OHPM="/Applications/DevEco-Studio.app/Contents/tools/ohpm/bin"
DEVECO_HVIGOR="/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin"
DEVECO_TOOLCHAIN="/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains"
OHOS_SDK="/Applications/DevEco-Studio.app/Contents/sdk/default"

TARGET="${1:-android}"

# ── 确保 pubspec_mobile.yaml 包含的是 Mobile 依赖（不被鸿蒙版覆盖）
# 验证方法：检查文件中是否含有 'sqflite:' 而非 'sqflite_ohos'
if [ ! -f "$PUBSPEC_MOBILE" ] || grep -q "sqflite_ohos\|shared_preferences_ohos" "$PUBSPEC_MOBILE" 2>/dev/null; then
  if grep -q "sqflite_ohos\|shared_preferences_ohos" "$PUBSPEC" 2>/dev/null; then
    echo "⚠️  当前 pubspec.yaml 是鸿蒙版本，无法自动备份 Mobile 版本"
    echo "   请先运行：./switch_platform.sh android（需要先手动恢复 Mobile pubspec）"
  else
    cp "$PUBSPEC" "$PUBSPEC_MOBILE"
    echo "✅ 已备份 Mobile pubspec → pubspec_mobile.yaml"
  fi
fi

case "$TARGET" in
  android|ios|mobile)
    echo "🔄 切换到 Android / iOS 模式..."

    # 1. 还原 pubspec.yaml
    cp "$PUBSPEC_MOBILE" "$PUBSPEC"

    # 2. 切换 service_locator.dart 到 Mobile 实现
    sed -i '' \
      -e "s|^// import 'diary_db_service_mobile.dart' as db_impl;|import 'diary_db_service_mobile.dart' as db_impl;|" \
      -e "s|^// import 'kv_store_service_mobile.dart' as kv_impl;|import 'kv_store_service_mobile.dart' as kv_impl;|" \
      -e "s|^import 'diary_db_service_ohos.dart' as db_impl;|// import 'diary_db_service_ohos.dart' as db_impl;|" \
      -e "s|^import 'kv_store_service_ohos.dart' as kv_impl;|// import 'kv_store_service_ohos.dart' as kv_impl;|" \
      "$SERVICE_LOCATOR"

    # 3. pub get
    echo "📦 运行 flutter pub get（官方 SDK）..."
    "$FLUTTER_MOBILE" pub get

    echo ""
    echo "✅ 已切换到 Android / iOS 模式"
    echo "   构建 Android: $FLUTTER_MOBILE build apk"
    echo "   构建 iOS:     $FLUTTER_MOBILE build ipa"
    ;;

  ohos|harmony|harmonyos)
    echo "🔄 切换到 HarmonyOS 模式..."

    # ── 首次使用：检查并克隆鸿蒙 Flutter SDK
    if [ ! -f "$FLUTTER_OHOS" ]; then
      echo "📥 首次使用：正在克隆鸿蒙 Flutter SDK（约 30-60 秒）..."
      git clone --depth 1 --branch dev \
        https://gitee.com/openharmony-sig/flutter_flutter.git \
        "$SCRIPT_DIR/flutter_flutter"
    fi

    # ── 修复版本号：鸿蒙 SDK 浅克隆后 git describe 无法工作，需要本地标签
    OHOS_SDK_DIR="$SCRIPT_DIR/flutter_flutter"
    if ! git -C "$OHOS_SDK_DIR" describe --match '*.*.*' --tags HEAD > /dev/null 2>&1; then
      echo "🔧 修复鸿蒙 Flutter SDK 版本号..."
      git -C "$OHOS_SDK_DIR" tag 3.3.10-ohos > /dev/null 2>&1 || true
      # 清除旧缓存，强制重新读取版本
      rm -f "$OHOS_SDK_DIR/bin/cache/flutter_tools.snapshot" \
            "$OHOS_SDK_DIR/bin/cache/flutter_tools.stamp" 2>/dev/null || true
    fi

    # 1. 切换 pubspec.yaml 为鸿蒙依赖
    cp "$PUBSPEC_OHOS" "$PUBSPEC"

    # 2. 切换 service_locator.dart 到 OHOS 实现
    sed -i '' \
      -e "s|^import 'diary_db_service_mobile.dart' as db_impl;|// import 'diary_db_service_mobile.dart' as db_impl;|" \
      -e "s|^import 'kv_store_service_mobile.dart' as kv_impl;|// import 'kv_store_service_mobile.dart' as kv_impl;|" \
      -e "s|^// import 'diary_db_service_ohos.dart' as db_impl;|import 'diary_db_service_ohos.dart' as db_impl;|" \
      -e "s|^// import 'kv_store_service_ohos.dart' as kv_impl;|import 'kv_store_service_ohos.dart' as kv_impl;|" \
      "$SERVICE_LOCATOR"

    # 3. 配置鸿蒙工具链 PATH 和 SDK 路径
    export PATH="$PATH:$DEVECO_OHPM:$DEVECO_HVIGOR:$DEVECO_TOOLCHAIN"
    export FLUTTER_GIT_URL="https://gitee.com/openharmony-sig/flutter_flutter.git"
    "$FLUTTER_OHOS" config --ohos-sdk "$OHOS_SDK" > /dev/null 2>&1

    # 4. pub get（使用鸿蒙 SDK；首次需要下载 Dart SDK 和工具，约 1-2 分钟）
    echo "📦 运行 flutter pub get（鸿蒙 SDK）..."
    echo "   ⏳ 首次运行需要约 1-2 分钟（下载工具链和 git 依赖）..."
    FLUTTER_GIT_URL="https://gitee.com/openharmony-sig/flutter_flutter.git" "$FLUTTER_OHOS" pub get

    echo ""
    echo "✅ 已切换到 HarmonyOS 模式"
    echo "   构建鸿蒙: $FLUTTER_OHOS build hap"
    echo ""
    echo "   如需连接鸿蒙设备调试，请确保 hdc 可用："
    echo "   export PATH=\"\$PATH:$DEVECO_TOOLCHAIN\""
    ;;

  *)
    echo "用法: $0 [android|ios|ohos]"
    echo ""
    echo "  android  切换到 Android / iOS 模式（使用官方 Flutter SDK）"
    echo "  ohos     切换到 HarmonyOS 模式（使用 flutter_flutter SDK）"
    exit 1
    ;;
esac
