// 3D 舞台：把硬币摆在屏幕上，并按时间表让它动起来。对应任务 T13、T16、T17。
//
// 一次完整的"仪式"分四段：
//     ① 等待   硬币微微悬浮呼吸、极缓慢地倾斜，像悬在空中的一枚实物
//     ② 抛掷   腾空翻滚 → 落地 → 连弹三下 → 转速渐慢
//     ③ 落定   静止不动
//     ④ 特写   镜头缓缓推近，把结果端到眼前，并保持住
//   下一次上划时，镜头先快速拉回常态，再开始抛。
//
// ★ 关键约定（以后换模型、换贴图都必须守住）★
//     硬币绕 X 轴旋转。角度 0° 时日面朝向观众，180° 时月面朝向观众。
// 技术文档第 10 号坑说的就是这个——换素材时正反面搞反，结果会全部相反。

import SwiftUI
import RealityKit
import UIKit

/// 场景的尺寸与节奏设定。T23 调手感时主要改这里。
///
/// 镜头是"绕着硬币看"的：由离地角度和距离决定位置，始终望向硬币。
/// 角度低时硬币显得很扁，像躺在桌面上；角度高时才看得清图案。
enum CoinScene {

    // 硬币
    static let coinRadius: Float = 0.33
    static let coinThickness: Float = 0.055

    // 常态镜头：低角度看过去，硬币是一枚躺在平面上的扁椭圆
    static let elevationFar: Float = 28          // 离地角度（度）
    static let distanceFar: Float = 3.3
    /// 镜头望向的点比硬币高一点，硬币就落在画面偏下，上方留出飞行空间
    static let lookUpFar: Float = 0.20

    // 特写镜头：绕到上方俯看，图案完整呈现
    static let elevationNear: Float = 78
    static let distanceNear: Float = 2.5
    static let lookUpNear: Float = 0.04

    static let fieldOfView: Float = 40

    /// 推近用多久（秒）。慢，才有端到眼前的从容感
    static let zoomInSeconds: Double = 1.1

    /// 镜头比硬币停稳提前多少秒开始推近，让两段动作接上，中间不空拍
    static let zoomLeadSeconds: Double = 0.5
    /// 拉回用多久。快，不耽误下一次抛掷
    static let zoomOutSeconds: Double = 0.22

    /// 揭晓之后多久没人碰，镜头自己退回远景（P06）
    static let idlePullBackAfter: Double = 10
    /// 自己退回远景用多久。和抛掷时那种 0.22 秒的快退不同，这是没人看的时候
    /// 悄悄换景，要慢、两头都软
    static let idlePullBackSeconds: Double = 2.6

    /// 双指张开到原来的几倍，镜头从远景一路推到特写（P07）。
    /// 用对数换算：张开一倍和捏回一半走的距离一样，手感对称
    static let pinchFullRange: Double = 2.0
    /// 双指松开后吸到远景或特写，大约多久停稳。
    ///
    /// ★ 用不过冲的弹簧，接着松手那一刻的速度往下走。★
    ///   第一版用"每帧靠近一点"、从零速度重新起步，松手时手指的速度断了一截，
    ///   加上捏到头时硬停，作者看着"躺下的那一刻、特写的那一刻停得太突然"。
    static let pinchSnapSeconds: Double = 0.7
    static var pinchSnapRate: Double { 4.7 / pinchSnapSeconds }

    /// 捏到头之后还能再"拉过去"多少（推近程度的单位）。
    /// 越往外越拉不动，像 iPhone 列表拉到顶的橡皮筋，松手再软软弹回来。
    static let pinchOvershoot: Double = 0.06

    /// 双指缩放中，镜头推近的程度（0 远景 ~ 1 特写，两头各有一点橡皮筋余量）
    static func pinchZoom(from start: Double, scale: Double) -> Double {
        let raw = start + log(max(scale, 0.01)) / log(pinchFullRange)
        let m = pinchOvershoot
        if raw > 1 { return 1 + m * (1 - exp(-(raw - 1) / m)) }
        if raw < 0 { return -m * (1 - exp(raw / m)) }
        return raw
    }

    /// 自动退回远景时，第 elapsed 秒镜头推近的程度（1 特写 → 0 远景）。
    ///
    /// ★ 用两头都软的曲线，不用"每帧靠近一点"。★ 后者一开始最快，
    ///   镜头会突然一动——背景"突然下转"就是这么栽过的（P02）。
    static func pullBackZoom(from start: Double, elapsed: Double) -> Double {
        let p = min(max(elapsed / idlePullBackSeconds, 0), 1)
        let eased = p * p * p * (p * (p * 6 - 15) + 10)     // 起步、收尾都是零速度
        return start * (1 - eased)
    }

    /// 把时间表里的高度（米）换算成场景里的高度
    static let heightScale: Float = 0.85

    // 亮度。整体偏暗或偏亮时，优先调这两个。
    /// 环境反射的强弱。这是"档位"，每加 1 就亮一倍。
    static let environmentStops: Float = 1.9
    /// 所有灯的总亮度倍数。
    /// 金属几乎不吃这几盏灯，它的明暗主要来自环境反射。
    /// 灯开大了反而会把亮暗之间填平，硬币就发灰了，所以这个数很小。
    static let lightGain: Float = 0.35

    // 跟手拖拽
    /// 手指能把硬币从平面上提起多高（场景单位）。到顶就不再升，避免拖出画面。
    static let maxDragLift: Float = 0.30
    /// 手指往上划多少点，硬币就提到大约七成高。数字越小越"轻飘"。
    static let dragSoftness: Float = 150
    /// 提到最高时硬币歪多少度，像被从桌面上掀起一角
    static let dragTilt: Float = 16
    /// 跟手的黏滞感。越小越贴手指，太小会显得生硬
    static let dragFollowSeconds: Double = 0.045
    /// 松手但没甩出去时，落回平面要多久
    static let dragReturnSeconds: Double = 0.22

    // 减少动态效果（系统辅助功能，前庭敏感的人会开）。
    //
    // 开着的时候：**不飞、不翻、不推镜头、镜头也不游移**。
    // 上划之后画面短暂暗下来，再亮起时结果已经摆在那里。
    // 震动和声音保留——它们不引起眩晕，而且是这个 App 重要的一半。
    /// 从上划到结果显出来，一共多久
    static let reduceMotionSeconds: Double = 0.75
    /// 第几秒换面。这一刻画面正好全黑，所以切换看不见
    static let reduceMotionSwap: Double = 0.30

    // 横拨自旋：停稳后横着一拨，硬币原地转几圈再缓缓停下。
    //
    // ★ 它永远不改变朝上的是哪一面。★ 只绕竖直轴转，结果完全不受影响，
    //   所以整件事做在画面层就够了——状态机、存档、一致性测试一行都不用动。
    /// 手指横向划 1 点，硬币转多少度。跟手的紧密程度
    static let spinPerPoint: Float = 0.78
    /// 甩出去时，手指速度（点/秒）换成角速度（度/秒）的倍数
    static let spinSpeedScale: Float = 0.78
    /// 角速度上限（度/秒）。再快图案就糊成一片了
    static let spinMaxSpeed: Float = 900
    /// 转速掉到十分之一需要多少秒。越大转得越久
    static let spinDecaySeconds: Double = 2.1
    /// 慢到这个角速度就算停了，免得无限趋近永远不停
    static let spinStopSpeed: Float = 10
    /// 每转过多少度，手上响一下轻微的震动
    static let spinTickDegrees: Float = 60
    /// 两次震动之间至少隔多久。转太快时宁可少震几下，也不能让震动把画面拖住
    static let spinTickMinInterval: Double = 0.07

