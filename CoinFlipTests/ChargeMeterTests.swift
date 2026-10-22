// 蓄力刻度尺的自动测试（2026-10）。

import XCTest
@testable import CoinFlip

final class ChargeMeterTests: XCTestCase {

    /// 没往上拖就是第 0 格；拖满（或拖过头）就停在最后一格，不会越界
    func testStepRange() {
        XCTAssertEqual(ChargeMeter.step(dragUp: 0), 0)
        XCTAssertEqual(ChargeMeter.step(dragUp: -50), 0, "往下拖不算")
        XCTAssertEqual(ChargeMeter.step(dragUp: FlipPlanner.maxDistance), ChargeMeter.steps)
        XCTAssertEqual(ChargeMeter.step(dragUp: FlipPlanner.maxDistance * 3), ChargeMeter.steps)
    }

    /// 一路往上拖，格子只增不减，而且每一格都会经过（不会跳格漏震）
    func testStepsIncreaseOneByOne() {
        var seen = Set<Int>()
        var last = 0
        for d in stride(from: 0.0, through: FlipPlanner.maxDistance, by: 1.0) {
            let s = ChargeMeter.step(dragUp: d)
            XCTAssertGreaterThanOrEqual(s, last)
            last = s
            seen.insert(s)
        }
        XCTAssertEqual(seen, Set(0...ChargeMeter.steps))
    }

    /// 越往上越重、越脆；拖满那一下比任何一格都重
    func testIntensityRises() {
        var last: Float = -1
        for s in 1..<ChargeMeter.steps {
            let v = HapticTuning.chargeIntensity(ChargeMeter.level(step: s))
            XCTAssertGreaterThan(v, last, "第 \(s) 格没有比上一格重")
            last = v
        }
        XCTAssertGreaterThan(HapticTuning.chargeFullIntensity, last)
        XCTAssertLessThanOrEqual(HapticTuning.chargeSharpness(0), HapticTuning.chargeSharpness(1))
    }

    /// 松手那一记：抛得越狠越重，而且不超出 0~1
    func testReleaseGetsHeavier() {
        XCTAssertLessThan(HapticTuning.releaseIntensity(0), HapticTuning.releaseIntensity(1))
        XCTAssertLessThanOrEqual(HapticTuning.releaseIntensity(5), 1)
        XCTAssertGreaterThanOrEqual(HapticTuning.releaseIntensity(-1), 0)
    }
}
