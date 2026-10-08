// 半圈数修正的自动测试（任务 T08）。
//
// 这是全项目最重要的一组测试。它保证了"抛出来是日面，屏幕上显示的就一定是日面"。
// 以后每次改动画，都要重新跑一遍。

import XCTest
@testable import CoinFlip

final class FlipPlannerHalfTurnsTests: XCTestCase {

    /// 任务清单里那张 8 行表格，逐行检查。
    ///
    /// 读法举例（第二行）：本来打算翻 6 个半圈，抛之前是日面朝上，
    /// 这次结果要出月面。6 是偶数，翻完还是日面，不对，
    /// 所以要补成 7（奇数），翻完才是月面。
    func testMakeHalfTurns() {
        let cases: [(base: Int, start: CoinFace, result: CoinFace, expected: Int)] = [
            (6, .sun,  .sun,  6),
            (6, .sun,  .moon, 7),
            (7, .sun,  .sun,  8),
            (7, .sun,  .moon, 7),
            (6, .moon, .moon, 6),
            (6, .moon, .sun,  7),
            (7, .moon, .moon, 8),
            (7, .moon, .sun,  7),
        ]

        for c in cases {
            let actual = FlipPlanner.makeHalfTurns(baseHalfTurns: c.base,
                                                   startFace: c.start,
                                                   result: c.result)
            XCTAssertEqual(
                actual, c.expected,
                "打算翻 \(c.base) 个半圈，\(c.start) 面起、要出 \(c.result) 面：应修正为 \(c.expected)，实际 \(actual)"
            )
        }
    }

    /// 不只验证那 8 行，而是把 0–40 个半圈、四种起止面组合全部试一遍，
    /// 每种都检查"翻完之后朝上的面"是否等于想要的结果。
    func testHalfTurnsAlwaysLandOnResult() {
        for base in 0...40 {
            for start in [CoinFace.sun, .moon] {
                for result in [CoinFace.sun, .moon] {
                    let turns = FlipPlanner.makeHalfTurns(baseHalfTurns: base,
                                                          startFace: start,
                                                          result: result)
                    // 翻偶数个半圈还是原来那面，翻奇数个半圈就换到另一面
                    let landedFace = (turns % 2 == 0) ? start : start.opposite
                    XCTAssertEqual(landedFace, result,
                                   "base=\(base) start=\(start) result=\(result) 时翻了 \(turns) 个半圈，落在 \(landedFace)")
                }
            }
        }
    }

    /// 修正只允许"不变"或"加 1"，不能乱改圈数。
    /// 否则会出现"轻轻一划反而翻了十圈"这种怪事。
    func testHalfTurnsChangeByAtMostOne() {
        for base in 0...40 {
            for start in [CoinFace.sun, .moon] {
                for result in [CoinFace.sun, .moon] {
                    let turns = FlipPlanner.makeHalfTurns(baseHalfTurns: base,
                                                          startFace: start,
                                                          result: result)
                    XCTAssertTrue(turns == base || turns == base + 1,
                                  "base=\(base) 被改成了 \(turns)，超出允许范围")
                }
            }
        }
    }
}
