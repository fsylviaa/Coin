// 猛摇手机时，硬币在整个屏幕里四处乱撞（2026-10，作者要的）。
//
// ★ 手机就是一个盒子，屏幕就是盒子的玻璃窗。★
//   猛地一摇，硬币被甩起来，撞到屏幕四边弹回来，在空中翻、立着、躺着都有可能，
//   落回玻璃上再弹、再滚，最后自己躺平。轻轻歪手机还是原来那套（ShakeModel，慢慢滑）。
//
// ★ 不改结果（作者定的）。★
//   乱撞的时候随便翻，但收尾时如果是另一面朝上，会在最后一下自己再翻回来，
//   停稳时一定是原来那面朝上——底部那行字和朝上的面永远一致。乱撞不算一次抛，不进记录。
//
// ★ 镜头不动（作者定的）。★ 盒子的四壁就是镜头看得到的四条边（视锥的四个面），
//   硬币碰到屏幕边就弹回来，永远不出画。
//
// 这里只做数学（一个简化的刚体：一枚有厚度的圆片），不碰画面、不碰感应器，
// 所以能用自动测试验收（ChaosModelTests）。
//
// 坐标：场景坐标，y 朝上；玻璃（地面）在 y = -厚度/2，平躺时圆心在 y = 0。
// 朝向：orientation 把"这一面的法线"从 +y 转到现在的方向。所以法线朝上 = 原来那面朝上。

import simd

struct ChaosModel {

    // MARK: - 调校参数

    /// 摇得这么猛（g）才开始乱撞。比上下摇小颠（0.55g）猛得多，轻轻歪、轻轻晃不会触发
    static let startAccel: Float = 1.3
    /// 乱撞时的重力（场景单位/秒²）。比抛掷（5，故意放慢的）重，落回得快、跟手
    static let gravity: Float = 9
    /// 手机每 1g 的加速度，硬币因为惯性往反方向受多大的推力（场景单位/秒²）。
    /// 9 → 45：作者说猛摇时硬币跟不上手。现在每秒摇 5 下，硬币每秒撞墙十几下，
    /// 几乎每一甩都能从一边撞到另一边
    static let shakeGain: Float = 45
    /// 刚开始乱撞那一下，额外给多大的速度（每 1g，场景单位/秒）
    static let startKick: Float = 1.1
    /// 落回玻璃弹起几成速度
    static let floorBounce: Float = 0.45
    /// 撞屏幕边弹回几成速度
    static let wallBounce: Float = 0.6
    /// 玻璃上的摩擦（越大，落地时越容易被"绊"得翻滚）
    static let friction: Float = 0.35
    /// 空气阻力、转动阻力（每秒衰减多少）
    static let airDrag: Float = 0.2
    static let spinDrag: Float = 0.5
    /// 速度、转速上限，免得一下甩得太离谱
    static let maxSpeed: Float = 14
    static let maxSpin: Float = 28
    /// 停止猛摇多久之后才开始收尾（秒）
    static let calmSeconds: Float = 0.45
    /// 不摇了这么久还没停下，也强行收尾（秒）
    static let forceSettleSeconds: Float = 2.5
    /// 最后躺平那一下用多久（秒）
    static let settleSeconds: Float = 0.45
    /// 另一面朝上时，自己翻回来的那一跳有多高（场景单位）
    static let rightingHop: Float = 0.16
    /// 撞得多重才出声（场景单位/秒）；两声之间至少隔多久（秒）
    static let knockMinSpeed: Float = 0.25
    static let knockGap: Float = 0.06
    /// 离镜头最远到哪（场景 z）。再远硬币就太小了
    static let farthestZ: Float = -1.6
    /// 离镜头最近到哪（沿视线的距离）。再近，画面横着放不下一整枚硬币，左右两堵墙会互相顶
    static let nearestDistance: Float = 2.3
    /// 撞墙时擦出的翻滚有多猛
    static let wallSpin: Float = 1.4

    // MARK: - 盒子

