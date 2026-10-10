// 地面与接触阴影：让硬币看起来是"落在什么东西上"，而不是浮在虚空。
//
// 两块都是贴地的圆片，用不受光的材质，所以不会被环境反射影响：
//
//   • 地面  硬币脚下一小片微亮的地，向外平滑化进黑背景里。
//          ★ 它必须看得见。★ 影子是靠"让本来亮的东西变暗"被看见的，
//          背景是纯黑，黑影子投上去等于没画——所以得先有这片地。
//          透明度平滑衰减到 0，所以不会出现地平线或者圆形的轮廓。
//
//   • 阴影  纯黑，中间浓、边缘散，压在那片地上。
//          硬币越高，这张图被放得越大、调得越淡，自然就"变大、变散、变淡"。
//
// 有两个坑都踩过，写在这里：
//
//   ① 这两张片子只差几毫米，谁先画非常要紧。地面要是画在阴影后面，
//      就把阴影整块盖掉——"地面看得见、影子怎么都看不见"就是这么来的。
//      所以用引擎的排序分组写死顺序（地面 0、阴影 1），
//      不去依赖引擎自己按离镜头的远近排，那个距离太近排不稳。
//
//   ② 两张都必须保持半透明。半透明的东西不写深度，硬币倾斜时
//      沉到地面以下的那一块才不会被地面切掉。曾经把地面改成不透明
//      来绕开 ①，结果硬币上多了一道直的缺口。
//
// 性能上的讲究：贴图和网格都只做一次，之后每帧只改缩放和透明度。
// 透明度还做了分档，只有跨档才真的换材质，避免每帧都生成新对象。

import RealityKit
import UIKit

enum GroundShadow {

    // MARK: - 尺寸与浓淡

    /// 地面那一片有多大（场景单位）
    static let groundRadius: Float = 1.2

    /// 阴影贴图在缩放为 1 时的半径
    static let shadowBaseRadius: Float = CoinScene.coinRadius * 2.9

    /// 贴地的那一刻，阴影缩到多小、多浓
    static let restScale: Float = 0.56
    static let restOpacity: Float = 0.86

    /// 升到最高时，阴影放到多大、多淡
    static let highScale: Float = 1.70
    static let highOpacity: Float = 0.32

    /// 硬币侧着时阴影淡成什么样。
    ///
    /// 真硬币侧过来时，投下的是一条细线，不是一个圆——挡住的光本来就少了。
    /// 所以按 cos(倾角) 的幂次减淡，物理上是对的。
    ///
    /// 它同时解决一个麻烦：硬币只有在**侧着**的时候下缘才会穿过这张平面，
    /// 而那正是阴影被减得最淡的时候。躲不开的相交，刚好发生在影响最小的时刻。
    /// 数字越大减得越狠（1.0 是严格按投影面积算）。
    /// 调浓阴影之后这里跟着加大，把"侧着时压暗硬币"那部分抵回去。
    static let tiltFade: Float = 2.2

    /// 地面和阴影要沉到硬币下方，正好托住它的底面
    static let groundY: Float = -CoinScene.coinThickness / 2
    static let shadowY: Float = -CoinScene.coinThickness / 2 + 0.006

    /// 透明度分成几档。只有跨档才换材质，省去每帧新建对象。
    private static let opacitySteps: Float = 48

    // MARK: - 画面先后

    /// 地面和阴影共用一个排序分组，组内按 order 从小到大画。
    private static let sortGroup = ModelSortGroup(depthPass: nil)

    private enum Layer: Int32 {
        case ground = 0
        case shadow = 1
    }

    // MARK: - 搭建

    /// 做出地面那一片。只在搭场景时调用一次。
    static func makeGround() -> Entity {
        let entity = ModelEntity(mesh: CoinSceneView.discMesh(radius: groundRadius),
                                 materials: [material(textureNamed: "ground_fade",
                                                      opacity: 1)])
        entity.name = "ground"
        entity.components.set(ModelSortGroupComponent(group: sortGroup,
                                                      order: Layer.ground.rawValue))
        // 圆片本来是立着的（正面朝观众），转 90° 让它平铺在地上
        entity.transform.rotation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
        entity.position = [0, groundY, 0]
        return entity
    }

