// 动画计算：某一刻，硬币应该在多高、怎么摆。对应任务 T16、T17。
//
// 它只做数学，不碰画面——所以可以用自动测试验收，不用靠眼睛看。
// 画面每一帧问它"现在第 t 秒，硬币该摆成什么样"，它就回答。
//
// 整个过程照着真硬币落在桌面上的样子来：
//     抛起 → 快速翻滚 → 边缘先着地（还歪着）
//     → 在平面上一边打转一边摇摆，幅度越来越小、转得越来越快
//     → 啪地躺平，停住
//
// 这就是真硬币快停下来时那阵"嗡嗡"的打转，物理上叫进动。
// 我们不算真实物理，只是照着它的样子编出来——结果早就定好了，这里只负责演得像。
//
// ⚠️ 这里的所有时间点都来自 FlipPlan（演出时间表），
//    绝不在这里另外写死秒数（技术文档第 3 号坑）。

import Foundation

enum FlipAnimator {

    /// 某一刻硬币的姿态
    struct Pose: Equatable {
        /// 离平面多高（场景单位，0 就是贴在平面上）
        let height: Double
        /// 绕横轴累计翻转了多少度。奇数个 180° 就是换了一面。
        let degrees: Double
        /// 离躺平还差多少度（0 就是完全躺平了）。
        ///
        /// 画面要用它把圆心顶起来：歪着的硬币支点在边缘，圆心是悬空的。
        /// 不算这一下，硬币会沉到地面以下，地面就会在币面上切一刀。
        let tiltDegrees: Double
        /// 绕竖直轴转了多少度——落地后在平面上打转的方位。
        /// 它不改变朝上的是哪一面，只是让摇摆的方向绕着走。
        ///
        /// P09 起飞行中也有：翻转轴在空中缓缓绕竖直方向转（进动），
        /// 落地时以同样的速度接上原来的打转，从抛起到躺平是一整个动作。
        let wobbleDegrees: Double
        /// 翻转轴此刻往竖直方向歪了多少度（P09，章动）。
        /// 只在飞行中有，起飞和落地那一刻都是 0，所以不影响最后朝上的是哪一面。
        let nutationDegrees: Double
        /// 这一刻是不是已经彻底停稳了
        let isFinished: Bool
    }

    /// 算出第 t 秒时硬币的姿态。
    ///
    /// - Parameters:
    ///   - t: 从脱手算起过了多少秒
    ///   - plan: 这一次抛掷的时间表
    ///   - heightScale: 把时间表里的高度（米）换算成场景里的高度
    ///   - axisYaw: 翻转轴绕竖直方向转了多少度（P09，跟着手指上划的方向）。
    ///     0 就是原来那样朝正前方翻。
    static func pose(at t: Double, plan: FlipPlan, heightScale: Double,
                     axisYaw: Double = 0) -> Pose {
        let total = Double(plan.halfTurns) * 180
        let end = wobbleEnd(halfTurns: plan.halfTurns, axisYaw: axisYaw)
        let side = turnSide(axisYaw: axisYaw)

        if t >= plan.endTime {
            return Pose(height: 0, degrees: total, tiltDegrees: 0,
                        wobbleDegrees: end, nutationDegrees: 0, isFinished: true)
        }

        return Pose(height: height(at: t, plan: plan) * heightScale,
                    degrees: degrees(at: t, plan: plan),
                    tiltDegrees: tilt(at: t, plan: plan),
                    wobbleDegrees: wobble(at: t, plan: plan, end: end, side: side),
                    nutationDegrees: side * nutation(at: t, plan: plan),
                    isFinished: false)
    }

    // MARK: - 高度

    /// 第 t 秒离平面多高（米）
    private static func height(at t: Double, plan: FlipPlan) -> Double {
        // 第一段：抛起到落地，走一条抛物线
        if t < plan.landTime {
            let progress = plan.landTime > 0 ? t / plan.landTime : 1
            return arc(progress: progress, peak: plan.height)
        }

        // 第二段：落地之后一下一下地弹，每一下都比上一下低。
        // 弹完之后硬币就贴在平面上了，但还会继续摇摆一阵。
        var remaining = t - plan.landTime
        for bounce in plan.bounces {
            if remaining < bounce.duration {
                let progress = bounce.duration > 0 ? remaining / bounce.duration : 1
                return arc(progress: progress, peak: bounce.height)
            }
            remaining -= bounce.duration
        }
        return 0
    }

