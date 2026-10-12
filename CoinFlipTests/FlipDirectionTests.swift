// 翻转方向跟着手指（P09）。
//
// 往左上划就朝左上翻，往右上划就朝右上翻。只改"往哪边翻"，不改"翻几个半圈"。
//
// ★ 这里守的是最容易出事的一处：斜着的轴翻奇数个半圈，硬币会多出一截朝向，
//   打转必须把它补回来，否则停稳那一刻硬币会原地扭一下——
//   看起来就像"落地看到的面和最后的结果接不上"（这个项目栽过一次）。

import XCTest
import simd
@testable import CoinFlip

final class FlipDirectionTests: XCTestCase {

    private let scale = Double(CoinScene.heightScale)
    private let directions: [Double] = [-50, -23, 0, 17, 50]

    /// 两个朝向是不是同一个（四元数正负都表示同一个朝向）
    private func same(_ a: simd_quatf, _ b: simd_quatf, tolerance: Float = 1e-4) -> Bool {
        abs(abs(simd_dot(a.vector, b.vector)) - 1) < tolerance
    }

    private func rotation(_ plan: FlipPlan, at t: Double, direction: Double) -> simd_quatf {
        let yaw = CoinSceneView.axisYaw(forFlipDirection: direction)
        let pose = FlipAnimator.pose(at: t, plan: plan, heightScale: scale, axisYaw: yaw)
        return CoinSceneView.flightRotation(startFace: plan.startFace,
                                            degrees: Float(pose.degrees),
                                            wobbleDegrees: Float(pose.wobbleDegrees),
                                            nutationDegrees: Float(pose.nutationDegrees),
                                            axisYawDegrees: Float(yaw),
                                            selfSpinDegrees: Float(pose.selfSpinDegrees))
    }

    /// ★ 停稳那一刻，不管往哪边划、翻了几个半圈，姿态都正好等于躺平姿态 ★
    func testEndsExactlyAtRestingPose() {
        for start in [CoinFace.sun, .moon] {
            for result in [CoinFace.sun, .moon] {
                for speed in [300.0, 900.0, 1800.0, 3000.0] {
                    let plan = FlipPlanner.makePlan(speed: speed, distance: 200,
                                                    startFace: start, result: result)
                    for d in directions {
                        let end = rotation(plan, at: plan.endTime, direction: d)
                        XCTAssertTrue(same(end, CoinSceneView.restingRotation(for: result)),
                                      "往 \(d)° 划、\(plan.halfTurns) 个半圈：停稳时姿态和躺平对不上")
                        // 最后一帧也要几乎一样，不能在停稳那一下扭一截
                        let almost = rotation(plan, at: plan.endTime - 1.0 / 60, direction: d)
                        let angle = 2 * acos(min(1, abs(simd_dot(almost.vector, end.vector))))
                        XCTAssertLessThan(angle * 180 / .pi, 3,
                                          "往 \(d)° 划：最后一帧和停稳差了 \(angle * 180 / .pi)°")
                    }
                }
            }
        }
    }

    /// 停稳时朝上的那一面必须等于结果
    func testFaceUpMatchesResult() {
        for start in [CoinFace.sun, .moon] {
            for result in [CoinFace.sun, .moon] {
                let plan = FlipPlanner.makePlan(speed: 1500, distance: 200,
                                                startFace: start, result: result)
                for d in directions {
                    let normal = rotation(plan, at: plan.endTime, direction: d).act([0, 0, 1])
                    let sunUp = normal.y > 0.99
                    XCTAssertEqual(sunUp ? CoinFace.sun : .moon, result,
                                   "往 \(d)° 划：朝上的面和结果不一致")
                }
            }
        }
    }

    /// 脱手那一刻姿态不能跳：斜着翻也要从原来躺着的样子起步
    func testLaunchDoesNotJump() {
        let plan = FlipPlanner.makePlan(speed: 1500, distance: 200, startFace: .sun, result: .moon)
        for d in directions {
            XCTAssertTrue(same(rotation(plan, at: 0, direction: d),
                               CoinSceneView.restingRotation(for: .sun)),
                          "往 \(d)° 划：一脱手硬币就扭了一下")
        }
    }

