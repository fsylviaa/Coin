// App 入口。
//
// 目前（T13）只做一件事：全屏黑底，中央显示一枚静止的银币。
// 上划、声音、震动在后面的任务里加。

import SwiftUI

@main
struct CoinFlipApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {

    /// T13 暂时写死显示日面。
    /// T14 会换成由 CoinController 决定，这里就不再写死了。
    private let face: CoinFace = .sun

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CoinSceneView(face: face)
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
    }
}
