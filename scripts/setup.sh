#!/bin/bash
# 检查开发环境是否就绪。工程文件 CoinFlip.xcodeproj 已随项目提供，不需要额外工具。
source "$(dirname "$0")/_common.sh"

echo "==> [1/2] 检查 Xcode"
DEV_DIR=$(xcode-select -p 2>/dev/null)
if [[ "$DEV_DIR" == *CommandLineTools* ]]; then
  echo "❌ 系统当前指向的是「命令行工具」，不是完整的 Xcode。"
  echo "   请运行：sudo xcode-select -s /Applications/Xcode.app"
  exit 1
fi
if ! xcodebuild -version >/dev/null 2>&1; then
  echo "❌ Xcode 还不能用。请依次运行："
  echo "   sudo xcodebuild -license accept"
  echo "   sudo xcodebuild -runFirstLaunch"
  xcodebuild -version 2>&1 | head -5
  exit 1
fi
xcodebuild -version | head -1

echo "==> [2/2] 检查工程文件与 iPhone 模拟器"
check_project
xcodebuild -list -project CoinFlip.xcodeproj >/dev/null 2>&1 \
  || { echo "❌ 工程文件无法读取，请把下面的输出发给我："; xcodebuild -list -project CoinFlip.xcodeproj 2>&1 | tail -15; exit 1; }
find_simulator
echo "    将使用模拟器：$SIM_NAME"

echo ""
echo "✅ 环境准备完成"
echo "   下一步：./scripts/test.sh 运行测试，或 ./scripts/run.sh 在模拟器里打开 App"
