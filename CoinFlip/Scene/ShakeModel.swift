// 歪手机、晃手机时硬币跟着动（P13，方案 A）。
//
// ★ 手机就是那张桌子。★ 桌子歪多少，硬币就按重力往低处滑多少——
//   像一枚真硬币放在倾斜的玻璃上：
//     • 歪得不够（静摩擦）：一动不动
//     • 歪过门槛：开始滑，而且越滑越快（是加速，不是匀速飘过去）
//     • 滑到边上：轻轻磕一下停住，不出画
//     • 放平：停在原地，不会自己回中间——想让它回来，就往反方向歪
//   第一版用的是"拴在中心的弹簧"，作者看着"像飘着平移过去"，已整个换掉。
//
// ★ 它永远不改变朝上的是哪一面。★
//   只有三样东西会动：贴着地面的位移、离地几厘米的小颠、几度以内的小晃。
//   小晃封顶 5°，离翻面差得远；底部那行字和朝上的面永远一致。
//
// 这里只做数学，不碰画面、不碰感应器，所以能用自动测试验收（ShakeModelTests）。

import simd

struct ShakeModel {

    // MARK: - 调校参数

    /// 手机歪 1g（约 90°）时的下滑加速度（场景单位/秒²）。
    /// 作者要"更沉、滑得慢"：3 → 2，摩擦同时加大。现在歪 10° 约 1.8 秒、20° 约 1 秒、30° 约 0.75 秒滑到边上
    static let gravity: Float = 2
    /// 静摩擦：手机歪过这么多（g，约等于角度的正弦）才开始滑。0.14 ≈ 8°（原 0.09 ≈ 5°）
    static let staticFriction: Float = 0.14
    /// 动摩擦：滑起来之后的阻力。比静摩擦小一点，所以一旦滑动就会滑下去
    static let kineticFriction: Float = 0.1
    /// 手机突然一甩 1g，硬币因为惯性往反方向冲多快（场景单位/秒，每秒 1g 的冲量）
    static let jerkKick: Float = 4
    /// 最远滑到哪（场景单位，硬币半径 0.33）。到这里像碰到软边，轻轻弹回一点停住
    static let maxOffset: Float = 0.24
    /// 碰边时弹回几成速度。作者要"减少触边回弹、碰边微弹"，又要"弹回距离再短、速度缓一些"：
    /// 0.2 → 0.12 → 0.07
    static let wallBounce: Float = 0.07
    /// 撞边多快才出声、震动（场景单位/秒）。轻轻蹭到边不出声
    static let knockMinSpeed: Float = 0.08
    /// 两次碰边声之间至少隔多久（秒），连着碰不会糊成一片
    static let knockGap: Float = 0.12
    /// 慢到这个速度就算停了（场景单位/秒）
    static let restSpeed: Float = 0.01

    /// 晃得够猛（加速度超过这么多 g）才会颠一下
    static let hopThreshold: Float = 0.55
    /// 颠起来最高多高（场景单位）。作者要"颠高一点"：0.025 → 0.06（约 6 厘米）
    static let maxHop: Float = 0.06
    /// 小晃最多几度。★ 远远不到翻面（90°）★
    static let maxWobble: Float = 5

    // MARK: - 状态

    /// 贴着地面的位移：x 是左右，y 是前后（场景里的 z）
    private(set) var offset = SIMD2<Float>(0, 0)
    private(set) var velocity = SIMD2<Float>(0, 0)
    /// 离地多高
    private(set) var hop: Float = 0
    private var hopSpeed: Float = 0
    /// 小晃：绕哪个方向歪、歪多少度
    private(set) var wobble: Float = 0
    private var wobbleSpeed: Float = 0
    private(set) var wobbleAxis = SIMD2<Float>(1, 0)
    /// 这一帧是不是刚碰到边（画面那边据此出声、震动）
    private(set) var hitWall = false
    /// 这一下撞得多重（0~1），决定声音和震动的轻重
    private(set) var wallImpact: Float = 0
    private var sinceKnock: Float = 1
    /// 这一帧是不是刚颠完落回玻璃（画面那边据此"嗒"一声、轻震一下）
    private(set) var hopLanded = false

    // MARK: - 推进一帧

