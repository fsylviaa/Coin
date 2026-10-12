// 每一次抛掷的"性格"（P11）。
//
// 每次抛出去，落地后的表现都在一个小范围里随机变一点：
// 打转往哪边、落地斜几度、磕碰几下、小跳高低、空中进动多少。
// 单看一次看不出来，连抛十次就觉得每次都是活的。
//
// ★ 它只管"怎么演"，绝不碰"翻几个半圈"。★
//   结果的正确性只取决于半圈数的奇偶，这里没有任何一项会改它。
//   PersonalityTests 用大量随机性格反复核对：结果永远对、停稳永远严丝合缝、时长不变长。
//
// ★ 抛出那一刻就定下来，写进时间表（FlipPlan），飞行中途不会再变。★
//   画面、声音、震动照的是同一张表，所以磕碰几下这类变化三者天然同步。

import Foundation

struct FlipPersonality: Equatable {

    /// 落地时比标准的 42° 多歪或少歪几度
    let landingTiltOffset: Double
    /// 落地小跳的高度倍数
    let hopScale: Double
    /// 躺平前边缘磕碰几下
    let rattleTaps: Int
    /// 空中进动的幅度倍数
    let precessionScale: Double
    /// 正上方抛时，打转、进动、自转往哪边：+1 或 −1。
    /// 斜着抛时不用它——那时方向跟着手指镜像（见 FlipAnimator.turnSide）
    let side: Double

    // MARK: - 范围

    static let landingTiltRange: ClosedRange<Double> = -6...6
    /// ★ 上限不超过 1.05 ★：小跳越高、时长越长，"丰富"不能做成"更长"
    static let hopScaleRange: ClosedRange<Double> = 0.8...1.05
    static let rattleTapsRange: ClosedRange<Int> = 8...10
    static let precessionScaleRange: ClosedRange<Double> = 0.7...1.3

    /// 没有性格：和加性格之前一模一样。测试和精简动画用它
    static let neutral = FlipPersonality(landingTiltOffset: 0, hopScale: 1,
                                         rattleTaps: FlipPlanner.rattleTaps,
                                         precessionScale: 1, side: 1)

    /// 随机抽一个性格
    static func random() -> FlipPersonality {
        var rng = SystemRandomNumberGenerator()
        return random(using: &rng)
    }

    static func random<G: RandomNumberGenerator>(using rng: inout G) -> FlipPersonality {
        FlipPersonality(landingTiltOffset: Double.random(in: landingTiltRange, using: &rng),
                        hopScale: Double.random(in: hopScaleRange, using: &rng),
                        rattleTaps: Int.random(in: rattleTapsRange, using: &rng),
                        precessionScale: Double.random(in: precessionScaleRange, using: &rng),
                        side: Bool.random(using: &rng) ? 1 : -1)
    }
}
