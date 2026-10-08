// 结果一致性总测试（任务 T10）。
//
// ★ 这是整个项目最重要的一组测试。★
//
// 它守护的是这条底线：
//     "随机器抛出来是日面，屏幕上最后显示的就一定是日面。"
//
// 这条底线一旦破了，整个 App 就失去意义——用户看到的结果是假的。
// 而且这种错误很隐蔽：动画照样流畅，只是结果反了，肉眼很难发现。
//
// 以后每次改动画、换贴图、加风格之后，都要重新跑这组测试。

import XCTest
@testable import CoinFlip

final class ResultConsistencyTests: XCTestCase {

    /// 模拟抛 1000 次：随机速度、随机起始面、随机结果。
    /// 每一次都检查"演完之后朝上的面"是否等于"预先决定的结果"。
    func testFinalFaceAlwaysMatchesResult() {
        for i in 0..<1000 {
            let speed = Double.random(in: 0...4000)
            let startFace = FlipPlanner.decideResult()
            let result = FlipPlanner.decideResult()

            let plan = FlipPlanner.makePlan(speed: speed, startFace: startFace, result: result)
            let landed = FlipPlanner.finalFace(of: plan)

            XCTAssertEqual(
                landed, plan.result,
                "第 \(i + 1) 次不一致：决定的是 \(plan.result)，演完却是 \(landed)。"
                + "（起始面 \(startFace)，速度 \(Int(speed))，翻了 \(plan.halfTurns) 个半圈）"
            )
        }
    }

    /// 上一个测试用的是随机值，可能漏掉边界情况。
    /// 这里把四种起止面组合 × 大量速度全部走一遍，不留死角。
    func testFinalFaceMatchesAcrossAllCombinations() {
        for startFace in [CoinFace.sun, .moon] {
            for result in [CoinFace.sun, .moon] {
                for speed in stride(from: 0.0, through: 5000.0, by: 10.0) {
                    let plan = FlipPlanner.makePlan(speed: speed, startFace: startFace, result: result)
                    XCTAssertEqual(
                        FlipPlanner.finalFace(of: plan), result,
                        "起始面 \(startFace) → 结果 \(result)，速度 \(Int(speed)) 时不一致"
                    )
                }
            }
        }
    }

    /// 顺带确认：力度不影响概率。
    /// 不管每次用多大力气，日月仍然各占一半。
    /// 防止有人把"用力程度"接进随机逻辑，造成"使劲划更容易出日面"。
    func testForceDoesNotAffectProbability() {
        var sunCount = 0
        for i in 0..<10_000 {
            // 速度在最轻和最重之间来回变化
            let speed = (i % 2 == 0) ? 0.0 : 5000.0
            let result = FlipPlanner.decideResult()
            let plan = FlipPlanner.makePlan(speed: speed, startFace: .sun, result: result)
            if plan.result == .sun { sunCount += 1 }
        }
        XCTAssertGreaterThanOrEqual(sunCount, 4800, "日面次数偏少：\(sunCount)")
        XCTAssertLessThanOrEqual(sunCount, 5200, "日面次数偏多：\(sunCount)")
    }
}