    /// 做出阴影那一片。只在搭场景时调用一次。
    static func makeShadow() -> ModelEntity {
        let entity = ModelEntity(mesh: CoinSceneView.discMesh(radius: shadowBaseRadius),
                                 materials: [material(textureNamed: "shadow_soft",
                                                      opacity: restOpacity)])
        entity.name = "shadow"
        entity.components.set(ModelSortGroupComponent(group: sortGroup,
                                                      order: Layer.shadow.rawValue))
        entity.transform.rotation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
        entity.position = [0, shadowY, 0]
        _ = shadowMaterials          // 趁现在把 49 档材质都做好，别留到第一帧
        return entity
    }

    // MARK: - 每帧更新

    /// 让阴影跟上硬币此刻的位置和高度。
    ///
    /// - Parameters:
    ///   - shadow: 阴影那一片
    ///   - coinPosition: 硬币此刻的位置
    ///   - tiltDegrees: 硬币此刻离躺平多少度（0~90）
    ///   - lastStep: 上一次用的透明度档位，用来判断要不要换材质
    /// - Returns: 这一次的透明度档位，调用方存起来下次传进来
    static func update(_ shadow: ModelEntity,
                       coinPosition: SIMD3<Float>,
                       tiltDegrees: Float,
                       lastStep: Int) -> Int {

        // 升得越高，t 越接近 1
        let t = min(max(coinPosition.y / maxLift, 0), 1)
        // 低处变化快、高处变化慢，这样刚离地那一下阴影的收放最明显
        let eased = sqrt(t)

        let scale = restScale + (highScale - restScale) * eased
        shadow.scale = [scale, scale, 1]
        // 跟着硬币横向走（本版硬币只上下动，但留着以后用）
        shadow.position = [coinPosition.x, shadowY, coinPosition.z]

        // 侧着的硬币投的影子小而淡，和它遮住的光成正比
        let flat = cos(min(max(tiltDegrees, 0), 90) * .pi / 180)
        let opacity = (restOpacity + (highOpacity - restOpacity) * eased)
            * pow(flat, tiltFade)
        let step = min(max(Int((opacity * opacitySteps).rounded()), 0), Int(opacitySteps))
        if step != lastStep {
            shadow.model?.materials = [shadowMaterials[step]]
        }
        return step
    }

    /// 硬币最高能升到多高。用来把高度折算成 0~1。
    private static let maxLift: Float =
        CoinScene.heightScale * Float(StyleProfile.silver.maxHeight)

    // MARK: - 材质

    /// 每一档透明度的材质都**提前做好**，之后每帧只是换个引用。
    ///
    /// 原来是跨档时现做一个材质。平时没事，但硬币快落地那几帧档位掉得最快，
    /// 一帧里要连做好几个——于是落地那一下偶尔会顿一帧。
    /// 和之前那次卡顿是同一类毛病：在渲染回调里分配对象。
    ///
    /// 在搭场景时就全部做好（makeShadow 里点一下），这样这点开销落在
    /// 建场景那一刻，而不是第一帧。
    static let shadowMaterials: [RealityKit.Material] =
        (0...Int(opacitySteps)).map {
            material(textureNamed: "shadow_soft", opacity: Float($0) / opacitySteps)
        }

    /// 贴图只读一次，之后一直复用——每帧重新解码贴图会很卡。
    private static var textureCache: [String: TextureResource] = [:]

    private static func texture(named name: String) -> TextureResource? {
        if let cached = textureCache[name] { return cached }
        guard let loaded = try? TextureResource.load(named: name) else { return nil }
        textureCache[name] = loaded
        return loaded
    }

    /// 不受光的材质：地面和阴影不该被环境反射照亮，它们就该是暗的。
    ///
    private static func material(textureNamed name: String,
                                 opacity: Float) -> RealityKit.Material {
        var material = UnlitMaterial()
        if let texture = texture(named: name) {
            material.color = .init(tint: .white, texture: .init(texture))
        } else {
            material.color = .init(tint: UIColor(white: 0, alpha: 1))
        }
        material.blending = .transparent(opacity: .init(floatLiteral: opacity))
        return material
    }
}
