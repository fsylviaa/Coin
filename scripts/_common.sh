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

# 找一台可用的 iPhone 模拟器，把编号存进 SIM_ID、名字存进 SIM_NAME
find_simulator() {
  local line
  line=$(xcrun simctl list devices available | grep -E '^[[:space:]]+iPhone' | tail -1)
  SIM_ID=$(printf '%s' "$line" | grep -oiE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}')
  SIM_NAME=$(printf '%s' "$line" | sed -E 's/^[[:space:]]*//; s/[[:space:]]*\(.*$//')
  if [ -z "$SIM_ID" ]; then
    echo "❌ 没有找到可用的 iPhone 模拟器。"
    echo "   请打开 Xcode → Settings → Components，下载一个 iOS 模拟器。"
    exit 1
  fi
  [ -n "$SIM_NAME" ] || SIM_NAME="iPhone 模拟器"
}

# 打开"模拟器"的显示窗口。
# 它藏在 Xcode 内部，不同 Xcode 版本位置不一样，所以按三种办法依次尝试。
open_simulator_app() {
  # 办法一：按程序的身份编号打开，不依赖路径，最可靠
  if open -b com.apple.iphonesimulator 2>/dev/null; then
    return 0
  fi
  # 办法二：按名字打开
  if open -a Simulator 2>/dev/null; then
    return 0
  fi
  # 办法三：在 Xcode 内部搜一遍
  local found
  found=$(find "$(xcode-select -p)" -maxdepth 6 -name "Simulator.app" -type d 2>/dev/null | head -1)
  if [ -n "$found" ] && open "$found" 2>/dev/null; then
    return 0
  fi
  echo "   (!) 没能自动打开模拟器窗口。App 其实已经装好并运行了，"
  echo "       请从 Xcode 菜单 Xcode -> Open Developer Tool -> Simulator 手动打开窗口。"
  return 1
}

# 检查工程是否已生成
check_project() {
  if [ ! -d "CoinFlip.xcodeproj" ]; then
    echo "❌ 还没有生成工程文件，工程文件 CoinFlip.xcodeproj 不见了，请重新下载项目"
    exit 1
  fi
}
