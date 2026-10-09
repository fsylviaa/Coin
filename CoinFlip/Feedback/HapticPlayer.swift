// 震动。对应任务 T20，这一版换成了系统的精细震动引擎。
//
// 为什么不用原来那套简易震动（UIImpactFeedbackGenerator）：
// 它只有"轻重"一个旋钮，而且强度低于 0.3 左右基本就摸不出来了。
// 一次抛掷里有十一下磕碰，强度从 1.0 一路衰到 0.002，
// 用简易震动的结果就是——只感觉到落地那一记，后面整串是空的。
//
// 精细震动（Core Haptics）多一个旋钮：**软硬**。
//     落地  重而软：沉甸甸的一记，像硬币砸在桌上
//     磕碰  轻而硬：脆的一串，像边缘在桌面上磕
// 两者手感完全不同，整串就有层次了，而不是一团模糊的嗡嗡。
//
// 还有一个附带好处：整串震动是**一次性排给系统**的，
// 由震动引擎自己按时间播放。不像原来那样每一下都要主线程醒过来干活，
// 所以它再密也不会影响画面。
//
// ⚠️ 模拟器和很老的机型没有这套引擎，所以必须留退路：
//    检测不到就退回简易震动，App 不能因此崩溃或者整个没震动。

import CoreHaptics
import UIKit

/// 震感的调节旋钮。T23 调手感时主要改这里。
enum HapticTuning {

    /// 总强度倍数。觉得整体太轻或太重，**先调这一个**。
    /// 1.0 是标准，1.3 偏重，0.7 偏轻。超过 1.0 的部分会被系统截断，
    /// 所以调到 1.5 以上基本不会再有变化。
    static let gain: Float = 1.0

    /// 最轻的一下也至少有这么强。
    /// 这是让"嗒嗒嗒"那串能被摸到的关键——真按原始强度来，后面七下是 0。
    static let floor: Float = 0.32

    /// 强度曲线的弯曲程度。越小，弱的磕碰被抬得越高、整串越平均；
    /// 越大，落地和磕碰的轻重差别越明显。
    static let curve: Float = 0.6

    /// 落地那一记后面跟的闷响有多长（秒）。它提供"重量感"。
    static let thudSeconds: Double = 0.09
    /// 闷响的强弱
    static let thudIntensity: Float = 0.55

    /// 脱手那一下的轻点提示
    static let tossIntensity: Float = 0.45

    /// 比这还轻的磕碰就不震了，免得糊成一片
    static let minStrength: Double = 0.02

    // MARK: - 强度映射

    /// 把磕碰强度换算成震动的轻重。
    ///
    /// 不是直接拿来用——原始强度后面七下都在 0.1 以下，照搬等于没震。
    /// 这里把弱的一端整体抬起来（floor），再用一条曲线保留轻重的层次，
    /// 这样整串既摸得到，又还是一路衰下去的。
    static func intensity(for strength: Double) -> Float {
        let s = Float(min(max(strength, 0), 1))
        return clamp((floor + (1 - floor) * pow(s, curve)) * gain)
    }

    /// 软硬。重的一下偏软（沉），轻的一下偏硬（脆）。
    /// 这是两种手感能被分辨出来的关键，比单纯调轻重有用得多。
    static func sharpness(for strength: Double) -> Float {
        clamp(0.98 - 0.42 * Float(min(max(strength, 0), 1)))
    }

    static func clamp(_ v: Float) -> Float { min(max(v, 0), 1) }
}

/// 负责把一次抛掷的磕碰表变成一串震动。
///
/// ⚠️ 所有方法都在主线程调用。
final class HapticPlayer {

    private var engine: CHHapticEngine?
    private var player: CHHapticPatternPlayer?

    /// 这台设备有没有精细震动引擎。没有就用下面这个简易的顶上。
    private let hasEngine = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    private let simple = UIImpactFeedbackGenerator(style: .rigid)

    init() {
        guard hasEngine else { return }
        engine = try? CHHapticEngine()
        engine?.playsHapticsOnly = true
        // 引擎被系统收走时（比如来电）自动恢复，不然之后就一直没震动了
        engine?.resetHandler = { [weak self] in _ = try? self?.engine?.start() }
        engine?.stoppedHandler = { _ in }
    }

    // MARK: - 预热

    /// 手指一开始动就调。启动引擎要花几毫秒，提前做掉，
    /// 免得落地那一刻才启动、第一下迟到。
    func warmUp() {
        if hasEngine {
            // 用异步的那个版本：启动引擎要花几毫秒，
            // 同步调会卡在手指按下那一帧上，刚修好的流畅度不能在这儿丢回去。
            engine?.start(completionHandler: nil)
        } else {
            simple.prepare()
        }
    }

    // MARK: - 播放

    /// 把这一次所有的磕碰一次性排给震动引擎。
    ///
    /// - Returns: 排成功了没有。返回 false 时调用方要自己一下一下地震。
    @discardableResult
    func play(_ plan: FlipPlan, elapsed: TimeInterval) -> Bool {
        guard hasEngine, let engine else { return false }

        var events: [CHHapticEvent] = [
            // 脱手那一下轻点，让"扔出去了"这件事有个回应
            CHHapticEvent(eventType: .hapticTransient,
                          parameters: [
                            .init(parameterID: .hapticIntensity,
                                  value: HapticTuning.clamp(HapticTuning.tossIntensity * HapticTuning.gain)),
                            .init(parameterID: .hapticSharpness, value: 0.85)],
                          relativeTime: 0)
        ]

        for contact in plan.contacts where contact.strength >= HapticTuning.minStrength {
            let at = contact.time - elapsed
            guard at > 0 else { continue }

            events.append(CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    .init(parameterID: .hapticIntensity, value: HapticTuning.intensity(for: contact.strength)),
                    .init(parameterID: .hapticSharpness, value: HapticTuning.sharpness(for: contact.strength))],
                relativeTime: at))

            // 落地那一记后面再跟一段短促的闷响，手上才有"重"的感觉。
            // 只有最重的那下值得加，磕碰加了只会糊。
            if contact.strength > 0.8 {
                events.append(CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        .init(parameterID: .hapticIntensity,
                              value: HapticTuning.clamp(HapticTuning.thudIntensity * HapticTuning.gain)),
                        .init(parameterID: .hapticSharpness, value: 0.15)],
                    relativeTime: at,
                    duration: HapticTuning.thudSeconds))
            }
        }

        guard let pattern = try? CHHapticPattern(events: events, parameters: []),
              let made = try? engine.makePlayer(with: pattern),
              (try? made.start(atTime: CHHapticTimeImmediate)) != nil
        else { return false }

        player = made
        return true
    }

    /// 没有精细震动引擎时，调用方每到一下磕碰就调一次这个。
    func simpleTap(strength: Double) {
        guard strength >= 0.12 else { return }    // 简易震动太轻了根本摸不出来
        simple.impactOccurred(intensity: CGFloat(HapticTuning.intensity(for: strength)))
    }

    // MARK: - 中断

    /// 切后台或被来电打断：立刻停掉还没震完的部分。
    func stopAll() {
        try? player?.stop(atTime: CHHapticTimeImmediate)
        player = nil
        engine?.stop(completionHandler: nil)
    }
}
