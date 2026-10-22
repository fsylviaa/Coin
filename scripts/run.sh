#!/bin/bash
# 编译 App，并在 iPhone 模拟器里打开它。
source "$(dirname "$0")/_common.sh"
check_xcode
check_project
find_simulator

echo "==> [1/3] 编译 App（第一次会比较慢）..."
xcodebuild build \
  -project CoinFlip.xcodeproj \
  -scheme CoinFlip \
  -destination "id=$SIM_ID" \
  -derivedDataPath build \
  -quiet || { echo "❌ 编译失败，请查看上方带 error 的那几行"; exit 1; }

APP_PATH="build/Build/Products/Debug-iphonesimulator/CoinFlip.app"

echo "==> [2/3] 启动模拟器: $SIM_NAME"
xcrun simctl boot "$SIM_ID" 2>/dev/null || true
open_simulator_app
# 等模拟器开机完成，否则装 App 会失败
xcrun simctl bootstatus "$SIM_ID" -b >/dev/null 2>&1 || true

echo "==> [3/3] 安装并打开 App"
xcrun simctl install "$SIM_ID" "$APP_PATH"
xcrun simctl launch "$SIM_ID" com.antheafsy.coinflip >/dev/null

echo ""
echo "✅ App 已在模拟器中打开。若没看到模拟器窗口，请点一下程序坞里的「Simulator」。"
