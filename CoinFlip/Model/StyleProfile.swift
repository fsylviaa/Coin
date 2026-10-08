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

    /// 落地音效的文件名（不带扩展名）
    let landSound: String

    /// 弹性：落地后弹起的高度，占抛起高度的比例。
    /// 0.2 表示抛多高就弹起两成。必须大于 0 小于 1，否则会越弹越高。
    let bounciness: Double

    /// 抛起高度的下限（单位：米）。轻轻一划也至少抛这么高。
    let minHeight: Double

    /// 抛起高度的上限（单位：米）。再用力也不会超过这个高度，免得飞出屏幕。
    let maxHeight: Double
}

extension StyleProfile {

    /// 现代银色纪念币。最小可用版唯一的风格。
    /// 这里的数值都是初始值，T23 在真机上调手感时再修改。
    static let silver = StyleProfile(
        id: "silver",
        textureSun: "sun_silver",
        textureMoon: "moon_silver",
        landSound: "land_silver",
        bounciness: 0.20,
        minHeight: 0.12,
        maxHeight: 0.65
    )
}
