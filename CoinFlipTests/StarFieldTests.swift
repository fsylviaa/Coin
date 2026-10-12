// 星点背景的自动测试（P02）。
//
// 守的是两件事：
//   1. 镜头不管怎么游移、推近，看到的方向都铺着星点——不会露出一块空的
//   2. 星空每次打开都一模一样（固定种子）

import XCTest
import simd
@testable import CoinFlip

final class StarFieldTests: XCTestCase {

    /// ★ 镜头能看到的所有方向，都要落在星点的覆盖范围里。★
    ///
    /// 把镜头从远景到特写、游移到最左最右都走一遍，
    /// 每个位置看屏幕的四角和四边中点，算出视线打到星空球面上的哪里。
    /// 以后要是调大了镜头角度或视野，这里会先红，提醒 StarField.Patch 跟着放大。
    func testCameraNeverSeesPastTheStars() {
        let elevations = stride(from: CoinScene.elevationFar - CoinScene.driftElevation - 1,
                                through: CoinScene.elevationNear + 2, by: 1)
        let yaws: [Float] = [-CoinScene.driftYaw - 0.5, 0, CoinScene.driftYaw + 0.5]
        let tanV = tan(CoinScene.fieldOfView / 2 * .pi / 180)
        // 竖屏宽高比约 0.46，取 0.5 留点余量
        let tanH = tanV * 0.5

        for el in elevations {
            for yaw in yaws {
                // 远景和特写之间的镜头距离、注视高度也跟着变，三档都看
                for z: Float in [0, 0.5, 1] {
                    let distance = CoinScene.distanceFar + (CoinScene.distanceNear - CoinScene.distanceFar) * z
                    let lookUp = CoinScene.lookUpFar + (CoinScene.lookUpNear - CoinScene.lookUpFar) * z
                    let er = el * .pi / 180, yr = yaw * .pi / 180
                    let lookAt = SIMD3<Float>(0, lookUp, 0)
                    let camera = lookAt + distance * SIMD3(sin(yr) * cos(er), sin(er), cos(yr) * cos(er))
                    let forward = simd_normalize(lookAt - camera)
                    let right = simd_normalize(simd_cross(forward, [0, 1, 0]))
                    let up = simd_cross(right, forward)

                    for sx: Float in [-1, 0, 1] {
                        for sy: Float in [-1, 0, 1] {
                            let ray = simd_normalize(forward + right * tanH * sx + up * tanV * sy)
                            let hit = hitSphere(from: camera, along: ray, radius: StarField.radius)
                            let a = StarField.angles(of: hit)
                            XCTAssert(a.down >= StarField.Patch.downMin && a.down <= StarField.Patch.downMax
                                      && abs(a.side) <= StarField.Patch.sideMax,
                                      "镜头离地 \(el)° 偏 \(yaw)° 时，屏幕边缘看到了星空外面"
                                        + "（down \(a.down)°, side \(a.side)°）。把 StarField.Patch 放大")
                        }
                    }
                }
            }
        }
    }

    /// 星空球面要在镜头的最远可见距离以内，不然整片会被裁掉看不见
    func testStarsAreWithinCameraRange() {
        XCTAssertLessThan(StarField.radius + CoinScene.distanceFar, 100)
        XCTAssertGreaterThan(StarField.radius, CoinScene.distanceFar * 5,
                             "星空离得不够远，镜头一动它会和地面一起晃，看不出纵深")
    }

    /// 两个角度和方向能互相换算回来（覆盖范围检查靠它）
    func testAnglesRoundTrip() {
        for (down, side): (Float, Float) in [(0, 0), (30, 10), (90, 0), (104, -20)] {
            let a = StarField.angles(of: StarField.direction(down: down, side: side))
            XCTAssertEqual(a.down, down, accuracy: 0.01)
            XCTAssertEqual(a.side, side, accuracy: 0.01)
        }
    }

    /// 固定种子：两次生成的星空完全一样
    func testStarFieldIsStable() {
        let a = StarField.starDescriptor().positions.elements
        let b = StarField.starDescriptor().positions.elements
        XCTAssertEqual(a.count, StarField.count * 4)
        XCTAssertEqual(a, b, "星空每次生成都不一样，打开 App 会看到星星换了位置")
    }

    /// 星星要扎堆在银河里：银河中线附近的密度明显高于外面
    func testStarsClusterInTheMilkyWay() {
        let points = StarField.starDescriptor().positions.elements
        var near = 0, far = 0
        for i in stride(from: 0, to: points.count, by: 4) {
            let centre = (points[i] + points[i + 2]) / 2
            let a = StarField.angles(of: centre)
            let d = abs(StarField.bandDistance(down: a.down, side: a.side))
            if d < 5 { near += 1 } else if d > 15 && d < 25 { far += 1 }
        }
        // 中线附近这段宽 10°，外侧两边加起来宽 20°。
        // 按每度算，银河里至少要密三倍：near / 10 > 3 × far / 20
        XCTAssertGreaterThan(Double(near), Double(far) * 1.5,
                             "星星没有扎堆在银河里（中线附近 \(near) 颗，外侧 \(far) 颗）")
    }

    /// 背景跟镜头：镜头在什么角度，背景看起来就该在 seenAngles 给的角度
    func testSkyOrientationCancelsPartOfTheCameraTurn() {
        let el: Float = 78, yaw: Float = 4
        let seen = StarField.seenAngles(cameraElevation: el, cameraYaw: yaw)
        XCTAssertLessThan(seen.elevation, el, "背景没有慢下来")
        XCTAssertGreaterThan(seen.elevation, StarField.referenceElevation)

        // 把镜头的位置换到背景自己的坐标里看，应该正好处在 seen 那个角度
        let q = StarField.orientation(cameraElevation: el, cameraYaw: yaw,
                                      seenElevation: seen.elevation, seenYaw: seen.yaw)
        let camera = position(elevation: el, yaw: yaw)
        let inSky = q.inverse.act(camera)
        let expected = position(elevation: seen.elevation, yaw: seen.yaw)
        XCTAssertEqual(simd_distance(inSky, expected), 0, accuracy: 0.001)
    }

    private func position(elevation: Float, yaw: Float) -> SIMD3<Float> {
        let e = elevation * .pi / 180, y = yaw * .pi / 180
        return SIMD3(sin(y) * cos(e), sin(e), cos(y) * cos(e))
    }

    /// 星点永远在底子前面，否则会被银河挡住看不见
    func testStarsSitInFrontOfTheSky() {
        XCTAssertLessThan(StarField.starRadius, StarField.radius)
    }

    private func hitSphere(from origin: SIMD3<Float>, along ray: SIMD3<Float>,
                           radius: Float) -> SIMD3<Float> {
        let b = simd_dot(origin, ray)
        let c = simd_dot(origin, origin) - radius * radius
        let t = -b + (b * b - c).squareRoot()
        return origin + ray * t
    }
}
