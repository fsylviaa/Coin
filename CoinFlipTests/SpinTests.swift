// 横拨自旋的自动测试。
//
// 这是一个"把玩"动作：停稳后横着一拨，硬币原地转几圈再缓缓停下。
//
// ★ 它绝不能改变朝上的是哪一面。★ 这是它敢做在画面层、不经过大脑的唯一理由。
//   转的是竖直轴，所以结果不受影响——下面第一组测试就是守这条的。

import XCTest
import simd
@testable import CoinFlip

final class SpinTests: XCTestCase {

    // MARK: - ★ 不能改变结果 ★

    /// 绕竖直轴转任意角度，朝上的那一面都不变。
    ///
    /// 做法是真的把转角乘上去，再看硬币的"正面法线"还朝不朝原来那边——
    /// 这和画面里实际做的是同一套计算，不是另写一遍。
    func testSpinNeverChangesWhichFaceIsUp() {
        for face in [CoinFace.sun, .moon] {
            let resting = CoinSceneView.restingRotation(for: face)
            let upBefore = resting.act(SIMD3<Float>(0, 0, 1))

            for degrees in stride(from: Float(0), through: 1080, by: 17) {
                let yaw = simd_quatf(angle: degrees * .pi / 180, axis: [0, 1, 0])
                let upAfter = (yaw * resting).act(SIMD3<Float>(0, 0, 1))

                // 竖直分量就是"哪一面朝上"。它必须纹丝不动。
                XCTAssertEqual(upAfter.y, upBefore.y, accuracy: 1e-5,
                               "\(face) 转了 \(Int(degrees)) 度之后，朝上的面变了")
            }
        }
    }

    // MARK: - 转速衰减

    /// 会停。不会越转越快，也不会无限趋近永远停不下来。
    func testSpinComesToRest() {
        var v = CoinScene.spinMaxSpeed
        var seconds = 0.0
        let step = 1.0 / 60

        while v != 0 {
            v = CoinSceneView.decayedSpin(v, dt: step)
            seconds += step
            if seconds > 30 { break }
        }
        XCTAssertEqual(v, 0, "转不停")
        XCTAssertLessThan(seconds, 12, "转了 \(Int(seconds)) 秒还不停，太久了")
        XCTAssertGreaterThan(seconds, 1.0, "一拨就停，没有把玩的余地")
    }

    /// 一路变慢，不会中途回升
    func testSpinOnlySlowsDown() {
        var v = CoinScene.spinMaxSpeed
        for _ in 0..<400 {
            let next = CoinSceneView.decayedSpin(v, dt: 1.0 / 60)
            XCTAssertLessThanOrEqual(abs(next), abs(v) + 1e-4, "转速中途变快了")
            v = next
            if v == 0 { break }
        }
    }

    /// ★ 停得平顺 ★（2026-10，作者说偶尔停得突然）：最后一帧不会从一个看得出的速度一下变成 0，
    /// 每一帧掉的速度也不会突然变大
    func testSpinStopsSmoothly() {
        var v: Float = 300
        var lastDrop: Float?
        while v != 0 {
            let next = CoinSceneView.decayedSpin(v, dt: 1.0 / 60)
            let drop = abs(v) - abs(next)
            if let last = lastDrop {
                XCTAssertLessThanOrEqual(drop, last + 0.05, "转速 \(v) 时一帧掉得比上一帧多，像被刹了一下")
            }
            if next == 0 { XCTAssertLessThan(abs(v), 1.5, "从 \(v)°/秒 一下停住，停得太突然") }
            lastDrop = drop
            v = next
        }
    }

    /// 往左拨就往左转，方向不会被衰减弄反
    func testSpinKeepsItsDirection() {
        var v = -CoinScene.spinMaxSpeed
        for _ in 0..<60 {
            v = CoinSceneView.decayedSpin(v, dt: 1.0 / 60)
            if v == 0 { break }
            XCTAssertLessThan(v, 0, "往左拨的硬币开始往右转了")
        }
    }

    /// 再使劲也封顶，图案不会糊成一片
    func testSpinSpeedIsCapped() {
        for speed in [500.0, 5_000.0, 50_000.0, -50_000.0] {
            let impulse = SpinImpulse(sideSpeed: speed)
            XCTAssertLessThanOrEqual(abs(impulse.degreesPerSecond), CoinScene.spinMaxSpeed,
                                     "速度 \(Int(speed)) 没有被封顶")
        }
        XCTAssertLessThan(SpinImpulse(sideSpeed: -3000).degreesPerSecond, 0,
                          "往左拨换算出来的方向错了")
    }

    // MARK: - 手势分辨

    /// 横着一拨会被认出来，而且方向正确
    func testSideFlickIsRecognised() {
        let right = SwipeDetector.evaluateSpin(translation: CGSize(width: 90, height: 8),
                                               velocity: CGSize(width: 700, height: 0))
        XCTAssertEqual(right, .spin(speed: 700))

        let left = SwipeDetector.evaluateSpin(translation: CGSize(width: -90, height: -8),
                                              velocity: CGSize(width: -700, height: 0))
        XCTAssertEqual(left, .spin(speed: -700))
    }

    /// 太短、太慢、太歪的都不算
    func testWeakOrSteepGesturesAreIgnored() {
        // 太短
        XCTAssertEqual(SwipeDetector.evaluateSpin(translation: CGSize(width: 10, height: 0),
                                                  velocity: CGSize(width: 900, height: 0)), .ignored)
        // 太慢
        XCTAssertEqual(SwipeDetector.evaluateSpin(translation: CGSize(width: 90, height: 0),
                                                  velocity: CGSize(width: 40, height: 0)), .ignored)
        // 太歪，更像是在抛
        XCTAssertEqual(SwipeDetector.evaluateSpin(translation: CGSize(width: 60, height: -120),
                                                  velocity: CGSize(width: 600, height: -900)), .ignored)
    }

    /// ★ 想抛的时候不能被判成拨。★
    /// 两者的允许范围有一小段重叠，调用方先问上划，所以上划一定赢。
    func testAnUpwardSwipeIsStillAToss() {
        let translation = CGSize(width: 40, height: -120)
        let velocity = CGSize(width: 300, height: -1400)

        guard case .swipeUp = SwipeDetector.evaluate(translation: translation,
                                                     velocity: velocity) else {
            return XCTFail("这一划本该算抛出")
        }
    }
}
