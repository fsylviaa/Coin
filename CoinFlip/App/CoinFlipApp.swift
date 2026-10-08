// App 入口：启动后显示的第一个画面。
// 目前只是全屏黑色背景；开发版底部有一行灰色小字，用来确认脚手架运行成功。
// 正式版（Release）不会显示这行字。

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
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            #if DEBUG
            VStack {
                Spacer()
                Text("CoinFlip 脚手架运行成功")
                    .font(.footnote)
                    .foregroundStyle(.gray)
                    .padding(.bottom, 24)
            }
            #endif
        }
        .statusBarHidden(true)
    }
}