    // 首次上划引导。
    //
    // 界面上没有按钮也没有文字，新用户是不知道要上划的。
    // 所以让硬币自己被轻轻提起又落回——不解释、不写字，手会懂。
    // 用的就是跟手拖拽那套抬升，所以引导演示的动作和真正要做的动作一模一样。
    //
    // ★ 它不会自己停。★ 一直邀请到用户真的成功抛出第一次为止——
    //   没学会之前就把提示收走，等于没提示。学会之后就永远不再出现。
    /// 先静静待一会儿，让人看清这是一枚静止的硬币，再开始提示
    static let hintDelay: Double = 1.0
    /// 提到"手指能提到的最高处"的多少。小一点，是邀请不是演示
    static let hintRise: Float = 0.36
    static let hintUpSeconds: Double = 0.34       // 提起：快起慢停
    static let hintDownSeconds: Double = 0.54     // 落回：慢一些，有重量
    static let hintGapSeconds: Double = 0.44      // 两次之间停一下
    /// 一次完整的"提起—落回—停顿"有多久
    static var hintCycle: Double { hintUpSeconds + hintDownSeconds + hintGapSeconds }

    // 等待时的镜头微动。
    // 硬币是躺在平面上的，自己不该浮起来，所以改成镜头极缓慢地游移，
    // 画面有呼吸感，物理上也说得通。
    static let driftYaw: Float = 5.5             // 左右游移幅度（度）
    static let driftElevation: Float = 2.0       // 高低游移幅度（度）
    static let driftYawPeriod: Double = 13.0
    static let driftElevationPeriod: Double = 9.0

    // 远景的呼吸感（P05）。只在"远景、没人碰"的时候有，其余时候缓缓收掉。
    //
    // ★ 全部靠"每帧转一点点"实现，不换材质。★ 换材质正是以前卡顿的地方。
    //
    // A 高光流动：硬币倒映的那个环境（night_env）极慢地来回转，
    //   币面上的高光就像有人在旁边缓缓移动台灯。硬币本身一动不动。
    static let breathEnvYaw: Float = 18          // 左右转多少度
    static let breathEnvYawPeriod: Double = 14.0
    static let breathEnvTilt: Float = 6          // 上下俯仰多少度，和左右错开节奏，流得更自然
    static let breathEnvTiltPeriod: Double = 11.0
    // 银河流转：背景在原有位置上再极慢地漂一点，像夜空在缓缓转动。
    // ★ 幅度不能大 ★ 星空只铺了镜头看得到的那一片，左右余量约 8°（见 StarField.Patch）
    static let skyDriftYaw: Float = 3
    static let skyDriftYawPeriod: Double = 40.0
    static let skyDriftTilt: Float = 1.5
    static let skyDriftTiltPeriod: Double = 31.0
    /// 呼吸感从有到无（或反过来）要多久。一抛起来就缓缓收掉，不是戛然而止
    static let breathFadeSeconds: Double = 1.2
}

/// 甩出去的那一拨。
///
/// 时间戳是用来辨认"这是不是新的一次"的——画面每帧都会读到同一个值，
/// 没有它就会把同一拨反复加速上去。
struct SpinImpulse: Equatable {
    let degreesPerSecond: Float
    let at: Date

    /// 从手指的横向速度换算。往右为正，并且封了顶，再使劲也不会糊成一片。
    init(sideSpeed: Double, at: Date = Date()) {
        let raw = Float(sideSpeed) * CoinScene.spinSpeedScale
        self.degreesPerSecond = min(max(raw, -CoinScene.spinMaxSpeed), CoinScene.spinMaxSpeed)
        self.at = at
    }
}

/// 在每一帧之间保存状态的小盒子。
///
/// 为什么需要它：画面每帧都要知道"现在在抛什么、什么时候脱手的"，
/// 但每帧回调是在场景搭好时注册的，拿不到后来变化的值。
/// 所以用这个盒子当中转站——外面把最新的值放进来，每帧回调从里面取。
@Observable
final class CoinSceneState {
    var coin: Entity?
    var camera: Entity?
    /// 贴地的那片阴影。只建一次，之后每帧只改缩放和透明度。
    var shadow: ModelEntity?
    /// 上一次用的阴影透明度档位，跨档才换材质
    var shadowStep: Int = -1
    var phase: CoinPhase = .waiting
    var startedAt: Date?
    var onFinished: () -> Void = {}

    /// 这一次的"演完了"通知只发一次，不要每帧都发
    var finishReported = false
    /// 镜头推近的程度：0 是常态，1 是特写
    var zoom: Double = 0
    /// 手指从按下到现在往上拖了多少点（屏幕点）
    var dragUp: CGFloat = 0
    /// 硬币当前被提起多高。它平滑地追 dragUp，所以松手会自己落回去。
    var lift: Float = 0
    /// 硬币**最低点**离平面多高。阴影看的是它，不是圆心——
    /// 歪着的硬币圆心被顶得很高，但它明明还贴在地上。
    var contactHeight: Float = 0
    /// 硬币此刻离躺平多少度（0~90）。阴影按它减淡。
    var coinTilt: Float = 0
    /// 脱手那一刻硬币已经被提到多高。飞行时要从这个高度接上，不能跳。
    var launchLift: Float = 0

    // ── 横拨自旋 ──
    /// 硬币静置时绕竖直轴转到了哪个角度（度）。
    ///
    /// ★ 它必须被"静置姿态"用上。★ 不然自旋停在某个角度后，
    ///   下一帧摆成不带转角的静置姿态，硬币会原地弹回去——
    ///   和当初落地那一刻突然扭 72 度是同一个坑。
    var restYaw: Float = 0
    /// 当前角速度（度/秒）。甩出去之后一路衰减到 0
    var spinVelocity: Float = 0
    /// 手指按下那一刻的转角。拖动期间以它为基准跟手
    var yawAtTouchDown: Float = 0
    /// 手指此刻横向拖了多少点
    var dragSide: CGFloat = 0
    var dragging = false
    /// 距离上一次自旋震动，又转过了多少度
    var yawSinceTick: Float = 0
    var lastTickAt: Date?
    /// 已经处理过的那一次甩动。靠时间戳辨认，避免同一次被加速两遍
    var lastImpulseAt: Date?
    var onSpinTick: () -> Void = {}

    /// 引导是什么时候开始的。为空表示不放引导。
    /// 手指一按下就重置，松手后重新从静止开始邀请。
    var hintStartedAt: Date?

    /// 上一帧是什么时候，用来算每帧间隔
    var lastTick: Date?
    /// 等待状态是从什么时候开始的，用来算呼吸的相位
    var idleSince = Date()

    // ── 银河背景（P02）──
    var starField: Entity?
    /// 背景此刻"看起来"处在镜头的哪个角度。它慢半拍地追着镜头，见 updateSky。
    /// 为空表示还没开始追（第一帧直接对齐，不要从别处滑过来）
    var skyElevation: Float?
    var skyYaw: Float = 0
    /// 背景此刻转动的速度（度/秒）。弹簧式地追，需要记住速度
    var skyElevationSpeed: Float = 0
    var skyYawSpeed: Float = 0

