// "记录"的自动测试。
//
// 守护的规则：
//   1. 只在硬币落定时记一次（正常演完、中途被打断都算；上划那一刻不算）
//   2. 日面 / 月面、连续、最长连续、今天、圈数都算得对
//   3. 关掉 App 再开，记录还在；清零只清记录，不动最后一次结果
//   4. 第 100 / 500 / 1000 次落定时有里程碑，下一次上划就消失

import XCTest
@testable import CoinFlip

final class FlipStatsTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!
    private var store: CoinStore!

    /// 固定时区的日历，测"今天"不受跑测试那台电脑的时区影响
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private let day1 = Date(timeIntervalSince1970: 1_792_400_000)   // 某天中午前后

    override func setUp() {
        super.setUp()
        suiteName = "FlipStatsTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        store = CoinStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func add(_ faces: [CoinFace], into s: inout FlipStats, halfTurns: Int = 10,
                        at date: Date? = nil) {
        for f in faces { s.record(f, halfTurns: halfTurns, at: date ?? day1, calendar: calendar) }
    }

    // MARK: - 计数

    func testEmpty() {
        let s = FlipStats()
        XCTAssertEqual(s.total, 0)
        XCTAssertEqual(s.percents.sun, 0)
        XCTAssertEqual(s.percents.moon, 0)
        XCTAssertNil(s.firstFlip)
    }

    func testCountsEachFace() {
        var s = FlipStats()
        add([.sun, .moon, .moon, .sun, .moon], into: &s)
        XCTAssertEqual(s.total, 5)
        XCTAssertEqual(s.sun, 2)
        XCTAssertEqual(s.moon, 3)
    }

    /// 百分比加起来必须是 100，不能出现 33% + 33%
    func testPercentsAddUpTo100() {
        var s = FlipStats()
        add([.sun, .moon, .moon], into: &s)
        XCTAssertEqual(s.percents.sun + s.percents.moon, 100)
        XCTAssertEqual(s.percents.sun, 33)
        var t = FlipStats()
        add([.sun, .sun, .moon], into: &t)
        XCTAssertEqual(t.percents.sun + t.percents.moon, 100)
    }

    // MARK: - 连续

    func testStreak() {
        var s = FlipStats()
        add([.sun, .sun, .sun], into: &s)
        XCTAssertEqual(s.lastFace, .sun)
        XCTAssertEqual(s.streak, 3)
        add([.moon], into: &s)
        XCTAssertEqual(s.lastFace, .moon)
        XCTAssertEqual(s.streak, 1, "换面了，连续从 1 重新数")
        XCTAssertEqual(s.longestStreak, 3, "最长连续记得之前的 3 次")
    }

    func testLongestStreakGrows() {
        var s = FlipStats()
        add([.moon, .moon, .sun, .sun, .sun, .sun, .moon], into: &s)
        XCTAssertEqual(s.longestStreak, 4)
    }

    // MARK: - 今天

    func testTodayCountsAndRollsOver() {
        var s = FlipStats()
        add([.sun, .moon], into: &s, at: day1)
        XCTAssertEqual(s.today(day1, calendar: calendar), 2)

        let nextDay = day1.addingTimeInterval(86_400)
        XCTAssertEqual(s.today(nextDay, calendar: calendar), 0, "第二天打开，还没抛就是 0")

        add([.sun], into: &s, at: nextDay)
        XCTAssertEqual(s.today(nextDay, calendar: calendar), 1, "新的一天从 1 开始数")
        XCTAssertEqual(s.total, 3, "总数不受日期影响")
    }

    // MARK: - 圈数

    func testTurns() {
        var s = FlipStats()
        s.record(.sun, halfTurns: 14, at: day1, calendar: calendar)
        s.record(.moon, halfTurns: 29, at: day1, calendar: calendar)
        s.record(.sun, halfTurns: 8, at: day1, calendar: calendar)
        XCTAssertEqual(s.maxHalfTurns, 29)
        XCTAssertEqual(s.totalHalfTurns, 51)
        XCTAssertEqual(FlipStats.turnsText(halfTurns: 28), "14")
        XCTAssertEqual(FlipStats.turnsText(halfTurns: 29), "14.5")
    }

    func testFirstFlipDateKeepsTheFirst() {
        var s = FlipStats()
        add([.sun], into: &s, at: day1)
        add([.moon], into: &s, at: day1.addingTimeInterval(500_000))
        XCTAssertEqual(s.firstFlip, day1)
    }

    // MARK: - 里程碑

    func testMilestones() {
        var s = FlipStats()
        for i in 1...1000 {
            s.record(i % 2 == 0 ? .sun : .moon, halfTurns: 10, at: day1, calendar: calendar)
            XCTAssertEqual(s.isMilestone, [100, 500, 1000].contains(i), "第 \(i) 次")
        }
    }

    // MARK: - 存档

    func testStoreRoundTrip() {
        var s = FlipStats()
        add([.sun, .moon, .moon], into: &s, halfTurns: 13)
        store.saveStats(s)
        XCTAssertEqual(CoinStore(defaults: defaults).loadStats(), s)
    }

    func testMissingOrBrokenStatsLoadEmpty() {
        XCTAssertEqual(store.loadStats(), FlipStats())
        defaults.set(Data("坏掉的".utf8), forKey: "flipStats")
        XCTAssertEqual(store.loadStats(), FlipStats())
    }

    /// 以后加新的一项，老存档缺这一项也要读得出来
    func testOldSaveWithFewerFieldsStillLoads() {
        defaults.set(Data(#"{"total":7,"sun":3,"moon":4}"#.utf8), forKey: "flipStats")
        let s = store.loadStats()
        XCTAssertEqual(s.total, 7)
        XCTAssertEqual(s.moon, 4)
        XCTAssertEqual(s.streak, 0)
    }

    // MARK: - 和大脑接起来

    private func makeController() -> CoinController {
        let d = day1
        return CoinController(store: store, now: { d })
    }

    func testCountsOnlyWhenSettled() {
        let c = makeController()
        c.start()
        let plan = c.requestFlip(speed: 1500, distance: 200)!
        XCTAssertEqual(c.stats.total, 0, "硬币还在空中，不记（卡片不能剧透）")
        c.finishFlip()
        XCTAssertEqual(c.stats.total, 1)
        XCTAssertEqual(c.stats.lastFace, plan.result, "记下的就是落定的那一面")
        XCTAssertEqual(c.stats.maxHalfTurns, plan.halfTurns)
    }

    func testInterruptedFlipCounts() {
        let c = makeController()
        c.start()
        let plan = c.requestFlip(speed: 1500, distance: 200)!
        c.interrupt()
        XCTAssertEqual(c.stats.total, 1)
        XCTAssertEqual(c.stats.lastFace, plan.result)
    }

    func testFinishTwiceCountsOnce() {
        let c = makeController()
        c.start()
        c.requestFlip(speed: 1500, distance: 200)
        c.finishFlip()
        c.finishFlip()
        c.interrupt()
        XCTAssertEqual(c.stats.total, 1, "同一次抛掷只记一次")
    }

    func testStatsSurviveRestart() {
        let c = makeController()
        c.start()
        for _ in 0..<3 {
            c.requestFlip(speed: 1500, distance: 200)
            c.finishFlip()
        }
        let again = makeController()
        again.start()
        XCTAssertEqual(again.stats.total, 3, "关掉 App 再开，记录还在")
    }

    func testResetClearsStatsButKeepsLastResult() {
        let c = makeController()
        c.start()
        let plan = c.requestFlip(speed: 1500, distance: 200)!
        c.finishFlip()
        c.resetStats()
        XCTAssertEqual(c.stats, FlipStats())
        XCTAssertEqual(store.loadStats(), FlipStats(), "清零也要存下来")
        XCTAssertEqual(store.load(), plan.result, "最后一次结果不受影响")
        XCTAssertEqual(c.phase, .resting(plan.result))
    }

    func testMilestoneShowsUntilNextFlip() {
        var s = FlipStats()
        for _ in 0..<99 { s.record(.sun, halfTurns: 10, at: day1, calendar: calendar) }
        store.saveStats(s)
        let c = makeController()
        c.start()
        c.requestFlip(speed: 1500, distance: 200)
        XCTAssertNil(c.milestone)
        c.finishFlip()
        XCTAssertEqual(c.milestone, 100)
        c.requestFlip(speed: 1500, distance: 200)
        XCTAssertNil(c.milestone, "下一次上划，里程碑就收起来")
        c.finishFlip()
        XCTAssertNil(c.milestone)
    }
}