    /// - Parameters:
    ///   - tilt: 手机相对"平常拿着的样子"歪了多少（重力的变化，单位 g；x 往右、y 往屏幕上方）
    ///   - jerk: 手机此刻的晃动加速度（单位 g；x 往右、y 往屏幕上方、z 朝向用户）
    ///   - enabled: 现在允不允许它动。不允许时原地不动（抛掷中、手指按着）
    mutating func step(dt: Float, tilt: SIMD2<Float>, jerk: SIMD3<Float>, enabled: Bool) {
        guard dt > 0 else { return }
        hitWall = false
        wallImpact = 0
        hopLanded = false
        sinceKnock += dt

        if enabled {
            // ★ 只认左右歪（作者要求）。★ 右边低（重力 x 变大）→ 往右滑。
            //   往前、往后歪不算坡——第一版前后也滑，作者不要
            let slope = SIMD2<Float>(tilt.x, 0)
            let speed = simd_length(velocity)
            let steep = simd_length(slope) > Self.staticFriction

            if speed < Self.restSpeed && !steep {
                // 静止、坡又不够陡：纹丝不动
                velocity = .zero
            } else if speed < Self.restSpeed {
                // 刚起步：沿坡往下加速。★ 这里不能清零 ★——摩擦大了以后，
                //   起步那几帧速度还没攒够，清零的话它就卡在原地一顿一顿的
                let dir = simd_normalize(slope)
                velocity += (slope - dir * Self.kineticFriction) * Self.gravity * dt
            } else {
                // 滑动中：重力沿坡往下拉，动摩擦逆着运动方向拖
                let along = velocity / speed
                let accel = slope * Self.gravity - along * Self.kineticFriction * Self.gravity
                // 摩擦只能让它停下，不能把它往回拉
                let next = velocity + accel * dt
                if simd_dot(next, velocity) < 0 && simd_length(slope) <= Self.staticFriction {
                    velocity = .zero
                } else {
                    velocity = next
                }
            }

            // 左右甩：惯性让硬币往反方向冲。
            // ★ 只算左右（x）。★ 上下摇（屏幕上下 y、朝向用户 z）不让它前后冲——
            //   第一版算了 y，作者看着上下摇时硬币前后乱窜。上下摇只让它原地颠一下（见下面）
            let kick = SIMD2<Float>(-jerk.x, 0)
            if abs(kick.x) > 0.25 {
                velocity += kick * Self.jerkKick * dt
            }
        } else {
            velocity = .zero
        }

        offset += velocity * dt

        // 软边：碰到就轻轻弹回一点，往外的速度大部分被吃掉
        let r = simd_length(offset)
        if r > Self.maxOffset {
            let dir = offset / r
            offset = dir * Self.maxOffset
            let outward = simd_dot(velocity, dir)
            if outward > 0 {
                velocity -= dir * outward * (1 + Self.wallBounce)
                if outward > Self.knockMinSpeed && sinceKnock >= Self.knockGap {
                    hitWall = true
                    wallImpact = min(outward / 1.2, 1)
                    sinceKnock = 0
                }
            }
        }

        // 上下摇：原地轻轻离地颠一下，落回时"嗒"一声（作者选的方案 B，像拍了一下桌子）
        let jolt = enabled ? simd_length(SIMD2<Float>(jerk.y, jerk.z)) : 0
        if jolt > Self.hopThreshold && hop <= 0.0005 && hopSpeed <= 0 {
            let up = min((jolt - Self.hopThreshold) * 1.0, 1) * Self.maxHop
            hopSpeed = (2 * 5 * up).squareRoot()          // 场景重力约 5
            let side = SIMD2<Float>(jerk.x, jerk.y)
            if simd_length(side) > 0.01 {
                let d = simd_normalize(side)
                wobbleAxis = SIMD2<Float>(-d.y, d.x)
            }
            wobbleSpeed += min(jolt, 1.5) * 120
        }
        if hop > 0 || hopSpeed > 0 {
            hopSpeed -= 5 * dt
            hop += hopSpeed * dt
            if hop <= 0 { hop = 0; hopSpeed = 0; hopLanded = true }
            hop = min(hop, Self.maxHop)
        }

        // 小晃：一根很紧的小弹簧，晃几下就停
        let ww = 2 * Float.pi * 6
        wobbleSpeed += (-ww * ww * wobble - 2 * 0.35 * ww * wobbleSpeed) * dt
        wobble += wobbleSpeed * dt
        wobble = max(-Self.maxWobble, min(Self.maxWobble, wobble))
    }

    // MARK: - 水平仪（作者要的："硬币始终保持真实的平"）

    /// 硬币最多歪多少度。再歪手机，硬币也不再跟（免得立起来）
    static let maxLevelDegrees: Float = 40

    /// 手机从"平常姿态"歪到"现在姿态"时，硬币要怎么转，才能在人眼里保持水平。
    ///
    /// 两个参数都是**手机自己坐标里**的重力方向（x 往右、y 往屏幕上方、z 朝向用户）。
    /// 返回值也在手机坐标里：绕哪根轴、转多少度（弧度）。
    ///
    /// 道理：手机一歪，"真正的上方"在手机里看就偏了。硬币原来朝上的那根轴（−平常重力）
    /// 要转到现在真正的上方（−现在重力），它在你眼里才是平的。
    /// 例：手机往左歪（左边低）→ 重力在手机里往左偏 → 真正的上方往右偏
    ///     → 硬币往右歪，也就是左边缘抬起来。
    static func levelRotation(baselineDown b: SIMD3<Float>,
                              currentDown g: SIMD3<Float>) -> (axis: SIMD3<Float>, angle: Float) {
        let lb = simd_length(b), lg = simd_length(g)
        guard lb > 1e-4, lg > 1e-4 else { return (.zero, 0) }
        let from = -b / lb, to = -g / lg
        let c = simd_cross(from, to)
        let s = simd_length(c)
        guard s > 1e-5 else { return (.zero, 0) }
        let angle = atan2(s, simd_dot(from, to))
        let limit = maxLevelDegrees * .pi / 180
        return (c / s, min(angle, limit))
    }

    /// 乱撞（ChaosModel）收尾后，把硬币交回来：停在它躺下的地方，静止（2026-10）
    mutating func place(at point: SIMD2<Float>) {
        self = ShakeModel()
        let r = simd_length(point)
        offset = r > Self.maxOffset ? point / r * Self.maxOffset : point
    }

    /// 一抛出去就清零：飞行接管硬币，起飞时的偏移由画面那边慢慢收回中间
    mutating func reset() {
        self = ShakeModel()
    }
}