    // ── 远景与呼吸（P05）──
    /// 冷启动后停在远景，直到第一次抛出。抛过之后揭晓时才推成特写
    var holdFar = true
    /// 硬币倒映的环境光，转它就是"高光流动"
    var environmentLight: Entity?
    /// 呼吸感此刻有几成（0~1）。远景没人碰时慢慢升到 1，其余时候慢慢落回 0
    var breath: Float = 0
    /// 呼吸的时钟，从 App 打开算起。用它而不是"进入远景的时刻"，
    /// 呼吸收掉再回来时相位接得上
    let breathStart = Date()

    // ── 揭晓后自动退回远景（P06）──
    /// 上一次有人碰（或者状态刚变）的时刻，从这里开始数 10 秒
    var lastActivity = Date()
    /// 正在自动退回远景：从什么时候开始、当时推近到几成。为空表示没在退
    var pullBackStart: Date?
    var pullBackFrom: Double = 1

    // ── 双指缩放（P07）──
    var pinching = false
    var pinchScale: Double = 1
    /// 第二根手指落下那一刻镜头推近到几成，缩放从这里接着走
    var pinchZoomStart: Double = 0
    /// 松手后正在吸向远景或特写；吸到位时轻震一下
    var pinchSnapping = false
    /// 镜头推近程度此刻的变化速度（每秒）。缩放中一路量着，松手后弹簧接着它走
    var zoomSpeed: Double = 0
    /// 减少动态效果下，用户自己捏到了特写（镜头平时一律停在远景）
    var pinchChoseNear = false
    var onPinchSnap: () -> Void = {}
}

struct CoinSceneView: View {

    /// 硬币现在处于什么状态。画面根据它决定演哪一段。
    var phase: CoinPhase

    /// 这一次抛掷是什么时候脱手的
    var startedAt: Date?

    /// 手指此刻往上拖了多少点。硬币靠它实时跟手。
    var dragUp: CGFloat = 0

    /// 动画演完时调用一次
    var onFinished: () -> Void = {}

    /// 手指此刻横向拖了多少点。硬币靠它实时跟手转动
    var dragSide: CGFloat = 0

    /// 手指此刻是不是按在屏幕上
    var dragging: Bool = false

    /// 刚刚甩出去的那一拨。时间戳用来辨认是不是新的一次
    var spinImpulse: SpinImpulse?

    /// 自旋每转过一个刻度调用一次，用来出震动
    var onSpinTick: () -> Void = {}

    /// 要不要放首次上划引导
    var showsHint: Bool = false

    /// 双指缩放中两指距离的倍数，为空表示没在缩放（P07）
    var pinchScale: CGFloat? = nil
    /// 松手后镜头吸到位的那一下
    var onPinchSnap: () -> Void = {}

    @State private var state = CoinSceneState()

    var body: some View {
        RealityView { content in
            // 银河星空（P02）：最先放，离得最远，其余东西都画在它前面
            let starField = StarField.make()
            content.add(starField)
            state.starField = starField

            let coin = makeCoin()
            coin.name = "coin"
            content.add(coin)
            // 硬币底下的承托光（P03 方案 A）。
            // P02 曾把原来那圈白色光晕删掉，结果影子跟着看不见了——
            // 影子只能把亮的东西压暗，底下全是暗的星空就没东西可压，硬币也像飘着。
            // 现在加回来的是一小片冷蓝银色的暗光，和银河一个色调（见 make_assets.py）。
            content.add(GroundShadow.makeGround())

            let shadow = GroundShadow.makeShadow()
            content.add(shadow)
            state.shadow = shadow

            content.add(makeLights())

            let camera = makeCamera()
            content.add(camera)

            state.coin = coin
            state.camera = camera
            coin.transform.rotation = Self.restingRotation(for: phase.currentFace)

            // 环境反射。读不出来就跳过，硬币仍由上面那组灯照亮。
            if let environment = await StudioEnvironment.load() {
                let light = StudioEnvironment.makeLight(environment, for: coin)
                content.add(light)
                state.environmentLight = light
            }

            // 跟着画面刷新走：每画一帧，系统就调一次这里。
            // 比自己起计时器更准，也不会在没动画时白白耗电。
            _ = content.subscribe(to: SceneEvents.Update.self) { _ in
                tick()
            }

        } update: { _ in
            if state.phase != phase {
                // 刚从抛掷切回等待，呼吸要从头开始，不然会突然跳一下
                if case .waiting = phase { state.idleSince = Date() }
                if case .flipping = phase {
                    // 抛过一次之后，揭晓时就推成特写了（冷启动那段远景到此为止）
                    state.holdFar = false
                    // 脱手这一刻硬币已经被手指提到一定高度，
                    // 记下来，飞行曲线要从这里接上，不能从地面重新开始。
                    state.launchLift = state.lift
                    state.lift = 0
                    // 新的一抛：转角归零，飞行中的朝向由时间表接管
                    state.restYaw = 0
                    state.spinVelocity = 0
                    state.yawSinceTick = 0
                }
                state.phase = phase
                state.finishReported = false
                state.lastActivity = Date()
                state.pullBackStart = nil
                state.pinchChoseNear = false
                state.pinchSnapping = false     // 吸附途中直接抛了：交还给平常的镜头，不再补那一下轻震
            }
            state.startedAt = startedAt
            state.onFinished = onFinished
            state.onSpinTick = onSpinTick
            state.dragUp = dragUp
            state.dragSide = dragSide

            // 手指刚按下：记住此刻的转角，拖动期间以它为基准；并掐掉残余的自旋
            if dragging != state.dragging {
                state.dragging = dragging
                if dragging {
                    state.yawAtTouchDown = state.restYaw
                    state.spinVelocity = 0
                }
            }

            // 刚甩出去的一拨。同一次只能加速一遍，所以用时间戳辨认
            if let impulse = spinImpulse, impulse.at != state.lastImpulseAt {
                state.lastImpulseAt = impulse.at
                state.spinVelocity = impulse.degreesPerSecond
            }

            // 双指缩放（P07）：开始时记下镜头位置，松开时决定吸到远景还是特写
            state.onPinchSnap = onPinchSnap
            if let scale = pinchScale {
                if !state.pinching {
                    state.pinching = true
                    state.pinchZoomStart = state.zoom
                    state.pullBackStart = nil
                    state.pinchSnapping = false
                    state.zoomSpeed = 0
                }
                state.pinchScale = Double(scale)
            } else if state.pinching {
                state.pinching = false
                if case .resting = state.phase {
                    // 过了一半就吸到特写，不到一半就吸回远景
                    let near = state.zoom >= 0.5
                    state.holdFar = !near
                    state.pinchChoseNear = near
                    state.pinchSnapping = true
                }
                state.lastActivity = Date()
            }

            // 引导一直放到成功抛出第一次为止。
            // 那一刻大脑会把 showsHint 置为 false，这里就自然收掉了。
            if showsHint, state.hintStartedAt == nil { state.hintStartedAt = Date() }
            if !showsHint { state.hintStartedAt = nil }
        }
        .background(.black)
        .ignoresSafeArea()
    }

    // MARK: - 每帧推进

    private func tick() {
        let now = Date()
        let dt = min(now.timeIntervalSince(state.lastTick ?? now), 0.05)
        state.lastTick = now

        updateLift(dt: dt, now: now)
        updateSpin(dt: dt, now: now)
        updateCamera(dt: dt, now: now)
        updateCoin(now: now)
        updateShadow()
    }

