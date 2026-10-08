// 动画计算的自动测试（任务 T16、T17）。
//
// 动画好不好看要用眼睛判断，但"有没有算错"可以自动验：
// 起点和终点必须落在原位、中途必须真的飞起来、转动只能往前不能倒退，
// 最关键的是——演完那一刻的朝向必须等于预先决定的结果。

import XCTest
@testable import CoinFlip

final class FlipAnimatorTests: XCTestCase {

    private let scale = 0.9

    private func makePlan(speed: Double = 1500,
                          start: CoinFace = .sun,
                          result: CoinFace = .moon) -> FlipPlan {
        FlipPlanner.makePlan(speed: speed, startFace: start, result: result)
    }

    private func total(_ plan: FlipPlan) -> Double {
        Double(plan.halfTurns) * 180
    }

    // MARK: - 起落

    /// 刚脱手那一刻：还在原位，一点没转
    func testStartsAtRest() {
        let pose = FlipAnimator.pose(at: 0, plan: makePlan(), heightScale: scale)
        XCTAssertEqual(pose.height, 0, accuracy: 1e-9)
        XCTAssertEqual(pose.degrees, 0, accuracy: 1e-9)
        XCTAssertFalse(pose.isFinished)
    }

    /// 飞到一半：确实离地了
    func testRisesInTheAir() {
        let plan = makePlan()
        let pose = FlipAnimator.pose(at: plan.landTime / 2, plan: plan, heightScale: scale)
        XCTAssertGreaterThan(pose.height, 0, "飞到一半应该离地")
    }

    /// 最高点大约就是时间表里写的高度
    func testPeakMatchesPlannedHeight() {
        let plan = makePlan()
        var highest = 0.0
        for i in 0...200 {
            let t = plan.landTime * Double(i) / 200
            highest = max(highest, FlipAnimator.pose(at: t, plan: plan, heightScale: scale).height)
        }
        XCTAssertEqual(highest, plan.height * scale, accuracy: plan.height * scale * 0.02)
    }

    /// 落地那一刻：贴回平面
    func testBackToGroundOnLanding() {
        let plan = makePlan()
        let pose = FlipAnimator.pose(at: plan.landTime, plan: plan, heightScale: scale)
        XCTAssertEqual(pose.height, 0, accuracy: 1e-6)
    }

    /// 停稳之后：落回原位，并标记为已完成
    func testFinishesFlat() {
        let plan = makePlan()
        let pose = FlipAnimator.pose(at: plan.endTime + 1, plan: plan, heightScale: scale)
        XCTAssertEqual(pose.height, 0, accuracy: 1e-9)
        XCTAssertTrue(pose.isFinished)
    }

    // MARK: - 落地后的弹跳与停滞（T17）

    /// 落地后有一连串磕碰，而不是只响一声
    func testHasManyContacts() {
        let plan = makePlan()
        XCTAssertGreaterThanOrEqual(plan.contacts.count, 6, "磕碰次数太少，没有'嗒嗒嗒'的感觉")
        XCTAssertEqual(plan.contacts.first?.time, plan.landTime, "第一次磕碰应该就是落地")
        XCTAssertEqual(plan.contacts.first?.strength, 1, "落地那一下应该最重")
    }

    /// 磕碰的间隔越来越短——这是真硬币躺平前最有辨识度的声音
    func testContactsGetDenser() {
        let plan = makePlan()
        // 跳过最初的落地和小跳，看后面那串磕碰
        let taps = Array(plan.contacts.dropFirst(2))
        var gaps: [Double] = []
        for i in 1..<taps.count {
            gaps.append(taps[i].time - taps[i - 1].time)
        }
        for i in 1..<gaps.count {
            XCTAssertLessThan(gaps[i], gaps[i - 1] + 1e-9,
                              "第 \(i + 1) 次磕碰的间隔反而变长了")
        }
    }

    /// 一次比一次轻，而且都发生在停稳之前
    func testContactsFadeOut() {
        let plan = makePlan()
        for i in 1..<plan.contacts.count {
            XCTAssertLessThanOrEqual(plan.contacts[i].strength,
                                     plan.contacts[i - 1].strength + 1e-9,
                                     "第 \(i + 1) 次磕碰反而更重")
        }
        for c in plan.contacts {
            XCTAssertGreaterThanOrEqual(c.time, plan.landTime)
            XCTAssertLessThanOrEqual(c.time, plan.endTime + 1e-6)
        }
    }

    /// 落地那一刻硬币还歪着，因为真硬币是边缘先着地的
    func testStillTiltedOnLanding() {
        let plan = makePlan()
        let atLanding = FlipAnimator.pose(at: plan.landTime, plan: plan, heightScale: scale).degrees
        let remaining = total(plan) - atLanding
        XCTAssertEqual(remaining, FlipPlanner.landingTilt, accuracy: 0.5,
                       "落地时应该还歪着约 \(FlipPlanner.landingTilt) 度")
    }

    /// 落地之后还在继续收那点歪斜，直到躺平
    func testKeepsTurningAfterLanding() {
        let plan = makePlan()
        let atLanding = FlipAnimator.pose(at: plan.landTime, plan: plan, heightScale: scale).degrees
        let later = FlipAnimator.pose(at: (plan.landTime + plan.endTime) / 2,
                                      plan: plan, heightScale: scale).degrees
        XCTAssertGreaterThan(later, atLanding, "落地之后应该还在继续收平")
    }

