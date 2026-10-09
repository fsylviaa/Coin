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

/// ⚠️ 所有方法都必须在主线程调用（手势回调和排队用的都是主线程，天然满足）。
///    但真正发声的那几步会被转到后台队列上去做，不占用画面线程。
final class FeedbackPlayer {

    /// 同时最多叠几声。
    ///
    /// 落地音本身有 0.95 秒的余韵，而磕碰最密时每 50 毫秒就来一下——
    /// 轮到某个播放器时它多半还在响。给一个正在响的播放器做跳转重置，
    /// 是主线程上的一次慢操作，这就是停稳前那阵卡顿的来源之一。
    /// 所以备足一次抛掷用得到的数量，让每一下都能拿到闲着的播放器。
    private static let voiceCount = 14

    /// 落地与磕碰用的播放器，轮流使用
    private var landPlayers: [AVAudioPlayer] = []
    private var nextVoice = 0

    /// 抛起那一声，只需要一个
    private var tossPlayer: AVAudioPlayer?

    /// 已经排好队、还没响的磕碰。切后台时要全部取消。
    private var pending: [DispatchWorkItem] = []

    /// 震动。整串磕碰是一次性排给它的，不占画面线程。
    private let haptics = HapticPlayer()

    /// 这一次的震动排进引擎了吗。没排成功（老机型、模拟器）就一下一下地补。
    private var hapticsScheduled = false

    /// 放声音专用的队列。
    ///
    /// ★ 声音绝不能在主线程上放。★ 主线程同时也是画面线程，
    /// 一次 play 里夹着文件跳转，就会让这一帧画不完。
    /// 磕碰最密的时候一帧里要放好几声，画面直接就卡住了。
    /// 串行队列保证这些操作按顺序执行，不会互相打架。
    private let audioQueue = DispatchQueue(label: "com.antheafsy.coinflip.audio",
                                           qos: .userInitiated)

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

    /// 手指一开始往上带就调用，让震动器提前热身，免得第一下迟到。
    func warmUp() {
        haptics.warmUp()
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

        // 震动整串一次性排给引擎，由它按时间自己播，主线程不用再管。
        // 排不进去（模拟器、老机型）就退回"每下磕碰补一次"。
        hapticsScheduled = haptics.play(plan,
                                        elapsed: Date().timeIntervalSince(startedAt))

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
        // 震动已经整串排好了就别再补，否则会震两遍
        if !hapticsScheduled { haptics.simpleTap(strength: strength) }
    }

    /// 抛起的那一声。抛得越高，弹得越响。
    private func playToss(force: Double) {
        guard let player = tossPlayer else { return }
        let style = StyleProfile.silver
        let span = max(style.maxHeight - style.minHeight, 0.0001)
        let t = min(max((force - style.minHeight) / span, 0), 1)

        audioQueue.async {
            player.currentTime = 0
            player.volume = Float(0.45 + 0.55 * t)
            player.play()
        }
    }

    private func playSound(volume: Float) {
        guard !landPlayers.isEmpty else { return }
        let players = landPlayers
        let start = nextVoice
        nextVoice += 1

        audioQueue.async {
            // 优先挑一个已经响完的，这样就不必做跳转重置
            let count = players.count
            var chosen = players[start % count]
            for k in 0..<count {
                let candidate = players[(start + k) % count]
                if !candidate.isPlaying { chosen = candidate; break }
            }
            if chosen.isPlaying || chosen.currentTime > 0 { chosen.currentTime = 0 }
            // 太轻的磕碰听不见也无妨，但不要是 0，否则后面几下整段消失
            chosen.volume = max(volume, 0.02)
            chosen.play()
        }
    }

    // MARK: - 中断

    /// 立刻停声、取消还没响的磕碰。切后台或被来电打断时调用。
    func stopAll() {
        cancelPending()
        haptics.stopAll()
        hapticsScheduled = false
        let players = landPlayers + [tossPlayer].compactMap { $0 }
        audioQueue.async {
            for player in players where player.isPlaying {
                player.stop()
                player.currentTime = 0
            }
        }
    }

    private func cancelPending() {
        for work in pending { work.cancel() }
        pending.removeAll()
    }
}