    /// 硬币歪着的时候，圆心被边缘顶起多高。
    ///
    /// 一枚半径 R、半厚 h 的圆饼歪 θ 度时，最低点在圆心下方
    /// R·sinθ + h·cosθ 处。躺平时这个值正好是 h，也就是现在的摆法，
    /// 所以减掉 h，得到的就是"因为歪着而多出来的那一截"。
    ///
    /// 真硬币躺下的过程里圆心本来就是一路降下来的，所以这不只是修 bug，
    /// 看着也更像那么回事。
    static func pivotLift(tiltDegrees: Double) -> Float {
        guard tiltDegrees > 0 else { return 0 }
        let a = Float(tiltDegrees * .pi / 180)
        let h = CoinScene.coinThickness / 2
        return CoinScene.coinRadius * sin(a) + h * cos(a) - h
    }

    /// 硬币转到这个累计角度时，离躺平还有多少度（0~90）。
    ///
    /// 翻转是绕横轴转的，转过 180 度又是平的（只是换了一面），
    /// 所以先对 180 取余，再把超过 90 的折回来。
    static func tiltFromFlat(degrees: Double) -> Float {
        let m = abs(degrees).truncatingRemainder(dividingBy: 180)
        return Float(m > 90 ? 180 - m : m)
    }

    /// 系统的"减少动态效果"开着没有。
    ///
    /// 每帧读一次。它是一个缓存好的系统设置，很便宜；
    /// 而且用户可能在 App 开着的时候去设置里改，所以不能只在启动时读一次。
    static var reduceMotion: Bool { UIAccessibility.isReduceMotionEnabled }

    /// 让阴影跟上硬币此刻的位置和高度。
    ///
    /// 放在摆完硬币之后，所以读到的永远是这一帧的真实位置——
    /// 飞行、弹跳、跟手抬起都走同一条路，不会出现阴影跳一下的情况。
    ///
    /// 开了系统的"减少动态效果"时，阴影固定在贴地那一档不再变化，
    /// 既保留了承托感，也不会有随高度收放的动态。
    private func updateShadow() {
        guard let shadow = state.shadow, let coin = state.coin else { return }

        // 用最低点而不是圆心：歪着的硬币圆心被顶得很高，
        // 但它还贴在地上，阴影这时候不该散开
        let position = Self.reduceMotion
            ? SIMD3<Float>(coin.position.x, 0, coin.position.z)
            : SIMD3<Float>(coin.position.x, state.contactHeight, coin.position.z)
        state.shadowStep = GroundShadow.update(shadow,
                                               coinPosition: position,
                                               tiltDegrees: Self.reduceMotion ? 0 : state.coinTilt,
                                               lastStep: state.shadowStep)
    }

    /// 手指把硬币提起多高。
    ///
    /// 不是手指移多少硬币就移多少——那样一甩就飞出画面。
    /// 用的是"越往上越使不上劲"的曲线：开头跟得很紧，接近上限时几乎提不动了，
    /// 像真的在对抗某种阻力。
    private func liftTarget(for dragUp: CGFloat) -> Float {
        guard dragUp > 0 else { return 0 }
        let d = Float(dragUp)
        return CoinScene.maxDragLift * (1 - exp(-d / CoinScene.dragSoftness))
    }

    /// 让硬币平滑地追上手指。
    ///
    /// 往上追得紧（贴手），松手落回时慢一些（有重量感）。
    /// 因为是"每帧往目标靠一点"，松手时目标自动变成 0，硬币就自己落回去了，
    /// 不需要单独写一段"回弹动画"。
    private func updateLift(dt: Double, now: Date) {
        if case .flipping = state.phase { return }

        var target = liftTarget(for: state.dragUp)

        // 引导：没人碰的时候，硬币自己把自己提起来又放下，一遍一遍地邀请
        if let startedAt = state.hintStartedAt {
            if state.dragUp > 0 {
                // 手指按下了，引导让位；松手后从头的静止开始重新邀请，
                // 这样不会出现"人刚碰一下，硬币自己又动起来"的别扭
                state.hintStartedAt = now
            } else {
                target = max(target, Self.hintLift(elapsed: now.timeIntervalSince(startedAt)))
            }
        }
        let seconds = target > state.lift
            ? CoinScene.dragFollowSeconds
            : CoinScene.dragReturnSeconds
        let k = Float(1 - exp(-dt / max(seconds / 3, 0.0001)))
        state.lift += (target - state.lift) * k
    }

    /// 横拨自旋：手指拖着它转，松手后带着余速继续转，一路衰减到停。
    ///
    /// 整件事只改绕竖直轴的转角，**不碰朝上的是哪一面**，所以它完全待在画面层，
    /// 不经过大脑、不进存档、不影响任何一致性测试。
    private func updateSpin(dt: Double, now: Date) {
        if case .flipping = state.phase {        // 抛掷中由时间表接管朝向
            state.spinVelocity = 0
            return
        }

        let before = state.restYaw

        if state.dragging {
            // 跟手：手指划到哪，硬币就转到哪。以按下那一刻的角度为基准
            state.restYaw = state.yawAtTouchDown
                + Float(state.dragSide) * CoinScene.spinPerPoint
        } else if state.spinVelocity != 0 {
            state.restYaw += state.spinVelocity * Float(dt)
            state.spinVelocity = Self.decayedSpin(state.spinVelocity, dt: dt)
        }

        tickSpin(turned: abs(state.restYaw - before), now: now)
    }

    /// 角速度随时间衰减。转得越久越慢，慢到一定程度就直接停住。
    static func decayedSpin(_ velocity: Float, dt: Double) -> Float {
        // 衰减到十分之一要 spinDecaySeconds 秒，换算成指数衰减的时间常数
        let tau = CoinScene.spinDecaySeconds / log(10)
        let next = velocity * Float(exp(-dt / tau))
        return abs(next) < CoinScene.spinStopSpeed ? 0 : next
    }

    /// 每转过一个刻度，手上响一下。
    ///
    /// 不调轻重、只调疏密——转得快"嗒嗒嗒"就密，慢下来就稀，
    /// 和真硬币在桌上转的感觉一致，而且比改强度省事得多。
    ///
    /// 还设了一个最短间隔：转得飞快时宁可少震几下，也不能让震动把画面拖住。
    /// 这是上一轮卡顿的教训。
    private func tickSpin(turned: Float, now: Date) {
        guard turned > 0 else { return }
        state.yawSinceTick += turned
        guard state.yawSinceTick >= CoinScene.spinTickDegrees else { return }
        state.yawSinceTick = 0

        if let last = state.lastTickAt,
           now.timeIntervalSince(last) < CoinScene.spinTickMinInterval { return }
        state.lastTickAt = now
        state.onSpinTick()
    }

