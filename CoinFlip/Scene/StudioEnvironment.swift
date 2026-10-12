// 环境反射：给硬币造一个可以映出来的世界。
//
// 真金属之所以好看，是因为它映出周围的环境——灯箱、墙面、反光板。
// 我们的场景除了黑背景什么都没有，所以金属度一调高就显得死板发灰。
//
// 这个文件把那张"全景展开图"（studio_env.png）变成环境光源。
// 系统会把它卷成一个球罩在场景外面，硬币表面映出的就是它：
// 转到哪，哪片灯箱就在币面上流过去。这是让它像金属而不是塑料的关键一步。
//
// ⚠️ 这一整块是可选的。万一在某些系统上用不了，下面的代码会安静地跳过，
//    硬币仍然由那组摄影棚灯照亮，只是少了环境反射。

import RealityKit
import UIKit

enum StudioEnvironment {

    /// 硬币倒映的是哪张全景图。
    ///
    /// P03b 起是 night_env：影棚的亮灯箱原样保留（银亮靠它们），
    /// 灯箱以外换成夜色、银河和星点，硬币的色调才和背景融在一起。
    /// ★ 想换回原来的影棚，把这里改回 "studio_env" 即可，两张图都在。★
    static let imageName = "night_env"

    /// 读取全景图并做成环境资源。失败就返回空，调用方会跳过。
    static func load() async -> EnvironmentResource? {
        guard let url = Bundle.main.url(forResource: imageName, withExtension: "png"),
              let image = UIImage(contentsOfFile: url.path),
              let cgImage = image.cgImage else { return nil }
        return try? await EnvironmentResource(equirectangular: cgImage)
    }

    /// 做一盏环境光，并让硬币接收它。
    ///
    /// 返回的这个节点要由调用方加进场景里。
    /// 不直接在这里加，是为了不依赖只有 SwiftUI 那边才有的场景类型。
    ///
    /// - Parameters:
    ///   - environment: 上面做好的环境资源
    ///   - coin: 硬币
    /// - Returns: 承载环境光的节点
    static func makeLight(_ environment: EnvironmentResource, for coin: Entity) -> Entity {
        let lightEntity = Entity()
        lightEntity.name = "ibl"
        lightEntity.components.set(
            ImageBasedLightComponent(source: .single(environment),
                                     intensityExponent: CoinScene.environmentStops)
        )

        // 接收环境光的组件要挂到真正有外观的那几个部件上，
        // 挂在空壳父节点上是不生效的，所以这里逐层挂下去。
        receive(from: lightEntity, in: coin)
        return lightEntity
    }

    private static func receive(from source: Entity, in entity: Entity) {
        entity.components.set(ImageBasedLightReceiverComponent(imageBasedLight: source))
        for child in entity.children {
            receive(from: source, in: child)
        }
    }
}
