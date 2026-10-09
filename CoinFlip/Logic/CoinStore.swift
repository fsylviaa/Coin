// 本机存储：记住最后一次抛出的结果。对应任务 T11。
//
// 整个 App 只往手机里存这一个值，不存历史、不统计次数、不上传任何数据。
// 用的是系统自带的 UserDefaults，相当于一个小抽屉。
// 删掉 App，这条记录也跟着没了。
//
// ⚠️ 结果必须在"决定的那一刻"就存，不能等落地后再存（技术文档第 7 号坑）。
//    否则硬币抛到一半时 App 被系统杀掉，这次结果就丢了。
//    真正调用保存的地方在 CoinController（T12）。

import Foundation

struct CoinStore {

    /// 存在手机里的键名。改了它，老用户的记录就读不到了，所以不要改。
    private static let key = "lastResult"

    /// 首次上划引导看过了没有
    private static let hintKey = "hasSeenSwipeHint"

    private let defaults: UserDefaults

    /// 平时用系统默认的抽屉；测试时传一个独立的抽屉进来，
    /// 这样跑测试不会把你自己玩 App 存下的结果冲掉。
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// 保存这一次的结果，覆盖上一次。
    func save(_ face: CoinFace) {
        defaults.set(face.rawValue, forKey: Self.key)
    }

    /// 读取最后一次结果。
    /// 返回空表示从来没抛过（新装的 App），这时该显示日面并等待第一次上划。
    func load() -> CoinFace? {
        guard let raw = defaults.string(forKey: Self.key) else { return nil }
        return CoinFace(rawValue: raw)
    }

    /// 上划引导放过了没有。
    ///
    /// 界面上没有任何按钮和文字，新用户拿到手是不知道要上划的。
    /// 所以第一次打开时硬币会自己被轻轻提起又落回几次，不解释，手会懂。
    /// ★ 只在第一次。★ 放过一次就永远不再出现。
    var hasSeenHint: Bool {
        defaults.bool(forKey: Self.hintKey)
    }

    /// 记下"引导已经放过了"。
    func markHintSeen() {
        defaults.set(true, forKey: Self.hintKey)
    }

    /// 清空记录，回到"从没抛过"的状态。目前只在测试里用。
    func clear() {
        defaults.removeObject(forKey: Self.key)
        defaults.removeObject(forKey: Self.hintKey)
    }
}