    /// 一面墙：硬币圆心到墙的距离 dot(normal, p) - offset 不能小于 margin
    struct Wall: Equatable {
        var normal: SIMD3<Float>
        var offset: Float
    }

    /// 镜头看得到的四条边 + 最远处，做成盒子的墙。法线都朝里。
    static func frustumWalls(camera c: SIMD3<Float>, forward f: SIMD3<Float>,
                             up u: SIMD3<Float>, right r: SIMD3<Float>,
                             tanV: Float, tanH: Float) -> [Wall] {
        let normals = [
            simd_normalize(r + f * tanH),     // 左边
            simd_normalize(-r + f * tanH),    // 右边
            simd_normalize(-u + f * tanV),    // 上边
            simd_normalize(u + f * tanV),     // 下边
        ]
        var walls = normals.map { Wall(normal: $0, offset: simd_dot($0, c)) }
        walls.append(Wall(normal: [0, 0, 1], offset: farthestZ))
        walls.append(Wall(normal: f, offset: simd_dot(f, c) + nearestDistance))
        return walls
    }

    // MARK: - 状态

    enum Phase: Equatable {
        case tumbling       // 乱撞中
        case righting       // 另一面朝上，正在自己翻回来
        case settling       // 最后躺平
        case done
    }

    let radius: Float
    let thickness: Float
    let walls: [Wall]
    /// 收尾时硬币要回到这个圆以内（和 ShakeModel 的软边一致）
    let homeRadius: Float

    private(set) var position: SIMD3<Float>
    private(set) var velocity: SIMD3<Float>
    private(set) var orientation: simd_quatf
    /// 角速度（场景坐标，弧度/秒）
    private(set) var spin: SIMD3<Float>
    private(set) var phase: Phase = .tumbling
    /// 这一帧撞得多重（0~1）。0 表示这一帧没有要出声的碰撞
    private(set) var impact: Float = 0

    private var quiet: Float = 0
    private var sinceKnock: Float = 1
    private var rightingTime: Float = 0
    private var settleStart: (p: SIMD3<Float>, q: simd_quatf)?
    private var settleTarget: (p: SIMD3<Float>, q: simd_quatf)?
    private var settleT: Float = 0

    /// 从硬币此刻的样子开始乱撞
    /// - Parameters:
    ///   - kick: 触发那一下手机的加速度（场景坐标，单位 g）
    init(position: SIMD3<Float>, yaw: Float, kick: SIMD3<Float>,
         radius: Float, thickness: Float, walls: [Wall], homeRadius: Float) {
        self.radius = radius
        self.thickness = thickness
        self.walls = walls
        self.homeRadius = homeRadius
        self.position = position
        self.orientation = simd_quatf(angle: yaw, axis: [0, 1, 0])
        // 惯性：手机往哪边猛地一动，硬币就往反方向甩；再往上抛一点，让它离开玻璃
        let k = -kick * Self.startKick
        self.velocity = SIMD3<Float>(k.x, abs(k.y) + abs(k.z) * 0.6 + 1.2, k.z)
        // 甩出去时带一点翻滚，方向跟着甩的方向
        let side = SIMD3<Float>(k.x, 0, k.z)
        let axis = simd_length(side) > 1e-3
            ? simd_normalize(simd_cross([0, 1, 0], side))
            : SIMD3<Float>(1, 0, 0)
        self.spin = axis * min(simd_length(kick) * 6, Self.maxSpin)
    }

    // MARK: - 推进一帧

    /// - Parameters:
    ///   - accel: 手机此刻的晃动加速度（已换到场景坐标，单位 g）
    mutating func step(dt: Float, accel: SIMD3<Float>) {
        guard dt > 0, phase != .done else { return }
        impact = 0
        sinceKnock += dt

        let shaking = simd_length(accel) > Self.startAccel * 0.6
        quiet = shaking ? 0 : quiet + dt

        // 又猛摇了：不管在收尾还是在翻回来，都回到乱撞
        if shaking && (phase == .settling || phase == .righting) {
            phase = .tumbling
            settleStart = nil
        }

        switch phase {
        case .tumbling, .righting:
            integrate(dt: dt, accel: phase == .tumbling ? accel : .zero)
            collideWalls()
            if phase == .righting {
                rightingTime -= dt
                if rightingTime <= 0 || velocity.y < 0 && lowestHeight < 0.02 { phase = .tumbling }
                else { break }
            }
            collideFloor()
            pushInsideWalls()       // 被玻璃顶起来以后可能又蹭出了屏幕边，再推回来
            checkCalm()
        case .settling:
            settle(dt: dt)
        case .done:
            break
        }
    }

