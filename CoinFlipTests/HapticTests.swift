// 震感的强度映射。对应任务 T20。
//
// 这组测试守的是一件事：**整串磕碰都要摸得到**。
// 原始强度从 1.0 一路衰到 0.002，照搬的话后面七下在手上完全是空的——
// 这就是改之前"只感觉到落地一下"的原因。映射函数负责把弱的一端抬起来，
// 同时还要保留轻重的层次。以后谁调了那几个旋钮，这里会立刻告诉他过头了没有。

import XCTest
@testable import CoinFlip

final class HapticTests: XCTestCase {

    /// 一次典型抛掷的全部磕碰强度，从重到轻
    private var strengths: [Double] {
        FlipPlanner.makePlan(speed: 1500, distance: 150,
                             startFace: .sun, result: .moon)
            .contacts.map(\.strength)
    }

    /// 人手能摸出来的大致下限。低于这个数，震了等于没震。
    private let perceptible: Float = 0.35

    /// 够得上门槛的磕碰，震感都必须摸得到
    func testEveryAudibleContactIsFeelable() {
        for s in strengths where s >= HapticTuning.minStrength {
            let i = HapticTuning.intensity(for: s)
            XCTAssertGreaterThanOrEqual(
                i, perceptible,
                "强度 \(String(format: "%.3f", s)) 的磕碰只震到 \(String(format: "%.2f", i))，摸不出来")
        }
    }

    /// 落地必须是最重的一下，而且要震满
    func testLandingIsTheStrongest() {
        XCTAssertEqual(HapticTuning.intensity(for: 1.0), 1.0, accuracy: 0.01,
                       "落地没有震满")
        for s in strengths.dropFirst() {
            XCTAssertLessThan(HapticTuning.intensity(for: s),
                              HapticTuning.intensity(for: 1.0),
                              "有磕碰震得比落地还重")
        }
    }

    /// 越往后越轻，层次不能被抬平
    func testIntensityKeepsDecaying() {
        let felt = strengths.filter { $0 >= HapticTuning.minStrength }
        for (a, b) in zip(felt, felt.dropFirst()) {
            XCTAssertGreaterThan(HapticTuning.intensity(for: a),
                                 HapticTuning.intensity(for: b),
                                 "这两下震感一样重，整串会糊成一片")
        }
    }

    /// 重的一下偏软（沉），轻的一下偏硬（脆）。这是两种手感能分辨开的关键。
    func testHeavyFeelsSoftAndLightFeelsSharp() {
        XCTAssertLessThan(HapticTuning.sharpness(for: 1.0),
                          HapticTuning.sharpness(for: 0.05),
                          "落地没有比磕碰更沉")
    }

    /// 任何输入都不能超出 0~1，否则系统会直接拒掉整串震动
    func testValuesStayInRange() {
        for s in [-1.0, 0, 0.5, 1.0, 99.0] {
            XCTAssertTrue((0...1).contains(HapticTuning.intensity(for: s)))
            XCTAssertTrue((0...1).contains(HapticTuning.sharpness(for: s)))
        }
    }
}
