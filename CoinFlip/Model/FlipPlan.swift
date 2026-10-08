// 一次抛掷的"演出时间表"。对应任务 T09、T17。
//
// 上划的瞬间，程序先定好结果，然后把这一次要怎么演算清楚，写成这张表：
// 飞多高、翻几个半圈、第几秒落地、落地后弹几下、第几秒彻底停稳。
//
// 之后画面、声音、震动都照着这同一张表执行，所以天然同步。
// ⚠️ 任何地方都不要另外写死秒数（比如"0.9 秒后播放撞击声"），
//    一律从这张表里取，否则改了高度，声音就会对不上画面。

struct FlipPlan: Equatable {

    /// 落地后的一次弹跳
    struct Bounce: Equatable {
        /// 弹起多高（米）
        let height: Double
        /// 这一下弹跳从离地到落回要多久（秒）
        let duration: Double
    }

    /// 预先决定好的结果。动画只是把它演出来，不会改变它。
    let result: CoinFace

    /// 抛之前朝上的那一面。用来算要翻奇数还是偶数个半圈。
    let startFace: CoinFace

    /// 抛起的最高高度（米）。已经限制在风格档案的上下限之间。
    let height: Double

    /// 翻转的半圈数。每半圈 180°，奇偶决定最终朝上哪一面。
    let halfTurns: Int

    /// 第几秒首次落地。声音和震动都在这一刻触发。
    let landTime: Double

    /// 落地之后的几次弹跳，一次比一次低
    let bounces: [Bounce]

    /// 硬币碰到平面的每一次。
    ///
    /// 第一次是落地，然后是一下小跳落回，之后是一连串越来越密的边缘磕碰。
    /// 声音和震动都照着这张表触发，所以听起来就是真硬币躺平前那阵"嗒嗒嗒"。
    let contacts: [Contact]

    /// 第几秒彻底停稳。到这一刻才解锁上划，允许下一次抛掷。
    let endTime: Double

    /// 落地后那一下小跳的高度。方便外部直接引用。
    var bounceHeight: Double { bounces.first?.height ?? 0 }

    /// 一次碰撞
    struct Contact: Equatable {
        /// 第几秒碰到平面
        let time: Double
        /// 这一下有多重。1 是落地那一下，之后越来越轻。
        let strength: Double
    }
}
