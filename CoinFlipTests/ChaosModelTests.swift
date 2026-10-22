// 猛摇手机时满屏乱撞（2026-10）。
//
// 守三条死规矩：
//   1. 不出画：硬币永远在镜头看得到的四条边以内
//   2. 不改结果：不管中间怎么翻，停稳时一定是原来那面朝上、平躺
//   3. 会停：不摇了几秒内一定躺下，交还给平常的样子

import XCTest
import simd
@testable import CoinFlip

final class ChaosModelTests: XCTestCase {

    private let dt: Float = 1.0 / 60

    /// 和画面里一样的镜头（远景）算出来的墙
    private func walls() -> [ChaosModel.Wall] {
        let e = CoinScene.elevationFar * .pi / 180
        let look = SIMD3<Float>(0, CoinScene.lookUpFar, 0)
        let cam = look + CoinScene.distanceFar * SIMD3<Float>(0, sin(e), cos(e))
        let f = simd_normalize(look - cam)
        let r = simd_normalize(simd_cross(f, [0, 1, 0]))
        let u = simd_cross(r, f)
        let tanV = tan(CoinScene.fieldOfView / 2 * .pi / 180)
        return ChaosModel.frustumWalls(camera: cam, forward: f, up: u, right: r,
                                       tanV: tanV, tanH: tanV * CoinScene.screenAspect)
    }

    private func make(kick: SIMD3<Float>, yaw: Float = 0) -> ChaosModel {
        ChaosModel(position: .zero, yaw: yaw, kick: kick,
                   radius: CoinScene.coinRadius, thickness: CoinScene.coinThickness,
                   walls: walls(), homeRadius: ShakeModel.maxOffset)
    }

    /// 固定种子的随机数，每次跑都一样
    private struct Seeded {
        var s: UInt64
        mutating func next() -> Float {
            s = s &* 6364136223846793005 &+ 1442695040888963407
            return Float(s >> 40) / Float(1 << 24)
        }
        mutating func range(_ a: Float, _ b: Float) -> Float { a + (b - a) * next() }
    }

    /// 各种摇法都走一遍：不出画、会翻、最后原来那面朝上躺平
    func testManyShakes() {
        var rng = Seeded(s: 7)
        let w = walls()
        for trial in 0..<40 {
            let shakeFor = rng.range(0.5, 3), freq = rng.range(2, 6), amp = rng.range(1.4, 3.5)
            let dir = simd_normalize(SIMD3<Float>(rng.range(-1, 1), rng.range(-1, 1), rng.range(-1, 1)))
            var m = make(kick: dir * 2, yaw: rng.range(0, 6))
            var t: Float = 0, highest: Float = 0, everFlipped = false
            while !m.isDone && t < 15 {
                let a = t < shakeFor ? dir * amp * sin(2 * .pi * freq * t) : .zero
                m.step(dt: dt, accel: a)
                t += dt
                highest = max(highest, m.position.y)
                if !m.faceUp { everFlipped = true }
                for wall in w {
                    XCTAssertGreaterThan(simd_dot(wall.normal, m.position) - wall.offset - m.radius, -0.02,
                                         "第 \(trial) 次：硬币撞出了屏幕边")
                }
            }
            XCTAssertTrue(m.isDone, "第 \(trial) 次：不摇了 \(t) 秒还没躺下")
            XCTAssertTrue(m.faceUp, "第 \(trial) 次：停下来换了一面")
            XCTAssertLessThan(m.tiltDegrees, 0.5, "第 \(trial) 次：没躺平")
            XCTAssertEqual(m.position.y, 0, accuracy: 1e-4)
            XCTAssertLessThanOrEqual(simd_length(SIMD2(m.position.x, m.position.z)), ShakeModel.maxOffset + 1e-4)
            XCTAssertGreaterThan(highest, 0.2, "第 \(trial) 次：撞得不够起劲")
            _ = everFlipped
        }
    }

    /// 乱撞时真的会翻过来（作者要的：躺的、立的都有）
    func testActuallyTumbles() {
        var flipped = 0
        for k in 0..<10 {
            let dir = simd_normalize(SIMD3<Float>(Float(k) - 4.5, 1, 0.5))
            var m = make(kick: dir * 2.5)
            var t: Float = 0, seen = false
            while !m.isDone && t < 15 {
                m.step(dt: dt, accel: t < 1.5 ? dir * 2.5 * sin(2 * .pi * 4 * t) : .zero)
                t += dt
                if !m.faceUp { seen = true }
            }
            if seen { flipped += 1 }
        }
        XCTAssertGreaterThanOrEqual(flipped, 5, "10 次猛摇只有 \(flipped) 次翻过面，不够乱")
    }

    /// ★ 跟得上手 ★（作者：猛摇时硬币跟不上）：每秒左右甩 5 下，硬币要从一边撞到另一边，
    /// 而且撞墙的次数要跟得上甩的次数
    func testKeepsUpWithFastShaking() {
        var m = make(kick: [2.5, 0, 0])
        var xs: [Float] = [], knocks = 0
        var t: Float = 0
        while t < 1.5 {
            m.step(dt: dt, accel: SIMD3<Float>(2.5, 0, 0) * sin(2 * .pi * 5 * t))
            t += dt
            xs.append(m.position.x)
            if m.impact > 0 { knocks += 1 }
        }
        XCTAssertGreaterThan((xs.max() ?? 0) - (xs.min() ?? 0), 0.7, "甩了半天硬币没从一边撞到另一边")
        XCTAssertGreaterThanOrEqual(knocks, 10, "1.5 秒甩了 7 个来回，只撞了 \(knocks) 下")
    }

    /// 撞到东西会报出声音的轻重，而且不会每帧都报
    func testKnocks() {
        var m = make(kick: [2.5, 1, 0])
        var knocks = 0, frames = 0
        var t: Float = 0
        while !m.isDone && t < 10 {
            m.step(dt: dt, accel: t < 1 ? SIMD3<Float>(3, 0, 0) * sin(2 * .pi * 5 * t) : .zero)
            t += dt; frames += 1
            if m.impact > 0 { knocks += 1; XCTAssertLessThanOrEqual(m.impact, 1) }
        }
        XCTAssertGreaterThan(knocks, 2)
        XCTAssertLessThan(Float(knocks), Float(frames) * 0.3)
    }
}
