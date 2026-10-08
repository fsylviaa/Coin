# CoinFlip 极简抛硬币（最小可用版）

当前状态：**脚手架**。只有目录结构、工程配置和一个占位测试，还没有业务逻辑。

需要：一台装好 **Xcode** 的 Mac（从 App Store 安装，并打开过一次）。
不需要任何第三方代码库或工具，所有功能都用苹果自带的框架（SwiftUI、RealityKit、AVFoundation、UIKit）。

---

## 目录结构

```
CoinFlip/                      ← 项目根目录
├── README.md                  本说明
├── CoinFlip.xcodeproj         Xcode 工程文件，双击即可用 Xcode 打开
├── .gitignore                 告诉 Git 哪些自动生成的文件不用保存
├── docs/                      需求文档、技术文档、任务清单
├── scripts/                   一键脚本
│   ├── setup.sh               检查 Xcode、工程文件和模拟器是否就绪
│   ├── test.sh                运行全部自动测试（等同 Xcode 里按 ⌘U）
│   ├── run.sh                 编译并在 iPhone 模拟器中打开 App
│   └── _common.sh             上面三个脚本共用的小工具，不用单独运行
├── CoinFlip/                  App 本体代码
│   ├── App/                   入口：App 启动后显示的第一个画面
│   ├── Model/                 数据定义：日/月、状态、时间表、风格档案
│   ├── Logic/                 决定与计算：随机器、时间表生成、保存、状态管理
│   ├── Scene/                 3D 画面与上划手势
│   ├── Feedback/              声音与震动
│   ├── Resources/             素材：贴图、音效
│   └── Assets.xcassets        App 图标与系统颜色
└── CoinFlipTests/             自动测试
```

每个文件夹里有一个占位文件，写着这个文件夹以后放什么、对应哪个任务。


---

## 跑起来

在"终端"App 中依次输入：

```bash
cd 你放项目的位置/CoinFlip     # 例如：cd ~/Desktop/CoinFlip
./scripts/setup.sh              # 检查环境
./scripts/test.sh               # 运行测试
./scripts/run.sh                # 在模拟器中打开 App
```

### 成功的样子

| 命令 | 终端最后应显示 |
| --- | --- |
| `setup.sh` | `✅ 环境准备完成` |
| `test.sh` | `✅ 全部测试通过` |
| `run.sh` | `✅ App 已在模拟器中打开…`，并弹出 iPhone 模拟器：全黑屏幕、无状态栏，底部一行灰色小字「CoinFlip 脚手架运行成功」 |

---

## 在真 iPhone 上运行

1. 打开 `CoinFlip.xcodeproj`（运行 `open CoinFlip.xcodeproj`）。
2. 左侧点最上方的 CoinFlip → TARGETS 选 CoinFlip → Signing & Capabilities → Team 选你的 Apple ID。
3. 顶部设备选你的 iPhone，按 `⌘R`。


---

## 常见问题

- **提示 `Permission denied`**：运行 `chmod +x scripts/*.sh` 后重试。
- **提示没有找到 Xcode**：运行 `sudo xcode-select -s /Applications/Xcode.app`。
