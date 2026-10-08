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
// 速度也是自己算的：取抬手前约 0.05 秒内的位移除以用时，
// 这样量到的是"甩出去那一下"的快慢，而不是整段拖动的平均速度。

import SwiftUI
import UIKit

struct SwipeCatcher: UIViewRepresentable {

    /// 手指每次抬起时调用，交出"一共移动了多少"和"抬手瞬间多快"。
    /// 算不算有效上划由调用方交给 SwipeDetector 判断，这里不做判断。
    var onDragEnded: (CGSize, CGSize) -> Void

    func makeUIView(context: Context) -> TouchTrackingView {
        let view = TouchTrackingView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true
        view.onDragEnded = onDragEnded
        return view
    }

    func updateUIView(_ uiView: TouchTrackingView, context: Context) {
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

    var onDragEnded: ((CGSize, CGSize) -> Void)?

    /// 算速度时往回看多久（秒）
    private let velocityWindow: TimeInterval = 0.05

    private var startPoint: CGPoint = .zero
    private var samples: [(point: CGPoint, time: TimeInterval)] = []

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        guard let touch = touches.first else { return }
        startPoint = touch.location(in: self)
        samples = [(startPoint, touch.timestamp)]
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        guard let touch = touches.first else { return }
        samples.append((touch.location(in: self), touch.timestamp))
        if samples.count > 40 { samples.removeFirst(samples.count - 40) }
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

        let translation = CGSize(width: endPoint.x - startPoint.x,
                                 height: endPoint.y - startPoint.y)

        // 找一个"抬手前约 0.05 秒"的位置作参照，算出最后那一下有多快
        var velocity = CGSize.zero
        let reference = samples.last { endTime - $0.time >= velocityWindow } ?? samples.first
        if let reference {
            let dt = endTime - reference.time
            if dt > 0.004 {
                velocity = CGSize(width: (endPoint.x - reference.point.x) / dt,
                                  height: (endPoint.y - reference.point.y) / dt)
            }
        }

        onDragEnded?(translation, velocity)
    }
}
