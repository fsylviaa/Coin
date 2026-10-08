// App 入口。对应任务 T14。
//
// 到这一步，画面开始听"大脑"（CoinController）的了：
// 启动时读取上次的结果，硬币就显示那一面。
//
// 开发版底部有一行小字，显示当前状态和结果，方便核对。
// 正式版（Release）不会有这行字，符合需求"界面无文字"的要求。

import SwiftUI

@main
struct CoinFlipApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {

    /// 大脑。画面只问它"现在该显示哪一面"，不自己做决定。
    @State private var controller = CoinController()

    /// 最近一次上划的速度，只给调试信息条用。T15 才会真正填进来。
    @State private var lastSpeed: Double = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CoinSceneView(face: controller.phase.currentFace)

            #if DEBUG
            VStack {
                Spacer()
                DebugBar(phase: controller.phase, speed: lastSpeed)
            }
            #endif
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear { controller.start() }
    }
}

#if DEBUG
/// 只在开发版出现的一行小字。
/// 它让你不用看代码，也能核对"信息条说是月，硬币显示的也是月"。
private struct DebugBar: View {

    let phase: CoinPhase
    let speed: Double

    var body: some View {
        Text("状态：\(phaseText) ｜ 结果：\(resultText) ｜ 速度：\(Int(speed))")
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(.gray)
            .padding(.bottom, 10)
    }

    private var phaseText: String {
        switch phase {
        case .waiting:  return "等待中"
        case .flipping: return "抛掷中"
        case .resting:  return "静置中"
        }
    }

    private var resultText: String {
        switch phase {
        case .waiting:              return "无"
        case .flipping(let plan):   return plan.result == .sun ? "日" : "月"
        case .resting(let face):    return face == .sun ? "日" : "月"
        }
    }
}
#endif
