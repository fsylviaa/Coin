// 分数 = 这一划的速度（2026-10）。

import XCTest
@testable import CoinFlip

final class FlipScoreTests: XCTestCase {

    /// 最后的分数就是速度（取整）
    func testFinalIsSpeed() {
        XCTAssertEqual(FlipScore.final(speed: 2380.4), 2380)
        XCTAssertEqual(FlipScore.final(speed: 4999.6), 5000)
        XCTAssertEqual(FlipScore.final(speed: -3), 0)
    }

    /// 跟着翻转一路往上滚：出手是 0，只涨不跌，最后一个半圈正好到速度
    func testRollsUpWithTurns() {
        let total = 9
        XCTAssertEqual(FlipScore.points(speed: 3200, halfTurns: 0, of: total), 0)
        var last = -1
        for n in 0...total {
            let p = FlipScore.points(speed: 3200, halfTurns: n, of: total)
            XCTAssertGreaterThan(p, last)
            last = p
        }
        XCTAssertEqual(last, 3200)
        XCTAssertLessThan(FlipScore.points(speed: 3200, halfTurns: total - 1, of: total), 3200,
                          "落地之前就到了最后的数")
    }

    /// 老存档没有新加的项也能读，读出来是 0
    func testOldSaveStillLoads() throws {
        let old = #"{"total":3,"sun":2,"moon":1}"#.data(using: .utf8)!
        let s = try JSONDecoder().decode(FlipStats.self, from: old)
        XCTAssertEqual(s.total, 3)
        XCTAssertEqual(s.maxSpeed, 0)
        XCTAssertEqual(s.maxChaosHits, 0)
    }

    /// 乱撞计数的纪录只留最多的那次
    func testChaosHitsKeepsBest() {
        var s = FlipStats()
        s.recordChaosHits(12)
        s.recordChaosHits(5)
        XCTAssertEqual(s.maxChaosHits, 12)
        s.recordChaosHits(30)
        XCTAssertEqual(s.maxChaosHits, 30)
    }
}
