// 演出时间表的自动测试（任务 T09）。
//
// 这组测试不判断"好不好看"，只判断"讲不讲得通"：
// 高度要落在上下限之间、划得越快抛得越高、落地要早于停稳、结果不能被改掉。

import XCTest
@testable import CoinFlip

final class FlipPlanTests: XCTestCase {

    private let style = StyleProfile.silver

    /// 速度为 0（根本没划动）时，用最低高度，不能是 0 或负数
    func testZeroSpeedUsesMinHeight() {
        let plan = FlipPlanner.makePlan(speed: 0, distance: 0, startFace: .sun, result: .sun, style: style)
        XCTAssertEqual(plan.height, style.minHeight)
    }

    /// 速度大到离谱时，高度被压在上限，不会飞出屏幕
    func testHugeSpeedUsesMaxHeight() {
        let plan = FlipPlanner.makePlan(speed: 100_000, distance: 10_000, startFace: .sun, result: .sun, style: style)
        XCTAssertEqual(plan.height, style.maxHeight)
    }

    /// 划得越快，抛得越高
    func testFasterIsHigher() {
        let slow = FlipPlanner.makePlan(speed: 200, distance: 60, startFace: .sun, result: .sun, style: style)
        let fast = FlipPlanner.makePlan(speed: 500, distance: 120, startFace: .sun, result: .sun, style: style)
        XCTAssertGreaterThanOrEqual(fast.height, slow.height)
    }

    /// 任意速度下，时间顺序都必须是：开始 → 落地 → 停稳
    func testTimeOrder() {
        for speed in stride(from: 0.0, through: 5000.0, by: 50.0) {
            let plan = FlipPlanner.makePlan(speed: speed, distance: speed / 10,
                                            startFace: .sun, result: .moon, style: style)
            XCTAssertGreaterThan(plan.landTime, 0, "speed=\(speed) 落地时刻不是正数")
            XCTAssertGreaterThan(plan.endTime, plan.landTime, "speed=\(speed) 停稳不晚于落地")
        }
    }

    /// 弹起的高度 = 抛起高度 × 风格的弹性
    /// （小数计算有极微小误差，所以允许十亿分之一的偏差）
    func testBounceHeight() {
        let plan = FlipPlanner.makePlan(speed: 1500, distance: 200, startFace: .sun, result: .sun, style: style)
        XCTAssertEqual(plan.bounceHeight, FlipPlanner.hopFloor + plan.height * style.bounciness,
                       accuracy: 1e-9)
    }

    /// 传进去的结果，原样出现在时间表里，不会被动画逻辑改掉
    func testPlanKeepsResult() {
        for result in [CoinFace.sun, .moon] {
            for start in [CoinFace.sun, .moon] {
                let plan = FlipPlanner.makePlan(speed: 900, distance: 150, startFace: start, result: result, style: style)
                XCTAssertEqual(plan.result, result)
                XCTAssertEqual(plan.startFace, start)
            }
        }
    }

    /// 高度始终落在风格规定的上下限之间
    func testHeightAlwaysWithinRange() {
        for speed in stride(from: -500.0, through: 8000.0, by: 25.0) {
            let plan = FlipPlanner.makePlan(speed: speed, distance: max(speed, 0) / 10,
                                            startFace: .moon, result: .sun, style: style)
            XCTAssertGreaterThanOrEqual(plan.height, style.minHeight, "speed=\(speed)")
            XCTAssertLessThanOrEqual(plan.height, style.maxHeight, "speed=\(speed)")
        }
    }

    /// 最慢也要翻够圈数，最快也不会翻得没完没了。
    /// 修正奇偶最多加 1，所以上限是 maxHalfTurns + 1。
    func testHalfTurnsWithinReasonableRange() {
        for speed in stride(from: 0.0, through: 8000.0, by: 25.0) {
            for result in [CoinFace.sun, .moon] {
                let plan = FlipPlanner.makePlan(speed: speed, distance: speed / 10,
                                                startFace: .sun, result: result, style: style)
                XCTAssertGreaterThanOrEqual(plan.halfTurns, FlipPlanner.minHalfTurns, "speed=\(speed)")
                XCTAssertLessThanOrEqual(plan.halfTurns, FlipPlanner.maxHalfTurns + 1, "speed=\(speed)")
            }
        }
    }

    /// 距离也算进用力程度：同样的速度，划得越长抛得越高
    func testLongerSwipeGoesHigher() {
        let short = FlipPlanner.makePlan(speed: 1200, distance: 50,
                                         startFace: .sun, result: .sun, style: style)
        let long = FlipPlanner.makePlan(speed: 1200, distance: 300,
                                        startFace: .sun, result: .sun, style: style)
        XCTAssertGreaterThan(long.height, short.height, "划得更长却没抛得更高")
    }

