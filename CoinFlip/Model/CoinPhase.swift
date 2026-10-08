// 硬币当前处在哪种状态。对应任务 T12。
//
// 同一时刻硬币只可能是其中一种，不会既在飞又在静置。
// "抛掷中不响应上划"这条规则，就是靠这个结构牢牢守住的——
// 不是靠"等 2 秒再解锁"这种猜测（技术文档第 6 号坑）。

enum CoinPhase: Equatable {

    /// 新装的 App，还没抛过。显示日面，可以上划。
    case waiting

    /// 抛掷中。从脱手到彻底停稳，这期间所有上划一律忽略。
    case flipping(FlipPlan)

    /// 落定静置，朝上的是这一面。可以上划。
    case resting(CoinFace)

    /// 现在能不能接受上划。只有抛掷中不行。
    var acceptsFlip: Bool {
        if case .flipping = self { return false }
        return true
    }

    /// 当前朝上的是哪一面。
    /// 抛掷中取这一次的结果（中途被打断时直接摆成它）；
    /// 还没抛过时默认日面。
    var currentFace: CoinFace {
        switch self {
        case .waiting:              return .sun
        case .flipping(let plan):   return plan.result
        case .resting(let face):    return face
        }
    }
}
