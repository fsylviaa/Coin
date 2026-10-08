// 随机器的自动测试（任务 T07）。
//
// 随机的东西没法"算出"正确答案，只能用大量样本看分布是否合理：
// 抛一万次，日面应该在 5000 次上下。

import XCTest
@testable import CoinFlip

final class FlipPlannerRandomTests: XCTestCase {

    /// 抛 10000 次，日面次数应落在 4800–5200 之间。
    ///
    /// 这个范围是算过的：真正的五五开，10000 次里日面的标准差是 50 次，
    /// 4800–5200 相当于允许偏离 4 个标准差，纯属偶然超出的概率约十万分之六。
    /// 也就是说，这个测试几乎不会"冤枉"正确的代码，
    /// 但如果有人偷偷把概率改成 55:45，它一定会报警。
    func testResultIsFair() {
        var sunCount = 0
        for _ in 0..<10_000 where FlipPlanner.decideResult() == .sun {
            sunCount += 1
        }
        XCTAssertGreaterThanOrEqual(sunCount, 4800, "日面次数偏少：\(sunCount)")
        XCTAssertLessThanOrEqual(sunCount, 5200, "日面次数偏多：\(sunCount)")
    }

    /// 抛 100 次，日面和月面都必须至少出现一次。
    /// 防止代码写死成永远返回同一面。
    func testBothFacesAppear() {
        var seen = Set<CoinFace>()
        for _ in 0..<100 {
            seen.insert(FlipPlanner.decideResult())
        }
        XCTAssertTrue(seen.contains(.sun), "100 次里一次日面都没出现")
        XCTAssertTrue(seen.contains(.moon), "100 次里一次月面都没出现")
    }
}
