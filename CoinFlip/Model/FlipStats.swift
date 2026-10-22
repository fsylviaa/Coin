// 抛硬币的记录：一共抛了多少次、日面月面各几次、连了几次……
//
// ★ 需求变更（2026-10-19）★
//   原需求是"不存历史、不统计次数"。作者决定加上"记录"，
//   所以现在手机里除了"最后一次结果"，还多存这一份统计。
//   仍然只存在这台手机里，不上传；删掉 App 就没了。
//
// 只存"数字"，不存每一次的明细——够算出卡片上的每一项就行，
// 抛一万次也只占几十个字节。
//
// 什么时候算一次：硬币**落定**那一刻（正常演完，或中途被打断直接摆成结果）。
// 横拨自旋、晃手机让硬币颠起来，都不算。
//
// 用词：两面叫"日面 / 月面"，不叫"正 / 反"。
// 需求规定不给两面预设"是 / 否"的含义（见 CoinFace），所以统计里也不分正反。

import Foundation

struct FlipStats: Codable, Equatable {

    /// 一共抛了多少次
    var total = 0
    /// 日面朝上几次
    var sun = 0
    /// 月面朝上几次
    var moon = 0

    /// 上一次落定的是哪一面（算"连续"用）
    var lastFace: CoinFace?
    /// 当前连续出了几次同一面（就是 lastFace 那一面）
    var streak = 0
    /// 历史上最长连续几次
    var longestStreak = 0

    /// "今天"是哪一天（本地日期，形如 2026-10-19）
    var todayKey: String?
    /// 那一天抛了几次。日期一变，读出来就是 0。
    var todayCount = 0

    /// 转得最多的那一抛，翻了几个半圈
    var maxHalfTurns = 0
    /// 一共翻了几个半圈
    var totalHalfTurns = 0

    /// 第一次抛是什么时候（"从 2026 年 10 月开始"）
    var firstFlip: Date?

    /// 最快的一划（就是最高分，点/秒，2026-10）
    var maxSpeed = 0

    /// 到这几次时，底部那行字会多一句"No. 100"
    static let milestones: Set<Int> = [100, 500, 1000]

    init() {}

    // MARK: - 记一次

    /// 硬币落定，记一次。
    mutating func record(_ face: CoinFace, halfTurns: Int, at date: Date,
                         calendar: Calendar = .current) {
        total += 1
        if face == .sun { sun += 1 } else { moon += 1 }

        if face == lastFace {
            streak += 1
        } else {
            lastFace = face
            streak = 1
        }
        longestStreak = max(longestStreak, streak)

        let key = Self.dayKey(date, calendar: calendar)
        if key == todayKey {
            todayCount += 1
        } else {
            todayKey = key
            todayCount = 1
        }

        maxHalfTurns = max(maxHalfTurns, max(halfTurns, 0))
        totalHalfTurns += max(halfTurns, 0)

        if firstFlip == nil { firstFlip = date }
    }

    /// 一抛停稳，得了 points 分。只留最高的
    mutating func recordScore(_ points: Int) {
        maxSpeed = max(maxSpeed, points)
    }

    // MARK: - 给卡片看的

    /// 今天抛了几次。存下的那一天不是今天，就是 0。
    func today(_ now: Date, calendar: Calendar = .current) -> Int {
        Self.dayKey(now, calendar: calendar) == todayKey ? todayCount : 0
    }

    /// 日面、月面各占百分之几。两个数加起来一定是 100（还没抛过时都是 0）。
    var percents: (sun: Int, moon: Int) {
        guard total > 0 else { return (0, 0) }
        let s = Int((Double(sun) / Double(total) * 100).rounded())
        return (s, 100 - s)
    }

    /// 这一次落定，是不是正好到了 100、500、1000 次
    var isMilestone: Bool { Self.milestones.contains(total) }

    /// 半圈数换成"几圈"的文字：14 个半圈是"7"，15 个是"7.5"。整数部分带千位分隔。
    static func turnsText(halfTurns: Int) -> String {
        let whole = (halfTurns / 2).formatted()
        return halfTurns % 2 == 0 ? whole : "\(whole).5"
    }

    static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    // MARK: - 读档

    // 手写读档：以后给记录加新的一项时，老的存档缺这一项也能读，
    // 缺的那项按 0 / 空算——不会因为升级 App 就把记录清掉。
    private enum CodingKeys: String, CodingKey {
        case total, sun, moon, lastFace, streak, longestStreak,
             todayKey, todayCount, maxHalfTurns, totalHalfTurns, firstFlip, maxSpeed
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        total          = try c.decodeIfPresent(Int.self, forKey: .total) ?? 0
        sun            = try c.decodeIfPresent(Int.self, forKey: .sun) ?? 0
        moon           = try c.decodeIfPresent(Int.self, forKey: .moon) ?? 0
        lastFace       = try c.decodeIfPresent(CoinFace.self, forKey: .lastFace)
        streak         = try c.decodeIfPresent(Int.self, forKey: .streak) ?? 0
        longestStreak  = try c.decodeIfPresent(Int.self, forKey: .longestStreak) ?? 0
        todayKey       = try c.decodeIfPresent(String.self, forKey: .todayKey)
        todayCount     = try c.decodeIfPresent(Int.self, forKey: .todayCount) ?? 0
        maxHalfTurns   = try c.decodeIfPresent(Int.self, forKey: .maxHalfTurns) ?? 0
        totalHalfTurns = try c.decodeIfPresent(Int.self, forKey: .totalHalfTurns) ?? 0
        firstFlip      = try c.decodeIfPresent(Date.self, forKey: .firstFlip)
        maxSpeed       = try c.decodeIfPresent(Int.self, forKey: .maxSpeed) ?? 0
    }
}
