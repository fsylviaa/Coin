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
    /// 拉回用多久。快，不耽误下一次抛掷
    static let zoomOutSeconds: Double = 0.22

    /// 把时间表里的高度（米）换算成场景里的高度
    static let heightScale: Float = 0.85

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
    var phase: CoinPhase = .waiting
    var startedAt: Date?
    var onFinished: () -> Void = {}

    /// 这一次的"演完了"通知只发一次，不要每帧都发
    var finishReported = false
    /// 镜头推近的程度：0 是常态，1 是特写
    var zoom: Double = 0
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

    /// 动画演完时调用一次
    var onFinished: () -> Void = {}

    @State private var state = CoinSceneState()

    var body: some View {
        RealityView { content in
            let coin = makeCoin()
            coin.name = "coin"
            content.add(coin)
            content.add(makeLights())

            let camera = makeCamera()
            content.add(camera)

            state.coin = coin
            state.camera = camera
            coin.transform.rotation = Self.restingRotation(for: phase.currentFace)

            // 跟着画面刷新走：每画一帧，系统就调一次这里。
            // 比自己起计时器更准，也不会在没动画时白白耗电。
            _ = content.subscribe(to: SceneEvents.Update.self) { _ in
                tick()
            }

        } update: { _ in
            if state.phase != phase {
                // 刚从抛掷切回等待，呼吸要从头开始，不然会突然跳一下
                if case .waiting = phase { state.idleSince = Date() }
                state.phase = phase
                state.finishReported = false
            }
            state.startedAt = startedAt
            state.onFinished = onFinished
        }
        .background(.black)
        .ignoresSafeArea()
    }

    // MARK: - 每帧推进

    private func tick() {
        let now = Date()
        let dt = min(now.timeIntervalSince(state.lastTick ?? now), 0.05)
        state.lastTick = now

        updateCamera(dt: dt, now: now)
        updateCoin(now: now)
    }

    /// 镜头：落定之后缓缓绕到上方并推近，一旦开抛就迅速退回低角度常态。
    ///
    /// 用的是"每帧往目标靠一点"的办法，所以中途改变目标也不会跳——
    /// 比如特写还没到位就上划了，它会从当前位置平滑地退回去。
    private func updateCamera(dt: Double, now: Date) {
        guard let camera = state.camera else { return }

        let target: Double = {
            if case .resting = state.phase { return 1 }
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
            coin.position = [0, Float(pose.height), 0]

            if pose.isFinished {
                // 停稳时摆成干净的躺平姿态，不留累加的零头。
                // 这是技术文档第 2 号坑：不归零的话抛多了姿态会越来越歪。
                coin.transform.rotation = Self.restingRotation(for: plan.result)
                if !state.finishReported {
                    state.finishReported = true
                    state.onFinished()
                }
            } else {
                coin.transform.rotation = Self.flightRotation(
                    startFace: plan.startFace,
                    degrees: Float(pose.degrees),
                    wobbleDegrees: Float(pose.wobbleDegrees)
                )
            }

        case .waiting:
            // 躺在平面上，一动不动。画面的呼吸感交给镜头的缓慢游移。
            coin.position = .zero
            coin.transform.rotation = Self.restingRotation(for: .sun)

        case .resting(let face):
            coin.position = .zero
            coin.transform.rotation = Self.restingRotation(for: face)
        }
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

    /// 带图案的金属面
    private func faceMaterial(textureNamed name: String) -> RealityKit.Material {
        var material = PhysicallyBasedMaterial()
        // 这个场景里没有环境可供反射，所以金属度调低、靠灯光打出高光，
        // 看起来反而更像有光泽的金属。
        material.metallic = 0.22
        material.roughness = 0.38

        if let texture = try? TextureResource.load(named: name) {
            material.baseColor = .init(tint: UIColor(white: 0.62, alpha: 1),
                                       texture: .init(texture))
        } else {
            material.baseColor = .init(tint: UIColor(white: 0.78, alpha: 1))
        }
        return material
    }

    /// 侧边：没有图案的抛光银
    private func edgeMaterial() -> RealityKit.Material {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: UIColor(white: 0.46, alpha: 1))
        material.metallic = 0.3
        material.roughness = 0.22
        return material
    }

    // MARK: - 灯光与摄像机

    private func makeLights() -> Entity {
        let rig = Entity()

        let key = DirectionalLight()
        key.light.intensity = 1500
        key.light.color = .white
        key.look(at: .zero, from: [-1.1, 1.5, 1.6], relativeTo: nil)
        rig.addChild(key)

        let fill = DirectionalLight()
        fill.light.intensity = 420
        fill.light.color = UIColor(red: 0.84, green: 0.89, blue: 1.0, alpha: 1)
        fill.look(at: .zero, from: [1.5, -1.0, 1.1], relativeTo: nil)
        rig.addChild(fill)

        let front = DirectionalLight()
        front.light.intensity = 260
        front.light.color = .white
        front.look(at: .zero, from: [0, 0.2, 2.0], relativeTo: nil)
        rig.addChild(front)

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
