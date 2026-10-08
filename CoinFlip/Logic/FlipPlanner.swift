// 演出规划师：负责"这一次抛硬币该怎么演"。
//
// 它只做决定和计算，不碰画面、声音、震动。
// 这样以后换画面、换音效，都不用动这里的代码。
//
// 已完成：T07 随机器、T08 半圈数修正、T09 生成时间表
// 待添加：T10 结果一致性检查

import Foundation

enum FlipPlanner {

    // MARK: - 调校参数（T23 调手感时只改这里的数字）

    /// 场景里的重力加速度（米/秒²）。
    /// 比真实的 9.8 小，硬币飞起来更舒缓，符合"沉静"的定位。数字越小飞得越慢。
    static let gravity: Double = 5.0

    /// 低于这个上划速度（点/秒），一律按最低高度处理，避免手抖也把硬币抛出去。
    static let minSpeed: Double = 300

    /// 达到这个上划速度，就抛到最高。再快也不会更高，免得飞出屏幕。
    static let maxSpeed: Double = 3000

    /// 最轻一划时翻几个半圈
    static let minHalfTurns: Int = 3

    /// 最用力一划时翻几个半圈
    static let maxHalfTurns: Int = 11

    // MARK: - 决定结果（T07）

    /// 决定这一次抛出的是日面还是月面。
    ///
    /// 这里只用系统自带的随机数，日月各 50%。
    /// ⚠️ 绝对不要为了让结果"看起来更均匀"而加任何平衡逻辑
    /// （比如"连续三次日面后强制出月面"）。
    /// 那样做恰恰破坏了五五开——真正的随机本来就会出现连续相同的结果。
    static func decideResult() -> CoinFace {
        Bool.random() ? .sun : .moon
    }

    // MARK: - 保证最终朝向正确（T08）

    /// 修正翻转的半圈数，让硬币停下来时朝上的那一面，正好等于已经决定好的结果。
    ///
    /// 道理很简单：硬币每翻半圈（180°），朝上的面就换一次。所以——
    ///   • 结果和抛之前朝上的面**相同** → 必须翻**偶数**个半圈（翻回来了）
    ///   • 结果和抛之前朝上的面**不同** → 必须翻**奇数**个半圈（翻过去了）
    ///
    /// 传进来的 baseHalfTurns 是按上划速度算出的"大概翻几下"，
    /// 奇偶不一定对得上，这里最多给它加 1，调成正确的奇偶。
    /// 加 1 而不是减 1，是为了避免速度很慢时把圈数减成 0（硬币原地不动）。
    ///
    /// ⚠️ 这是全项目最容易出错的地方。
    /// 以后调动画想让硬币多翻几圈时，只能改 baseHalfTurns，
    /// 绝不能跳过这个函数直接改最终圈数，否则显示的面会和结果相反。
    static func makeHalfTurns(baseHalfTurns: Int,
                              startFace: CoinFace,
                              result: CoinFace) -> Int {
        let needOdd = (startFace != result)       // 要换面，就得翻奇数个半圈
        let isOdd = baseHalfTurns % 2 == 1        // 现在是不是奇数
        return (needOdd == isOdd) ? baseHalfTurns : baseHalfTurns + 1
    }

    // MARK: - 生成时间表（T09）

    /// 根据上划速度和已决定的结果，排出这一次抛掷的完整时间表。
    ///
    /// - Parameters:
    ///   - speed: 手指离开屏幕时的向上速度（点/秒）
    ///   - startFace: 抛之前朝上的那一面
    ///   - result: 已经决定好的结果
    ///   - style: 风格档案，提供高度上下限和弹性
    static func makePlan(speed: Double,
                         startFace: CoinFace,
                         result: CoinFace,
                         style: StyleProfile = .silver) -> FlipPlan {

        // 1. 把上划速度换算成 0~1 的"用力程度"
        let force = forceFactor(speed: speed)

        // 2. 用力程度决定抛多高
        let height = lerp(from: style.minHeight, to: style.maxHeight, factor: force)

        // 3. 用力程度决定翻几个半圈，再修正奇偶，保证最终朝向等于结果
        let baseHalfTurns = minHalfTurns
            + Int((Double(maxHalfTurns - minHalfTurns) * force).rounded())
        let halfTurns = makeHalfTurns(baseHalfTurns: baseHalfTurns,
                                      startFace: startFace,
                                      result: result)

        // 4. 按抛物线算出飞行时间：抛上去再落回来
        let landTime = flightDuration(height: height)

        // 5. 落地后弹一下，弹起的高度由风格的弹性决定
        let bounceHeight = height * style.bounciness
        let endTime = landTime + flightDuration(height: bounceHeight)

        return FlipPlan(result: result,
                        startFace: startFace,
                        height: height,
                        halfTurns: halfTurns,
                        landTime: landTime,
                        bounceHeight: bounceHeight,
                        endTime: endTime)
    }

    // MARK: - 小工具

    /// 把上划速度压成 0~1 的"用力程度"。
    /// 慢于 minSpeed 算 0（最轻），快过 maxSpeed 算 1（最重）。
    static func forceFactor(speed: Double) -> Double {
        guard speed > minSpeed else { return 0 }
        guard speed < maxSpeed else { return 1 }
        return (speed - minSpeed) / (maxSpeed - minSpeed)
    }

    /// 在两个数之间按比例取值。
    /// 特意让 factor 为 0 和 1 时精确返回两端的值，避免小数计算带来的误差。
    private static func lerp(from low: Double, to high: Double, factor: Double) -> Double {
        if factor <= 0 { return low }
        if factor >= 1 { return high }
        return low + (high - low) * factor
    }

    /// 抛到指定高度，再落回原处，一共要多少秒。
    /// 用的是中学物理的自由落体公式：上升时间 = √(2h/g)，来回要乘 2。
    static func flightDuration(height: Double) -> Double {
        2 * (2 * max(height, 0) / gravity).squareRoot()
    }
}