    /// 只快不长、或只长不快，都到不了最高——要"又快又长"才行
    func testNeitherAloneReachesMax() {
        let fastOnly = FlipPlanner.makePlan(speed: 100_000, distance: 0,
                                            startFace: .sun, result: .sun, style: style)
        let longOnly = FlipPlanner.makePlan(speed: 0, distance: 100_000,
                                            startFace: .sun, result: .sun, style: style)
        XCTAssertLessThan(fastOnly.height, style.maxHeight)
        XCTAssertLessThan(longOnly.height, style.maxHeight)
        XCTAssertGreaterThan(fastOnly.height, longOnly.height, "速度应该占大头")
    }

    /// 整个动画不能太长，否则等得不耐烦。最用力一划也要在 2.5 秒内停稳。
    func testTotalDurationIsAcceptable() {
        let plan = FlipPlanner.makePlan(speed: 100_000, distance: 10_000, startFace: .sun, result: .moon, style: style)
        XCTAssertLessThan(plan.endTime, 2.5, "最用力一划要 \(plan.endTime) 秒才停稳，太久了")
    }

    /// ★ 大跳 + 小跳 + 嗒嗒嗒，时长要有上限 ★
    ///
    /// 作者要"大跳 + 小跳 + 嗒嗒嗒"，多一下小跳躲不开要变长一点；
    /// 但最用力的一抛、性格里最高的弹跳，落地后那段也不许超过下限 0.5 秒（现在最多约 +0.48）。
    /// 轻抛只有一下大跳，没有小跳
    func testLightTossHasNoSmallHop() {
        let plan = FlipPlanner.makePlan(speed: 300, distance: 40, startFace: .sun, result: .moon)
        XCTAssertEqual(plan.bounces.count, 1)
    }

    func testHigherBounceDoesNotLengthenTheFlip() {
        let strongest = FlipPersonality(landingTiltOffset: 0,
                                        hopScale: FlipPersonality.hopScaleRange.upperBound,
                                        rattleTaps: FlipPlanner.rattleTaps,
                                        precessionScale: 1, side: 1)
        for speed in stride(from: 200.0, through: 4000.0, by: 200.0) {
            let plan = FlipPlanner.makePlan(speed: speed, distance: 400,
                                            startFace: .sun, result: .moon,
                                            personality: strongest)
            XCTAssertLessThanOrEqual(plan.endTime - plan.landTime,
                                     FlipPlanner.minSettleSeconds + 0.5,
                                     "速度 \(Int(speed))：小跳太高，把落地后那段拉长了")
            // 小跳落回那一下要明显：不能和落地挤在一起，至少隔开 0.35 秒
            XCTAssertGreaterThan(plan.contacts[1].time - plan.contacts[0].time, 0.35,
                                 "速度 \(Int(speed))：大跳落回太快，两下震动分不开")
            // 小跳只在中等以上力度出现
            let force = FlipPlanner.forceFactor(speed: speed, distance: 400)
            XCTAssertEqual(plan.bounces.count, force >= FlipPlanner.secondHopMinForce ? 2 : 1,
                           "速度 \(Int(speed))：小跳该不该出现判错了")
            if plan.bounces.count == 2 {
                XCTAssertGreaterThan(plan.contacts[2].time - plan.contacts[1].time, 0.18,
                                     "速度 \(Int(speed))：小跳落回太快，和大跳那下分不开")
                // 节奏：落地 > 大跳落回 > 小跳落回 > 嗒嗒嗒
                XCTAssertGreaterThan(plan.contacts[1].strength, plan.contacts[2].strength)
                XCTAssertGreaterThan(plan.contacts[2].strength, plan.contacts[3].strength)
            }
        }
    }

    /// 用力抛能转更多圈（2026-10）：
    /// 平常力度的上限和以前一样；只有爆发区才往上加；一路只涨不跌。
    func testBurstZoneSpinsMore() {
        XCTAssertEqual(FlipPlanner.baseHalfTurns(force: 0), FlipPlanner.minHalfTurns)
        XCTAssertEqual(FlipPlanner.baseHalfTurns(force: FlipPlanner.burstForce),
                       FlipPlanner.normalMaxHalfTurns)
        XCTAssertEqual(FlipPlanner.baseHalfTurns(force: 1), FlipPlanner.maxHalfTurns)
        XCTAssertEqual(FlipPlanner.baseHalfTurns(force: 5), FlipPlanner.maxHalfTurns, "超出范围要贴边")
        var last = 0
        for i in 0...100 {
            let n = FlipPlanner.baseHalfTurns(force: Double(i) / 100)
            XCTAssertGreaterThanOrEqual(n, last, "force=\(i)% 时圈数反而变少了")
            last = n
        }
        XCTAssertGreaterThan(FlipPlanner.maxHalfTurns, FlipPlanner.normalMaxHalfTurns)
    }
}
