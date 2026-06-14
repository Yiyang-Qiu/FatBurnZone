import SwiftUI

/// 根视图 — 根据设置状态展示 SetupView 或 WorkoutView
struct ContentView: View {
    @EnvironmentObject var viewModel: WorkoutViewModel

    var body: some View {
        Group {
            if viewModel.isSetupComplete {
                WorkoutView()
            } else {
                SetupView()
            }
        }
        .task {
            // 首次启动时自动请求 HealthKit 授权
            await viewModel.requestAuthorization()
        }
    }
}