    // MARK: - 结果

    /// 原来那面朝上没有
    var faceUp: Bool { orientation.act([0, 1, 0]).y > 0 }

    /// 离平躺歪了多少度（0 平躺，90 立着）
    var tiltDegrees: Float {
        let n = orientation.act([0, 1, 0])
        return acos(min(abs(n.y), 1)) * 180 / .pi
    }

    /// 硬币最低点离玻璃多高（阴影用）
    var lowestHeight: Float { lowestPoint().y - floorY }

    /// 绕竖直方向转了多少（弧度）。收尾后交给 restYaw，接得上
    var yaw: Float {
        let x = orientation.act([1, 0, 0])
        return atan2(-x.z, x.x)
    }

    var isDone: Bool { phase == .done }

    // MARK: - 内部

    private var floorY: Float { -thickness / 2 }

    /// 圆片上离玻璃最近的那一点
    private func lowestPoint() -> SIMD3<Float> {
        let n = orientation.act([0, 1, 0])
        let down = SIMD3<Float>(0, -1, 0)
        // 厚度：朝下的那个面
        let face = -n * (n.y >= 0 ? 1 : -1) * (thickness / 2)
        // 边缘：圆片平面里最朝下的方向
        let radial = down - simd_dot(down, n) * n
        let len = simd_length(radial)
        let rim = len > 1e-4 ? radial / len * radius : .zero
        return position + face + rim
    }

    private func inverseInertia(_ torque: SIMD3<Float>) -> SIMD3<Float> {
        // 薄圆片：绕自身法线 1/2 r²，绕直径 1/4 r² + h²/12（质量算 1）
        let axial = 0.5 * radius * radius
        let diameter = 0.25 * radius * radius + thickness * thickness / 12
        let local = orientation.inverse.act(torque)
        let solved = SIMD3<Float>(local.x / diameter, local.y / axial, local.z / diameter)
        return orientation.act(solved)
    }

    private mutating func integrate(dt: Float, accel: SIMD3<Float>) {
        velocity += (SIMD3<Float>(0, -Self.gravity, 0) - accel * Self.shakeGain) * dt
        velocity *= exp(-Self.airDrag * dt)
        spin *= exp(-Self.spinDrag * dt)
        if simd_length(velocity) > Self.maxSpeed { velocity = simd_normalize(velocity) * Self.maxSpeed }
        if simd_length(spin) > Self.maxSpin { spin = simd_normalize(spin) * Self.maxSpin }

        position += velocity * dt
        let w = simd_length(spin)
        if w > 1e-6 {
            orientation = simd_normalize(simd_quatf(angle: w * dt, axis: spin / w) * orientation)
        }
    }

    private mutating func collideWalls() {
        for wall in walls {
            let gap = simd_dot(wall.normal, position) - wall.offset - radius
            guard gap < 0 else { continue }
            position -= wall.normal * gap
            let vn = simd_dot(velocity, wall.normal)
            guard vn < 0 else { continue }
            velocity -= (1 + Self.wallBounce) * vn * wall.normal
            // 擦着墙的那一份速度带出一点翻滚
            let tangent = velocity - simd_dot(velocity, wall.normal) * wall.normal
            spin += simd_cross(wall.normal, tangent) * (Self.wallSpin / radius) * min(-vn, 1)
            knock(-vn)
        }
    }

