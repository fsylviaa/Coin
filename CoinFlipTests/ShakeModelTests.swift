// 歪手机、晃手机时硬币跟着动（P13）。手机就是那张桌子，硬币按重力滑。

import XCTest
import simd
@testable import CoinFlip

final class ShakeModelTests: XCTestCase {

    private let dt: Float = 1.0 / 60

    private func run(_ model: inout ShakeModel, seconds: Float,
                     tilt: SIMD2<Float> = .zero, jerk: SIMD3<Float> = .zero,
                     enabled: Bool = true) {
        for _ in 0..<Int(seconds / dt) {
            model.step(dt: dt, tilt: tilt, jerk: jerk, enabled: enabled)
        }
    }

    /// 歪得不够（静摩擦）：纹丝不动
    func testGentleTiltDoesNothing() {
        var m = ShakeModel()
        run(&m, seconds: 2, tilt: [0.06, 0])           // 约 3.4°
        XCTAssertEqual(simd_length(m.offset), 0, accuracy: 1e-6, "坡这么缓不该滑")
    }

    /// 歪过门槛：往低的那边滑。右边低 → 往右（+x）
    func testSlidesDownhill() {
        var right = ShakeModel()
        run(&right, seconds: 0.6, tilt: [0.34, 0])     // 约 20°
        XCTAssertGreaterThan(right.offset.x, 0.05, "右边低，硬币应该往右滑")
    }

    /// ★ 只认左右歪 ★（作者要求）：往前、往后歪，硬币不动
    func testIgnoresForwardBackTilt() {
        var m = ShakeModel()
        run(&m, seconds: 2, tilt: [0, 0.6])
        XCTAssertEqual(simd_length(m.offset), 0, accuracy: 1e-6, "前后歪不该滑")
        run(&m, seconds: 2, tilt: [0, -0.6])
        XCTAssertEqual(simd_length(m.offset), 0, accuracy: 1e-6, "前后歪不该滑")
    }

    /// ★ 是加速滑下去，不是匀速飘过去 ★（第一版作者看着"像飘着平移"）
    func testAcceleratesLikeGravity() {
        var m = ShakeModel()
        run(&m, seconds: 0.1, tilt: [0.34, 0])
        let early = m.velocity.x
        run(&m, seconds: 0.2, tilt: [0.34, 0])
        XCTAssertGreaterThan(m.velocity.x, early * 2, "越滑应该越快")
    }

    /// 越陡滑得越快
    func testSteeperIsFaster() {
        var gentle = ShakeModel(), steep = ShakeModel()
        run(&gentle, seconds: 0.3, tilt: [0.2, 0])
        run(&steep, seconds: 0.3, tilt: [0.5, 0])
        XCTAssertGreaterThan(steep.offset.x, gentle.offset.x)
    }

    /// ★ 放平之后停在原地，不会自己回中间 ★
    func testStaysWhereItStopsWhenLevel() {
        var m = ShakeModel()
        run(&m, seconds: 0.8, tilt: [0.34, 0])
        run(&m, seconds: 3)                             // 放平
        let resting = m.offset.x
        XCTAssertGreaterThan(resting, 0.05)
        run(&m, seconds: 3)
        XCTAssertEqual(m.offset.x, resting, accuracy: 1e-6, "放平了却自己挪回去了")
    }

    /// 往反方向歪，它就滑回来
    func testTiltBackBringsItBack() {
        var m = ShakeModel()
        run(&m, seconds: 0.8, tilt: [0.4, 0])
        let there = m.offset.x
        // 先要把往右的冲劲刹住，再滑回来，所以多给一点时间
        run(&m, seconds: 1.5, tilt: [-0.4, 0])
        XCTAssertLessThan(m.offset.x, there - 0.05)
    }

