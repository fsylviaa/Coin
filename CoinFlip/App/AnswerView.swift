// 落定时浮出的那句答案（2026-10，作者要的"答案之书"）。
//
// 上面一行中文，下面一行小字英文。
// 出现：快落定时淡淡浮出来（作者定的）。
// 消失：停留一会儿后，★ 像被火烧出很多小洞一样 ★（作者原话）——
//   字面上冒出一个个小洞，洞边一圈暗橙色的火光，洞越烧越大、越来越多，直到整句话没了。
//   开了"减少动态效果"就只是淡出（在 CoinFlipApp 里处理）。

import SwiftUI

struct AnswerView: View {

    let answer: Answer
    /// 开始烧的时刻；nil 表示还没开始烧
    let burnStart: Date?
    /// 烧多久（秒）。被下一抛提前打断时烧得快一些
    var burnSeconds: Double = 1.4

    var body: some View {
        // "减少动态效果"开着时不烧，外面直接淡出（见 CoinFlipApp）
        if let start = burnStart {
            TimelineView(.animation) { context in
                let t = min(max(context.date.timeIntervalSince(start) / burnSeconds, 0), 1)
                BurnedText(content: text, progress: t, seed: answer.zh)
            }
        } else {
            text
        }
    }

    private var text: some View {
        VStack(spacing: 8) {
            Text(answer.zh)
                .font(.system(size: 21, weight: .light))
                .tracking(3)
                .foregroundStyle(.white.opacity(0.88))
            Text(answer.en)
                .font(.system(size: 12, weight: .regular, design: .serif))
                .italic()
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.45))
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: 300)
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
}

/// 烧到 progress（0~1）时的样子
private struct BurnedText<Content: View>: View {
    let content: Content
    let progress: Double
    let seed: String

    var body: some View {
        let holes = Self.holes(seed: seed)
        content
            // 洞：从字上挖掉
            .mask {
                Canvas { ctx, size in
                    ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
                    ctx.blendMode = .destinationOut
                    for h in holes {
                        let r = h.radius(at: progress)
                        guard r > 0 else { continue }
                        let c = CGPoint(x: h.x * size.width, y: h.y * size.height)
                        // 两三个圆叠在一起，洞的边才是不规则的，像烧的而不是打孔
                        for (dx, dy, k) in h.lobes {
                            let rr = r * k
                            ctx.fill(Path(ellipseIn: CGRect(x: c.x + dx * r - rr, y: c.y + dy * r - rr,
                                                            width: rr * 2, height: rr * 2)),
                                     with: .color(.white))
                        }
                    }
                }
            }
            // 火光：洞边一圈暗橙色，只亮在还没烧掉的字上
            .overlay {
                Canvas { ctx, size in
                    ctx.addFilter(.blur(radius: 1.6))
                    for h in holes {
                        let r = h.radius(at: progress)
                        guard r > 0, r < h.maxRadius * 0.98 else { continue }
                        let c = CGPoint(x: h.x * size.width, y: h.y * size.height)
                        let rr = r + 2.2
                        ctx.stroke(Path(ellipseIn: CGRect(x: c.x - rr, y: c.y - rr, width: rr * 2, height: rr * 2)),
                                   with: .color(Color(red: 1.0, green: 0.52, blue: 0.18).opacity(0.95)),
                                   lineWidth: 2.4)
                    }
                }
                .mask(content)
                .blendMode(.plusLighter)
            }
            // 最后一小段整体再淡一下，保证烧得干干净净
            .opacity(progress < 0.82 ? 1 : max(0, 1 - (progress - 0.82) / 0.18))
    }

    /// 一个洞：在哪、什么时候开始烧、最大多大
    struct Hole {
        let x: Double, y: Double
        let birth: Double          // 0~1，什么时候冒出来
        let maxRadius: Double      // 点
        let lobes: [(Double, Double, Double)]

        func radius(at p: Double) -> Double {
            let life = (p - birth) / 0.45
            guard life > 0 else { return 0 }
            let e = min(life, 1)
            return maxRadius * (1 - pow(1 - e, 2))
        }
    }

    /// 同一句话每次烧的样子一样（按这句话本身定种子），不同的话不一样
    static func holes(seed: String) -> [Hole] {
        var s: UInt64 = 1469598103934665603
        for b in seed.utf8 { s = (s ^ UInt64(b)) &* 1099511628211 }
        func next() -> Double {
            s = s &* 6364136223846793005 &+ 1442695040888963407
            return Double(s >> 11) / Double(1 << 53)
        }
        return (0..<64).map { _ in
            Hole(x: next(), y: next(),
                 birth: pow(next(), 1.6) * 0.55,      // 先零星几个，后面越来越多
                 maxRadius: 9 + next() * 18,
                 lobes: [(0, 0, 1),
                         (next() - 0.5, next() - 0.5, 0.55 + next() * 0.3),
                         (next() - 0.5, next() - 0.5, 0.4 + next() * 0.3)])
        }
    }
}
