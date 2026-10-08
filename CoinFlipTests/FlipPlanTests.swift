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
        let plan = FlipPlanner.makePlan(speed: 0, startFace: .sun, result: .sun, style: style)
        XCTAssertEqual(plan.height, style.minHeight)
    }

    /// 速度大到离谱时，高度被压在上限，不会飞出屏幕
    func testHugeSpeedUsesMaxHeight() {
        let plan = FlipPlanner.makePlan(speed: 100_000, startFace: .sun, result: .sun, style: style)
        XCTAssertEqual(plan.height, style.maxHeight)
    }

    /// 划得越快，抛得越高
    func testFasterIsHigher() {
        let slow = FlipPlanner.makePlan(speed: 200, startFace: .sun, result: .sun, style: style)
        let fast = FlipPlanner.makePlan(speed: 500, startFace: .sun, result: .sun, style: style)
        XCTAssertGreaterThanOrEqual(fast.height, slow.height)
    }

    /// 任意速度下，时间顺序都必须是：开始 → 落地 → 停稳
    func testTimeOrder() {
        for speed in stride(from: 0.0, through: 5000.0, by: 50.0) {
            let plan = FlipPlanner.makePlan(speed: speed, startFace: .sun, result: .moon, style: style)
            XCTAssertGreaterThan(plan.landTime, 0, "speed=\(speed) 落地时刻不是正数")
            XCTAssertGreaterThan(plan.endTime, plan.landTime, "speed=\(speed) 停稳不晚于落地")
        }
    }

    /// 弹起的高度 = 抛起高度 × 风格的弹性
    /// （小数计算有极微小误差，所以允许十亿分之一的偏差）
    func testBounceHeight() {
        let plan = FlipPlanner.makePlan(speed: 1500, startFace: .sun, result: .sun, style: style)
        XCTAssertEqual(plan.bounceHeight, plan.height * style.bounciness, accuracy: 1e-9)
    }

    /// 传进去的结果，原样出现在时间表里，不会被动画逻辑改掉
    func testPlanKeepsResult() {
        for result in [CoinFace.sun, .moon] {
            for start in [CoinFace.sun, .moon] {
                let plan = FlipPlanner.makePlan(speed: 900, startFace: start, result: result, style: style)
                XCTAssertEqual(plan.result, result)
                XCTAssertEqual(plan.startFace, start)
            }
        }
    }

    /// 高度始终落在风格规定的上下限之间
    func testHeightAlwaysWithinRange() {
        for speed in stride(from: -500.0, through: 8000.0, by: 25.0) {
            let plan = FlipPlanner.makePlan(speed: speed, startFace: .moon, result: .sun, style: style)
            XCTAssertGreaterThanOrEqual(plan.height, style.minHeight, "speed=\(speed)")
            XCTAssertLessThanOrEqual(plan.height, style.maxHeight, "speed=\(speed)")
        }
    }

    /// 最慢也要翻够圈数，最快也不会翻得没完没了。
    /// 修正奇偶最多加 1，所以上限是 maxHalfTurns + 1。
    func testHalfTurnsWithinReasonableRange() {
        for speed in stride(from: 0.0, through: 8000.0, by: 25.0) {
            for result in [CoinFace.sun, .moon] {
                let plan = FlipPlanner.makePlan(speed: speed, startFace: .sun, result: result, style: style)
                XCTAssertGreaterThanOrEqual(plan.halfTurns, FlipPlanner.minHalfTurns, "speed=\(speed)")
                XCTAssertLessThanOrEqual(plan.halfTurns, FlipPlanner.maxHalfTurns + 1, "speed=\(speed)")
            }
        }
    }

    /// 整个动画不能太长，否则等得不耐烦。最用力一划也要在 2.5 秒内停稳。
    func testTotalDurationIsAcceptable() {
        let plan = FlipPlanner.makePlan(speed: 100_000, startFace: .sun, result: .moon, style: style)
        XCTAssertLessThan(plan.endTime, 2.5, "最用力一划要 \(plan.endTime) 秒才停稳，太久了")
    }
}