    /// 歪得再狠也滑不出软边；颠和晃都有上限，晃远远到不了翻面
    func testStaysInBounds() {
        var m = ShakeModel()
        for i in 0..<900 {
            let a = Float(i) * 0.05
            m.step(dt: dt, tilt: [cos(a) * 0.9, sin(a) * 0.9], jerk: [sin(a * 3) * 3, cos(a * 2) * 3, 2],
                   enabled: true)
            XCTAssertLessThanOrEqual(simd_length(m.offset), ShakeModel.maxOffset + 1e-5)
            XCTAssertLessThanOrEqual(m.hop, ShakeModel.maxHop + 1e-5)
            XCTAssertLessThanOrEqual(abs(m.wobble), ShakeModel.maxWobble + 1e-5)
        }
    }

    /// 撞边：弹回很短、很缓（作者要求）。用左右甩来测——甩出去的速度比慢慢滑快得多
    func testFlickBouncesOnlyALittle() {
        var m = ShakeModel()
        var impact: Float = 0
        var rebound: Float = 0
        for i in 0..<180 {
            m.step(dt: dt, tilt: .zero, jerk: [i < 8 ? -1.5 : 0, 0, 0], enabled: true)
            if m.hitWall { impact = m.wallImpact }
            if impact > 0 { rebound = max(rebound, ShakeModel.maxOffset - m.offset.x) }
        }
        XCTAssertGreaterThan(impact, 0, "甩到边上没有出声、震动")
        XCTAssertLessThan(rebound, 0.02, "撞边后弹回去太远了（\(rebound)）")
    }

    /// 轻轻蹭到边不出声；两次碰边声隔得足够开
    func testKnocksAreNotSpammy() {
        var m = ShakeModel()
        var lastKnock: Int? = nil
        for i in 0..<300 {
            m.step(dt: dt, tilt: [0.9, 0], jerk: .zero, enabled: true)
            if m.hitWall {
                if let last = lastKnock {
                    XCTAssertGreaterThanOrEqual(Float(i - last) * dt, ShakeModel.knockGap - 1e-4)
                }
                lastKnock = i
            }
        }
    }

    /// 滑到边上会"磕"一下（画面那边据此出声、震动）
    func testHitsTheWall() {
        var m = ShakeModel()
        var hit = false
        for _ in 0..<120 {
            m.step(dt: dt, tilt: [0.7, 0], jerk: .zero, enabled: true)
            hit = hit || m.hitWall
        }
        XCTAssertTrue(hit, "滑到边上没有磕一下")
        XCTAssertEqual(simd_length(m.offset), ShakeModel.maxOffset, accuracy: 1e-4)
    }

    /// 猛晃一下会颠起来一点，然后落回
    func testJoltMakesASmallHop() {
        var m = ShakeModel()
        m.step(dt: dt, tilt: .zero, jerk: [0, 0, 1.5], enabled: true)
        var peak: Float = 0
        for _ in 0..<60 {
            m.step(dt: dt, tilt: .zero, jerk: .zero, enabled: true)
            peak = max(peak, m.hop)
        }
        XCTAssertGreaterThan(peak, 0.003, "猛晃一下没有颠")
        XCTAssertEqual(m.hop, 0, accuracy: 1e-6, "颠完没落回地面")
    }

    /// ★ 上下摇只颠不走 ★（作者选的方案 B）：位置一点都不变，只离地颠一下、落回时报一声
    func testUpDownShakeOnlyHops() {
        var m = ShakeModel()
        var landed = 0
        var peak: Float = 0
        for i in 0..<120 {
            let up: Float = i < 4 ? 1.6 : 0                 // 上下猛摇一下
            m.step(dt: dt, tilt: .zero, jerk: [0, up, up * 0.5], enabled: true)
            peak = max(peak, m.hop)
            if m.hopLanded { landed += 1 }
        }
        XCTAssertEqual(simd_length(m.offset), 0, accuracy: 1e-6, "上下摇不该让硬币前后走")
        XCTAssertGreaterThan(peak, 0.02, "上下摇颠得太低（作者要高一点）")
        XCTAssertEqual(landed, 1, "落回玻璃应该正好报一次")
    }

