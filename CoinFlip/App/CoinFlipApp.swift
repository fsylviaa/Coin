// App 入口。对应任务 T14、T15、T16。
//
// 一次完整的抛掷是这样走通的：
//   手指上划 → 透明板接到触摸 → 判断是不是有效上划
//     → 问大脑要一张时间表（大脑同时决定结果并存档）
//     → 把时间表交给 3D 画面，画面每帧照着演
//     → 演完通知大脑，状态切回静置
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

    /// App 是在前台、还是被切到后台了
    @Environment(\.scenePhase) private var scenePhase

    /// 大脑。画面只问它"现在该显示哪一面"，不自己做决定。
    @State private var controller = CoinController()

    /// 这一次抛掷是什么时候脱手的。配合时间表算出每一帧该摆成什么样。
    @State private var flipStartedAt: Date?

    /// 最近一次有效上划的速度，显示在调试信息条上
    @State private var lastSpeed: Double = 0

    /// 声音与震动
    @State private var feedback = FeedbackPlayer()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CoinSceneView(
                phase: controller.phase,
                startedAt: flipStartedAt,
                onFinished: { controller.finishFlip() }
            )

            // 透明手势板，盖在 3D 画面之上
            SwipeCatcher { translation, velocity in
                guard case .swipeUp(let speed) = SwipeDetector.evaluate(
                    translation: translation, velocity: velocity
                ) else { return }

                lastSpeed = speed

                // 大脑说了算：抛掷中它会返回空，这一划就被忽略
                if let plan = controller.requestFlip(speed: speed) {
                    let now = Date()
                    flipStartedAt = now
                    feedback.warmUp()
                    // 把这一次所有的磕碰排进队列，画面和声音照的是同一张表
                    feedback.schedule(plan, startedAt: now)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()

            #if DEBUG
            VStack {
                Spacer()
                DebugBar(phase: controller.phase, speed: lastSpeed)
            }
            .allowsHitTesting(false)        // 信息条不抢手势
            #endif
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear { controller.start() }
        .onChange(of: scenePhase) { _, phase in handle(phase) }
    }
}

extension RootView {

    /// 切后台、被来电打断时的处理。对应任务 T22。
    ///
    /// 抛到一半被打断，就**立刻落定为这一次已经决定好的结果**：
    ///   • 不重新随机——结果在上划那一刻就定了，也已经存过档
    ///   • 不续播动画——回来时直接看到结果，不会接着飞
    ///   • 立刻停声，并取消还没响的磕碰，免得回到主屏幕还在响
    ///
    /// 没在抛的时候切后台，什么都不做，保持原状。
    private func handle(_ phase: ScenePhase) {
        switch phase {
        case .active:
            // 回到前台：什么都不做。状态已经在离开时处理好了。
            break

        case .inactive, .background:
            feedback.stopAll()
            controller.interrupt()
            flipStartedAt = nil

        @unknown default:
            break
        }
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
