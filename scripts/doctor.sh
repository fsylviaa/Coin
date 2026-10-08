#!/bin/bash
# 环境检查：把排查问题需要的信息一次性打印出来。
# 用法：./scripts/doctor.sh   然后把全部输出复制给 Claude。

cd "$(dirname "$0")/.." || exit 1

echo "===== 1. Xcode 位置 ====="
echo "xcode-select -p : $(xcode-select -p 2>&1)"
xcodebuild -version 2>&1 | head -2

echo
echo "===== 2. Simulator.app 在不在 ====="
for p in \
  "$(xcode-select -p)/Applications/Simulator.app" \
  "/Applications/Xcode.app/Contents/Developer/Applications/Simulator.app" \
  "/Applications/Xcode-beta.app/Contents/Developer/Applications/Simulator.app"
do
  [ -d "$p" ] && echo "找到: $p" || echo "没有: $p"
done
echo "按名字查找:"
mdfind "kMDItemCFBundleIdentifier == 'com.apple.iphonesimulator'" 2>/dev/null | head -5
echo "（上面一行都没有就说明系统也搜不到）"

echo
echo "===== 3. 已安装的模拟器系统 ====="
xcrun simctl list runtimes 2>&1 | head -10

echo
echo "===== 4. 可用的 iPhone 模拟器（最多显示 5 个）====="
xcrun simctl list devices available 2>&1 | grep -E '^[[:space:]]+iPhone' | head -5
echo "--- 脚本实际选中的是 ---"
line=$(xcrun simctl list devices available | grep -E '^[[:space:]]+iPhone' | tail -1)
echo "原始行: [$line]"
echo "取出的编号: [$(printf '%s' "$line" | grep -oiE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}')]"
echo "取出的名字: [$(printf '%s' "$line" | sed -E 's/^[[:space:]]*//; s/[[:space:]]*\(.*$//')]"

echo
echo "===== 5. 现在开着的模拟器 ====="
xcrun simctl list devices booted 2>&1 | head -5

echo
echo "===== 6. 检查完毕，请把以上全部内容复制给 Claude ====="