    /// 一条抛物线：从 0 升到最高点，再落回 0。
    private static func arc(progress: Double, peak: Double) -> Double {
        let p = min(max(progress, 0), 1)
        return peak * 4 * p * (1 - p)
    }

    // MARK: - 翻转

    /// 第 t 秒绕横轴一共转过了多少度。
    ///
    /// 上抛和下落是两段不同的节奏：
    ///   • 上升到最高点：匀速稳稳地转，有分量
    ///   • 从最高点落下：一路减速，到贴近平面时几乎只是缓缓转动
    ///
    /// 两段在最高点处转速是接续上的，不会有突然变速的突兀感。
    /// 想让上抛更活泼就加圈数，想让下落更从容就加减速程度，互不干扰。
    ///
    /// 另外故意少转一点点：落地那一刻硬币还歪着一个角度，
    /// 因为真硬币是边缘先着地的。剩下这点角度在摇摆中慢慢收完。
    ///
    /// 收的节奏是**故意往后拖**的：歪着的时候币面侧对镜头，读不出图案，
    /// 要等镜头抬起来推近，答案才一点点显出来。揭晓的那一口气就在这儿。
    private static func degrees(at t: Double, plan: FlipPlan) -> Double {
        let total = Double(plan.halfTurns) * 180
        let landing = min(FlipPlanner.landingTilt, total)

        if t <= plan.landTime {
            let progress = plan.landTime > 0 ? t / plan.landTime : 1
            return (total - landing) * spinProgress(progress)
        }
        return total - tilt(at: t, plan: plan)
    }

    /// 第 t 秒时，硬币离躺平还差多少度。
    ///
    /// 落地之后它从落地倾角一路收到 0；落地之前只在**最后一小段**里悄悄长起来，
    /// 到落地那一刻正好接上。
    ///
    /// 为什么飞行段要这样处理：画面会按这个角度把圆心顶起来。
    /// 要是整个飞行过程都顶，最高点会被抬高两成，硬币就飞出屏幕了——
    /// 用六次方意味着飞到九成路程时才抬了不到一个点，肉眼完全看不出，
    /// 落地那一刻却已经严丝合缝地对上了。
    static func tilt(at t: Double, plan: FlipPlan) -> Double {
        let total = Double(plan.halfTurns) * 180
        let landing = min(FlipPlanner.landingTilt, total)

        if t >= plan.endTime { return 0 }

        if t <= plan.landTime {
            let progress = plan.landTime > 0 ? t / plan.landTime : 1
            return landing * pow(progress, 6)
        }

        // 先一直歪着，最后才躺平；越接近躺平收得越慢，不会拍一下砸平
        let p = settleProgress(at: t, plan: plan)
        return landing * pow(1 - pow(p, FlipPlanner.flattenDelay), 1.6)
    }

    /// 飞行走到 progress（0 到 1）时，已经转完了全部的百分之多少。
    ///
    /// 前半程（上升）匀速，后半程（下落）按一条减速曲线收住。
    /// 两段的"转量"加起来归一化成 1，所以无论减速程度怎么调，
    /// 落地时转过的总度数都不变——结果的正确性不受影响。
    private static func spinProgress(_ progress: Double) -> Double {
        let d = max(FlipPlanner.descentSlowdown, 0)
        let ascent = 0.5                     // 上升段的转量
        let descent = 0.5 / (d + 1)          // 下落段的转量
        let whole = ascent + descent

        if progress <= 0.5 {
            return progress / whole
        }
        let y = (progress - 0.5) / 0.5
        return (ascent + 0.5 * (1 - pow(1 - y, d + 1)) / (d + 1)) / whole
    }

    // MARK: - 进动与章动（P09）

    /// 飞行中翻转轴绕竖直方向一共转多少度（进动）。
    ///
    /// 真硬币几乎从来不绕一根固定的轴翻——轴自己也在慢慢转。
    /// 加上它，空中就不再是"绕着一根杆子机械地翻"。
    /// 只绕竖直方向转，所以不改变翻了几个半圈，也就不改变结果。
    static let flightPrecessionDegrees: Double = 60

    /// 飞行中翻转轴最多往竖直方向歪多少度（章动）。
    /// 起飞、落地两头都是 0，中间最大——歪出去又正回来，结果不受影响。
    static let nutationPeakDegrees: Double = 12

