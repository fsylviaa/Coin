// 双指缩放的换算（P07）。

import XCTest
@testable import CoinFlip

final class PinchZoomTests: XCTestCase {

    /// 不动手指，镜头不动
    func testNoChangeWithoutMovement() {
        XCTAssertEqual(CoinScene.pinchZoom(from: 0.3, scale: 1), 0.3, accuracy: 1e-9)
    }

    /// 从远景张开到两倍，正好到特写；从特写捏到一半，正好回远景
    func testFullRange() {
        XCTAssertEqual(CoinScene.pinchZoom(from: 0, scale: CoinScene.pinchFullRange), 1, accuracy: 1e-9)
        XCTAssertEqual(CoinScene.pinchZoom(from: 1, scale: 1 / CoinScene.pinchFullRange), 0, accuracy: 1e-9)
    }

    /// 张开推近、捏合拉远
    func testDirection() {
        XCTAssertGreaterThan(CoinScene.pinchZoom(from: 0.5, scale: 1.2), 0.5)
        XCTAssertLessThan(CoinScene.pinchZoom(from: 0.5, scale: 0.8), 0.5)
    }

    /// 捏到头之后是"橡皮筋"：还能再过去一点，但越往外越拉不动，永远不超过余量。
    /// 第一版在两头硬停，作者看着"停得太突然"
    func testRubberBandAtBothEnds() {
        let m = CoinScene.pinchOvershoot
        // 正常幅度地多张开一点：过了头，但没碰到余量的上限
        let far = CoinScene.pinchZoom(from: 0.9, scale: 1.5)
        XCTAssertGreaterThan(far, 1, "到头就硬停了，没有橡皮筋")
        XCTAssertLessThan(far, 1 + m)
        let near = CoinScene.pinchZoom(from: 0.1, scale: 0.6)
        XCTAssertLessThan(near, 0, "到头就硬停了，没有橡皮筋")
        XCTAssertGreaterThan(near, -m)
        // 极端幅度（手指张到十倍）：无限贴近上限，但绝不越过。
        // ★ 这里只能用"不超过"，不能用"小于"——贴得太近时电脑的小数精度
        //   会把它算成正好等于上限（第一版就栽在这里，测试误报失败）。
        XCTAssertLessThanOrEqual(CoinScene.pinchZoom(from: 0.9, scale: 10), 1 + m)
        XCTAssertGreaterThanOrEqual(CoinScene.pinchZoom(from: 0.1, scale: 0.01), -m)
        // 越往外越拉不动：多张开同样一截，过界越多走得越少
        let a = CoinScene.pinchZoom(from: 1, scale: 1.1) - 1
        let b = CoinScene.pinchZoom(from: 1, scale: 1.21) - CoinScene.pinchZoom(from: 1, scale: 1.1)
        XCTAssertLessThan(b, a)
    }

    /// 在范围里面时没有橡皮筋，一对一跟手
    func testNoRubberBandInside() {
        XCTAssertEqual(CoinScene.pinchZoom(from: 0.5, scale: 1.2),
                       0.5 + log(1.2) / log(CoinScene.pinchFullRange), accuracy: 1e-9)
    }
}
