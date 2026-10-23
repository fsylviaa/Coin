// 满屏乱撞时的计数：这一阵连着撞了几下（2026-10，作者要的）。
//
// 这套样子原来用在"抛的时候跳动的分数"上（后来分数换成了答案之书），作者要把它挪到这里：
//   • 硬币每撞一下（屏幕边或玻璃），数字跳一下
//   • 越过"最多连撞"纪录的那一刻：变成暖金色、放大一点、有一圈柔光，手上"咚咚"两下
//   • 这一阵停下来时：破了纪录就一道光从数字上扫过，背后荡开一圈细金环，停留得更久
//   • 第一次乱撞（还没有纪录）不算破纪录
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
        Text(text)
            .font(.system(size: 46, weight: .ultraLight))
            .monospacedDigit()
            .foregroundStyle(isRecord ? Self.gold : Color.white.opacity(0.82))
            .shadow(color: isRecord ? Self.gold.opacity(0.55) : .clear, radius: isRecord ? 14 : 0)
            .scaleEffect(isRecord ? 1.18 : 1)
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
