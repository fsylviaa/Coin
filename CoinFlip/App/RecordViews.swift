// "记录"的界面：右上角的小图标 + 点开后的统计卡片。
//
// 小图标：照作者给的参考图，把 "Coin" 里的 o 换成一摞硬币（顶上一枚刻着一颗小星），
//        字是 iPhone 自带的无衬线体·常规。平时很淡（三成亮），按下时亮一下。
// 小卡片：字体用"无衬线·细"（作者选的 B），英文标签全大写、字距拉开。
//        底部那行"Coin: Luna"的字体不变（衬线体），这里不碰它。
//
// 两面叫"日面 / 月面"（SOL / LUNA），不叫"正 / 反"——需求规定不给两面预设含义。

import SwiftUI

// MARK: - 小图标

/// 右上角的 "C[一摞硬币]in"
struct RecordIcon: View {

    /// 字号。图标整体大小跟着它走。
    var size: CGFloat = 17

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 0) {
            Text("C")
            CoinStackGlyph()
                .frame(width: size * 0.76, height: size * 0.78)
                .padding(.horizontal, size * 0.02)
                // 硬币堆的底边比字的基线略低一点点，跟字母 o 一样"坐"在线上
                .alignmentGuide(.lastTextBaseline) { d in d.height - size * 0.06 }
            Text("in")
        }
        .font(.system(size: size, weight: .regular))
        .foregroundStyle(.white)
    }
}

/// 一摞四枚硬币，斜着看，顶上那枚中间一颗小星。
///
/// 硬币之间的缝、顶面的那圈边、小星，都是"挖空"的（透出后面的星空），
/// 不是涂黑——这样图标放在什么背景上都干净。
struct CoinStackGlyph: View {

    var body: some View {
        Canvas { ctx, size in
            // 设计稿坐标：横 -24…24，竖 -18…30（和给作者看的预览图同一套数）
            let k = min(size.width, size.height) / 48
            ctx.translateBy(x: size.width / 2, y: (size.height - 48 * k) / 2 + 18 * k)
            ctx.scaleBy(x: k, y: k)

            let rx: CGFloat = 22, ry: CGFloat = 8, thick: CGFloat = 6

            func ellipse(_ cy: CGFloat, _ a: CGFloat = rx, _ b: CGFloat = ry) -> Path {
                Path(ellipseIn: CGRect(x: -a, y: cy - b, width: a * 2, height: b * 2))
            }
            /// 一枚硬币的整个外形（顶面 + 侧边）
            func silhouette(_ cy: CGFloat) -> Path {
                var p = ellipse(cy)
                p.addPath(ellipse(cy + thick))
                p.addRect(CGRect(x: -rx, y: cy, width: rx * 2, height: thick))
                return p
            }
            /// 一枚硬币的轮廓线：顶面一圈 + 侧边两竖 + 底下半圈
            func outline(_ cy: CGFloat) -> Path {
                var p = ellipse(cy)
                p.move(to: CGPoint(x: -rx, y: cy))
                p.addLine(to: CGPoint(x: -rx, y: cy + thick))
                for i in 1...32 {
                    let a = Double.pi * Double(32 - i) / 32      // 从左边经过最下面到右边
                    p.addLine(to: CGPoint(x: rx * CGFloat(cos(a)), y: cy + thick + ry * CGFloat(sin(a))))
                }
                p.addLine(to: CGPoint(x: rx, y: cy))
                return p
            }

            // 从最下面一枚往上叠：先涂白，再沿轮廓挖一道缝
            for cy in [16, 8, 0, -8] as [CGFloat] {
                ctx.blendMode = .normal
                ctx.fill(silhouette(cy), with: .color(.white))
                ctx.blendMode = .destinationOut
                ctx.stroke(outline(cy), with: .color(.white), lineWidth: 2.2)
            }

            // 顶面那圈边、中间的小星，都挖空
            ctx.blendMode = .destinationOut
            ctx.stroke(ellipse(-8, 15, 5), with: .color(.white), lineWidth: 1.6)
            var star = Path()
            let pts: [(CGFloat, CGFloat)] = [(0, -12.5), (1.6, -8.6), (6, -8), (1.6, -7.4),
                                             (0, -3.5), (-1.6, -7.4), (-6, -8), (-1.6, -8.6)]
            star.move(to: CGPoint(x: pts[0].0, y: pts[0].1))
            for p in pts.dropFirst() { star.addLine(to: CGPoint(x: p.0, y: p.1)) }
            star.closeSubpath()
            ctx.fill(star, with: .color(.white))
        }
        .accessibilityHidden(true)
    }
}

/// 平时三成亮，按下时亮起来
struct RecordIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.8 : 0.35)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - 小卡片

struct RecordCard: View {

