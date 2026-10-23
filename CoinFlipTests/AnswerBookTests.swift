// 答案之书（2026-10）。

import XCTest
@testable import CoinFlip

final class AnswerBookTests: XCTestCase {

    /// 每一句都中英成对、不空、够短（一眼读完），而且不重复
    func testEntries() {
        XCTAssertGreaterThanOrEqual(AnswerBook.all.count, 400)
        var seen = Set<String>()
        for a in AnswerBook.all {
            XCTAssertFalse(a.zh.isEmpty); XCTAssertFalse(a.en.isEmpty)
            XCTAssertLessThanOrEqual(a.zh.count, 14, "太长：\(a.zh)")
            XCTAssertLessThanOrEqual(a.en.count, 44, "太长：\(a.en)")
            XCTAssertTrue(seen.insert(a.zh).inserted, "重复：\(a.zh)")
        }
    }

    /// 翻完一整副牌之前不会重复；换下一副时，第一张不会正好是上一张
    func testDeckDoesNotRepeat() {
        var deck = AnswerBook.Deck()
        var rng = SystemRandomNumberGenerator()
        var last: Answer?
        for _ in 0..<3 {
            var round = Set<String>()
            for _ in 0..<AnswerBook.all.count {
                let a = deck.draw(using: &rng)
                XCTAssertTrue(round.insert(a.zh).inserted, "一副牌还没翻完就重复了")
                XCTAssertNotEqual(a, last, "连着两次同一句")
                last = a
            }
        }
    }
}
