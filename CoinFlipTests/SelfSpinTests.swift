// 自转（P10）：硬币在空中绕自己的中心轴转，像飞盘。

import XCTest
import simd
@testable import CoinFlip

final class SelfSpinTests: XCTestCase {

    private let scale = Double(CoinScene.heightScale)

    /// 起飞时从 0 开始，停稳时正好转完整圈
    func testStartsAtZeroAndEndsOnWholeTurn() {
        let plan = FlipPlanner.makePlan(speed: 1500, distance: 200, startFace: .sun, result: .moon)
        XCTAssertEqual(FlipAnimator.pose(at: 0, plan: plan, heightScale: scale).selfSpinDegrees,
                       0, accuracy: 1e-9)
        let end = FlipAnimator.pose(at: plan.endTime, plan: plan, heightScale: scale).selfSpinDegrees
        XCTAssertEqual(end.truncatingRemainder(dividingBy: 360), 0, accuracy: 1e-9,
                       "自转没停在整圈上，停稳那一下图案会原地扭")
    }

    /// 空中转得快、落地后越来越慢，停稳前几乎不转了
    func testSlowsDownToAStop() {
        let plan = FlipPlanner.makePlan(speed: 1500, distance: 200, startFace: .sun, result: .moon)
        func rate(_ t: Double) -> Double {
            let h = 1.0 / 600
            return (FlipAnimator.pose(at: t + h, plan: plan, heightScale: scale).selfSpinDegrees
                - FlipAnimator.pose(at: t, plan: plan, heightScale: scale).selfSpinDegrees) / h
        }
        let early = rate(0.01), mid = rate(plan.landTime), late = rate(plan.endTime - 0.02)
        XCTAssertGreaterThan(early, mid)
        XCTAssertGreaterThan(mid, late)
        XCTAssertLessThan(late, early * 0.05, "停稳前还在转，收尾会显得突然")
    }

    /// ★ 加了自转，停稳姿态照样严丝合缝、朝上的面照样等于结果 ★
    func testDoesNotChangeTheResult() {
        for start in [CoinFace.sun, .moon] {
            for result in [CoinFace.sun, .moon] {
                for speed in [300.0, 1500.0, 3000.0] {
                    let plan = FlipPlanner.makePlan(speed: speed, distance: 200,
                                                    startFace: start, result: result)
                    let pose = FlipAnimator.pose(at: plan.endTime, plan: plan, heightScale: scale)
                    let q = CoinSceneView.flightRotation(startFace: start,
                                                         degrees: Float(pose.degrees),
                                                         wobbleDegrees: Float(pose.wobbleDegrees),
                                                         nutationDegrees: Float(pose.nutationDegrees),
                                                         selfSpinDegrees: Float(pose.selfSpinDegrees))
                    let rest = CoinSceneView.restingRotation(for: result)
                    XCTAssertEqual(abs(simd_dot(q.vector, rest.vector)), 1, accuracy: 1e-4,
                                   "加了自转，停稳时姿态和躺平对不上")
                    XCTAssertGreaterThan((q.act([0, 0, 1]).y > 0) == (result == .sun) ? 1 : 0, 0,
                                         "加了自转，朝上的面和结果不一致")
                }
            }
        }
    }
}
