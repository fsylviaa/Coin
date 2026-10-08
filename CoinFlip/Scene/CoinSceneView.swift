// 3D 舞台：把硬币摆在屏幕上。对应任务 T13。
//
// 这里只负责"显示"，不做决定。抛不抛、抛出什么结果，都是 CoinController 说了算。
//
// ★ 关键约定（以后换模型、换贴图都必须守住）★
//     硬币绕 X 轴旋转。角度 0° 时日面朝向观众，180° 时月面朝向观众。
// 技术文档第 10 号坑说的就是这个——换素材时正反面搞反，结果会全部相反。

import SwiftUI
import RealityKit

/// 场景的尺寸设定。T23 调手感时可能会微调这里。
enum CoinScene {

    /// 硬币半径（场景单位）
    static let coinRadius: Float = 0.33

    /// 硬币厚度
    static let coinThickness: Float = 0.055

    /// 摄像机离硬币多远
    static let cameraDistance: Float = 2.6

    /// 摄像机略微抬高，能看到一点点硬币的厚度，不是纯正面
    static let cameraHeight: Float = 0.16

    /// 摄像机的视野角度
    static let fieldOfView: Float = 40

    /// 把时间表里的高度（米）换算成场景里的高度。
    /// 换算后最高一抛仍完整留在屏幕内，不会飞出去。
    static let heightScale: Float = 0.9
}

struct CoinSceneView: View {

    /// 当前要显示哪一面
    var face: CoinFace

    var body: some View {
        RealityView { content in
            let coin = makeCoin()
            coin.name = "coin"
            content.add(coin)
            content.add(makeLights())
            content.add(makeCamera())
            apply(face: face, to: coin)

        } update: { content in
            if let coin = content.entities.first(where: { $0.name == "coin" }) {
                apply(face: face, to: coin)
            }
        }
        .background(.black)
        .ignoresSafeArea()
    }

    // MARK: - 摆放

    /// 让指定的一面朝向观众，并把硬币放回原位、摆平。
    ///
    /// 日面 = 0°，月面 = 180°。这里直接设成"干净"的角度，
    /// 不是在上一次的基础上继续加——那正是技术文档第 2 号坑。
    private func apply(face: CoinFace, to coin: Entity) {
        coin.position = .zero
        coin.transform.rotation = Self.rotation(for: face)
    }

    /// 某一面朝向观众时，硬币该转到什么角度
    static func rotation(for face: CoinFace) -> simd_quatf {
        simd_quatf(angle: face == .sun ? 0 : .pi, axis: [1, 0, 0])
    }

    // MARK: - 搭建硬币

    /// 硬币由三部分拼成：
    ///   • 中间一块银色圆柱，提供厚度和侧边
    ///   • 前面一张圆形贴图（日面）
    ///   • 后面一张圆形贴图（月面），转过去背对前面
    ///
    /// 为什么不直接给圆柱的两个端面贴不同的图：
    /// RealityKit 对圆柱端面的贴图方式没有保证，不同系统版本可能不一样。
    /// 用两张独立的平面最稳妥，正反面绝不会贴混。
    private func makeCoin() -> Entity {
        let style = StyleProfile.silver
        let coin = Entity()

        // 饼身：立着的圆柱转 90°，让两个端面朝向前后
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
    ///
    /// 做法是把圆切成很多个三角形，像切披萨一样，全都从圆心出发。
    static func discMesh(radius: Float, segments: Int = 128) -> MeshResource {
        var positions: [SIMD3<Float>] = [[0, 0, 0]]      // 圆心
        var normals: [SIMD3<Float>] = [[0, 0, 1]]
        var uvs: [SIMD2<Float>] = [[0.5, 0.5]]           // 圆心对应贴图正中

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

    /// 带图案的金属面。贴图四角是透明的，所以要开启透明混合，
    /// 否则会看到一个方块而不是圆形硬币。
    private func faceMaterial(textureNamed name: String) -> RealityKit.Material {
        var material = PhysicallyBasedMaterial()
        // 这个场景里没有环境可供反射，所以金属度调低、靠灯光打出高光，
        // 看起来反而更像有光泽的金属。T23 调手感时可以再试别的数值。
        material.metallic = 0.22
        material.roughness = 0.38

        if let texture = try? TextureResource.load(named: name) {
            material.baseColor = .init(tint: UIColor(white: 0.62, alpha: 1), texture: .init(texture))
        } else {
            // 贴图万一加载不了，退回纯银色，至少还能看到硬币
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

    /// 一盏主灯从左上前方照过来，一盏弱补光从右下把暗面提亮一点，
    /// 免得背光那侧黑成一块。最小可用版的灯固定不动，不跟手机倾斜。
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

        // 正前方一盏柔光，保证硬币整体不发暗
        let front = DirectionalLight()
        front.light.intensity = 260
        front.light.color = .white
        front.look(at: .zero, from: [0, 0.2, 2.0], relativeTo: nil)
        rig.addChild(front)

        return rig
    }

    /// 摄像机固定不动，正对硬币
    private func makeCamera() -> Entity {
        let camera = PerspectiveCamera()
        camera.camera.fieldOfViewInDegrees = CoinScene.fieldOfView
        let position = SIMD3<Float>(0, CoinScene.cameraHeight, CoinScene.cameraDistance)
        camera.position = position
        camera.look(at: .zero, from: position, relativeTo: nil)
        return camera
    }
}
