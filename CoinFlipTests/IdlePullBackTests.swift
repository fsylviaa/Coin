// 揭晓后自动退回远景的曲线（P06）。

import XCTest
@testable import CoinFlip

final class IdlePullBackTests: XCTestCase {

    /// 从特写出发，走完正好到远景
    func testEndsAtFar() {
        XCTAssertEqual(CoinScene.pullBackZoom(from: 1, elapsed: 0), 1, accuracy: 1e-9)
        XCTAssertEqual(CoinScene.pullBackZoom(from: 1, elapsed: CoinScene.idlePullBackSeconds),
                       0, accuracy: 1e-9)
        XCTAssertEqual(CoinScene.pullBackZoom(from: 1, elapsed: 99), 0, accuracy: 1e-9)
    }

    /// 一路只退不进，不会来回晃
    func testMovesOneWay() {
        var last = 1.0
        for i in 1...100 {
            let z = CoinScene.pullBackZoom(from: 1,
                                           elapsed: CoinScene.idlePullBackSeconds * Double(i) / 100)
            XCTAssertLessThanOrEqual(z, last + 1e-12)
            last = z
        }
    }

    /// ★ 起步和收尾都是软的 ★：头尾 5% 的时间里只走了极小一段。
    /// 一开始就全速（"每帧靠近一点"那种）会让镜头突然一动——P02 栽过。
    func testStartsAndEndsGently() {
        let d = CoinScene.idlePullBackSeconds
        let early = 1 - CoinScene.pullBackZoom(from: 1, elapsed: d * 0.05)
        let late = CoinScene.pullBackZoom(from: 1, elapsed: d * 0.95)
        XCTAssertLessThan(early, 0.01, "起步太猛")
        XCTAssertLessThan(late, 0.01, "收尾太猛")
    }

    /// 要等得够久：10 秒是作者定的，不要被顺手改短
    func testWaitsTenSeconds() {
        XCTAssertEqual(CoinScene.idlePullBackAfter, 10)
    }
}
