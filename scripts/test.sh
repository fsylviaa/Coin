#!/bin/bash
# 在模拟器上运行全部自动测试（等同于在 Xcode 里按 ⌘U）。
source "$(dirname "$0")/_common.sh"
check_xcode
check_project
find_simulator

echo "==> 在模拟器 $SIM_NAME 上运行测试（第一次会比较慢，请耐心等 1–3 分钟）..."
if xcodebuild test \
    -project CoinFlip.xcodeproj \
    -scheme CoinFlip \
    -destination "id=$SIM_ID" \
    -quiet; then
  echo ""
  echo "✅ 全部测试通过"
else
  echo ""
  echo "❌ 有测试失败，请查看上方带 error 的那几行"
  exit 1
fi
