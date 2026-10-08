// 状态管理的自动测试（任务 T12）。
//
// 这组测试守护三条规则：
//   1. 抛掷中的上划一律忽略，不排队、不叠加
//   2. 结果在决定的瞬间就存档，不等落地
//   3. 中途被打断也落在本次已决定的结果上，不重新随机

import XCTest
@testable import CoinFlip

final class CoinControllerTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!
    private var store: CoinStore!

    override func setUp() {
        super.setUp()
        suiteName = "CoinControllerTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        store = CoinStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        store = nil
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    private func makeController() -> CoinController {
        CoinController(store: store)
    }

    // MARK: - 启动

    /// 新装的 App：没有存档，进入等待状态
    func testStartWithoutSavedIsWaiting() {
        store.clear()
        let c = makeController()
        c.start()
        XCTAssertEqual(c.phase, .waiting)
    }

    /// 上次抛出月面：重新打开后以月面静置
    func testStartWithSavedMoon() {
        store.save(.moon)
        let c = makeController()
        c.start()
        XCTAssertEqual(c.phase, .resting(.moon))
    }

    // MARK: - 抛掷

    /// 等待状态下上划：拿到时间表，进入抛掷中
    func testFlipFromWaiting() {
        store.clear()
        let c = makeController()
        c.start()
        let plan = c.requestFlip(speed: 1200)
        XCTAssertNotNil(plan)
        XCTAssertFalse(c.phase.acceptsFlip, "抛掷中应该不接受上划")
    }

    /// 静置状态下上划：也能正常开始
    func testFlipFromResting() {
        store.save(.sun)
        let c = makeController()
        c.start()
        XCTAssertNotNil(c.requestFlip(speed: 800))
    }

    /// ★ 抛掷中再上划：返回空，状态和时间表都不变
    func testFlipIgnoredWhileFlipping() {
        store.clear()
        let c = makeController()
        c.start()
        let first = c.requestFlip(speed: 1500)
        let phaseAfterFirst = c.phase

        for _ in 0..<5 {
            XCTAssertNil(c.requestFlip(speed: 3000), "抛掷中的上划应被忽略")
        }
        XCTAssertEqual(c.phase, phaseAfterFirst, "被忽略的上划不该改变状态")

        // 停稳后落在第一次的结果上，说明后面那几次上划没有偷偷生效
        c.finishFlip()
        XCTAssertEqual(c.phase, .resting(first!.result))
    }

    /// ★ 结果在决定的瞬间就存档，不等落地
    func testResultSavedImmediately() {
        store.clear()
        let c = makeController()
        c.start()
        let plan = c.requestFlip(speed: 1000)!
        // 此刻还没调用 finishFlip，但抽屉里已经有结果了
        XCTAssertEqual(store.load(), plan.result, "结果应在上划瞬间就存档")
    }

    // MARK: - 结束与打断

    /// 正常演完：落在本次结果上
    func testFinishGoesResting() {
        store.clear()
        let c = makeController()
        c.start()
        let plan = c.requestFlip(speed: 1000)!
        c.finishFlip()
        XCTAssertEqual(c.phase, .resting(plan.result))
    }

    /// ★ 抛掷中被打断（切后台、来电）：直接落定为本次结果，存档也一致
    func testInterruptGoesResting() {
        store.clear()
        let c = makeController()
        c.start()
        let plan = c.requestFlip(speed: 2000)!
        c.interrupt()
        XCTAssertEqual(c.phase, .resting(plan.result))
        XCTAssertEqual(store.load(), plan.result)
    }

    /// 没在抛掷时被打断：什么都不该发生
    func testInterruptWhileRestingDoesNothing() {
        store.save(.moon)
        let c = makeController()
        c.start()
        c.interrupt()
        XCTAssertEqual(c.phase, .resting(.moon))
    }

    // MARK: - 连续使用

    /// 连抛 100 次：每次的起始面都等于上一次的结果，存档始终跟得上。
    /// 这是在模拟真人反复抛掷，确认状态不会越用越乱。
    func testManyFlipsStayConsistent() {
        store.clear()
        let c = makeController()
        c.start()

        var previousFace = CoinFace.sun
        for i in 0..<100 {
            let plan = c.requestFlip(speed: Double.random(in: 0...4000))!
            XCTAssertEqual(plan.startFace, previousFace, "第 \(i + 1) 次的起始面不对")
            XCTAssertEqual(FlipPlanner.finalFace(of: plan), plan.result, "第 \(i + 1) 次显示面与结果不一致")
            c.finishFlip()
            XCTAssertEqual(c.phase, .resting(plan.result))
            XCTAssertEqual(store.load(), plan.result)
            previousFace = plan.result
        }
    }
}
