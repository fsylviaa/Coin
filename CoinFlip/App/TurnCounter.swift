// 这一抛转了几圈（2026-10，作者要的"抛的同时数字就跳"）。
//
// 抛出去那一刻从 0 开始，硬币每翻过半圈跳 0.5，落地那一下停在最后的数。
// 停稳后一会儿淡掉。只有数字，没有字。
//
// 破纪录（这一抛超过了以前"转得最多的一抛"）时，特效不一样：
//   • 数字在空中越过旧纪录的那一刻：变成暖金色、放大一点、有一圈柔光，手上"咚咚"两下
//   • 落地那一刻：一道光从数字上扫过，背后荡开一圈细金环
//   • 停留得更久
// 第一次抛（还没有纪录）不算破纪录。
//
// ★ 数字跟着硬币实际翻过的角度走，落地之前不会到最后一个数，不会比硬币先把结果露出来。★

import SwiftUI

struct TurnCounter: View {

    /// 已经翻了几个半圈
    let halfTurns: Int
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
        .accessibilityLabel("转了 \(FlipStats.turnsText(halfTurns: halfTurns)) 圈"
                            + (isRecord ? "，新纪录" : ""))
    }

    private var number: some View {
        Text(FlipStats.turnsText(halfTurns: halfTurns))
            .font(.system(size: 46, weight: .ultraLight))
            .monospacedDigit()
            .foregroundStyle(isRecord ? Self.gold : Color.white.opacity(0.82))
            .shadow(color: isRecord ? Self.gold.opacity(0.55) : .clear, radius: isRecord ? 14 : 0)
            .scaleEffect(isRecord ? 1.18 : 1)
            .contentTransition(.numericText(value: Double(halfTurns)))
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
