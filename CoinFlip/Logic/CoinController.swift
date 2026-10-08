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

    private let store: CoinStore
    private let style: StyleProfile

    init(store: CoinStore = CoinStore(), style: StyleProfile = .silver) {
        self.store = store
        self.style = style
    }

    /// App 启动时调用一次。
    /// 读得到上次的结果就以那一面静置；读不到说明是新装的，进入等待状态。
    func start() {
        if let saved = store.load() {
            phase = .resting(saved)
        } else {
            phase = .waiting
        }
    }

    /// 收到一次有效上划。
    ///
    /// - Returns: 这一次的演出时间表；若当前正在抛掷中，返回 nil 表示这次上划被忽略。
    ///
    /// ⚠️ 注意第 3 行：结果一决定就马上存，不等落地。
    ///    这样即使硬币飞到一半 App 被系统杀掉，结果也不会丢。
    @discardableResult
    func requestFlip(speed: Double) -> FlipPlan? {
        guard phase.acceptsFlip else { return nil }   // 抛掷中，直接忽略，不排队也不叠加

        let result = FlipPlanner.decideResult()
        store.save(result)                            // 立刻存档，先于动画

        let plan = FlipPlanner.makePlan(speed: speed,
                                        startFace: phase.currentFace,
                                        result: result,
                                        style: style)
        phase = .flipping(plan)
        return plan
    }

    /// 动画正常演完（到达时间表的 endTime）时调用。
    func finishFlip() {
        guard case .flipping(let plan) = phase else { return }
        phase = .resting(plan.result)
    }

    /// 抛掷中被打断：切后台、来电等。
    ///
    /// 直接摆成本次已经决定好的结果，不重新随机、不续播动画。
    /// 结果在 requestFlip 时就存过了，这里不需要再存。
    func interrupt() {
        guard case .flipping(let plan) = phase else { return }
        phase = .resting(plan.result)
    }
}
