// 每一抛的分数（2026-10）。
//
// ★ 分数就是这一划的速度（点/秒）★——作者看了开发版底部挂的那个速度值，说它比
//   "高度 × 圈数"更有刺激：轻轻一划几百，用力一甩三四千，没有上限，越狠越大。
//   （历次：圈数 1~6 太小太固定 → 高度×半圈 + 连击 → 去掉连击 → 现在用速度。）
//
// 抛的时候数字跟着硬币翻转往上滚：翻过几成半圈，就滚到速度的几成；
// 落地那一刻才到最后的数（和之前一样，不会比硬币先露出结果）。
//
// 这里只做数学，界面在 CoinFlipApp / TurnCounter。

import Foundation

enum FlipScore {

    /// 这一抛的最终分数
    static func final(speed: Double) -> Int {
        max(Int(speed.rounded()), 0)
    }

    /// 已经翻了 halfTurns 个半圈（一共 total 个）时，屏幕上滚到多少
    static func points(speed: Double, halfTurns n: Int, of total: Int) -> Int {
        guard total > 0 else { return final(speed: speed) }
        let share = Double(min(max(n, 0), total)) / Double(total)
        return Int((Double(final(speed: speed)) * share).rounded())
    }
}
