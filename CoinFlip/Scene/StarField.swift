// 银河星空背景（P02）。
//
// 两层，都钉在离硬币很远的一块大球面上，从镜头看过去就是"背景"：
//   1. 底子（sky_milkyway.png）：深蓝黑底 + 一条斜穿的淡银河 + 暗尘带。
//      全是软的云状明暗，贴图不用很清楚。
//   2. 星点（star_dots.png）：两千多颗小方片，五档亮度 × 冷白暖三色，
//      最亮的几颗带十字星芒；越靠近银河中线越密。
//
// 为什么放进三维场景、而不是在最底层铺一张图：
//   镜头会游移、会从低角度绕到上方推近。背景要是贴在屏幕上不动，
//   硬币和地面在动而背景纹丝不动，看着就像一张贴纸。
//   钉在远处的球面上，镜头一转银河就跟着慢慢滑过去——这就是纵深感。
//
// 为什么星点要单独做、不画进底子里：
//   屏幕上每 1° 约 64 像素，底子贴图每 1° 只有约 20 像素，
//   星画进去会被放大成糊斑——第一版"基本看不到星星"就是这个原因之一。
//
// ★ 一次搭好、之后再也不动。★
//   不按帧换材质、不按帧改形状（§2.5 的偶发掉帧还没查清，
//   按帧换材质正是以前出过问题的地方）。每帧没有任何额外计算。
//
// 只盖住镜头看得到的那一片方向（见 Patch），其余方向是空的。
// 镜头角度以后要是调大了，StarFieldTests 会提醒这里也得跟着放大。

import Foundation
import RealityKit
import UIKit
import simd

enum StarField {

    // MARK: - 调校参数

    /// 底子所在球面的半径（场景单位）。只要远大于场景本身（地面半径 1.2、镜头距离 3.3）
    /// 就行，再远也看不出区别；但不能超过镜头的最远可见距离，否则会被裁掉。
    static let radius: Float = 30

    /// 星点比底子近一点点，保证永远画在银河前面
    static let starRadius: Float = 29.5

    /// 一共多少颗星。镜头一次大约只看到其中一成多。
    static let count = 2600

    /// 星点有多爱扎堆在银河里：离中线越近越容易留下。
    /// 银河外面也保留两成的密度，不至于一边全空。
    static let outsideDensity: Float = 0.18
    static let bandWidth: Float = 7

    /// 五档星点各占几成（星芒、亮、中、暗、极暗），和 star_dots.png 的档一一对应。
    /// 绝大多数是暗的，亮星稀少，才像真的星空。
    static let shares: [Float] = [0.012, 0.05, 0.15, 0.33, 0.458]

    /// 五档星点的方片多大（度）。星芒那档的方片要容下十字光芒，所以大得多。
    static let sizes: [Float] = [1.0, 0.42, 0.30, 0.22, 0.17]

    /// star_dots.png 每档有几种颜色（冷、白、暖）
    static let colorsPerTier = 3

    /// 每颗大小在上面的基础上随机浮动多少
    static let sizeJitter: Float = 0.15

    /// 随机种子。固定下来，每次打开星空都一模一样。
    static let seed: UInt64 = 20261012

    // MARK: - 跟镜头的关系（余韵）

    /// 背景少走镜头动作的几成。0 是钉死不动（镜头一动整片扫过去，最快），
    /// 1 是贴在屏幕上（完全不动，像贴纸）。0.7 = 背景只走镜头的三成。
    static let followShare: Float = 0.7

    /// 背景从开始动到基本停稳要多久（秒）。越大余韵越长。
    ///
    /// ★ 用的是"弹簧"式的追法，不是"每帧靠近一点"。★
    ///   "每帧靠近一点"一开始最快、然后越来越慢——镜头一动，背景立刻全速冲出去，
    ///   作者看着就是"突然转了一下"。弹簧是从静止慢慢加速、到中段最快、
    ///   再慢慢收住，两头都是软的，没有任何一刻是突然的。
    static let settleSeconds: Double = 3.0

    /// 弹簧的快慢，由 settleSeconds 换算（不过冲的弹簧大约 4.7/rate 秒走完九成五）
    static var springRate: Double { 4.7 / settleSeconds }

    /// 以远景的镜头角度为基准：背景在远景时就是"本来的样子"
    static var referenceElevation: Float { CoinScene.elevationFar }

    /// 镜头在某个角度时，背景应该"看起来"处在哪个角度（还没算惯性）
    static func seenAngles(cameraElevation: Float,
                           cameraYaw: Float) -> (elevation: Float, yaw: Float) {
        let keep = 1 - followShare
        return (referenceElevation + keep * (cameraElevation - referenceElevation),
                keep * cameraYaw)
    }

