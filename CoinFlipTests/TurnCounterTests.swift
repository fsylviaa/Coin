// 抛的时候跳动的计数（2026-10）。
//
// 守的是一条死规矩：数字不能比硬币先把结果露出来。

import XCTest
@testable import CoinFlip

final class TurnCounterTests: XCTestCase {

    private let scale = Double(CoinScene.heightScale)

    /// 落地之前，计数永远到不了总数；落地那一刻正好是总数；一路只涨不跌
    func testCounterNeverRevealsBeforeLanding() {
        for speed in stride(from: 300.0, through: 6000.0, by: 300.0) {
            for start in [CoinFace.sun, .moon] {
                for result in [CoinFace.sun, .moon] {
                    let plan = FlipPlanner.makePlan(speed: speed, distance: speed / 8,
                                                    startFace: start, result: result)
                    var last = 0
                    var t = 0.0
                    while t <= plan.endTime {
                        let pose = FlipAnimator.pose(at: t, plan: plan, heightScale: scale)
                        let n = FlipAnimator.shownHalfTurns(at: t, plan: plan, degrees: pose.degrees)
                        if t < plan.landTime {
                            XCTAssertLessThan(n, plan.halfTurns,
                                              "速度 \(Int(speed))：还没落地（\(t) 秒）计数就到了总数")
                        } else {
                            XCTAssertEqual(n, plan.halfTurns)
                        }
                        XCTAssertGreaterThanOrEqual(n, last, "速度 \(Int(speed))：计数往回跳了")
                        last = n
                        t += 1.0 / 120
                    }
                    XCTAssertEqual(last, plan.halfTurns)
                }
            }
        }
    }

    /// 刚出手是 0
    func testStartsAtZero() {
        let plan = FlipPlanner.makePlan(speed: 2000, distance: 200, startFace: .sun, result: .moon)
        let pose = FlipAnimator.pose(at: 0, plan: plan, heightScale: scale)
        XCTAssertEqual(FlipAnimator.shownHalfTurns(at: 0, plan: plan, degrees: pose.degrees), 0)
    }
}
