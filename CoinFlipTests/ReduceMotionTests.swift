// 减少动态效果模式的自动测试。
//
// 那个模式下硬币不飞不转，画面 0.75 秒就结束，所以声音也要用精简版——
// 否则结果早就摆在眼前，耳朵里还在落地。
//
// ★ 精简的是演出，不是结果。★ 下面第一组守的就是这条：
//   把时间表精简掉之后，这一次抛出的是哪一面，必须一个字都没变。

import XCTest
@testable import CoinFlip

final class ReduceMotionTests: XCTestCase {

    private func plan(_ speed: Double = 1500) -> FlipPlan {
        FlipPlanner.makePlan(speed: speed, distance: 150, startFace: .sun, result: .moon)
    }

    // MARK: - ★ 结果不能变 ★

    /// 精简之后，决定结果的那几项必须原封不动。
    ///
    /// result 自不必说；startFace 和 halfTurns 也不能动——
    /// 一致性测试是靠这两项反推最终朝向的，动了就对不上了。
    func testSimplifyKeepsEverythingThatDecidesTheResult() {
        for speed in [300.0, 1500.0, 4000.0] {
            let full = plan(speed)
            let short = full.simplified(landAt: 0.3, endAt: 0.75)

            XCTAssertEqual(short.result, full.result, "结果被改了")
            XCTAssertEqual(short.startFace, full.startFace, "起始面被改了")
            XCTAssertEqual(short.halfTurns, full.halfTurns, "半圈数被改了")
        }
    }

    /// 反向验证：精简之后，照半圈数推出来的朝向仍然等于当初决定的结果
    func testSimplifiedPlanStillLandsOnTheDecidedFace() {
        for start in [CoinFace.sun, .moon] {
            for result in [CoinFace.sun, .moon] {
                let full = FlipPlanner.makePlan(speed: 1500, distance: 150,
                                                startFace: start, result: result)
                let short = full.simplified(landAt: 0.3, endAt: 0.75)
                XCTAssertEqual(FlipPlanner.finalFace(of: short), result,
                               "\(start) → \(result) 精简之后朝向对不上了")
            }
        }
    }

    // MARK: - 演出确实被精简了

    /// 只剩落地那一下，中间那串磕碰全去掉
    func testOnlyOneContactRemains() {
        let short = plan().simplified(landAt: 0.3, endAt: 0.75)
        XCTAssertEqual(short.contacts.count, 1, "磕碰没精简干净")
        XCTAssertEqual(short.contacts.first?.time ?? -1, 0.3, accuracy: 1e-9)
        XCTAssertEqual(short.contacts.first?.strength ?? -1, 1, accuracy: 1e-9)
        XCTAssertTrue(short.bounces.isEmpty, "还留着弹跳")
    }

    /// 整段明显比正常模式短
    func testItIsMuchShorter() {
        let full = plan()
        let short = full.simplified(landAt: CoinScene.reduceMotionSwap,
                                    endAt: CoinScene.reduceMotionSeconds)
        XCTAssertLessThan(short.endTime, full.endTime * 0.5,
                          "精简之后还是这么长，等于没精简")
    }

    /// 换面必须发生在画面全黑的时候，否则会看到硬币突然跳一下
    func testFaceSwapHappensWhileTheScreenIsDark() {
        XCTAssertGreaterThan(CoinScene.reduceMotionSwap, 0.15,
                             "黑幕还没盖上就换面了，会看到跳变")
        XCTAssertLessThan(CoinScene.reduceMotionSwap, CoinScene.reduceMotionSeconds,
                          "换面比整段还晚")
    }
}