    /// 背景该转到什么朝向，才能让镜头"看起来"在 seen 那个角度看它。
    ///
    /// 镜头的位置 = 先绕横轴抬高 elevation、再绕竖轴转 yaw。
    /// 背景转"镜头实际的转法"减去"想让它看起来的转法"，两者一抵，
    /// 从镜头里看，背景就像镜头处在 seen 角度一样。
    static func orientation(cameraElevation: Float, cameraYaw: Float,
                            seenElevation: Float, seenYaw: Float) -> simd_quatf {
        cameraTurn(elevation: cameraElevation, yaw: cameraYaw)
            * cameraTurn(elevation: seenElevation, yaw: seenYaw).inverse
    }

    private static func cameraTurn(elevation: Float, yaw: Float) -> simd_quatf {
        simd_quatf(angle: yaw * .pi / 180, axis: [0, 1, 0])
            * simd_quatf(angle: -elevation * .pi / 180, axis: [1, 0, 0])
    }

    // MARK: - 覆盖范围

    /// 星空铺在哪一片方向上。
    ///
    /// 用两个角度描述一个方向（以硬币为中心往外看）：
    ///   • down：从"水平朝镜头对面"往下转了多少度。0 是水平，90 是正下方，
    ///     超过 90 就是转过了正下方、开始朝镜头这一侧
    ///   • side：往左右偏了多少度
    ///
    /// 实算（含游移、推近全过程）镜头看到的是 down 2°～104°、side 左右 17° 以内。
    /// 这里各留了约 8° 余量；StarFieldTests 会把镜头走一遍确认没有露边。
    /// 背景跟着镜头转了一部分（余韵）以后，实际看到的范围只会更小，不会更大。
    ///
    /// 为什么不用常见的"经纬度"：经纬度在两极会挤成一个点，
    /// 而特写正好是从上往下看，挤点会落在硬币旁边。这里把"两极"放到了左右两侧，
    /// 镜头永远看不到那里。
    ///
    /// ★ 和 make_assets.py 的 SKY_SIDE、SKY_DOWN 必须一致。★
    enum Patch {
        static let downMin: Float = -4
        static let downMax: Float = 112
        static let sideMax: Float = 26
    }

    /// 到银河中线的角距离（度）。
    /// ★ 和 make_assets.py 的 band_distance 是同一个公式，改一边必须改另一边。★
    static func bandDistance(down: Float, side: Float) -> Float {
        let slope: Float = 0.32
        // 30：远景里硬币正后方，银河从硬币正下方穿过，影子压在银河上（P03）
        let center: Float = 30
        return (side - slope * (down - center)) / (1 + slope * slope).squareRoot()
    }

    /// 由两个角度（度）得到方向。
    static func direction(down: Float, side: Float) -> SIMD3<Float> {
        let d = down * .pi / 180
        let s = side * .pi / 180
        return SIMD3(sin(s), -sin(d) * cos(s), -cos(d) * cos(s))
    }

    /// 反过来：一个方向对应的两个角度（度）。测试用来检查镜头看到的方向都在范围内。
    static func angles(of v: SIMD3<Float>) -> (down: Float, side: Float) {
        let u = simd_normalize(v)
        let side = asin(max(-1, min(1, u.x)))
        let down = atan2(-u.y, -u.z)
        return (down * 180 / .pi, side * 180 / .pi)
    }

    // MARK: - 搭建

    /// 做出整片星空（底子 + 星点）。只在搭场景时调用一次。
    /// 任何一层做不出来就跳过那一层，画面退回原来的黑底，不影响别的。
    static func make() -> Entity {
        let root = Entity()
        root.name = "starField"

        if let mesh = try? MeshResource.generate(from: [skyDescriptor()]),
           let texture = try? TextureResource.load(named: "sky_milkyway") {
            var material = UnlitMaterial()
            material.color = .init(tint: .white, texture: .init(texture))
            let sky = ModelEntity(mesh: mesh, materials: [material])
            sky.name = "sky"
            root.addChild(sky)
        }

        if let mesh = try? MeshResource.generate(from: [starDescriptor()]),
           let texture = try? TextureResource.load(named: "star_dots") {
            var material = UnlitMaterial()
            material.color = .init(tint: .white, texture: .init(texture))
            // 半透明：星点的亮暗写在贴图的透明度里，叠在银河上不会有黑边
            material.blending = .transparent(opacity: .init(floatLiteral: 1))
            let stars = ModelEntity(mesh: mesh, materials: [material])
            stars.name = "stars"
            // 和地面、阴影排在同一组里，并且最先画——
            // 半透明的东西谁先谁后系统按距离猜，猜错了星点会盖到地面光晕上面
            stars.components.set(ModelSortGroupComponent(group: GroundShadow.sortGroup,
                                                         order: GroundShadow.starsOrder))
            root.addChild(stars)
        }
        return root
    }

