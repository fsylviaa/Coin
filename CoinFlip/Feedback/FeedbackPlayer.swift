// 声音与震动。对应任务 T19、T20。
//
// 一次抛掷有两种声音：
//   • 脱手那一声"叮"，余韵很长，硬币升到高处时它还在响
//   • 落地那一下，以及之后越来越轻、越来越密的磕碰，连起来是"嗒嗒嗒"
//
// ⚠️ 这里不写死任何秒数，全部从 FlipPlan 取（技术文档第 3 号坑）。
//    改了抛掷高度，声音会自动跟着对上。

import AVFoundation
import UIKit

/// ⚠️ 所有方法都必须在主线程调用。手势回调和排队用的都是主线程，所以天然满足。
final class FeedbackPlayer {

    /// 同时最多叠几声。磕碰很密，一声没完下一声就来了，
    /// 所以准备好几个播放器轮流用，不然会互相打断。
    private static let voiceCount = 5

    /// 落地与磕碰用的播放器，轮流使用
    private var landPlayers: [AVAudioPlayer] = []
    private var nextVoice = 0

    /// 抛起那一声，只需要一个
    private var tossPlayer: AVAudioPlayer?

    /// 已经排好队、还没响的磕碰。切后台时要全部取消。
    private var pending: [DispatchWorkItem] = []

    private let impact = UIImpactFeedbackGenerator(style: .rigid)

    // MARK: - 准备

    init() {
        configureAudioSession()
        loadPlayers()
    }

    /// 音频类别设为 ambient：
    ///   • 静音键打开时自动不出声（需求要求遵循系统静音）
    ///   • 不会打断用户正在听的音乐
    /// ⚠️ 千万别改成 playback，那样静音键会失效（技术文档第 9 号坑）。
    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [])
        try? session.setActive(true)
    }

    /// 启动时就把音效读进内存并预热。
    /// 不这么做的话，第一次抛掷的声音会迟到半拍（技术文档第 4 号坑）。
    private func loadPlayers() {
        let style = StyleProfile.silver

        if let url = Bundle.main.url(forResource: style.landSound, withExtension: "wav") {
            for _ in 0..<Self.voiceCount {
                guard let player = try? AVAudioPlayer(contentsOf: url) else { continue }
                player.prepareToPlay()
                landPlayers.append(player)
            }
        }

        if let url = Bundle.main.url(forResource: style.tossSound, withExtension: "wav"),
           let player = try? AVAudioPlayer(contentsOf: url) {
            player.prepareToPlay()
            tossPlayer = player
        }
    }

    /// 上划的瞬间调用，让震动器提前热身，免得第一下迟到。
    func warmUp() {
        impact.prepare()
    }

    // MARK: - 按时间表播放

    /// 收到一张时间表，就把这一次所有的磕碰排进队列。
    ///
    /// - Parameters:
    ///   - plan: 这一次抛掷的时间表
    ///   - startedAt: 脱手的时刻。已经过去的磕碰会被跳过。
    func schedule(_ plan: FlipPlan, startedAt: Date) {
        cancelPending()

        // 脱手那一声。余韵很长，硬币升到高处时它还在响。
        playToss(force: plan.height)

        for contact in plan.contacts {
            let delay = contact.time - Date().timeIntervalSince(startedAt)
            let strength = contact.strength

            if delay <= 0 {
                fire(strength: strength)
                continue
            }
            let work = DispatchWorkItem { [weak self] in self?.fire(strength: strength) }
            pending.append(work)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        }
    }

    /// 响一下。轻重由这次磕碰的强度决定。
    private func fire(strength: Double) {
        playSound(volume: Float(strength))
        playHaptic(strength: strength)
    }

    /// 抛起的那一声。抛得越高，弹得越响。
    private func playToss(force: Double) {
        guard let player = tossPlayer else { return }
        let style = StyleProfile.silver
        let span = max(style.maxHeight - style.minHeight, 0.0001)
        let t = min(max((force - style.minHeight) / span, 0), 1)

        player.currentTime = 0
        player.volume = Float(0.45 + 0.55 * t)
        player.play()
    }

    private func playSound(volume: Float) {
        guard !landPlayers.isEmpty else { return }
        let player = landPlayers[nextVoice % landPlayers.count]
        nextVoice += 1

        player.currentTime = 0
        // 太轻的磕碰听不见也无妨，但不要是 0，否则后面几下整段消失
        player.volume = max(volume, 0.02)
        player.play()
    }

    /// 震动。太轻的磕碰就不震了——手感上分辨不出来，只会糊成一片。
    private func playHaptic(strength: Double) {
        guard strength >= 0.12 else { return }
        impact.impactOccurred(intensity: CGFloat(min(strength, 1)))
        impact.prepare()
    }

    // MARK: - 中断

    /// 立刻停声、取消还没响的磕碰。切后台或被来电打断时调用。
    func stopAll() {
        cancelPending()
        for player in landPlayers + [tossPlayer].compactMap({ $0 })
        where player.isPlaying {
            player.stop()
            player.currentTime = 0
        }
    }

    private func cancelPending() {
        for work in pending { work.cancel() }
        pending.removeAll()
    }
}