    private mutating func pushInsideWalls() {
        // 角落里两堵墙互相顶，推一遍不一定推干净，多推几遍
        for _ in 0..<4 {
            for wall in walls {
                let gap = simd_dot(wall.normal, position) - wall.offset - radius
                if gap < 0 { position -= wall.normal * gap }
            }
        }
    }

    private mutating func collideFloor() {
        let contact = lowestPoint()
        let depth = floorY - contact.y
        guard depth > 0 else { return }
        position.y += depth

        let up = SIMD3<Float>(0, 1, 0)
        let arm = contact - position
        let vc = velocity + simd_cross(spin, arm)
        let vn = vc.y
        guard vn < 0 else { return }

        // 很慢地贴着玻璃时不弹，免得在原地抖个不停
        let e: Float = -vn < 0.3 ? 0 : Self.floorBounce
        let k = 1 + simd_dot(up, simd_cross(inverseInertia(simd_cross(arm, up)), arm))
        let j = -(1 + e) * vn / k
        velocity += up * j
        spin += inverseInertia(simd_cross(arm, up * j))

        // 摩擦：贴着玻璃滑的那一份被拖住，转成翻滚
        let vc2 = velocity + simd_cross(spin, arm)
        var vt = vc2 - simd_dot(vc2, up) * up
        let speed = simd_length(vt)
        if speed > 1e-5 {
            vt /= speed
            let kt = 1 + simd_dot(vt, simd_cross(inverseInertia(simd_cross(arm, vt)), arm))
            let jt = max(-speed / kt, -Self.friction * j)
            velocity += vt * jt
            spin += inverseInertia(simd_cross(arm, vt * jt))
        }
        knock(-vn)
    }

    private mutating func knock(_ speed: Float) {
        guard speed > Self.knockMinSpeed, sinceKnock >= Self.knockGap else { return }
        impact = max(impact, min(speed / 3, 1))
        sinceKnock = 0
    }

    /// 不摇了、也快停了：原来那面朝上就躺平收尾；另一面朝上就自己翻回来
    private mutating func checkCalm() {
        guard phase == .tumbling, quiet >= Self.calmSeconds else { return }
        // 一般要等它差不多停了才收尾；但万一一直立着滚个没完，不摇了 2.5 秒也强行收尾
        let calm = simd_length(velocity) < 0.8 && lowestHeight < 0.03
        guard calm || quiet >= Self.forceSettleSeconds else { return }
        if faceUp {
            beginSettle()
        } else {
            // 小跳一下，在空中正好翻半圈，落回来就是原来那面朝上
            let up = (2 * Self.gravity * Self.rightingHop).squareRoot()
            let air = 2 * up / Self.gravity
            let n = orientation.act([0, 1, 0])
            var axis = simd_cross(n, [0, 1, 0])
            if simd_length(axis) < 1e-3 { axis = orientation.act([1, 0, 0]) }
            axis = simd_normalize(axis)
            let angle = acos(max(min(n.y, 1), -1))      // 转到法线朝上要转多少
            velocity = SIMD3<Float>(velocity.x * 0.3, up, velocity.z * 0.3)
            spin = axis * (angle / air)
            rightingTime = air
            phase = .righting
            knock(1)
        }
    }

    private mutating func beginSettle() {
        var home = SIMD2<Float>(position.x, position.z)
        if simd_length(home) > homeRadius { home = simd_normalize(home) * homeRadius }
        settleStart = (position, orientation)
        settleTarget = (SIMD3<Float>(home.x, 0, home.y), simd_quatf(angle: yaw, axis: [0, 1, 0]))
        settleT = 0
        velocity = .zero
        spin = .zero
        phase = .settling
    }

    private mutating func settle(dt: Float) {
        guard let start = settleStart, let target = settleTarget else { phase = .done; return }
        settleT = min(settleT + dt / Self.settleSeconds, 1)
        let s = settleT * settleT * (3 - 2 * settleT)
        position = simd_mix(start.p, target.p, SIMD3<Float>(repeating: s))
        orientation = simd_slerp(start.q, target.q, s)
        if settleT >= 1 {
            position = target.p
            orientation = target.q
            phase = .done
        }
    }
}