    /// 左右甩仍然会让硬币往反方向冲
    func testSideFlickStillKicks() {
        var m = ShakeModel()
        for i in 0..<30 {
            m.step(dt: dt, tilt: .zero, jerk: [i < 6 ? 1.2 : 0, 0, 0], enabled: true)
        }
        XCTAssertLessThan(m.offset.x, -0.005, "往右甩，硬币应该往左冲")
    }

    /// 不允许动的时候（抛掷中、手指按着）：原地不动
    func testIgnoresInputWhenDisabled() {
        var m = ShakeModel()
        run(&m, seconds: 1, tilt: [1, 1], jerk: [2, 2, 2], enabled: false)
        XCTAssertEqual(simd_length(m.offset), 0, accuracy: 1e-6)
        XCTAssertEqual(m.hop, 0)
    }

    /// 清零之后完全回到初始状态
    func testResetClearsEverything() {
        var m = ShakeModel()
        run(&m, seconds: 0.3, tilt: [0.5, 0.5], jerk: [1, 1, 1])
        m.reset()
        XCTAssertEqual(m.offset, .zero)
        XCTAssertEqual(m.hop, 0)
        XCTAssertEqual(m.wobble, 0)
    }
}

/// 特写时不响应歪手机、晃手机（作者要求，不然会出框）
final class ShakeCloseUpTests: XCTestCase {
    func testOnlyInFarView() {
        XCTAssertTrue(CoinScene.shakeAllowed(zoom: 0))
        XCTAssertFalse(CoinScene.shakeAllowed(zoom: 1), "特写时还在响应摇晃，会出框")
        XCTAssertFalse(CoinScene.shakeAllowed(zoom: 0.5), "推近到一半就该关掉了")
    }
}

/// 水平仪：手机歪多少，硬币反着歪多少，在人眼里始终是平的
final class LevelTests: XCTestCase {

    /// 平常拿着的姿势（往后仰 45°）
    private let held = simd_normalize(SIMD3<Float>(0, -0.7, -0.7))

    /// 没歪：不转
    func testNoTiltNoTurn() {
        let r = ShakeModel.levelRotation(baselineDown: held, currentDown: held)
        XCTAssertEqual(r.angle, 0, accuracy: 1e-6)
    }

    /// 手机往左歪（左边低）：硬币往右歪——转完之后它的"上方"偏向屏幕右边
    func testRollLeftLiftsLeftEdge() {
        // 往左歪 20°：重力在手机里往左偏
        let a: Float = 20 * .pi / 180
        let rolled = SIMD3<Float>(-sin(a) * 0.7 / 0.7, held.y * cos(a), held.z)
        let r = ShakeModel.levelRotation(baselineDown: held, currentDown: simd_normalize(rolled))
        let up = simd_quatf(angle: r.angle, axis: r.axis).act(-held)
        XCTAssertGreaterThan(up.x, 0.05, "硬币的上方应该偏向右边（左边缘抬起）")
        XCTAssertGreaterThan(r.angle, 0.1)
    }

    /// 转完之后，硬币的上方正好指向现在真正的上方
    func testAlignsWithTrueUp() {
        let now = simd_normalize(SIMD3<Float>(0.3, -0.6, -0.6))
        let r = ShakeModel.levelRotation(baselineDown: held, currentDown: now)
        let up = simd_quatf(angle: r.angle, axis: r.axis).act(-held)
        XCTAssertEqual(simd_dot(up, -now), 1, accuracy: 1e-4)
    }

    /// 歪得再狠，硬币最多歪 maxLevelDegrees，不会立起来
    func testCapped() {
        let r = ShakeModel.levelRotation(baselineDown: held,
                                         currentDown: SIMD3<Float>(-1, 0, 0))
        XCTAssertLessThanOrEqual(r.angle, ShakeModel.maxLevelDegrees * .pi / 180 + 1e-5)
    }
}
