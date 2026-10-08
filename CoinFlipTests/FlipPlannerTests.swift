// 自动测试文件。在 Xcode 里按 ⌘U，或在终端运行 ./scripts/test.sh 执行。
// 目前只有一个占位测试，用来确认测试环境能正常工作。
// 之后的任务（T04–T12）会在这里加入真正的测试。

import XCTest
@testable import CoinFlip

final class FlipPlannerTests: XCTestCase {

    func testSetupWorks() {
        XCTAssertTrue(true, "测试环境运行正常")
    }

    func testOppositeOfSunIsMoon() {
        XCTAssertEqual(CoinFace.sun.opposite, .moon)
    }

    func testOppositeOfMoonIsSun() {
        XCTAssertEqual(CoinFace.moon.opposite, .sun)
    }

    func testRawValues() {
        XCTAssertEqual(CoinFace.sun.rawValue, "sun")
        XCTAssertEqual(CoinFace.moon.rawValue, "moon")
    }
}
