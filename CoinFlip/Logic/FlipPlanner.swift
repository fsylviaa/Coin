// 演出规划师：负责"这一次抛硬币该怎么演"。
//
// 它只做决定和计算，不碰画面、声音、震动。
// 这样以后换画面、换音效，都不用动这里的代码。
//
// 已完成：T07 随机器、T08 半圈数修正、T09 生成时间表、T10 结果一致性检查

import Foundation

enum FlipPlanner {

    // MARK: - 调校参数（T23 调手感时只改这里的数字）

    /// 场景里的重力加速度（米/秒²）。
    /// 比真实的 9.8 小，硬币飞起来更舒缓，符合"沉静"的定位。数字越小飞得越慢。
    static let gravity: Double = 5.0

    /// 低于这个上划速度（点/秒），速度这一项不加分，避免手抖也把硬币抛出去。
    static let minSpeed: Double = 300

    /// 达到这个上划速度，速度这一项就满了。再快也不会更高，免得飞出屏幕。
    static let maxSpeed: Double = 3000

    /// 低于这个上划距离（点），距离这一项不加分
    static let minDistance: Double = 40

    /// 达到这个上划距离，距离这一项就满了
    static let maxDistance: Double = 320

    /// 速度占用力程度的几成，剩下的归距离。
    /// 偏向速度是因为"甩"的爽快主要来自撒手那一下；
    /// 但拖拽是看得见的蓄力动作，完全不算数会让人觉得白拖了。
    static let speedWeight: Double = 0.7

    /// 最轻一划时翻几个半圈
    static let minHalfTurns: Int = 2

    /// 最用力一划时翻几个半圈。
    /// 不宜太多——转得慢才有分量，转成陀螺就只剩炫技了。
    static let maxHalfTurns: Int = 7

    /// 小跳之后，边缘磕碰平面多少次。
    /// 这才是"硬币躺平前那阵嗒嗒嗒"的主体。
    static let rattleTaps: Int = 9

    /// 磕碰间隔收紧的程度。小于 1 就是越来越密，越小收得越急。
    static let rattleAccel: Double = 0.55

    /// 下落时的减速程度。只影响最高点之后那一段，不影响上抛。
    /// 0 是全程匀速；数字越大，落下时收得越慢越从容。
    static let descentSlowdown: Double = 3.0

    /// 落地那一刻硬币还歪着多少度。
    /// 真硬币是边缘先着地的，不会平平地拍下去。这个角度在摇摆中慢慢收到 0。
    /// 落地那一刻硬币还歪着多少度（边缘先着地）。
    ///
    /// 这个角度同时在做另一件事：**不让人太早看清结果**。
    /// 歪得越厉害，摇停的那段时间里币面越是侧着对镜头，读不出图案；
    /// 要等镜头抬起来推近，答案才一点点显出来——揭晓才有那一口气。
    /// 太小的话，硬币一落地就躺平了，推近只是把早就知道的答案放大。
    static let landingTilt: Double = 42

    /// 躺平这件事往后拖多少。
    ///
    /// 1 是匀着收；越大越是"先一直歪着、最后才躺平"。
    /// 和上面那个角度配合，决定"看不清"的那一段有多长。
    /// ⚠️ 必须大于 1：小于 1 会让硬币在最后一瞬间猛地拍平，很突兀。
    static let flattenDelay: Double = 1.8

    /// 落地后摇摆时，硬币在平面上打几圈转。
    /// 不宜多——转太快就糊成一团，反而看不出是硬币在晃。
    /// 落地后在平面上打转多少圈。
    ///
    /// ★ 必须是整数圈。★ 不是整圈的话，停稳那一刻硬币的朝向
    ///   和它一路转过来的朝向对不上，会原地突然扭一下——
    ///   看起来就像"落地看到的面和最后给的面接不上"。
    ///   FlipAnimator 会把它取整，但这里本来就该写整数。
    static let wobbleTurns: Double = 1.0

    /// 摇摆至少要持续这么久（秒），哪怕弹跳早就结束了。
    /// 太短就没有"晃几下才躺稳"的感觉。
    static let minSettleSeconds: Double = 0.85

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
    /// - Parameters:
    ///   - speed: 手势里往上最快的那一下有多快（点/秒）
    ///   - distance: 手指一共往上划了多远（点）
    static func makePlan(speed: Double,
                         distance: Double,
                         startFace: CoinFace,
                         result: CoinFace,
                         style: StyleProfile = .silver) -> FlipPlan {

        // 1. 把速度和距离一起换算成 0~1 的"用力程度"
        let force = forceFactor(speed: speed, distance: distance)

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

        // 5. 落地之后：先一下小跳，再是一连串越来越密的边缘磕碰。
        //    真硬币落在硬平面上几乎不弹，声音主要来自躺平前的那阵磕碰。
        let hopHeight = height * style.bounciness
        let hop = FlipPlan.Bounce(height: hopHeight,
                                  duration: flightDuration(height: hopHeight))
        let settle = max(hop.duration * 1.6, minSettleSeconds)
        let endTime = landTime + settle

        let hopStrength = (hopHeight / height).squareRoot()
        var contacts = [FlipPlan.Contact(time: landTime, strength: 1)]
        contacts.append(.init(time: landTime + hop.duration, strength: hopStrength))

        // 磕碰从小跳落回之后开始，一路密到停稳
        let tapStart = landTime + hop.duration
        let tapSpan = endTime - tapStart
        for k in 1...rattleTaps {
            let p = pow(Double(k) / Double(rattleTaps), rattleAccel)
            let fade = 1 - Double(k - 1) / Double(rattleTaps)
            // 磕碰一定比前面那下小跳更轻，整串才是一路衰下去的
            contacts.append(.init(time: tapStart + tapSpan * p,
                                  strength: hopStrength * 0.8 * pow(fade, 2.0)))
        }

        return FlipPlan(result: result,
                        startFace: startFace,
                        height: height,
                        halfTurns: halfTurns,
                        landTime: landTime,
                        bounces: [hop],
                        contacts: contacts,
                        endTime: endTime)
    }

    // MARK: - 动画结束时朝上的是哪一面（T10）

    /// 按时间表演完之后，朝上的会是哪一面。
    ///
    /// 只看两件事：抛之前是哪面、一共翻了几个半圈。
    /// 翻偶数个半圈又转回原来那面，翻奇数个半圈就换到另一面。
    ///
    /// 这个函数本身不参与抛硬币，它存在的意义是**反过来检查**：
    /// 用它算出的面，必须永远等于时间表里预先决定的 result。
    /// 一旦有人改坏了动画逻辑，测试就会立刻发现。
    static func finalFace(of plan: FlipPlan) -> CoinFace {
        plan.halfTurns % 2 == 0 ? plan.startFace : plan.startFace.opposite
    }

    // MARK: - 小工具

    /// 把速度和距离一起压成 0~1 的"用力程度"。
    ///
    /// 两项各自先压到 0~1，再按 speedWeight 加权。
    /// 所以"又快又长"才到得了最高；只快不长、或只长不快，都只到一部分。
    static func forceFactor(speed: Double, distance: Double) -> Double {
        let fast = ramp(speed, from: minSpeed, to: maxSpeed)
        let far = ramp(distance, from: minDistance, to: maxDistance)
        return speedWeight * fast + (1 - speedWeight) * far
    }

    /// 把一个值从 from~to 压到 0~1，超出范围就贴边
    private static func ramp(_ value: Double, from low: Double, to high: Double) -> Double {
        guard value > low else { return 0 }
        guard value < high else { return 1 }
        return (value - low) / (high - low)
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
