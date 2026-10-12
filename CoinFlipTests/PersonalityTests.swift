// 每一次抛掷的"性格"（P11）。
//
// ★ 守的是三条线：结果永远对、停稳永远严丝合缝、时长不变长。★
// 用固定种子抽几百个性格反复核对——随机的东西必须用大量样本来测。

import XCTest
import simd
@testable import CoinFlip

final class PersonalityTests: XCTestCase {

    private let scale = Double(CoinScene.heightScale)

    private func randomPlans(count: Int = 300) -> [FlipPlan] {
        var rng = SplitMix64(seed: 42)
        var plans: [FlipPlan] = []
        for i in 0..<count {
            let start: CoinFace = i % 2 == 0 ? .sun : .moon
            let result: CoinFace = (i / 2) % 2 == 0 ? .sun : .moon
            let speed = 200 + Double(i % 15) * 200
            plans.append(FlipPlanner.makePlan(speed: speed, distance: 60 + Double(i % 7) * 40,
                                              startFace: start, result: result,
                                              personality: .random(using: &rng)))
        }
        return plans
    }

    /// 性格永远落在设定的范围里
    func testStaysInRange() {
        for plan in randomPlans() {
            let p = plan.personality
            XCTAssertTrue(FlipPersonality.landingTiltRange.contains(p.landingTiltOffset))
            XCTAssertTrue(FlipPersonality.hopScaleRange.contains(p.hopScale))
            XCTAssertTrue(FlipPersonality.rattleTapsRange.contains(p.rattleTaps))
            XCTAssertTrue(FlipPersonality.precessionScaleRange.contains(p.precessionScale))
            XCTAssertTrue(p.side == 1 || p.side == -1)
        }
    }

    /// ★ 性格不改变结果 ★：半圈数的奇偶永远对，停稳时朝上的面永远等于结果
    func testNeverChangesTheResult() {
        for plan in randomPlans() {
            XCTAssertEqual(FlipPlanner.finalFace(of: plan), plan.result)
            let pose = FlipAnimator.pose(at: plan.endTime, plan: plan, heightScale: scale)
            let q = CoinSceneView.flightRotation(startFace: plan.startFace,
                                                 degrees: Float(pose.degrees),
                                                 wobbleDegrees: Float(pose.wobbleDegrees),
                                                 nutationDegrees: Float(pose.nutationDegrees),
                                                 selfSpinDegrees: Float(pose.selfSpinDegrees))
            let rest = CoinSceneView.restingRotation(for: plan.result)
            XCTAssertEqual(abs(simd_dot(q.vector, rest.vector)), 1, accuracy: 1e-4,
                           "某个性格让停稳时的姿态和躺平对不上")
        }
    }

    /// 最后一帧和停稳之间不能扭（性格改了落地斜度和打转方向，这一条要重新守）
    func testLastFrameStillMatches() {
        for plan in randomPlans(count: 120) {
            func q(_ t: Double) -> simd_quatf {
                let pose = FlipAnimator.pose(at: t, plan: plan, heightScale: scale)
                return CoinSceneView.flightRotation(startFace: plan.startFace,
                                                    degrees: Float(pose.degrees),
                                                    wobbleDegrees: Float(pose.wobbleDegrees),
                                                    nutationDegrees: Float(pose.nutationDegrees),
                                                    selfSpinDegrees: Float(pose.selfSpinDegrees))
            }
            let a = q(plan.endTime - 1.0 / 60), b = q(plan.endTime)
            let angle = 2 * acos(min(1, abs(simd_dot(a.vector, b.vector)))) * 180 / .pi
            XCTAssertLessThan(angle, 3, "最后一帧和停稳差了 \(angle)°")
        }
    }

    /// ★ 时长不变长 ★：和没有性格的同一抛相比，最多只多出一点点
    func testDoesNotMakeItLonger() {
        var rng = SplitMix64(seed: 7)
        for speed in stride(from: 200.0, through: 3200.0, by: 300.0) {
            let neutral = FlipPlanner.makePlan(speed: speed, distance: 200,
                                               startFace: .sun, result: .moon)
            for _ in 0..<20 {
                let p = FlipPlanner.makePlan(speed: speed, distance: 200,
                                             startFace: .sun, result: .moon,
                                             personality: .random(using: &rng))
                XCTAssertLessThanOrEqual(p.endTime, neutral.endTime * 1.03,
                                         "某个性格让这一抛变长了")
                XCTAssertEqual(p.landTime, neutral.landTime, accuracy: 1e-9,
                               "性格不该改变飞多久")
                XCTAssertEqual(p.halfTurns, neutral.halfTurns, "性格不该改变翻几个半圈")
            }
        }
    }

    /// 磕碰几下真的跟着性格变（声音、震动照同一张表，所以三者同步）
    func testRattleCountFollowsPersonality() {
        for taps in FlipPersonality.rattleTapsRange {
            let personality = FlipPersonality(landingTiltOffset: 0, hopScale: 1, rattleTaps: taps,
                                              precessionScale: 1, side: 1)
            let plan = FlipPlanner.makePlan(speed: 1500, distance: 200, startFace: .sun,
                                            result: .moon, personality: personality)
            // 落地一下 + 每一下弹跳落回各一下 + 磕碰若干下
            XCTAssertEqual(plan.contacts.count, 1 + plan.bounces.count + taps)
        }
    }

    /// 没有性格时和加性格之前完全一样
    func testNeutralIsUnchanged() {
        XCTAssertEqual(FlipPersonality.neutral.rattleTaps, FlipPlanner.rattleTaps)
        XCTAssertEqual(FlipPersonality.neutral.hopScale, 1)
        XCTAssertEqual(FlipPersonality.neutral.landingTiltOffset, 0)
    }
}
