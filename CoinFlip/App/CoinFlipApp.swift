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

    /// 手指此刻往上拖了多少点。硬币靠它实时跟手。
    @State private var dragUp: CGFloat = 0

    /// 手指此刻横向拖了多少点。硬币靠它实时跟手转动。
    @State private var dragSide: CGFloat = 0

    /// 手指此刻是不是按在屏幕上
    @State private var dragging = false

    /// 刚刚甩出去的那一拨
    @State private var spinImpulse: SpinImpulse?

    /// 盖在硬币上的黑幕。减少动态效果模式下用它遮住换面那一下，
    /// 0 是完全透明。它只做淡入淡出，不缩放不移动——这正是那个模式要的。
    @State private var veil: Double = 0

    /// 最近一次有效上划的速度，显示在调试信息条上
    @State private var lastSpeed: Double = 0

    /// 这一次手势有没有预热过震动器。手指一动就预热，脱手那一帧就不用再忙了。
    @State private var warmedUp = false

    /// 声音与震动
    @State private var feedback = FeedbackPlayer()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CoinSceneView(
                phase: controller.phase,
                startedAt: flipStartedAt,
                dragUp: dragUp,
                onFinished: { controller.finishFlip() },
                dragSide: dragSide,
                dragging: dragging,
                spinImpulse: spinImpulse,
                onSpinTick: { feedback.spinTick() },
                showsHint: controller.showsHint
            )

            // 透明手势板，盖在 3D 画面之上
            SwipeCatcher { translation in
                // 手指移动中：把拖了多远报给画面，硬币实时跟着抬起和转动。
                // 往下拖按 0 算，硬币不会被按进平面里。
                dragging = true
                dragUp = max(-translation.height, 0)
                dragSide = translation.width

                // 手指刚一动就预热震动器。
                // 预热是一次不便宜的主线程操作，放在脱手那一帧做会让起手顿一下；
                // 提前到手势刚开始时做，那会儿画面还没开始演，顿了也看不出来。
                // 上下左右都要算——横拨自旋也要震动。
                if !warmedUp && max(dragUp, abs(dragSide)) > 4 {
                    warmedUp = true
                    feedback.warmUp()
                }

            } onDragEnded: { drag in
                dragUp = 0
                dragSide = 0
                dragging = false
                warmedUp = false

                // ⚠️ 必须先问上划、再问横拨。两者的允许范围有一小段重叠，
                //    重叠时按上划算——想抛却被判成拨，比反过来更让人恼火。
                if case .swipeUp(let speed, let distance) = SwipeDetector.evaluate(
                    translation: drag.translation, velocity: drag.upVelocity
                ) {
                    lastSpeed = speed

                    // 大脑说了算：抛掷中它会返回空，这一划就被忽略
                    if let plan = controller.requestFlip(speed: speed, distance: distance) {
                        let now = Date()
                        flipStartedAt = now

                        if CoinSceneView.reduceMotion {
                            // 不飞不转：画面暗下来，再亮起时结果已经在那里。
                            // 声音也用精简版，否则画面早就结束了耳朵里还在落地。
                            feedback.schedule(
                                plan.simplified(landAt: CoinScene.reduceMotionSwap,
                                                endAt: CoinScene.reduceMotionSeconds),
                                startedAt: now)
                            revealWithoutMotion()
                        } else {
                            // 把这一次所有的磕碰排进队列，画面和声音照的是同一张表
                            feedback.schedule(plan, startedAt: now)
                        }
                    }
                    return
                }

                // 横拨：原地自旋。它不经过大脑——只绕竖直轴转，
                // 朝上的是哪一面完全不受影响，所以结果和存档都不用动。
                if case .spin(let speed) = SwipeDetector.evaluateSpin(
                    translation: drag.translation, velocity: drag.sideVelocity
                ), controller.phase.acceptsFlip {
                    spinImpulse = SpinImpulse(sideSpeed: speed)
                }
                // 两样都不算：硬币会自己缓缓落回平面
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()

            // 黑幕盖住硬币，但不盖底部那行字——那行字该一直看得见
            Color.black
                .ignoresSafeArea()
                .opacity(veil)
                .allowsHitTesting(false)

            VStack {
                Spacer()
                StatusLine(phase: controller.phase, speed: lastSpeed)
            }
            .allowsHitTesting(false)        // 这行字不抢手势
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear { controller.start() }
        .onChange(of: scenePhase) { _, phase in handle(phase) }
    }
}

extension RootView {

    /// 减少动态效果模式下的揭晓：画面暗下去，再亮起来。
    ///
    /// 全程只有透明度在变，没有任何缩放、旋转或位移——
    /// 这正是前庭敏感的人需要的。换面那一下发生在全黑的时候，所以看不见跳变。
    private func revealWithoutMotion() {
        let swap = CoinScene.reduceMotionSwap
        let total = CoinScene.reduceMotionSeconds

        withAnimation(.easeIn(duration: swap)) { veil = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + swap) {
            withAnimation(.easeOut(duration: total - swap)) { veil = 0 }
        }
    }

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
            dragUp = 0
            dragSide = 0
            dragging = false
            veil = 0            // 别把黑幕留在屏幕上

        @unknown default:
            break
        }
    }
}

/// 屏幕底部那一行字。正式版里这是整个 App 唯一的文字。
///
/// 它既是给用户看的（硬币现在是什么状态、结果是哪一面），
/// 也是核对用的——写着 Luna，硬币朝上的就必须是月面。
/// 这个对照在开发时抓过错，所以这行字不只是装饰。
///
/// 用词跟着币面上的拉丁文走：日面刻的是 SOL INVICTUS，月面是 LUNA REGINA。
/// 所以不说 Sun / Moon，说 Sol / Luna。
///
/// ⚠️ 它常驻正式版。原来 V1 需求写的是"界面无文字"，这一条已经改了，
///    两份文档都同步过。改动这里之前先看一眼文档，别又改回去。
private struct StatusLine: View {

    let phase: CoinPhase
    let speed: Double

    var body: some View {
        Text(text)
            // 衬线体，和币面上的拉丁文是一路的；字距拉开，少量文字才站得住
            .font(.system(size: 12, weight: .regular, design: .serif))
            .tracking(2.6)
            .foregroundStyle(.white.opacity(0.34))
            .padding(.bottom, 18)
            // 换词时淡入淡出，不要硬切——它现在是体验的一部分，不是调试输出
            .contentTransition(.opacity)
            .animation(.easeInOut(duration: 0.38), value: text)
            .accessibilityLabel(spokenText)
    }

    private var text: String {
        #if DEBUG
        // 开发版多挂一个上划速度，调手感时要看。正式版没有。
        if case .flipping = phase { return "Coin: \(word) · \(Int(speed))" }
        #endif
        return "Coin: \(word)"
    }

    private var word: String {
        switch phase {
        case .waiting:              return "Ready"
        case .flipping:             return "Tossing"
        case .resting(let face):    return face == .sun ? "Sol" : "Luna"
        }
    }

    /// 旁白读出来的版本。Sol / Luna 对看不见屏幕的人没有意义，所以说日面月面。
    private var spokenText: String {
        switch phase {
        case .waiting:              return "硬币静止，上划抛出"
        case .flipping:             return "抛掷中"
        case .resting(let face):    return face == .sun ? "结果：日面" : "结果：月面"
        }
    }
}
