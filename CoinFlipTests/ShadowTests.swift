// 地面与阴影的自动测试。
//
// 守的是那条"灰边"的修法。来龙去脉见 FlipAnimatorTests 里的长注释：
// 硬币侧着飞过低空时，下缘必然穿过地面那张半透明平面——这是物理上躲不开的
// （半径 0.33 的硬币要翻身，圆心必须离地 0.33 以上，而轻抛只有 0.10）。
// 既然躲不开相交，就让它盖上去也看不出来。

import XCTest
import UIKit
@testable import CoinFlip

final class ShadowTests: XCTestCase {

    /// 银色币面大致的亮度
    private let coin: Double = 230

    // MARK: - 地面：亮色 + 低不透明度

    /// ★ 地面盖在硬币上时必须几乎看不出来。★
    ///
    /// 同样一团光，"暗色 + 高不透明度"和"亮色 + 低不透明度"在黑底上长得一样，
    /// 盖到明亮的硬币上却天差地别。这条测试量的就是后一种情况。
    func testGroundBarelyShowsWhenItCrossesTheCoin() throws {
        let (colour, alpha) = try groundCentre()

        let onCoin = colour * alpha + coin * (1 - alpha)
        XCTAssertLessThan(
            abs(onCoin - coin), 20,
            "地面盖在硬币上会留下一道差 \(Int(abs(onCoin - coin))) 的灰边。"
                + "把 ground_fade 的颜色调亮、peak 按比例调低，黑底上的观感不变")
    }

    /// 黑底上承托光的亮度要守住：太亮又成了一团白光（P02 作者删掉过），
    /// 太暗影子就没东西可压、又看不见了。
    ///
    /// P03 第二版定的是最亮通道约 33（第一版 56 作者嫌太白，原来的白色光晕约 80）。
    /// 中心带云絮纹理，所以留的余量大一些。
    /// 调亮颜色必须用降低不透明度来抵消，这个乘积才是眼睛看到的亮度。
    func testGroundGlowOnBlackIsUnchanged() throws {
        let (colour, alpha) = try groundCentre()

        XCTAssertEqual(colour * alpha, 33, accuracy: 20,
                       "黑底上的承托光亮度变了，影子的可见度和整体观感会跟着变")
    }

    /// 读出地面贴图正中心的颜色与不透明度（取最亮的通道）
    private func groundCentre() throws -> (colour: Double, alpha: Double) {
        let bundle = Bundle(for: ShadowTests.self)
        let url = try XCTUnwrap(
            Bundle.main.url(forResource: "ground_fade", withExtension: "png")
                ?? bundle.url(forResource: "ground_fade", withExtension: "png"),
            "找不到 ground_fade.png")
        let image = try XCTUnwrap(UIImage(contentsOfFile: url.path)?.cgImage)

        var pixel = [UInt8](repeating: 0, count: 4)
        let context = try XCTUnwrap(CGContext(
            data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        // 只取正中间那一个像素
        context.draw(image, in: CGRect(x: -CGFloat(image.width) / 2 + 0.5,
                                       y: -CGFloat(image.height) / 2 + 0.5,
                                       width: CGFloat(image.width),
                                       height: CGFloat(image.height)))

        let alpha = Double(pixel[3]) / 255
        guard alpha > 0 else { return (0, 0) }
        // 画出来的是预乘的，要除回去才是原色
        let colour = Double(max(pixel[0], max(pixel[1], pixel[2]))) / alpha
        return (colour, alpha)
    }

    // MARK: - 阴影：按倾角减淡

    /// 硬币侧得越厉害，阴影越淡——真硬币侧过来投的是一条线，不是一个圆。
    /// 这也正好让"躲不开的相交"发生在阴影最淡的时候。
    func testShadowFadesAsTheCoinTilts() {
        let flat = shadowOpacity(tilt: 0)
        let half = shadowOpacity(tilt: 45)
        let edge = shadowOpacity(tilt: 88)

        XCTAssertGreaterThan(flat, half, "侧过来阴影没有变淡")
        XCTAssertGreaterThan(half, edge, "快立起来了阴影还这么浓")
        XCTAssertLessThan(edge, flat * 0.1, "硬币快立起来时阴影该几乎没有了")
        XCTAssertLessThan(shadowOpacity(tilt: 60), flat * 0.35,
                          "侧到 60 度时阴影还太浓，穿过地面那下会很明显")
    }

    /// 躺平时阴影要足够浓，承托感全靠它
    func testFlatCoinKeepsItsShadow() {
        XCTAssertGreaterThan(shadowOpacity(tilt: 0), 0.5, "躺平了阴影还这么淡，硬币像浮着")
    }

    /// 贴地、某个倾角时阴影的浓度（和 GroundShadow.update 里算的是同一套）
    private func shadowOpacity(tilt: Float) -> Float {
        GroundShadow.restOpacity
            * pow(cos(tilt * .pi / 180), GroundShadow.tiltFade)
    }
}
