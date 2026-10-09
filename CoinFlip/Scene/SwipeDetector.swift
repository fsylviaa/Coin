// 上划识别：判断一次手势算不算有效上划，并量出它有多快。对应任务 T15。
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

    /// 一次手势的判定结果
    enum Result: Equatable {
        /// 有效上划，附带峰值速度（点/秒）和往上划的距离（点），都是正数
        case swipeUp(speed: Double, distance: Double)
        /// 不算上划
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
}