    /// 落地后会在平面上打转：两头慢、中间最快，收尾要收住不能戛然而止
    func testWobbleEasesInAndOut() {
        let plan = makePlan()
        XCTAssertEqual(FlipAnimator.pose(at: plan.landTime, plan: plan, heightScale: scale)
                        .wobbleDegrees, 0, accuracy: 1e-6, "落地之前不该打转")

        let settle = plan.endTime - plan.landTime
        let step = settle / 20
        func spun(_ a: Double, _ b: Double) -> Double {
            FlipAnimator.pose(at: b, plan: plan, heightScale: scale).wobbleDegrees
                - FlipAnimator.pose(at: a, plan: plan, heightScale: scale).wobbleDegrees
        }
        let early = spun(plan.landTime, plan.landTime + step)
        let middle = spun(plan.landTime + settle / 2, plan.landTime + settle / 2 + step)
        let late = spun(plan.endTime - step, plan.endTime)

        XCTAssertGreaterThan(middle, early, "中途应该比刚落地时转得快")
        XCTAssertGreaterThan(middle, late, "中途应该比临近停住时转得快")
        XCTAssertLessThan(late, middle * 0.25, "收尾转得还是太快，会显得戛然而止")

        let totalSpin = FlipAnimator.pose(at: plan.endTime, plan: plan, heightScale: scale)
            .wobbleDegrees
        XCTAssertEqual(totalSpin, FlipPlanner.wobbleTurns * 360, accuracy: 1,
                       "打转的总圈数不对")
    }

    /// 打转的最快速度不能太离谱，否则屏幕上就是一团糊
    func testWobbleSpeedStaysReadable() {
        let plan = makePlan(speed: 4000)
        let settle = plan.endTime - plan.landTime
        let step = settle / 60
        var fastest = 0.0
        for i in 0..<60 {
            let a = plan.landTime + settle * Double(i) / 60
            let d = FlipAnimator.pose(at: a + step, plan: plan, heightScale: scale).wobbleDegrees
                - FlipAnimator.pose(at: a, plan: plan, heightScale: scale).wobbleDegrees
            fastest = max(fastest, d / step)
        }
        XCTAssertLessThan(fastest, 1000, "打转最快到了每秒 \(Int(fastest / 360)) 圈，太快了")
    }

    /// 打转只绕竖直轴，不会把朝上的那一面转掉
    func testWobbleDoesNotChangeWhichFaceIsUp() {
        let plan = makePlan()
        for i in 0...20 {
            let t = plan.landTime + (plan.endTime - plan.landTime) * Double(i) / 20
            let pose = FlipAnimator.pose(at: t, plan: plan, heightScale: scale)
            let halfTurns = Int((pose.degrees / 180).rounded())
            let up = halfTurns % 2 == 0 ? plan.startFace : plan.startFace.opposite
            XCTAssertEqual(up, plan.result, "摇摆途中朝上的面变了")
        }
    }

    /// 越接近躺平，收得越慢
    func testRotationSlowsDownTowardTheEnd() {
        let plan = makePlan()
        let settle = plan.endTime - plan.landTime
        let step = settle / 10

        func turned(from a: Double, to b: Double) -> Double {
            FlipAnimator.pose(at: b, plan: plan, heightScale: scale).degrees
                - FlipAnimator.pose(at: a, plan: plan, heightScale: scale).degrees
        }

        let early = turned(from: plan.landTime, to: plan.landTime + step)
        let late = turned(from: plan.endTime - step, to: plan.endTime)
        XCTAssertGreaterThan(early, late, "落地刚开始应该比临近躺平时收得快")
    }

    // MARK: - 正确性

    /// ★ 最重要的一条：演完那一刻朝上的面，必须等于预先决定的结果。
    /// 这是把"动画"和"结果"真正对上的地方。
    func testFinalOrientationMatchesResult() {
        for start in [CoinFace.sun, .moon] {
            for result in [CoinFace.sun, .moon] {
                for speed in stride(from: 0.0, through: 4000.0, by: 100.0) {
                    let plan = makePlan(speed: speed, start: start, result: result)
                    let pose = FlipAnimator.pose(at: plan.endTime, plan: plan, heightScale: scale)

                    let halfTurns = Int((pose.degrees / 180).rounded())
                    let landed = halfTurns % 2 == 0 ? start : start.opposite

                    XCTAssertEqual(landed, result,
                                   "起始 \(start) → 结果 \(result)，速度 \(Int(speed)) 时演成了 \(landed)")
                }
            }
        }
    }

    /// 整个过程中硬币不会沉到地面以下
    func testNeverGoesBelowGround() {
        let plan = makePlan(speed: 3000)
        for i in 0...400 {
            let t = plan.endTime * Double(i) / 400
            let pose = FlipAnimator.pose(at: t, plan: plan, heightScale: scale)
            XCTAssertGreaterThanOrEqual(pose.height, -1e-9, "第 \(t) 秒沉到地下了")
        }
    }

    /// 转动只会往前，不会倒着转回去
    func testRotationNeverGoesBackwards() {
        let plan = makePlan(speed: 2000)
        var previous = -1.0
        for i in 0...400 {
            let t = plan.endTime * Double(i) / 400
            let d = FlipAnimator.pose(at: t, plan: plan, heightScale: scale).degrees
            XCTAssertGreaterThanOrEqual(d, previous - 1e-9, "第 \(t) 秒倒转了")
            previous = d
        }
    }

    /// 快到停稳时，转动已经非常接近最终角度，不会最后一帧猛地跳过去
    func testNoSuddenJumpAtTheEnd() {
        let plan = makePlan(speed: 2500)
        let justBefore = FlipAnimator.pose(at: plan.endTime - 0.001,
                                           plan: plan, heightScale: scale).degrees
        XCTAssertEqual(justBefore, total(plan), accuracy: 1.0,
                       "最后一刻还差 \(total(plan) - justBefore) 度，会看到硬币猛地一跳")
    }
}