    /// 引导进行到第 elapsed 秒时，硬币该被提起多高。
    ///
    /// 周而复始，不会自己停——收不收由大脑决定（成功抛出第一次就收）。
    static func hintLift(elapsed: Double) -> Float {
        let t = elapsed - CoinScene.hintDelay
        guard t >= 0 else { return 0 }            // 还在开头那段静止里

        let cycle = CoinScene.hintCycle
        let p = t.truncatingRemainder(dividingBy: cycle)
        let shape: Double
        if p < CoinScene.hintUpSeconds {
            // 提起：一开始快，接近顶点时收住，像被一只看不见的手拎起来
            let x = p / CoinScene.hintUpSeconds
            shape = 1 - pow(1 - x, 3)
        } else if p < CoinScene.hintUpSeconds + CoinScene.hintDownSeconds {
            // 落回：两头慢中间快，有重量
            let x = (p - CoinScene.hintUpSeconds) / CoinScene.hintDownSeconds
            shape = 1 - (3 * x * x - 2 * x * x * x)
        } else {
            shape = 0                              // 两次之间歇一下
        }
        // 夹到 0~1 之间。
        // 不夹的话，在"落回"正好走完的那一帧（x 恰好是 1），
        // 1 − (3x² − 2x³) 这个式子会因为浮点误差算出 −2e-16 这样的极小负数，
        // 硬币等于被往地面里按了一下。数值上看不见，但负的高度本身就是错的。
        return Float(min(max(shape, 0), 1)) * CoinScene.maxDragLift * CoinScene.hintRise
    }

    /// 镜头：落定之后缓缓绕到上方并推近，一旦开抛就迅速退回低角度常态。
    ///
    /// 用的是"每帧往目标靠一点"的办法，所以中途改变目标也不会跳——
    /// 比如特写还没到位就上划了，它会从当前位置平滑地退回去。
    private func updateCamera(dt: Double, now: Date) {
        guard let camera = state.camera else { return }

        checkIdlePullBack(now: now)

        let target: Double = {
            // 减少动态效果：镜头不自己动；只有用户自己双指捏到特写时才停在特写（P07）
            if Self.reduceMotion {
                if case .resting = state.phase, state.pinchChoseNear { return 1 }
                return 0
            }
            // 手指一按住往上带，就先退回常态景别，给接下来的抛掷腾出空间
            if state.dragUp > 10 { return 0 }
            // 冷启动：停在远景，看着硬币躺在银河上；抛过一次之后才推近揭晓（P05）
            if case .resting = state.phase { return state.holdFar ? 0 : 1 }
            // 不等彻底停稳就开始抬镜头。摇摆的最后那一段幅度已经很小，
            // 非要等它走完，画面上就会空出一拍，像卡住了。
            if case .flipping(let plan) = state.phase, let startedAt = state.startedAt {
                let t = now.timeIntervalSince(startedAt)
                if t >= plan.endTime - CoinScene.zoomLeadSeconds { return 1 }
            }
            return 0
        }()

        if state.pinching, case .resting = state.phase {
            // 双指缩放中：镜头直接跟着手指走，不经过平滑（P07）。
            // 顺便量着速度，松手后弹簧要接着这个速度走，不能断档
            let next = CoinScene.pinchZoom(from: state.pinchZoomStart, scale: state.pinchScale)
            if dt > 0 {
                state.zoomSpeed = 0.6 * state.zoomSpeed + 0.4 * (next - state.zoom) / dt
            }
            state.zoom = next
        } else if state.pinchSnapping {
            // 松手后：不过冲的弹簧，从松手那一刻的速度起步，慢慢软着陆
            let w = CoinScene.pinchSnapRate
            let a = w * w * (target - state.zoom) - 2 * w * state.zoomSpeed
            state.zoomSpeed += a * dt
            state.zoom += state.zoomSpeed * dt
            // 真正停稳了才轻震，像卡进了档位
            if abs(target - state.zoom) < 0.004, abs(state.zoomSpeed) < 0.05 {
                state.zoom = target
                state.zoomSpeed = 0
                state.pinchSnapping = false
                state.onPinchSnap()
            }
        } else if let start = state.pullBackStart {
            // 揭晓后没人碰，正在慢慢退回远景（P06）
            state.zoom = CoinScene.pullBackZoom(from: state.pullBackFrom,
                                                elapsed: now.timeIntervalSince(start))
            if now.timeIntervalSince(start) >= CoinScene.idlePullBackSeconds {
                state.pullBackStart = nil
            }
        } else {
            let seconds = target > state.zoom ? CoinScene.zoomInSeconds : CoinScene.zoomOutSeconds
            // 指数逼近：离目标越近走得越慢，自带缓入缓出的味道
            let k = 1 - exp(-dt / max(seconds / 3, 0.0001))
            state.zoom += (target - state.zoom) * k
        }

        let z = Float(state.zoom)
        var elevation = lerp(CoinScene.elevationFar, CoinScene.elevationNear, z)
        let distance = lerp(CoinScene.distanceFar, CoinScene.distanceNear, z)
        let lookUp = lerp(CoinScene.lookUpFar, CoinScene.lookUpNear, z)
        var yaw: Float = 0

        // 远景、没人碰的时候：镜头极缓慢地游移 + 呼吸（P05）。
        // 原来只在"等待"时游移，并且一抛就戛然而止；现在按呼吸的权重缓缓收放，
        // 冷启动停在远景的那段也有。
        // 减少动态效果下这一项也要停——持续不断的缓慢移动正是最容易引起不适的那种
        updateBreath(dt: dt)
        if state.breath > 0 {
            let e = now.timeIntervalSince(state.idleSince)
            yaw = state.breath * CoinScene.driftYaw
                * Float(sin(e * 2 * .pi / CoinScene.driftYawPeriod))
            elevation += state.breath * CoinScene.driftElevation
                * Float(sin(e * 2 * .pi / CoinScene.driftElevationPeriod + 0.7))
        }
        breatheEnvironment(now: now)

        let er = elevation * .pi / 180
        let yr = yaw * .pi / 180
        let lookAt = SIMD3<Float>(0, lookUp, 0)
        let position = lookAt + distance * SIMD3<Float>(
            sin(yr) * cos(er),
            sin(er),
            cos(yr) * cos(er)
        )
        camera.position = position
        camera.look(at: lookAt, from: position, relativeTo: nil)

        updateSky(cameraElevation: elevation, cameraYaw: yaw, dt: dt)
    }

    /// 揭晓后 10 秒没人碰，就悄悄退回远景（P06）。
    ///
    /// "有人碰"包括：手指按着、往上提、横拨让它转着。转着的时候不算闲着，
    /// 停下来才开始数。
    ///
    /// ★ 退的途中一碰：当作"我还在看"，平滑地回到特写，重新数 10 秒。★
    ///   第一版只是停掉慢退、却把"停在远景"留着，于是改走抛掷时那种 0.22 秒的
    ///   快退，作者看到的是"直接躺下了"。
    ///   要是这一碰其实是往上划着要抛，镜头照常快退——那是抛掷本来的样子。
    private func checkIdlePullBack(now: Date) {
        let busy = state.dragging || state.dragUp > 0 || state.spinVelocity != 0 || state.pinching
        if busy {
            state.lastActivity = now
            if state.pullBackStart != nil {
                state.pullBackStart = nil
                state.holdFar = false
            }
            return
        }
        guard case .resting = state.phase, !state.holdFar, !Self.reduceMotion else { return }
        if now.timeIntervalSince(state.lastActivity) >= CoinScene.idlePullBackAfter {
            state.holdFar = true                 // 从此停在远景，和冷启动一样，有呼吸
            state.pullBackStart = now
            state.pullBackFrom = state.zoom
        }
    }

    /// 现在算不算"远景、没人碰"：这时才有游移和呼吸
    private var isIdleFar: Bool {
        if Self.reduceMotion || state.dragging || state.dragUp > 10 || state.pinching { return false }
        switch state.phase {
        case .waiting: return true
        case .resting: return state.holdFar
        case .flipping: return false
        }
    }

