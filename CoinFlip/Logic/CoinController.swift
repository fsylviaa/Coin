// 状态管理：整个 App 的"门卫"。对应任务 T12。
//
// 它把前面几块拼成一条完整的链路：
//   上划 → 看门卫让不让 → 随机决定结果 → 立刻存档 → 排演出时间表 → 进入抛掷中
//
// 画面层（T13 之后）只跟这个控制器打交道，不直接碰随机器和存储。

import Foundation
import Observation

@Observable
final class CoinController {

    /// 硬币当前的状态。画面根据它决定显示什么。
    private(set) var phase: CoinPhase = .waiting

    /// 要不要放首次上划引导。只有装上之后从没抛过的那一次是 true。
    private(set) var showsHint = false

    /// 抛硬币的记录（卡片上显示的那些数）。硬币落定时才加一次。
    private(set) var stats = FlipStats()

    /// 这一次落定正好是第 100 / 500 / 1000 次时，存着这个数；下一次上划就清掉。
    /// 底部那行字靠它多显示一句"No. 100"。
    private(set) var milestone: Int?

    private let store: CoinStore
    private let style: StyleProfile
    /// 现在几点。平时就是真实时间；测试里换成固定时间，好测"今天"。
    private let now: () -> Date

    init(store: CoinStore = CoinStore(), style: StyleProfile = .silver,
         now: @escaping () -> Date = Date.init) {
        self.store = store
        self.style = style
        self.now = now
    }

    /// App 启动时调用一次。
    /// 读得到上次的结果就以那一面静置；读不到说明是新装的，进入等待状态。
    func start() {
        if let saved = store.load() {
            phase = .resting(saved)
        } else {
            phase = .waiting
        }
        stats = store.loadStats()
        showsHint = !store.hasSeenHint
    }

    /// 引导放完了，或者用户自己动手了——两种情况都算看过。
    /// 记下之后就永远不再放。
    func hintFinished() {
        guard showsHint else { return }
        showsHint = false
        store.markHintSeen()
    }

    /// 收到一次有效上划。
    ///
    /// - Returns: 这一次的演出时间表；若当前正在抛掷中，返回 nil 表示这次上划被忽略。
    ///
    /// ⚠️ 注意第 3 行：结果一决定就马上存，不等落地。
    ///    这样即使硬币飞到一半 App 被系统杀掉，结果也不会丢。
    @discardableResult
    func requestFlip(speed: Double, distance: Double) -> FlipPlan? {
        guard phase.acceptsFlip else { return nil }   // 抛掷中，直接忽略，不排队也不叠加

        hintFinished()                                // 会抛了，引导就不用再放了
        milestone = nil                               // 上一次的"No. 100"到此为止

        let result = FlipPlanner.decideResult()
        store.save(result)                            // 立刻存档，先于动画

        let plan = FlipPlanner.makePlan(speed: speed,
                                        distance: distance,
                                        startFace: phase.currentFace,
                                        result: result,
                                        style: style,
                                        // 每次抛出那一刻抽一个"性格"（P11），写进时间表，中途不变
                                        personality: .random())
        phase = .flipping(plan)
        return plan
    }

    /// 动画正常演完（到达时间表的 endTime）时调用。
    func finishFlip() {
        guard case .flipping(let plan) = phase else { return }
        settle(plan)
    }

    /// 抛掷中被打断：切后台、来电等。
    ///
    /// 直接摆成本次已经决定好的结果，不重新随机、不续播动画。
    /// 结果在 requestFlip 时就存过了，这里不需要再存。
    func interrupt() {
        guard case .flipping(let plan) = phase else { return }
        settle(plan)
    }

    /// 硬币落定：摆成结果，并记一次。
    ///
    /// 记录放在落定这一刻（而不是上划那一刻），这样硬币还在空中时打开卡片，
    /// 卡片上的数字不会提前"剧透"这一次的结果。
    /// 代价：硬币飞到一半 App 被系统杀掉，这一次不进记录（结果本身照样存着）。
    private func settle(_ plan: FlipPlan) {
        phase = .resting(plan.result)
        stats.record(plan.result, halfTurns: plan.halfTurns, at: now())
        store.saveStats(stats)
        milestone = stats.isMilestone ? stats.total : nil
    }

    /// 卡片上点"清零"并确认后调用。只清记录，不动"最后一次结果"。
    func resetStats() {
        stats = FlipStats()
        store.saveStats(stats)
        milestone = nil
    }
}