    /// 底子：覆盖范围那一片球面，切成网格，贴图按两个角度均匀铺上去。
    static func skyDescriptor(sideSteps: Int = 24, downSteps: Int = 64) -> MeshDescriptor {
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var uvs: [SIMD2<Float>] = []
        var indices: [UInt32] = []

        for j in 0...downSteps {
            let fv = Float(j) / Float(downSteps)
            let down = Patch.downMin + (Patch.downMax - Patch.downMin) * fv
            for i in 0...sideSteps {
                let fu = Float(i) / Float(sideSteps)
                let side = -Patch.sideMax + 2 * Patch.sideMax * fu
                let dir = direction(down: down, side: side)
                positions.append(dir * radius)
                normals.append(-dir)
                // ★ 竖向要反着取。★ 贴图坐标的 0 在图片最下面一行，
                //   而 sky_milkyway.png 的第一行（最上面）是 down 最小的地方。
                //   不反的话银河会上下颠倒，和星点扎堆的位置对不上。
                //   （币面已经验证过：v = 0 对应图片底部。）
                uvs.append([fu, 1 - fv])
            }
        }
        let row = UInt32(sideSteps + 1)
        for j in 0..<UInt32(downSteps) {
            for i in 0..<UInt32(sideSteps) {
                let a = j * row + i, b = a + 1, c = a + row, d = c + 1
                // 正反两面都铺上，不用操心哪一面朝镜头
                indices += [a, b, d, a, d, c,
                            a, d, b, a, c, d]
            }
        }

        var descriptor = MeshDescriptor(name: "sky")
        descriptor.positions = MeshBuffer(positions)
        descriptor.normals = MeshBuffer(normals)
        descriptor.textureCoordinates = MeshBuffer(uvs)
        descriptor.primitives = .triangles(indices)
        return descriptor
    }

    /// 星点：所有星合成一个网格（一次画完，比两千多个单独的东西省得多）。
    static func starDescriptor() -> MeshDescriptor {
        var rng = SplitMix64(seed: seed)
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var uvs: [SIMD2<Float>] = []
        var indices: [UInt32] = []
        positions.reserveCapacity(count * 4)

        let cells = Float(shares.count * colorsPerTier)
        let sMax = sin(Patch.sideMax * .pi / 180)
        var placed = 0

        while placed < count {
            // 在覆盖范围里均匀撒点。左右方向按 sin 均匀取，
            // 球面上才是真正的均匀（否则会往两边挤）
            let down = Patch.downMin + (Patch.downMax - Patch.downMin) * rng.unit()
            let side = asin((rng.unit() * 2 - 1) * sMax) * 180 / .pi

            // 越靠近银河中线越容易留下 → 星星扎堆在银河里
            let band = bandDistance(down: down, side: side) / bandWidth
            let keep = outsideDensity + (1 - outsideDensity) * exp(-band * band)
            if rng.unit() > keep { continue }
            placed += 1

            // 这颗属于哪一档、哪种颜色
            let pick = rng.unit()
            var tier = shares.count - 1
            var acc: Float = 0
            for (i, share) in shares.enumerated() {
                acc += share
                if pick < acc { tier = i; break }
            }
            let color = min(Int(rng.unit() * Float(colorsPerTier)), colorsPerTier - 1)

            let jitter = 1 + sizeJitter * (rng.unit() * 2 - 1)
            let half = starRadius * (sizes[tier] * .pi / 180) * jitter / 2

            let dir = direction(down: down, side: side)
            let center = dir * starRadius
            // 方片铺在球面的切面上：一条边顺着"往下"，一条边顺着"往旁边"
            let d = down * .pi / 180
            let s = side * .pi / 180
            let alongDown = SIMD3<Float>(0, -cos(d), sin(d))
            let alongSide = SIMD3<Float>(cos(s), sin(d) * sin(s), cos(d) * sin(s))

            let base = UInt32(positions.count)
            positions += [
                center - alongSide * half - alongDown * half,
                center + alongSide * half - alongDown * half,
                center + alongSide * half + alongDown * half,
                center - alongSide * half + alongDown * half,
            ]
            normals += Array(repeating: -dir, count: 4)

            let cell = Float(tier * colorsPerTier + color)
            let u0 = cell / cells
            let u1 = (cell + 1) / cells
            uvs += [[u0, 0], [u1, 0], [u1, 1], [u0, 1]]

            indices += [base, base + 1, base + 2, base, base + 2, base + 3,
                        base, base + 2, base + 1, base, base + 3, base + 2]
        }

        var descriptor = MeshDescriptor(name: "stars")
        descriptor.positions = MeshBuffer(positions)
        descriptor.normals = MeshBuffer(normals)
        descriptor.textureCoordinates = MeshBuffer(uvs)
        descriptor.primitives = .triangles(indices)
        return descriptor
    }
}

/// 可以指定种子的随机数。系统自带的每次都不一样，星空就会每次打开都换一个样子。
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// 0 到 1 之间
    mutating func unit() -> Float {
        Float(next() >> 40) / Float(1 << 24)
    }
}