    /// 呼吸感的权重缓缓追向目标：进远景慢慢起来，一抛就慢慢收掉，都不突兀
    private func updateBreath(dt: Double) {
        let target: Float = isIdleFar ? 1 : 0
        let k = Float(1 - exp(-dt / max(CoinScene.breathFadeSeconds / 3, 0.0001)))
        state.breath += (target - state.breath) * k
        if state.breath < 0.0005 && target == 0 { state.breath = 0 }
    }

    /// A 高光流动：转硬币倒映的那个环境，币面高光就缓缓流过去（P05）
    private func breatheEnvironment(now: Date) {
        guard let light = state.environmentLight else { return }
        let t = now.timeIntervalSince(state.breathStart)
        let yaw = state.breath * CoinScene.breathEnvYaw
            * Float(sin(t * 2 * .pi / CoinScene.breathEnvYawPeriod))
        let tilt = state.breath * CoinScene.breathEnvTilt
            * Float(sin(t * 2 * .pi / CoinScene.breathEnvTiltPeriod + 1.3))
        light.orientation = simd_quatf(angle: yaw * .pi / 180, axis: [0, 1, 0])
            * simd_quatf(angle: tilt * .pi / 180, axis: [1, 0, 0])
    }

    /// 银河流转：在背景原有朝向上再叠一点极慢的漂移（P05）
    private func skyDrift(now: Date) -> simd_quatf {
        let t = now.timeIntervalSince(state.breathStart)
        let yaw = state.breath * CoinScene.skyDriftYaw
            * Float(sin(t * 2 * .pi / CoinScene.skyDriftYawPeriod))
        let tilt = state.breath * CoinScene.skyDriftTilt
            * Float(sin(t * 2 * .pi / CoinScene.skyDriftTiltPeriod + 2.1))
        return simd_quatf(angle: yaw * .pi / 180, axis: [0, 1, 0])
            * simd_quatf(angle: tilt * .pi / 180, axis: [1, 0, 0])
    }

    /// 背景慢半拍地追着镜头走（P02）。
    ///
    /// 银河钉在远处不动的话，镜头一动它就整片扫过去：抛起那一下镜头 0.22 秒
    /// 从特写退回远景，背景也刷地扫过一大片，然后跟着镜头一下子停住——
    /// 停住那一刻正好是硬币飞向最高点的时候，作者看着像"卡了一下"。
    ///
    /// 所以背景自己转一点，抵掉镜头的一部分动作：
    ///   • 只走镜头的三成（StarField.followShare），整体慢下来
    ///   • 像挂在弹簧上一样追（StarField.settleSeconds）：从静止慢慢起步、
    ///     中段最快、再慢慢收住。镜头猛地一动，背景只是缓缓滑开，
    ///     硬币从最高点落下时它还在滑，三秒左右才落定——这就是"余韵"。
    ///   ★ 第一版用的是"每帧靠近一点"，一开始最快，作者看着是"突然下转"。★
    ///
    /// 每帧只改一下它的朝向，不换材质、不改形状，开销可以忽略。
    private func updateSky(cameraElevation: Float, cameraYaw: Float, dt: Double) {
        guard let sky = state.starField else { return }
        let target = StarField.seenAngles(cameraElevation: cameraElevation,
                                          cameraYaw: cameraYaw)
        if let current = state.skyElevation {
            // 不过冲的弹簧：拉力 = rate² × 差距，阻力 = 2 × rate × 速度
            let w = Float(StarField.springRate)
            let t = Float(min(dt, 0.05))      // 偶尔一帧很长时别让弹簧一步跨过头
            let aE = w * w * (target.elevation - current) - 2 * w * state.skyElevationSpeed
            state.skyElevationSpeed += aE * t
            state.skyElevation = current + state.skyElevationSpeed * t
            let aY = w * w * (target.yaw - state.skyYaw) - 2 * w * state.skyYawSpeed
            state.skyYawSpeed += aY * t
            state.skyYaw += state.skyYawSpeed * t
        } else {
            state.skyElevation = target.elevation
            state.skyYaw = target.yaw
        }
        sky.orientation = skyDrift(now: Date()) * StarField.orientation(cameraElevation: cameraElevation,
                                                cameraYaw: cameraYaw,
                                                seenElevation: state.skyElevation ?? target.elevation,
                                                seenYaw: state.skyYaw)
    }

    private func lerp(_ a: Float, _ b: Float, _ t: Float) -> Float { a + (b - a) * t }

    /// 硬币：抛掷中照时间表演，其余时候安静地躺在平面上。
    private func updateCoin(now: Date) {
        guard let coin = state.coin else { return }

        switch state.phase {

        case .flipping(let plan):
            guard let startedAt = state.startedAt else { return }
            let t = now.timeIntervalSince(startedAt)

            // 减少动态效果：硬币原地不动，到点直接换成结果那一面。
            // 换面这一下由外层的黑幕盖住，所以看不到突兀的跳变。
            if Self.reduceMotion {
                applyLift(to: coin,
                          face: t < CoinScene.reduceMotionSwap ? plan.startFace : plan.result)
                if t >= CoinScene.reduceMotionSeconds, !state.finishReported {
                    state.finishReported = true
                    let notify = state.onFinished
                    DispatchQueue.main.async { notify() }
                }
                return
            }

            let pose = FlipAnimator.pose(at: t, plan: plan,
                                         heightScale: Double(CoinScene.heightScale))

            // 脱手时硬币已经被提到 launchLift，飞行曲线要从那里接上，
            // 否则会看到硬币先"掉"回地面再飞起来。
            // 这段额外高度在升到最高点前均匀让渡给抛物线本身。
            let carry = plan.landTime > 0
                ? state.launchLift * Float(max(0, 1 - t / plan.landTime))
                : 0

            // ★ 歪着的硬币，圆心是被边缘顶起来的。★
            //   不算这一下，圆心按 0 摆，下半边就沉到地面那张圆片以下了——
            //   地面会在币面上切出一道笔直的边。这是模型本身的错，
            //   不是渲染的错，所以修在这里，而不是去跟渲染顺序较劲。
            let contact = Float(pose.height) + carry
            state.contactHeight = contact
            // 真实的倾角要从累计翻转角折算——pose.tiltDegrees 是摇停用的，
            // 飞行中几乎是 0，拿它算阴影会让翻滚时的影子一直是满的
            state.coinTilt = Self.tiltFromFlat(degrees: pose.degrees)
            coin.position = [0, contact + Self.pivotLift(tiltDegrees: pose.tiltDegrees), 0]

            if pose.isFinished {
                // 停稳时摆成干净的躺平姿态，不留累加的零头。
                // 这是技术文档第 2 号坑：不归零的话抛多了姿态会越来越歪。
                coin.transform.rotation = Self.restingRotation(for: plan.result)
                if !state.finishReported {
                    state.finishReported = true
                    // 挪到这一帧画完之后再通知。
                    // 这里是渲染回调里，当场改状态会让 SwiftUI 在一帧中途
                    // 重建整棵界面树，正好卡在硬币停稳那一刻，看起来就是顿一下。
                    let notify = state.onFinished
                    DispatchQueue.main.async { notify() }
                }
            } else {
                coin.transform.rotation = Self.flightRotation(
                    startFace: plan.startFace,
                    degrees: Float(pose.degrees),
                    wobbleDegrees: Float(pose.wobbleDegrees)
                )
            }

        case .waiting:
            applyLift(to: coin, face: .sun)

        case .resting(let face):
            applyLift(to: coin, face: face)
        }
    }

