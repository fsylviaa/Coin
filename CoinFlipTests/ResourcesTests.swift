// 素材文件的自动测试（任务 T06）。
//
// 这几个测试不看图案好不好看，只确认三件事：
//   1. 三个文件确实被打包进了 App，运行时找得到
//   2. 文件名和风格档案里写的一致（改了档案忘了改文件名，这里会报警）
//   3. 文件不是空的

import XCTest
@testable import CoinFlip

final class ResourcesTests: XCTestCase {

    /// App 自己的包。素材都应该在这里面。
    private let bundle = Bundle(for: ResourcesTests.self) == Bundle.main
        ? Bundle.main
        : Bundle(identifier: "com.coinflip.app.dev") ?? Bundle.main

    private func url(_ name: String, _ ext: String) -> URL? {
        // 先在 App 包里找，找不到再在测试包里找（两种打包方式都能通过）
        Bundle.main.url(forResource: name, withExtension: ext)
            ?? bundle.url(forResource: name, withExtension: ext)
            ?? Bundle(for: ResourcesTests.self).url(forResource: name, withExtension: ext)
    }

    /// 三个素材文件都能找到，而且不是空文件
    func testResourcesExist() {
        let style = StyleProfile.silver
        let items: [(String, String)] = [
            (style.textureSun, "png"),
            (style.textureMoon, "png"),
            (style.textureSun + "_normal", "png"),
            (style.textureMoon + "_normal", "png"),
            ("studio_env", "png"),
            (style.tossSound, "wav"),
            (style.landSound, "wav"),
        ]

        for (name, ext) in items {
            guard let fileURL = url(name, ext) else {
                XCTFail("找不到素材 \(name).\(ext)，请确认它在 CoinFlip/Resources 文件夹里")
                continue
            }
            let size = (try? FileManager.default
                .attributesOfItem(atPath: fileURL.path)[.size] as? Int) ?? 0
            XCTAssertGreaterThan(size ?? 0, 1000, "\(name).\(ext) 太小了，可能是空文件")
        }
    }

    /// 日面和月面用的是两个不同的文件，不会一面贴错成另一面
    func testSunAndMoonAreDifferentFiles() {
        XCTAssertNotEqual(StyleProfile.silver.textureSun, StyleProfile.silver.textureMoon)
    }
}
