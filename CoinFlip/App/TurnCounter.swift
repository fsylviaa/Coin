// 满屏乱撞时的计数：这一阵连着撞了几下（2026-10，作者要的）。
//
// 这套样子原来用在"抛的时候跳动的分数"上（后来分数换成了答案之书），作者要把它挪到这里：
//   • 硬币每撞一下（屏幕边或玻璃），数字跳一下
//   • 越过"最多连撞"纪录的那一刻：变成暖金色、放大一点、有一圈柔光，手上"咚咚"两下
//   • 这一阵停下来时：破了纪录就一道光从数字上扫过，背后荡开一圈细金环，停留得更久
//   • 第一次乱撞（还没有纪录）不算破纪录
//   • 升温（作者选的：不加 COMBO / PERFECT 这种字，让数字自己升温）：撞得越多越大、越亮、越暖；
//     过 10、25、50、100（之后每 100）这几关时，数字轻轻弹一下，手上一记重的，声音亮一点
// 只有数字，没有字。

import SwiftUI

struct TurnCounter: View {

    /// 显示的数字（"3.5"、"12"）
    let text: String
    /// 数字的大小，只用来让跳动时的滚动方向对（往上涨）
    let value: Double
    /// 这一抛已经超过旧纪录了
    let isRecord: Bool
    /// 破了纪录而且已经落地：放落地那一下的光
    let recordLanded: Bool
    /// 升温（0~1）：撞得越多越大、越亮、越暖（2026-10，作者选的"不加字，数字自己升温"）
    var heat: Double = 0
    /// 过关那一下轻轻弹一下（10、25、50、100……）
    var pulse: Bool = false

    /// 撞了 n 下，热到几成。前面升得快、后面慢：10 下已过一半，100 下满
    static func heat(hits n: Int) -> Double {
        guard n > 0 else { return 0 }
        return min(log(1 + Double(n)) / log(101), 1)
    }

    /// 过关的那几个数：10、25、50、100，之后每 100 一关
    static func isMilestone(_ n: Int) -> Bool {
        [10, 25, 50].contains(n) || (n >= 100 && n % 100 == 0)
    }

    static let gold = Color(red: 0.96, green: 0.86, blue: 0.64)

    var body: some View {
        ZStack {
            if recordLanded { RecordRing() }

            number
                .overlay {
                    if recordLanded {
                        Sweep().mask(number)
                    }
                }
        }
        .accessibilityElement()
        .accessibilityLabel(text + (isRecord ? "，新纪录" : ""))
    }

    private var number: some View {
        let h = min(max(heat, 0), 1)
        // 升温：从冷白慢慢暖成米色（金色留给破纪录）
        let warm = Color(red: 1.0, green: 1.0 - 0.07 * h, blue: 1.0 - 0.22 * h)
            .opacity(0.82 + 0.18 * h)
        let glow = isRecord ? Self.gold.opacity(0.55)
                            : Color(red: 1.0, green: 0.9, blue: 0.75).opacity(0.45 * h)
        return Text(text)
            .font(.system(size: 46, weight: .ultraLight))
            .monospacedDigit()
            .foregroundStyle(isRecord ? AnyShapeStyle(Self.gold) : AnyShapeStyle(warm))
            .shadow(color: glow, radius: isRecord ? 14 : 12 * h)
            .scaleEffect((isRecord ? 1.18 : 1 + 0.22 * h) * (pulse ? 1.16 : 1))
            .contentTransition(.numericText(value: value))
    }
}

/// 落地那一下：一道斜光从左扫到右，只扫一遍
private struct Sweep: View {
    @State private var x: CGFloat = -1

    var body: some View {
        GeometryReader { geo in
            LinearGradient(colors: [.clear, .white.opacity(0.9), .clear],
                           startPoint: .leading, endPoint: .trailing)
                .frame(width: geo.size.width * 0.45)
                .rotationEffect(.degrees(18))
                .offset(x: x * geo.size.width * 1.3)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.9)) { x = 1 }
        }
        .allowsHitTesting(false)
    }
}

/// 落地那一下：数字背后荡开一圈细金环，越荡越淡
private struct RecordRing: View {
    @State private var grow = false

    var body: some View {
        Circle()
            .stroke(TurnCounter.gold, lineWidth: 1)
            .frame(width: 40, height: 40)
            .scaleEffect(grow ? 4.2 : 0.6)
            .opacity(grow ? 0 : 0.8)
            .onAppear {
                withAnimation(.easeOut(duration: 1.2)) { grow = true }
            }
            .allowsHitTesting(false)
    }
}
