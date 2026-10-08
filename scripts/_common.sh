#!/bin/bash
# 公共函数，其他脚本会自动引用，不需要单独运行。

# 切换到项目根目录（无论从哪里运行脚本）
cd "$(dirname "$0")/.." || exit 1

# 检查是否装了完整的 Xcode（不是只有命令行工具）
check_xcode() {
  if ! xcodebuild -version >/dev/null 2>&1; then
    echo "❌ 没有找到可用的 Xcode。"
    echo "   1. 请先从 App Store 安装 Xcode，并打开一次完成初始化。"
    echo "   2. 然后在终端运行：sudo xcode-select -s /Applications/Xcode.app"
    exit 1
  fi
}

# 找一台可用的 iPhone 模拟器，把它的编号存进 SIM_ID
find_simulator() {
  SIM_ID=$(xcrun simctl list devices available \
    | grep -E '^[[:space:]]+iPhone' \
    | tail -1 \
    | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}')
  if [ -z "$SIM_ID" ]; then
    echo "❌ 没有找到可用的 iPhone 模拟器。"
    echo "   请打开 Xcode → Settings → Components，下载一个 iOS 模拟器。"
    exit 1
  fi
  SIM_NAME=$(xcrun simctl list devices available | grep "$SIM_ID" | sed -E 's/^[[:space:]]+//; s/ \([0-9A-F-]{36}\).*$//')
}

# 检查工程是否已生成
check_project() {
  if [ ! -d "CoinFlip.xcodeproj" ]; then
    echo "❌ 还没有生成工程文件，工程文件 CoinFlip.xcodeproj 不见了，请重新下载项目"
    exit 1
  fi
}
