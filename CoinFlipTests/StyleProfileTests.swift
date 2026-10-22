// 风格档案的自动测试（任务 T05）。
// 这些测试不检查数值好不好看，只检查数值是否"讲得通"——
// 比如弹性不能大于 1，否则硬币会越弹越高，永远停不下来。

import XCTest
@testable import CoinFlip

final class StyleProfileTests: XCTestCase {

    /// 抛起高度的下限要大于 0，并且小于上限
    func testSilverHeightRange() {
        XCTAssertGreaterThan(StyleProfile.silver.minHeight, 0)
        XCTAssertLessThan(StyleProfile.silver.minHeight, StyleProfile.silver.normalMaxHeight)
        XCTAssertLessThanOrEqual(StyleProfile.silver.normalMaxHeight, StyleProfile.silver.maxHeight)
    }

    /// 弹性要在 0 和 1 之间
    func testSilverBounciness() {
        XCTAssertGreaterThan(StyleProfile.silver.bounciness, 0)
        XCTAssertLessThan(StyleProfile.silver.bounciness, 1)
    }

    /// 这条风格档案的名字是 silver
    func testSilverId() {
        XCTAssertEqual(StyleProfile.silver.id, "silver")
    }
}
