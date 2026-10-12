// 手势识别：判断一次手势是上划（抛出）、横拨（原地自旋），还是什么都不算。
// 对应任务 T15，横拨是后来新增的把玩动作。
//
// 这里只做判断和计算，不碰画面也不碰硬币，所以可以单独用自动测试验收。
//
// 为什么要设门槛（技术文档第 7 号坑）：
// 手指按住屏幕时难免有几毫米的抖动，松开时也可能带一点点位移。
// 如果不设门槛，轻轻碰一下屏幕硬币就飞出去了。
// 以后加长按切换风格（V1 功能）时，这个门槛还能防止长按被误判成上划。

import Foundation
import CoreGraphics

enum SwipeDetector {

    /// 至少要往上划这么多点，才算数
    static let minDistance: Double = 26

    /// 至少要有这么快（点/秒），才算数
    static let minSpeed: Double = 150

    /// 允许的倾斜程度：横向移动不能超过纵向移动的这个倍数。
    /// 1.0 表示方向要偏向上，斜着划 45 度以内都算上划，再歪就不算了。
    static let maxHorizontalRatio: Double = 1.3

    // ── 横拨自旋的门槛 ──
    //
    // ★ 横拨永远不改变朝上的是哪一面。★ 它只绕竖直轴转，所以结果不受影响。
    //   这不是"我觉得安全"：FlipAnimatorTests 里有一个测试专门守着这条性质。

    /// 至少要横着划这么多点，才算一次横拨
    static let minSideDistance: Double = 22

    /// 至少要有这么快（点/秒），才算横拨。
    /// 比上划的门槛低一些——横拨是"轻轻一拨"，本来就不该使劲。
    static let minSideSpeed: Double = 110

    /// 横拨允许的倾斜：竖直移动不能超过横向移动的这个倍数。
    /// 比上划那边严（上划是 1.3），因为斜着划更可能是想抛，不是想拨。
    static let maxVerticalRatio: Double = 0.8

    // ── 翻转方向（P09）──

    /// 上划偏离竖直方向最多算多少度。再歪的上划照样抛，只是翻转方向按这个封顶。
    static let maxFlipAngle: Double = 50

    /// 这一划往哪个方向翻（度）：0 是正上方，往右偏为正，往左偏为负。
    ///
    /// 用的是手指从按下到松开的整体方向，不是某一瞬间的速度方向——
    /// 整体方向才是"你想往哪边抛"，瞬间方向会被手抖带偏。
    static func flipDirection(translation: CGSize) -> Double {
        let up = -Double(translation.height)
        let side = Double(translation.width)
        guard up > 0 else { return 0 }
        let degrees = atan2(side, up) * 180 / .pi
        return min(max(degrees, -maxFlipAngle), maxFlipAngle)
    }

    /// 一次手势的判定结果
    enum Result: Equatable {
        /// 有效上划，附带峰值速度（点/秒）和往上划的距离（点），都是正数
        case swipeUp(speed: Double, distance: Double)
        /// 有效横拨，附带峰值速度（点/秒）。**往右为正，往左为负。**
        case spin(speed: Double)
        /// 什么都不算
        case ignored
    }

    /// 判断一次手势。
    ///
    /// - Parameters:
    ///   - translation: 手指从按下到松开，一共移动了多少（屏幕坐标：往上是负数）
    ///   - velocity: 松开瞬间的速度（屏幕坐标：往上是负数）
    static func evaluate(translation: CGSize, velocity: CGSize) -> Result {
        // 屏幕坐标里往上是负的，先翻成正的，后面好读
        let up = -Double(translation.height)
        let upSpeed = -Double(velocity.height)
        let sideways = abs(Double(translation.width))

        guard up >= minDistance else { return .ignored }             // 划得太短
        guard upSpeed >= minSpeed else { return .ignored }           // 划得太慢
        guard sideways <= up * maxHorizontalRatio else { return .ignored }  // 太歪，不算上划

        return .swipeUp(speed: upSpeed, distance: up)
    }

    /// 判断一次手势算不算横拨。
    ///
    /// ⚠️ 调用方必须**先问 evaluate、再问这个**。两者的允许范围有一小段重叠，
    ///    重叠时按上划算——想抛却被判成拨，比想拨却被判成抛更让人恼火。
    ///
    /// - Parameters:
    ///   - translation: 手指从按下到松开一共移动了多少
    ///   - velocity: 横向峰值速度（往右为正）
    static func evaluateSpin(translation: CGSize, velocity: CGSize) -> Result {
        let sideways = Double(translation.width)
        let distance = abs(sideways)
        let speed = Double(velocity.width)
        // 上下都算"歪"：往右下拨和往右上拨一样是拨
        let vertical = abs(Double(translation.height))

        guard distance >= minSideDistance else { return .ignored }          // 拨得太短
        guard abs(speed) >= minSideSpeed else { return .ignored }           // 拨得太慢
        guard vertical <= distance * maxVerticalRatio else { return .ignored }  // 太歪，更像在抛

        return .spin(speed: speed)
    }
}
