// 手势接收层。对应任务 T15。
//
// 一块铺满全屏的透明板，专门用来接手指的拖动。
//
// 为什么做得这么底层：
// 3D 画面（RealityView）会干扰触摸。我们先后试过 SwiftUI 的拖动手势、
// 系统的手势识别器，都收不到——它们都可能被别的手势"取消"掉。
// 所以这里直接处理最原始的触摸事件：手指按下、移动、抬起。
// 这是触摸能走到的最前面一层，几乎不可能被拦下。
//
// 速度也是自己算的，而且取的是**整个手势里最快的那一下**，不是抬手那一瞬间。
//
// 为什么：真人划屏幕时，手指常常在抬起前先慢下来——划到位、停一下、再松手。
// 只看抬手那一瞬间的话，速度接近 0，一次明明很用力的上划会被判成无效。
// 取峰值就贴合"你用了多大力气甩"这个真实意图。

import SwiftUI
import UIKit

/// 一次手势结束时量到的全部信息。
///
/// 两个速度都取整个手势里的峰值，而不是抬手那一瞬间——理由见下面的注释。
/// 分开量是因为上划和横拨是两件事：上划看竖直方向最快多少，横拨看水平方向。
struct DragOutcome: Equatable {
    /// 从按下到松开一共移动了多少（屏幕坐标：往上是负数）
    let translation: CGSize
    /// 整个手势里往上最快的那一下
    let upVelocity: CGSize
    /// 整个手势里横向最快的那一下（往右为正）
    let sideVelocity: CGSize
}

struct SwipeCatcher: UIViewRepresentable {

    /// 手指移动过程中持续调用，交出"从按下到现在一共移动了多少"。
    /// 硬币靠它实时跟着手指走，所以必须每一帧都报，不能等到松手。
    var onDragChanged: (CGSize) -> Void = { _ in }

    /// 手指抬起时调用，交出这一次手势量到的全部信息。
    /// 算不算上划、算不算横拨，由调用方交给 SwipeDetector 判断，这里不做判断。
    var onDragEnded: (DragOutcome) -> Void

    func makeUIView(context: Context) -> TouchTrackingView {
        let view = TouchTrackingView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true
        view.onDragChanged = onDragChanged
        view.onDragEnded = onDragEnded
        return view
    }

    func updateUIView(_ uiView: TouchTrackingView, context: Context) {
        uiView.onDragChanged = onDragChanged
        uiView.onDragEnded = onDragEnded
    }

    /// 明确告诉系统：外面给多大，这块板子就占多大。
    /// 不写这一段，板子会是 0×0，什么也接不到。
    func sizeThatFits(_ proposal: ProposedViewSize,
                      uiView: TouchTrackingView,
                      context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? UIScreen.main.bounds.width,
               height: proposal.height ?? UIScreen.main.bounds.height)
    }
}

/// 直接记录触摸的透明板
final class TouchTrackingView: UIView {

    var onDragChanged: ((CGSize) -> Void)?
    var onDragEnded: ((DragOutcome) -> Void)?

    /// 算一小段速度时，跨多长时间取样（秒）。
    /// 太短会被手抖放大，太长会把快慢抹平。
    private let velocitySpan: TimeInterval = 0.045

    private var startPoint: CGPoint = .zero
    private var samples: [(point: CGPoint, time: TimeInterval)] = []

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        guard let touch = touches.first else { return }
        startPoint = touch.location(in: self)
        samples = [(startPoint, touch.timestamp)]
        onDragChanged?(.zero)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)
        samples.append((point, touch.timestamp))
        if samples.count > 80 { samples.removeFirst(samples.count - 80) }

        // 实时上报，硬币才能跟着手指走
        onDragChanged?(CGSize(width: point.x - startPoint.x,
                              height: point.y - startPoint.y))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        finish(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        finish(touches)
    }

    private func finish(_ touches: Set<UITouch>) {
        defer { samples = [] }
        guard let touch = touches.first else { return }

        let endPoint = touch.location(in: self)
        let endTime = touch.timestamp
        samples.append((endPoint, endTime))

        let translation = CGSize(width: endPoint.x - startPoint.x,
                                 height: endPoint.y - startPoint.y)

        onDragChanged?(.zero)              // 手指离开，硬币不再被牵着
        onDragEnded?(DragOutcome(translation: translation,
                                 upVelocity: peakVelocity(.up),
                                 sideVelocity: peakVelocity(.side)))
    }

    private enum Axis { case up, side }

    /// 整个手势里某个方向上"最快的那一下"有多快。
    ///
    /// 做法是沿着记录下来的轨迹滑动一个小窗口，逐段算速度，取那个方向最快的一段。
    /// 这样无论你是划到底直接松手，还是先停一下再松，量到的都是你真正用的力气。
    ///
    /// 两个方向要分开取峰值：一次上划里横向可能在某一瞬间也很快（手抖），
    /// 合在一起取会互相污染。
    private func peakVelocity(_ axis: Axis) -> CGSize {
        guard samples.count >= 2 else { return .zero }

        var best = CGSize.zero
        var bestScore: CGFloat = 0

        for (i, later) in samples.enumerated() {
            // 往回找一个间隔够长的取样点作参照
            var j = i - 1
            while j > 0 && later.time - samples[j].time < velocitySpan { j -= 1 }
            guard j >= 0 else { continue }

            let earlier = samples[j]
            let dt = later.time - earlier.time
            guard dt > 0.004 else { continue }

            let v = CGSize(width: (later.point.x - earlier.point.x) / dt,
                           height: (later.point.y - earlier.point.y) / dt)
            // 屏幕坐标里往上是负的，所以越负越快；横向两个方向都算数
            let score = axis == .up ? -v.height : abs(v.width)
            if score > bestScore {
                bestScore = score
                best = v
            }
        }
        return best
    }
}
