// 风格档案：一种硬币风格的全部参数集中在这里。
//
// 为什么要有这个文件：
// 最小可用版只有银币一种风格，但以后会加青铜、深金。
// 如果把"用哪张贴图""弹多高"这些数值散落在代码各处，加新风格时就要满世界找。
// 规定：凡是和风格有关的数值，只能写在这里，别的地方一律从这里取。
//
// 对应任务 T05。调手感（T23）时也只改这个文件里的数字。

struct StyleProfile {

    /// 风格的名字，用来区分不同硬币
    let id: String

    /// 日面贴图的文件名（不带扩展名）
    let textureSun: String

    /// 月面贴图的文件名（不带扩展名）
    let textureMoon: String
    /// 侧边的滚花与刻字贴图（不含 _normal 后缀）
    let textureEdge: String

    /// 抛起时那一声的文件名（不带扩展名）。余韵较长，一直响到硬币升上去。
    let tossSound: String

    /// 落地与磕碰的音效文件名（不带扩展名）
    let landSound: String

    /// 弹性：落地后那一下小跳有多高，占抛起高度的比例。
    /// 真硬币落在硬平面上几乎不弹，所以这个数很小——
    /// 落地后的声音主要来自躺平前的边缘磕碰，不是弹跳。
    /// 必须大于 0 小于 1，否则会越弹越高。
    ///
    /// P11 之后作者要"落地后弹得更高，落地一震、弹起落回再一震"：
    /// 0.055 → 0.16 → 0.2，并且另加一个保底高度（FlipPlanner.hopFloor），
    /// 轻抛也看得清再跳一下。最用力那一抛，落地后那段只长约 0.1 秒。
    /// FlipPlanTests 守着这一条，不让它悄悄变长。
    let bounciness: Double

    /// 抛起高度的下限（单位：米）。轻轻一划也至少抛这么高。
    let minHeight: Double

    /// 平常力度最高抛到多高（单位：米）。只有狠甩进了"爆发区"才会超过它
    /// （FlipPlanner.burstForce，和多转几圈是同一个门槛）。
    /// 落地后的弹跳、阴影、抛起那声的响度都按它算，所以平常的手感和以前一样。
    let normalMaxHeight: Double

    /// 抛起高度的上限（单位：米）。再用力也不会超过这个高度，免得飞出屏幕。
    let maxHeight: Double

    /// 这个高度算平常力度里的几成（0~1）。爆发区一律算 1。
    /// 声音、震动的轻重用它，免得加高了上限以后平常的抛掷都变轻了。
    func heightLevel(_ height: Double) -> Double {
        let span = max(normalMaxHeight - minHeight, 0.0001)
        return min(max((height - minHeight) / span, 0), 1)
    }
}

extension StyleProfile {

    /// 现代银色纪念币。最小可用版唯一的风格。
    /// 这里的数值都是初始值，T23 在真机上调手感时再修改。
    static let silver = StyleProfile(
        id: "silver",
        textureSun: "sun_silver",
        textureMoon: "moon_silver",
        textureEdge: "edge_silver",
        tossSound: "toss_silver",
        landSound: "land_silver",
        bounciness: 0.2,
        minHeight: 0.12,
        normalMaxHeight: 0.65,
        // 2026-10 作者要"可以抛得更高"：0.65 → 1.0，只有狠甩才到得了。
        // 算过：硬币往下挪之后，最高时硬币上沿离屏幕顶约 15%，不出画；
        // 空中时间 1.02 → 1.26 秒，6 圈时每帧转的角度从 56° 降到 46°，没那么闪了。
        maxHeight: 1.0
    )
}