    /// ★ 左划正好是右划照镜子 ★（第一版不是，作者看出来了）
    func testLeftIsMirrorOfRight() {
        let plan = FlipPlanner.makePlan(speed: 1500, distance: 200, startFace: .sun, result: .moon)
        for d in [15.0, 30.0, 50.0] {
            for i in 0...20 {
                let t = plan.endTime * Double(i) / 20
                let right = rotation(plan, at: t, direction: d)
                let left = rotation(plan, at: t, direction: -d)
                // 照镜子（左右翻转）：币面朝向 (0,0,1) 的 x 取反；币面横向 (1,0,0) 整个取反再 x 取反
                let nR = right.act([0, 0, 1]), nL = left.act([0, 0, 1])
                XCTAssertEqual(nL.x, -nR.x, accuracy: 1e-4, "第 \(i) 帧：左右不对称")
                XCTAssertEqual(nL.y, nR.y, accuracy: 1e-4)
                XCTAssertEqual(nL.z, nR.z, accuracy: 1e-4)
                let xR = right.act([1, 0, 0]), xL = left.act([1, 0, 0])
                XCTAssertEqual(xL.x, xR.x, accuracy: 1e-4, "第 \(i) 帧：左右不对称")
                XCTAssertEqual(xL.y, -xR.y, accuracy: 1e-4)
                XCTAssertEqual(xL.z, -xR.z, accuracy: 1e-4)
            }
        }
    }

    /// 屏幕上看到的翻转方向 = 手指划的方向（把镜头斜看的透视折算掉之后）
    func testScreenDirectionMatchesSwipe() {
        let el = Double(CoinScene.elevationFar) * .pi / 180
        for d in [-50.0, -20.0, 0, 35, 50] {
            let yaw = CoinSceneView.axisYaw(forFlipDirection: d) * .pi / 180
            // 地面上的翻转方向垂直于翻转轴；投到屏幕上（往上的分量被压成 sin 28°）
            let groundX = sin(-yaw), groundZ = -cos(-yaw)
            let screen = atan2(groundX, -groundZ * sin(el)) * 180 / .pi
            XCTAssertEqual(screen, d, accuracy: 0.01, "划 \(d)°，屏幕上看到的是 \(screen)°")
        }
    }

    /// 往里翻：一抛起来，靠近镜头的那一边先往上翘
    func testTumblesAwayFromViewer() {
        let plan = FlipPlanner.makePlan(speed: 1500, distance: 200, startFace: .sun, result: .moon)
        let early = rotation(plan, at: plan.landTime * 0.05, direction: 0)
        // 躺平时币面局部的 −y 指向镜头（+z），翻起来后它应该往上（y > 0）
        let nearEdge = early.act([0, -1, 0])
        XCTAssertGreaterThan(nearEdge.y, 0, "靠近镜头的那一边往下沉了——翻反了")
    }

    /// 手指方向的换算：正上方 0，往右为正、往左为负，太歪的封顶
    func testDirectionFromSwipe() {
        XCTAssertEqual(SwipeDetector.flipDirection(translation: CGSize(width: 0, height: -200)), 0)
        XCTAssertEqual(SwipeDetector.flipDirection(translation: CGSize(width: 100, height: -100)),
                       45, accuracy: 1e-9)
        XCTAssertEqual(SwipeDetector.flipDirection(translation: CGSize(width: -100, height: -100)),
                       -45, accuracy: 1e-9)
        XCTAssertEqual(SwipeDetector.flipDirection(translation: CGSize(width: 300, height: -100)),
                       SwipeDetector.maxFlipAngle)
    }
}

/// 拖动时"跟手原地转"和"往上抛"不打架（P09）
final class SpinFollowTests: XCTestCase {

    /// 往上划（离竖直 50° 以内）：硬币完全不跟着原地转
    func testNoSpinWhileSwipingUp() {
        XCTAssertEqual(CoinSceneView.spinFollowWeight(dragUp: 200, dragSide: 0), 0)
        XCTAssertEqual(CoinSceneView.spinFollowWeight(dragUp: 200, dragSide: 200), 0)   // 45°
        XCTAssertEqual(CoinSceneView.spinFollowWeight(dragUp: 100, dragSide: 115), 0)   // 约 49°
    }

    /// 横着拨：完全跟手
    func testFullSpinWhileSweepingSideways() {
        XCTAssertEqual(CoinSceneView.spinFollowWeight(dragUp: 0, dragSide: 150), 1)
        XCTAssertEqual(CoinSceneView.spinFollowWeight(dragUp: 40, dragSide: 150), 1)    // 约 75°
        XCTAssertEqual(CoinSceneView.spinFollowWeight(dragUp: -60, dragSide: 150), 1)   // 往下拨也算拨
    }

    /// 中间平滑过渡，不会一下子跳
    func testBlendsSmoothly() {
        var last: Float = -1
        for deg in stride(from: 40.0, through: 80.0, by: 1.0) {
            let r = deg * .pi / 180
            let w = CoinSceneView.spinFollowWeight(dragUp: CGFloat(cos(r) * 200),
                                                   dragSide: CGFloat(sin(r) * 200))
            XCTAssertGreaterThanOrEqual(w, last)
            XCTAssertLessThan(w - max(last, 0), 0.25, "\(deg)° 附近跳得太猛")
            last = w
        }
    }
}
