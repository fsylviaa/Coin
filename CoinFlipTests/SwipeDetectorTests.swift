// 上划识别的自动测试（任务 T15）。
//
// 屏幕坐标里"往上"是负数，所以测试里的 height 多半带负号，别看岔了。
// 这些测试能在电脑上自动跑，但手感门槛松紧合不合适，最后还得真机上手试。

import XCTest
@testable import CoinFlip

final class SwipeDetectorTests: XCTestCase {

    /// 取出判定结果里的速度；不是有效上划就返回 nil
    private func speed(_ result: SwipeDetector.Result) -> Double? {
        if case .swipeUp(let s) = result { return s }
        return nil
    }

    // MARK: - 应该算上划

    /// 又快又长的一划：算
    func testFastLongSwipeUpIsAccepted() {
        let r = SwipeDetector.evaluate(translation: .init(width: 0, height: -200),
                                       velocity: .init(width: 0, height: -1800))
        XCTAssertEqual(speed(r), 1800)
    }

    /// 刚好够到门槛：算
    func testExactlyAtThresholdIsAccepted() {
        let r = SwipeDetector.evaluate(
            translation: .init(width: 0, height: -SwipeDetector.minDistance),
            velocity: .init(width: 0, height: -SwipeDetector.minSpeed))
        XCTAssertNotNil(speed(r))
    }

    /// 斜着往上划（45 度以内）：算
    func testSlightlyDiagonalSwipeIsAccepted() {
        let r = SwipeDetector.evaluate(translation: .init(width: 60, height: -120),
                                       velocity: .init(width: 300, height: -1000))
        XCTAssertEqual(speed(r), 1000)
    }

    /// 划得越快，报上去的速度越大
    func testFasterSwipeReportsHigherSpeed() {
        let slow = speed(SwipeDetector.evaluate(translation: .init(width: 0, height: -120),
                                                velocity: .init(width: 0, height: -400)))!
        let fast = speed(SwipeDetector.evaluate(translation: .init(width: 0, height: -120),
                                                velocity: .init(width: 0, height: -2600)))!
        XCTAssertGreaterThan(fast, slow)
    }

    // MARK: - 不该算上划

    /// 往下划：不算
    func testSwipeDownIsIgnored() {
        let r = SwipeDetector.evaluate(translation: .init(width: 0, height: 200),
                                       velocity: .init(width: 0, height: 1800))
        XCTAssertEqual(r, .ignored)
    }

    /// 往左、往右划：不算
    func testHorizontalSwipesAreIgnored() {
        for dx in [-250.0, 250.0] {
            let r = SwipeDetector.evaluate(translation: .init(width: dx, height: 0),
                                           velocity: .init(width: dx * 8, height: 0))
            XCTAssertEqual(r, .ignored, "横向划 \(dx) 不该触发抛掷")
        }
    }

    /// 轻点屏幕（几乎没动）：不算
    func testTapIsIgnored() {
        let r = SwipeDetector.evaluate(translation: .init(width: 0, height: -2),
                                       velocity: .init(width: 0, height: -10))
        XCTAssertEqual(r, .ignored)
    }

    /// 手指轻微抖动后松开：不算
    func testTinyJitterIsIgnored() {
        let r = SwipeDetector.evaluate(translation: .init(width: 3, height: -6),
                                       velocity: .init(width: 20, height: -60))
        XCTAssertEqual(r, .ignored)
    }

    /// 划得够长但很慢（比如慢慢往上拖）：不算
    func testSlowDragIsIgnored() {
        let r = SwipeDetector.evaluate(translation: .init(width: 0, height: -300),
                                       velocity: .init(width: 0, height: -50))
        XCTAssertEqual(r, .ignored)
    }

    /// 够快但距离太短：不算
    func testShortFlickIsIgnored() {
        let r = SwipeDetector.evaluate(translation: .init(width: 0, height: -10),
                                       velocity: .init(width: 0, height: -2000))
        XCTAssertEqual(r, .ignored)
    }

    /// 太斜（横向比纵向还多）：不算
    func testTooDiagonalIsIgnored() {
        let r = SwipeDetector.evaluate(translation: .init(width: 300, height: -100),
                                       velocity: .init(width: 2000, height: -800))
        XCTAssertEqual(r, .ignored)
    }

    // MARK: - 门槛本身要讲得通

    /// 门槛必须是正数，否则等于没设
    func testThresholdsArePositive() {
        XCTAssertGreaterThan(SwipeDetector.minDistance, 0)
        XCTAssertGreaterThan(SwipeDetector.minSpeed, 0)
        XCTAssertGreaterThan(SwipeDetector.maxHorizontalRatio, 0)
    }
}
