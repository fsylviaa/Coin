// 读手机的动作感应器（P13）。
//
// 不弹授权窗：系统只对"运动与健身"那类数据要授权，这里读的是设备姿态和加速度。
//
// ★ 用"拉"的方式读，不用回调。★
//   每帧在画面线程里问一句"现在是多少"，不让感应器从另一条线程往这边推数据。
//   以前把震动挪到后台线程反而更卡过（§2.5），这里不冒这个险。
//
// ★ 以"平常拿着的样子"为平。★ 人拿手机本来就是斜的（往后仰着看屏幕），
//   不能把这个当成坡，否则硬币永远往下滑。这里维护一个很慢才跟上的"平常姿态"，
//   硬币只对偏离它的那部分有反应。
//
// 切到后台就停，回来再开——不在后台白白耗电。模拟器没有感应器，读数恒为 0。

import CoreMotion
import UIKit
import simd

final class ShakeSensor {

    /// "平常姿态"跟上新姿态要多久（秒）。
    ///
    /// 要很慢：慢慢歪过去时，硬币得一直感到这个坡、一路滑下去。
    /// 第一版是 1.2 秒，歪着不动一会儿坡就"没了"，加上回中的弹簧，作者看着像飘。
    /// 现在 8 秒：换个姿势拿手机，过一阵才会被当成新的"平"；
    /// 而硬币没有回中的弹簧，坡没了它也只是停在原地。
    static let baselineSeconds: Double = 8

    private let manager = CMMotionManager()
    private var baseline: SIMD3<Double>?
    private var observers: [NSObjectProtocol] = []

    init() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: UIApplication.didEnterBackgroundNotification,
                                            object: nil, queue: .main) { [weak self] _ in self?.stop() })
        observers.append(center.addObserver(forName: UIApplication.willEnterForegroundNotification,
                                            object: nil, queue: .main) { [weak self] _ in self?.start() })
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
        manager.stopDeviceMotionUpdates()
    }

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 60
        manager.startDeviceMotionUpdates()
        baseline = nil
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        baseline = nil
    }

    struct Reading {
        /// 相对平常姿态歪了多少（重力的变化，单位 g；x 往右、y 往屏幕上方）
        var tilt = SIMD2<Float>(0, 0)
        /// 晃动加速度（单位 g）
        var jerk = SIMD3<Float>(0, 0, 0)
        /// 平常姿态和现在姿态下的重力方向（手机坐标），给水平仪用
        var baselineDown = SIMD3<Float>(0, -1, 0)
        var currentDown = SIMD3<Float>(0, -1, 0)
    }

    /// 这一刻的读数。没有感应器时（模拟器）全是"没歪、没晃"
    func read(dt: Double) -> Reading {
        guard let motion = manager.deviceMotion else { return Reading() }
        let g = SIMD3<Double>(motion.gravity.x, motion.gravity.y, motion.gravity.z)
        if baseline == nil { baseline = g }
        let k = 1 - exp(-dt / Self.baselineSeconds)
        baseline! += (g - baseline!) * k
        let d = g - baseline!
        let a = motion.userAcceleration
        let b = baseline!
        return Reading(tilt: SIMD2<Float>(Float(d.x), Float(d.y)),
                       jerk: SIMD3<Float>(Float(a.x), Float(a.y), Float(a.z)),
                       baselineDown: SIMD3<Float>(Float(b.x), Float(b.y), Float(b.z)),
                       currentDown: SIMD3<Float>(Float(g.x), Float(g.y), Float(g.z)))
    }
}
