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

    /// 自旋每转过一个刻度响一下的轻重。
    /// 它很密，所以要很轻——靠疏密表达转速，不靠轻重。
    static let spinTickIntensity: Float = 0.30

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

    // MARK: - 蓄力（2026-10）

    /// 蓄力每一格的轻重：最开头几乎摸不到，越往上拖越重。level 是 0~1。
    static func chargeIntensity(_ level: Float) -> Float {
        clamp((0.14 + 0.46 * pow(min(max(level, 0), 1), 1.3)) * gain)
    }

    /// 蓄力每一格的软硬：越往上越脆，像弹簧越拧越紧。
    static func chargeSharpness(_ level: Float) -> Float {
        clamp(0.50 + 0.35 * min(max(level, 0), 1))
    }

    /// 拖满那一下：明显重一截、偏沉，告诉手"到头了"
    static let chargeFullIntensity: Float = 0.85
    static let chargeFullSharpness: Float = 0.35

    /// 松手那一记：抛得越狠越重（force 是 0~1，按抛起高度算）
    static func releaseIntensity(_ force: Double) -> Float {
        clamp((tossIntensity + 0.45 * Float(min(max(force, 0), 1))) * gain)
    }
}

/// 蓄力的"刻度尺"（2026-10）。
///
/// 往上拖的距离被切成一格一格，每拖过新的一格，手上"嗒"一下，越往上越重；
/// 拖到 FlipPlanner.maxDistance（"划得远"这一项满分）时，重重地来一下"满了"。
///
/// 只认**拖到过的最高处**：手指往回缩再往上，不会把走过的格子再震一遍，
/// 免得手指一抖就嗒嗒乱响。
enum ChargeMeter {

    /// 一共几格（不含"满了"那一下）
    static let steps = 12

    /// 一格多长（点）
    static var stepDistance: Double { FlipPlanner.maxDistance / Double(steps) }

    /// 往上拖了 dragUp 点，到了第几格（0 ~ steps）
    static func step(dragUp: Double) -> Int {
        guard dragUp > 0 else { return 0 }
        // 先判"满了"，别让小数误差把正好拖满算成差一格
        if dragUp >= FlipPlanner.maxDistance { return steps }
        return min(Int(dragUp / stepDistance), steps - 1)
    }

    /// 第几格换算成 0~1
    static func level(step: Int) -> Float {
        Float(min(max(step, 0), steps)) / Float(steps)
    }
}

/// 负责把一次抛掷的磕碰表变成一串震动。
///
/// ⚠️ 所有方法都在主线程调用。
final class HapticPlayer {

    private var engine: CHHapticEngine?
    private var player: CHHapticPatternPlayer?
    /// 自旋刻度那一下。只搭一次，反复重启
    private var tickPlayer: CHHapticPatternPlayer?
    /// 蓄力每一格各一个播放器，第一次用到时才搭，之后反复重启。
    /// 键 0 ~ steps-1 是普通格，steps 是"满了"那一下。
    private var chargePlayers: [Int: CHHapticPatternPlayer] = [:]

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

        // 抛得多狠（0~1），按抛起高度算。松手那一记跟着它变重
        let force = StyleProfile.silver.heightLevel(plan.height)

        var events: [CHHapticEvent] = [
            // 脱手那一下：蓄完力松手，干脆地"啪"一记。抛得越狠越重（2026-10 蓄力）
            CHHapticEvent(eventType: .hapticTransient,
                          parameters: [
                            .init(parameterID: .hapticIntensity,
                                  value: HapticTuning.releaseIntensity(force)),
                            .init(parameterID: .hapticSharpness, value: 0.9)],
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

    /// 自旋转过一个刻度时响一下。
    ///
    /// 这一下会非常频繁（转得快时每秒十几次），所以播放器**只做一次**，
    /// 之后每次只是重新启动它——不能每次都现搭一个图案，那样主线程扛不住。
    func spinTick() {
        guard hasEngine else {
            simple.impactOccurred(intensity: 0.28)
            return
        }
        if tickPlayer == nil { tickPlayer = makeTickPlayer() }
        try? tickPlayer?.start(atTime: CHHapticTimeImmediate)
    }

    /// 自旋刻度用的那一下：很轻、很脆，像硬币边缘擦过桌面
    private func makeTickPlayer() -> CHHapticPatternPlayer? {
        guard let engine else { return nil }
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                .init(parameterID: .hapticIntensity,
                      value: HapticTuning.clamp(HapticTuning.spinTickIntensity * HapticTuning.gain)),
                .init(parameterID: .hapticSharpness, value: 0.95)],
            relativeTime: 0)
        guard let pattern = try? CHHapticPattern(events: [event], parameters: []) else { return nil }
        return try? engine.makePlayer(with: pattern)
    }

    /// 蓄力：拖到了第 step 格（step == ChargeMeter.steps 就是"满了"）。
    ///
    /// 和自旋刻度一样，播放器搭好就留着反复用，主线程只做一次"重启"。
    func chargeTick(step: Int) {
        let full = step >= ChargeMeter.steps
        let level = ChargeMeter.level(step: step)
        let intensity = full ? HapticTuning.chargeFullIntensity : HapticTuning.chargeIntensity(level)
        let sharpness = full ? HapticTuning.chargeFullSharpness : HapticTuning.chargeSharpness(level)

        guard hasEngine, let engine else {
            simple.impactOccurred(intensity: CGFloat(intensity))
            return
        }
        let key = min(max(step, 0), ChargeMeter.steps)
        if chargePlayers[key] == nil {
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [.init(parameterID: .hapticIntensity, value: intensity),
                             .init(parameterID: .hapticSharpness, value: sharpness)],
                relativeTime: 0)
            if let pattern = try? CHHapticPattern(events: [event], parameters: []) {
                chargePlayers[key] = try? engine.makePlayer(with: pattern)
            }
        }
        try? chargePlayers[key]?.start(atTime: CHHapticTimeImmediate)
    }

    /// 破纪录那一刻：沉甸甸的"咚咚"两下（2026-10 计数）。只搭一次，之后反复重启。
    private var recordPlayer: CHHapticPatternPlayer?

    func recordBroken() {
        guard hasEngine, let engine else {
            simple.impactOccurred(intensity: 1)
            return
        }
        if recordPlayer == nil {
            let hit = { (at: TimeInterval, i: Float) in
                CHHapticEvent(eventType: .hapticTransient,
                              parameters: [.init(parameterID: .hapticIntensity, value: i),
                                           .init(parameterID: .hapticSharpness, value: 0.4)],
                              relativeTime: at)
            }
            if let pattern = try? CHHapticPattern(events: [hit(0, 0.95), hit(0.09, 0.7)], parameters: []) {
                recordPlayer = try? engine.makePlayer(with: pattern)
            }
        }
        try? recordPlayer?.start(atTime: CHHapticTimeImmediate)
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
        tickPlayer = nil          // 引擎要停了，这个播放器也跟着作废
        chargePlayers.removeAll() // 同上
        recordPlayer = nil
        engine?.stop(completionHandler: nil)
    }
}
