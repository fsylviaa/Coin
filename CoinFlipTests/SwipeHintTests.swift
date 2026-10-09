// 首次上划引导的自动测试。
//
// 守的是两件事：
//   ① **只在第一次**。界面上没有按钮也没有文字，新用户需要这一下提示；
//      但老用户每次打开都看一遍提示，就从"体贴"变成"啰嗦"了。
//   ② 引导的动作要和真正要做的动作一致，而且会自己结束，不会一直演下去。

import XCTest
@testable import CoinFlip

final class SwipeHintTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!
    private var store: CoinStore!

    override func setUp() {
        super.setUp()
        suiteName = "SwipeHintTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        store = CoinStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        store = nil; defaults = nil; suiteName = nil
        super.tearDown()
    }

    // MARK: - 只放一次

    /// 新装的 App：第一次打开要放引导
    func testHintShowsOnFirstLaunch() {
        let controller = CoinController(store: store)
        controller.start()
        XCTAssertTrue(controller.showsHint, "新装的 App 没有放引导，新用户不知道要上划")
    }

    /// 成功抛过一次之后，再打开就不该放了——哪怕 App 完全重启
    func testHintNeverShowsAgain() {
        let first = CoinController(store: store)
        first.start()
        first.requestFlip(speed: 1200, distance: 120)

        let second = CoinController(store: store)
        second.start()
        XCTAssertFalse(second.showsHint, "学会之后还在放，每次打开都要看一遍")
    }

    /// ★ 没学会之前不能收。★
    /// 只是打开看看、碰两下但没抛成功，下次打开引导还得在。
    func testHintStaysUntilFirstSuccessfulFlip() {
        let first = CoinController(store: store)
        first.start()
        XCTAssertTrue(first.showsHint)

        let second = CoinController(store: store)
        second.start()
        XCTAssertTrue(second.showsHint, "还没抛成功过，引导就不该收走")
    }

    /// 自己动手抛了一次，就说明已经会了，引导不用再放
    func testFlippingCountsAsLearned() {
        let controller = CoinController(store: store)
        controller.start()
        controller.requestFlip(speed: 1200, distance: 120)
        XCTAssertFalse(controller.showsHint, "已经会抛了还要放引导")

        let next = CoinController(store: store)
        next.start()
        XCTAssertFalse(next.showsHint, "会抛之后重启，引导又回来了")
    }

    /// 已经抛过的老用户，重装前的记录还在时不该再被提示
    func testReturningUserSeesNoHint() {
        store.markHintSeen()
        let controller = CoinController(store: store)
        controller.start()
        XCTAssertFalse(controller.showsHint)
    }

    // MARK: - 引导动作本身

    /// 开头先静一会儿，让人看清这是一枚静止的硬币
    func testStartsStill() {
        XCTAssertEqual(CoinSceneView.hintLift(elapsed: 0), 0, accuracy: 1e-6)
        XCTAssertEqual(CoinSceneView.hintLift(elapsed: CoinScene.hintDelay - 0.01),
                       0, accuracy: 1e-6)
    }

    /// ★ 不会自己停。★ 放到第一百次、第五分钟，它还在邀请。
    /// 收不收由大脑决定——成功抛出第一次才收。
    func testKeepsInvitingForever() {
        let peakAt = CoinScene.hintDelay + CoinScene.hintUpSeconds
        for k in [0, 1, 2, 10, 50, 200] {
            let t = peakAt + CoinScene.hintCycle * Double(k)
            XCTAssertGreaterThan(
                CoinSceneView.hintLift(elapsed: t),
                CoinScene.maxDragLift * CoinScene.hintRise * 0.9,
                "第 \(k + 1) 次邀请没了，用户还没学会就把提示收走了")
        }
    }

    /// 提起的高度是"邀请"，不能高到看着像在自己抛
    func testNeverLiftsTooHigh() {
        let ceiling = CoinScene.maxDragLift * CoinScene.hintRise + 1e-5
        for i in 0...3000 {
            let lift = CoinSceneView.hintLift(elapsed: Double(i) / 100)
            XCTAssertGreaterThanOrEqual(lift, 0)
            XCTAssertLessThanOrEqual(lift, ceiling, "引导把硬币提得太高了")
        }
    }

    /// 每一次都真的提起来过，而且每两次之间都回到平面上
    func testEachPulseRisesAndReturns() {
        for k in 0..<6 {
            let base = CoinScene.hintDelay + CoinScene.hintCycle * Double(k)

            XCTAssertGreaterThan(
                CoinSceneView.hintLift(elapsed: base + CoinScene.hintUpSeconds),
                CoinScene.maxDragLift * CoinScene.hintRise * 0.9,
                "第 \(k + 1) 次没有真的提起来")

            XCTAssertEqual(
                CoinSceneView.hintLift(elapsed: base + CoinScene.hintCycle - 0.01),
                0, accuracy: 1e-5,
                "第 \(k + 1) 次之后没有落回平面")
        }
    }
}
