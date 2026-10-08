// 硬币的两面：日面与月面。对应任务 T04。
//
// 需求规定不给日/月预设"是/否"的含义，由用户自己在心里赋予。
// 所以这里只是两个名字，不带任何倾向。

enum CoinFace: String, Codable {
    case sun    // 日面
    case moon   // 月面

    /// 另一面。日的另一面是月，月的另一面是日。
    var opposite: CoinFace {
        self == .sun ? .moon : .sun
    }
}
