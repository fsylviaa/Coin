// App 入口。对应任务 T14、T15。
//
// 画面听"大脑"（CoinController）的：启动时读取上次结果，硬币就显示那一面。
// 手势由盖在 3D 画面之上的透明板接收。
//
// 开发版底部有一行小字显示状态，正式版（Release）没有，
// 符合需求"界面无文字"的要求。

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

    /// 最近一次有效上划的速度，显示在调试信息条上
    @State private var lastSpeed: Double = 0

    #if DEBUG
    /// 一共收到过几次拖动（不管算不算上划）。
    /// 它和"速度"配合着看，能分清问题出在哪：
    ///   手势数一直是 0  → 触摸根本没传到手势层
    ///   手势数在涨但速度不动 → 收到了，但没过上划的门槛
    @State private var dragCount = 0
    #endif

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CoinSceneView(face: controller.phase.currentFace)

            // 透明手势板，盖在 3D 画面之上
            SwipeCatcher { translation, velocity in
                #if DEBUG
                dragCount += 1
                #endif
                if case .swipeUp(let speed) = SwipeDetector.evaluate(
                    translation: translation, velocity: velocity
                ) {
                    // T15 先只显示速度，确认手势识别准不准。
                    // T16 会在这里真正调用 controller.requestFlip(speed:)。
                    lastSpeed = speed
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()

            #if DEBUG
            VStack {
                Spacer()
                DebugBar(phase: controller.phase, speed: lastSpeed, dragCount: dragCount)
            }
            .allowsHitTesting(false)        // 信息条不抢手势
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
    let dragCount: Int

    var body: some View {
        Text("状态：\(phaseText) ｜ 结果：\(resultText) ｜ 速度：\(Int(speed)) ｜ 手势：\(dragCount)")
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
