import SwiftUI

/// iOS 配套 App 入口 — 提供年龄设置和燃脂区间预览
@main
struct iOSApp: App {
    var body: some Scene {
        WindowGroup {
            SettingsView()
        }
    }
}