    /// 没在抛的时候：硬币躺在平面上，但会跟着手指被提起来。
    ///
    /// 提起的同时让它歪一点，像被从桌面上掀起一角——
    /// 纯粹平移上升看着像"浮空"，加一点倾斜才有被捏住的实感。
    private func applyLift(to coin: Entity, face: CoinFace) {
        coin.position = [0, state.lift, 0]
        state.contactHeight = state.lift

        let ratio = CoinScene.maxDragLift > 0 ? state.lift / CoinScene.maxDragLift : 0
        let tilt = CoinScene.dragTilt * ratio * .pi / 180
        state.coinTilt = CoinScene.dragTilt * ratio

        // ★ 转角必须加在这里。★ 漏了的话，自旋停下的那一帧硬币会原地弹回正，
        //   和当初落地时突然扭 72 度是同一个坑。
        //   它绕的是竖直轴，所以只改朝向，不改朝上的是哪一面。
        let yaw = simd_quatf(angle: state.restYaw * .pi / 180, axis: [0, 1, 0])
        coin.transform.rotation = yaw
            * simd_quatf(angle: tilt, axis: [1, 0, 0])
            * Self.restingRotation(for: face)
    }

    // MARK: - 姿态
    //
    // ★ 关键约定 ★
    // 硬币平躺在水平面上，图案朝天。贴图所在的面在模型里朝向 +Z，
    // 所以绕横轴转 -90° 就让日面朝上，再加 180° 就换成月面朝上。
    // 每多转半圈（180°）就换一次朝上的面——整个结果正确性都建立在这条上。

    /// 躺平时，指定的一面朝上
    static func restingRotation(for face: CoinFace) -> simd_quatf {
        simd_quatf(angle: baseAngle(for: face) * .pi / 180, axis: [1, 0, 0])
    }

    /// 某一面朝上时，横轴该转到多少度
    static func baseAngle(for face: CoinFace) -> Float {
        face == .sun ? -90 : 90
    }

    /// 飞行与摇摆中的姿态。
    ///
    /// 先按抛之前朝上的那一面定好起始角，再加上这一刻累计翻转的度数；
    /// 外面再套一层绕竖直轴的旋转，那是落地后在平面上打转的方位——
    /// 绕竖直轴转不会改变朝上的是哪一面，所以不影响结果。
    static func flightRotation(startFace: CoinFace,
                               degrees: Float,
                               wobbleDegrees: Float) -> simd_quatf {
        let tumble = simd_quatf(angle: (baseAngle(for: startFace) + degrees) * .pi / 180,
                                axis: [1, 0, 0])
        let spin = simd_quatf(angle: wobbleDegrees * .pi / 180, axis: [0, 1, 0])
        return spin * tumble
    }

    // MARK: - 搭建硬币

    /// 硬币由三部分拼成：
    ///   • 中间一块银色圆柱，提供厚度和侧边
    ///   • 前面一张圆形贴图（日面）
    ///   • 后面一张圆形贴图（月面），转过去背对前面
    ///
    /// 为什么不直接给圆柱的两个端面贴不同的图：
    /// RealityKit 对圆柱端面的贴图方式没有保证，不同系统版本可能不一样。
    /// 用两张独立的圆面最稳妥，正反面绝不会贴混。
    private func makeCoin() -> Entity {
        let style = StyleProfile.silver
        let coin = Entity()

        let body = ModelEntity(
            mesh: .generateCylinder(height: CoinScene.coinThickness,
                                    radius: CoinScene.coinRadius),
            materials: [bodyMaterial()]
        )
        body.transform.rotation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
        coin.addChild(body)

        // 侧边的滚花与刻字。
        // 套在饼身外面一丁点，和两个币面一样是"贴上去"的——
        // 自己生成网格是为了能控制贴图怎么绕：横向绕一圈，纵向是厚度。
        let band = ModelEntity(
            mesh: Self.edgeMesh(radius: CoinScene.coinRadius + 0.0012,
                                thickness: CoinScene.coinThickness),
            materials: [edgeMaterial(textureNamed: style.textureEdge)]
        )
        coin.addChild(band)

        // 贴图稍微浮出饼身一丁点，避免和饼身表面重叠闪烁
        let offset = CoinScene.coinThickness / 2 + 0.0015

        let sunFace = ModelEntity(
            mesh: Self.discMesh(radius: CoinScene.coinRadius),
            materials: [faceMaterial(textureNamed: style.textureSun)]
        )
        sunFace.position = [0, 0, offset]
        coin.addChild(sunFace)

        let moonFace = ModelEntity(
            mesh: Self.discMesh(radius: CoinScene.coinRadius),
            materials: [faceMaterial(textureNamed: style.textureMoon)]
        )
        moonFace.position = [0, 0, -offset]
        moonFace.transform.rotation = simd_quatf(angle: .pi, axis: [0, 1, 0])
        coin.addChild(moonFace)

        return coin
    }

    /// 做一个正圆形的面，正面朝向 +Z，并把贴图正正好好铺满这个圆。
    ///
    /// 为什么不用现成的方形平面：
    /// 方形平面要靠贴图四角透明才能看起来是圆的，而透明在不同设备上表现不一，
    /// 容易露出方块边缘。自己生成圆形网格最保险，形状由几何决定，与透明无关。
    static func discMesh(radius: Float, segments: Int = 128) -> MeshResource {
        var positions: [SIMD3<Float>] = [[0, 0, 0]]
        var normals: [SIMD3<Float>] = [[0, 0, 1]]
        var uvs: [SIMD2<Float>] = [[0.5, 0.5]]

        for i in 0...segments {
            let a = 2 * Float.pi * Float(i) / Float(segments)
            positions.append([radius * cos(a), radius * sin(a), 0])
            normals.append([0, 0, 1])
            // ★ 横向要反着取。★
            //   这里的 u 用 0.5 − 0.5·cos 而不是加，是因为贴到硬币上之后
            //   横向会整个镜像过来：拉丁文会变成 И Я Ǝ 那样的反字。
            //   竖直方向则不用反（反了的话字是上下颠倒，不是左右镜像）。
            uvs.append([0.5 - 0.5 * cos(a), 0.5 - 0.5 * sin(a)])
        }

        var indices: [UInt32] = []
        for i in 1...segments {
            indices += [0, UInt32(i), UInt32(i + 1)]
        }

        var descriptor = MeshDescriptor(name: "coinFace")
        descriptor.positions = MeshBuffer(positions)
        descriptor.normals = MeshBuffer(normals)
        descriptor.textureCoordinates = MeshBuffer(uvs)
        descriptor.primitives = .triangles(indices)

        return (try? MeshResource.generate(from: [descriptor]))
            ?? .generatePlane(width: radius * 2, height: radius * 2)
    }

