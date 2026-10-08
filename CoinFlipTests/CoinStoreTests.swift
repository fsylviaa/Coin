// 本机存储的自动测试（任务 T11）。
//
// 每个测试都用一个独立的临时抽屉，跑完就清掉，
// 不会影响你自己玩 App 时存下的结果。

import XCTest
@testable import CoinFlip

final class CoinStoreTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!
    private var store: CoinStore!

    override func setUp() {
        super.setUp()
        suiteName = "CoinStoreTests-\(UUID().uuidString)"
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

    /// 什么都没存过时，读出来是空的（代表"从没抛过"）
    func testEmptyLoadsNil() {
        store.clear()
        XCTAssertNil(store.load())
    }

    /// 存月面，读出来还是月面
    func testSaveMoonLoadsMoon() {
        store.save(.moon)
        XCTAssertEqual(store.load(), .moon)
    }

    /// 新结果覆盖旧结果，不会攒成一个列表
    func testOverwrite() {
        store.save(.moon)
        store.save(.sun)
        XCTAssertEqual(store.load(), .sun)
    }

    /// 存了之后再清空，又回到"从没抛过"
    func testClearRemovesResult() {
        store.save(.sun)
        store.clear()
        XCTAssertNil(store.load())
    }

    /// 两个 CoinStore 读的是同一个抽屉。
    /// 这模拟"关掉 App 再打开"——新开的那次能读到上次存的结果。
    func testPersistsAcrossInstances() {
        CoinStore(defaults: defaults).save(.moon)
        XCTAssertEqual(CoinStore(defaults: defaults).load(), .moon)
    }

    /// 抽屉里混进了看不懂的内容时，当作"从没抛过"，而不是崩溃。
    func testCorruptedValueLoadsNil() {
        defaults.set("banana", forKey: "lastResult")
        XCTAssertNil(store.load())
    }
}