    let stats: FlipStats
    /// 现在几点（算"今天"用）
    let now: Date
    /// 用户确认清零
    var onReset: () -> Void

    @State private var confirming = false

    var body: some View {
        VStack(spacing: 0) {
            if stats.total == 0 { empty } else { content }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 28)
        .frame(width: 300)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color(red: 0.05, green: 0.06, blue: 0.10).opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
        )
        .foregroundStyle(.white)
        .confirmationDialog("清零所有记录？", isPresented: $confirming, titleVisibility: .visible) {
            Button("清零", role: .destructive) { onReset() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("清零后不能恢复。硬币现在朝上的那一面不受影响。")
        }
    }

    // ── 字体 B：无衬线·细 ──
    private func light(_ size: CGFloat) -> Font { .system(size: size, weight: .light) }

    /// 小标签：全大写、字距拉开、很淡
    private func tag(_ text: String) -> some View {
        Text(text)
            .font(light(11))
            .tracking(2.6)
            .opacity(0.42)
    }

    private var empty: some View {
        VStack(spacing: 10) {
            tag("RECORD")
            Text("还没有记录")
                .font(light(17))
                .opacity(0.75)
                .padding(.top, 8)
            Text("上划抛一次，就从这里开始")
                .font(light(12))
                .opacity(0.4)
        }
        .padding(.vertical, 12)
    }

    private var content: some View {
        let pct = stats.percents
        let share = Double(stats.sun) / Double(max(stats.total, 1))

        return VStack(spacing: 0) {
            tag("RECORD")

            // 总次数
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(stats.total.formatted())
                    .font(.system(size: 52, weight: .ultraLight))
                    .monospacedDigit()
                Text("次").font(light(14)).opacity(0.6)
            }
            .padding(.top, 6)

            // 日面 / 月面
            HStack(alignment: .bottom) {
                faceBlock("SOL · 日面", count: stats.sun, percent: pct.sun, alignment: .leading)
                Spacer()
                faceBlock("LUNA · 月面", count: stats.moon, percent: pct.moon, alignment: .trailing)
            }
            .padding(.top, 18)

            // 一根细条：左边日面占多少，右边月面占多少
            GeometryReader { g in
                HStack(spacing: 2) {
                    Capsule().fill(.white.opacity(0.75))
                        .frame(width: max(0, (g.size.width - 2) * share))
                    Capsule().fill(.white.opacity(0.2))
                }
            }
            .frame(height: 2)
            .padding(.top, 10)

            hairline

            VStack(spacing: 13) {
                row("当前连续", "\(faceName(stats.lastFace)) · \(stats.streak) 次")
                row("最长连续", "\(stats.longestStreak) 次")
                row("今天", "\(stats.today(now)) 次")
                row("转得最多的一抛", "\(FlipStats.turnsText(halfTurns: stats.maxHalfTurns)) 圈")
                row("一共翻了", "\(FlipStats.turnsText(halfTurns: stats.totalHalfTurns)) 圈")
                row("最快一划", "\(stats.maxSpeed.formatted())")
                row("最多连撞", "\(stats.maxChaosHits.formatted()) 下")
            }

            hairline

            HStack {
                Text(sinceText).font(light(12)).opacity(0.4)
                Spacer()
                Button { confirming = true } label: {
                    Text("清零")
                        .font(light(12))
                        .tracking(1.5)
                        .opacity(0.45)
                        .padding(.vertical, 6)
                        .padding(.leading, 12)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            // 作者署名（2026-10，作者定的写法）。
            // ★ 用 ©，不用 ® ★：® 只能用在已注册的商标上，没注册就用算冒充注册商标。
            //   年份是首次发布那年，以后不用年年改
            Text("© 2026 F·Sylvia")
                .font(light(10))
                .tracking(2)
                .opacity(0.22)
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
                .accessibilityLabel("版权所有 2026 F·Sylvia")
        }
    }

    private func faceBlock(_ label: String, count: Int, percent: Int,
                           alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            tag(label)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(count.formatted()).font(light(24)).monospacedDigit()
                Text("\(percent)%").font(light(13)).monospacedDigit().opacity(0.55)
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).opacity(0.55)
            Spacer()
            Text(value).monospacedDigit()
        }
        .font(light(14))
    }

    private var hairline: some View {
        Rectangle()
            .fill(.white.opacity(0.08))
            .frame(height: 0.5)
            .padding(.vertical, 18)
    }

    private func faceName(_ face: CoinFace?) -> String {
        switch face {
        case .sun:  return "日面"
        case .moon: return "月面"
        case nil:   return "—"
        }
    }

    private var sinceText: String {
        guard let first = stats.firstFlip else { return "" }
        let c = Calendar.current.dateComponents([.year, .month], from: first)
        return "从 \(c.year ?? 0) 年 \(c.month ?? 0) 月开始"
    }
}