    /// 第 t 秒翻转轴歪了多少度：只在飞行中有，两头为 0
    private static func nutation(at t: Double, plan: FlipPlan) -> Double {
        guard t < plan.landTime, plan.landTime > 0 else { return 0 }
        return nutationPeakDegrees * sin(.pi * t / plan.landTime)
    }

    // MARK: - 摇摆打转

    /// 第 t 秒绕竖直轴转了多少度。
    ///
    /// 飞行中（P09）：从 0 开始慢慢起步，落地时转到 flightPrecessionDegrees。
    /// 落地之后：从落地那一刻的转速接着走，中途最快，再缓缓收住，
    /// 停在整圈上（wobbleEndDegrees）。
    ///
    /// 真硬币快停住时那阵打转其实是越来越快的，但照搬过来在屏幕上
    /// 会糊成一团，而且最后戛然而止很突兀。所以改成两头慢中间快，
    /// 转速最高不过每秒两圈，看得清是硬币在晃，收尾也自然。
    ///
    /// 它只是让歪斜的方向绕着圈走，不影响朝上的是哪一面。
    private static func wobble(at t: Double, plan: FlipPlan, end: Double, side: Double) -> Double {
        let start = side * flightPrecessionDegrees
        guard plan.landTime > 0 else { return 0 }

        if t <= plan.landTime {
            // 起步速度为 0，越转越快
            let p = t / plan.landTime
            return start * p * p
        }

        // 落地之后：三次曲线，起点接上落地时的位置和转速，终点停在整圈、速度为 0
        let p = settleProgress(at: t, plan: plan)
        let settle = plan.endTime - plan.landTime
        let landingSpeed = 2 * start / plan.landTime              // 度/秒
        // 换算成"每走完一整段"的单位；封顶，保证一路只往前转、中途仍是最快
        let m0 = side * min(abs(landingSpeed) * settle, abs(end - start))
        let h00 = 2 * p * p * p - 3 * p * p + 1
        let h10 = p * p * p - 2 * p * p + p
        let h01 = -2 * p * p * p + 3 * p * p
        return h00 * start + h10 * m0 + h01 * end
    }

    /// 打转一共转过多少度。
    ///
    /// ★ 取整到整圈。★ 画面在停稳那一刻会把硬币摆成干净的躺平姿态，
    ///   那个姿态是不带打转的。如果打转停在半圈上，这两者就对不上，
    ///   硬币会在最后一帧原地扭一下，像是突然换了一面。
    ///   取整之后，转完正好回到出发时的朝向，两边严丝合缝。
    static var wobbleEndDegrees: Double {
        FlipPlanner.wobbleTurns.rounded() * 360
    }

    /// 翻转轴转了 axisYaw 度时，打转要停在多少度，停稳那一刻才和躺平姿态对得上（P09）。
    ///
    /// ★ 斜着的轴翻奇数个半圈，硬币会多出一个 2 × axisYaw 的朝向。★
    ///   （绕斜轴翻 180° = 先转到正轴、翻 180°、再转回来，一来一回朝向差了两倍。）
    ///   打转把这一截补回来，停稳时就严丝合缝。偶数个半圈没有这一截。
    ///   FlipAnimatorTests 里用四元数逐一核对了最后一帧和躺平姿态。
    static func wobbleEnd(halfTurns: Int, axisYaw: Double) -> Double {
        let correction = halfTurns % 2 == 1 ? -2 * axisYaw : 0
        return turnSide(axisYaw: axisYaw) * wobbleEndDegrees + correction
    }

    /// 进动、章动、打转往哪边转：+1 或 −1，跟着手指划的方向镜像（P09）。
    ///
    /// ★ 左划必须正好是右划照镜子。★ 第一版固定朝一边转：
    ///   往右划时进动把轴往回带、往左划时往外推，作者看着"左划右划飞行姿态不一样"。
    ///   正上方（axisYaw = 0）沿用原来的方向。
    static func turnSide(axisYaw: Double) -> Double {
        axisYaw > 0 ? -1 : 1
    }

    /// 落地之后到停稳之间走了多少（0 到 1）
    private static func settleProgress(at t: Double, plan: FlipPlan) -> Double {
        let settle = plan.endTime - plan.landTime
        guard settle > 0 else { return 1 }
        return min(max((t - plan.landTime) / settle, 0), 1)
    }
}