    /// 侧边那一圈的网格：一个没有盖子的圆筒。
    ///
    /// 为什么不用系统现成的圆柱：现成的那个贴图怎么绕是它说了算，
    /// 滚花会歪、刻字会糊。这里自己定：
    /// 横向（u）绕一圈正好 0 到 1，纵向（v）是硬币的厚度。
    /// 接缝处 u 从 1 回到 0，所以贴图的图案必须能首尾相接——
    /// 滚花是均匀重复的，刻字绕一圈整两遍，都对得上。
    static func edgeMesh(radius: Float, thickness: Float,
                         segments: Int = 192) -> MeshResource {
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var uvs: [SIMD2<Float>] = []
        let half = thickness / 2

        for i in 0...segments {
            let a = 2 * Float.pi * Float(i) / Float(segments)
            // ★ 横向反着取，理由同币面。★ 不反的话边上的刻字是镜像的。
            let u = 1 - Float(i) / Float(segments)
            let c = cos(a), s = sin(a)
            // 法线朝外，所以侧边映出来的是硬币四周的环境
            positions.append([radius * c, radius * s, half])
            positions.append([radius * c, radius * s, -half])
            normals.append([c, s, 0])
            normals.append([c, s, 0])
            uvs.append([u, 0])
            uvs.append([u, 1])
        }

        var indices: [UInt32] = []
        for i in 0..<segments {
            let a = UInt32(i * 2), b = a + 1, c = a + 2, d = a + 3
            // 绕序要让三角形正面朝外，否则整圈会被背面剔除掉、什么都看不见
            indices += [a, b, c, b, d, c]
        }

        var descriptor = MeshDescriptor(name: "coinEdge")
        descriptor.positions = MeshBuffer(positions)
        descriptor.normals = MeshBuffer(normals)
        descriptor.textureCoordinates = MeshBuffer(uvs)
        descriptor.primitives = .triangles(indices)

        return (try? MeshResource.generate(from: [descriptor]))
            ?? .generateCylinder(height: thickness, radius: radius)
    }

    /// 带图案的金属面。
    ///
    /// 用了两张贴图：
    ///   • 彩色图：银面的颜色和图案
    ///   • 法线图：每一点的表面朝向。有了它，手机才能实时算出
    ///     "硬币转到这个角度时，这道浮雕该多亮"——高光会跟着硬币走，
    ///     而不是像印花一样贴死在上面。
    private func faceMaterial(textureNamed name: String) -> RealityKit.Material {
        var material = PhysicallyBasedMaterial()
        // 真正的金属：金属度拉满、表面抛得很光。
        // 金属不靠自己发亮，全靠映出周围的环境——所以必须配合环境贴图，
        // 没有环境的时候金属度高反而会死灰一片。
        material.metallic = 0.98
        material.roughness = 0.13

        if let texture = try? TextureResource.load(named: name) {
            material.baseColor = .init(tint: UIColor(white: 0.96, alpha: 1),
                                       texture: .init(texture))
        } else {
            material.baseColor = .init(tint: UIColor(white: 0.78, alpha: 1))
        }

        // 法线图要按"方向数据"读，不能当成普通图片，
        // 否则系统会给它做色彩校正，起伏就全错了。
        if let normal = try? TextureResource.load(named: name + "_normal",
                                                  options: .init(semantic: .normal)) {
            material.normal = .init(texture: .init(normal))
        }
        return material
    }

    /// 侧边：没有图案的抛光银
    /// 饼身：藏在三张贴图底下的那块实心金属。
    /// 正反面和侧边都是"贴"在它外面一丁点的，所以它几乎看不见，
    /// 存在的意义是从任何角度看过去硬币都是实的，不会漏出里面。
    private func bodyMaterial() -> RealityKit.Material {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: UIColor(white: 0.80, alpha: 1))
        material.metallic = 1.0
        material.roughness = 0.2
        return material
    }

    /// 侧边：滚花与刻字。
    ///
    /// ★ 对比度要低。★ 侧边是配角，它的任务是让硬币在翻滚时边缘有细碎的光在走，
    ///   证明这是一块有厚度的金属，而不是两张纸背靠背。做亮了就会抢正反面的戏。
    ///
    /// 所以起伏几乎全交给法线图（只改反光的方向），彩色贴图基本是平的一片银；
    /// 粗糙度也比正反面高一点，滚花上的光是一片细碎的微光，不是一排小镜子。
    private func edgeMaterial(textureNamed name: String) -> RealityKit.Material {
        var material = PhysicallyBasedMaterial()
        material.metallic = 1.0
        material.roughness = 0.17

        if let color = try? TextureResource.load(named: name) {
            material.baseColor = .init(tint: UIColor(white: 0.97, alpha: 1),
                                       texture: .init(color))
        } else {
            material.baseColor = .init(tint: UIColor(white: 0.88, alpha: 1))
        }
        if let bump = try? TextureResource.load(named: name + "_normal",
                                                options: .init(semantic: .normal)) {
            material.normal = .init(texture: .init(bump))
        }
        return material
    }

    // MARK: - 灯光与摄像机

    private func makeLights() -> Entity {
        let rig = Entity()

        /// 加一盏灯。角度用"从哪个方向照过来"描述，比写坐标直观。
        func addLight(azimuth: Float, elevation: Float,
                      intensity: Float, color: UIColor = .white) {
            let light = DirectionalLight()
            light.light.intensity = intensity * CoinScene.lightGain
            light.light.color = color
            let a = azimuth * .pi / 180
            let e = elevation * .pi / 180
            let from = SIMD3<Float>(sin(a) * cos(e), sin(e), cos(a) * cos(e)) * 4
            light.look(at: .zero, from: from, relativeTo: nil)
            rig.addChild(light)
        }

        // 主灯：左前上方。硬币大部分时候的明暗由它决定。
        addLight(azimuth: -38, elevation: 42, intensity: 1150)

        // 顶灯：正上方。硬币躺平、镜头俯看特写时，主要靠它照亮图案。
        addLight(azimuth: 0, elevation: 84, intensity: 620)

        // 两盏侧灯：左右贴着地平线打过来。
        // 硬币翻滚时，它们会在币面上扫出一道道掠过的高光——
        // 这是这组灯里最重要的两盏，没有它们金属就是一块死板的灰。
        addLight(azimuth: -96, elevation: 9, intensity: 760,
                 color: UIColor(red: 0.92, green: 0.95, blue: 1.0, alpha: 1))
        addLight(azimuth: 98, elevation: 13, intensity: 700,
                 color: UIColor(red: 1.0, green: 0.97, blue: 0.92, alpha: 1))

        // 轮廓灯：从硬币后方斜打，勾出边缘的一道亮线，把硬币从黑底里拎出来。
        addLight(azimuth: 158, elevation: 30, intensity: 540)

        // 补光：右下方很弱的一盏，免得背光那侧黑成一团。
        addLight(azimuth: 46, elevation: -22, intensity: 230,
                 color: UIColor(red: 0.86, green: 0.90, blue: 1.0, alpha: 1))

        return rig
    }

    /// 摄像机。
    /// 它的位置每一帧由 updateCamera 按"离地角度 + 距离"重新算，
    /// 这里只给一个合理的初始位置，免得第一帧出现在原点。
    private func makeCamera() -> Entity {
        let camera = PerspectiveCamera()
        camera.camera.fieldOfViewInDegrees = CoinScene.fieldOfView

        let er = CoinScene.elevationFar * .pi / 180
        let lookAt = SIMD3<Float>(0, CoinScene.lookUpFar, 0)
        let position = lookAt + CoinScene.distanceFar * SIMD3<Float>(0, sin(er), cos(er))
        camera.position = position
        camera.look(at: lookAt, from: position, relativeTo: nil)
        return camera
    }
}
