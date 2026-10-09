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
    /// 脱手那一刻硬币已经被提到多高。飞行时要从这个高度接上，不能跳。
    var launchLift: Float = 0

    /// 引导是什么时候开始的。为空表示不放引导。
    /// 手指一按下就重置，松手后重新从静止开始邀请。
    var hintStartedAt: Date?

    /// 上一帧是什么时候，用来算每帧间隔
    var lastTick: Date?
    /// 等待状态是从什么时候开始的，用来算呼吸的相位
    var idleSince = Date()
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

    /// 要不要放首次上划引导
    var showsHint: Bool = false

    @State private var state = CoinSceneState()

    var body: some View {
        RealityView { content in
            let coin = makeCoin()
            coin.name = "coin"
            content.add(coin)
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
                content.add(StudioEnvironment.makeLight(environment, for: coin))
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
                    // 脱手这一刻硬币已经被手指提到一定高度，
                    // 记下来，飞行曲线要从这里接上，不能从地面重新开始。
                    state.launchLift = state.lift
                    state.lift = 0
                }
                state.phase = phase
                state.finishReported = false
            }
            state.startedAt = startedAt
            state.onFinished = onFinished
            state.dragUp = dragUp

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
        updateCamera(dt: dt, now: now)
        updateCoin(now: now)
        updateShadow()
    }

    /// 让阴影跟上硬币此刻的位置和高度。
    ///
    /// 放在摆完硬币之后，所以读到的永远是这一帧的真实位置——
    /// 飞行、弹跳、跟手抬起都走同一条路，不会出现阴影跳一下的情况。
    ///
    /// 开了系统的"减少动态效果"时，阴影固定在贴地那一档不再变化，
    /// 既保留了承托感，也不会有随高度收放的动态。
    private func updateShadow() {
        guard let shadow = state.shadow, let coin = state.coin else { return }

        let position = UIAccessibility.isReduceMotionEnabled
            ? SIMD3<Float>(coin.position.x, 0, coin.position.z)
            : coin.position
        state.shadowStep = GroundShadow.update(shadow,
                                               coinPosition: position,
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
        return Float(shape) * CoinScene.maxDragLift * CoinScene.hintRise
    }

    /// 镜头：落定之后缓缓绕到上方并推近，一旦开抛就迅速退回低角度常态。
    ///
    /// 用的是"每帧往目标靠一点"的办法，所以中途改变目标也不会跳——
    /// 比如特写还没到位就上划了，它会从当前位置平滑地退回去。
    private func updateCamera(dt: Double, now: Date) {
        guard let camera = state.camera else { return }

        let target: Double = {
            // 手指一按住往上带，就先退回常态景别，给接下来的抛掷腾出空间
            if state.dragUp > 10 { return 0 }
            if case .resting = state.phase { return 1 }
            // 不等彻底停稳就开始抬镜头。摇摆的最后那一段幅度已经很小，
            // 非要等它走完，画面上就会空出一拍，像卡住了。
            if case .flipping(let plan) = state.phase, let startedAt = state.startedAt {
                let t = now.timeIntervalSince(startedAt)
                if t >= plan.endTime - CoinScene.zoomLeadSeconds { return 1 }
            }
            return 0
        }()

        let seconds = target > state.zoom ? CoinScene.zoomInSeconds : CoinScene.zoomOutSeconds
        // 指数逼近：离目标越近走得越慢，自带缓入缓出的味道
        let k = 1 - exp(-dt / max(seconds / 3, 0.0001))
        state.zoom += (target - state.zoom) * k

        let z = Float(state.zoom)
        var elevation = lerp(CoinScene.elevationFar, CoinScene.elevationNear, z)
        let distance = lerp(CoinScene.distanceFar, CoinScene.distanceNear, z)
        let lookUp = lerp(CoinScene.lookUpFar, CoinScene.lookUpNear, z)
        var yaw: Float = 0

        // 等待时让镜头极缓慢地游移，画面不至于死板
        if case .waiting = state.phase {
            let e = now.timeIntervalSince(state.idleSince)
            yaw = CoinScene.driftYaw * Float(sin(e * 2 * .pi / CoinScene.driftYawPeriod))
            elevation += CoinScene.driftElevation
                * Float(sin(e * 2 * .pi / CoinScene.driftElevationPeriod + 0.7))
        }

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
    }

    private func lerp(_ a: Float, _ b: Float, _ t: Float) -> Float { a + (b - a) * t }

    /// 硬币：抛掷中照时间表演，其余时候安静地躺在平面上。
    private func updateCoin(now: Date) {
        guard let coin = state.coin else { return }

        switch state.phase {

        case .flipping(let plan):
            guard let startedAt = state.startedAt else { return }
            let t = now.timeIntervalSince(startedAt)
            let pose = FlipAnimator.pose(at: t, plan: plan,
                                         heightScale: Double(CoinScene.heightScale))

            // 脱手时硬币已经被提到 launchLift，飞行曲线要从那里接上，
            // 否则会看到硬币先"掉"回地面再飞起来。
            // 这段额外高度在升到最高点前均匀让渡给抛物线本身。
            let carry = plan.landTime > 0
                ? state.launchLift * Float(max(0, 1 - t / plan.landTime))
                : 0
            coin.position = [0, Float(pose.height) + carry, 0]

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

        let ratio = CoinScene.maxDragLift > 0 ? state.lift / CoinScene.maxDragLift : 0
        let tilt = CoinScene.dragTilt * ratio * .pi / 180
        coin.transform.rotation = simd_quatf(angle: tilt, axis: [1, 0, 0])
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
            materials: [edgeMaterial()]
        )
        body.transform.rotation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
        coin.addChild(body)

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
            // 贴图的竖直方向是从上往下数的，所以这里要反过来
            uvs.append([0.5 + 0.5 * cos(a), 0.5 - 0.5 * sin(a)])
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
    private func edgeMaterial() -> RealityKit.Material {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: UIColor(white: 0.88, alpha: 1))
        material.metallic = 1.0
        material.roughness = 0.12
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
