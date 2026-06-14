import SwiftUI

/// 首次设置页 — 年龄获取/输入
struct SetupView: View {
    @EnvironmentObject var viewModel: WorkoutViewModel

    /// 手动输入的年龄
    @State private var manualAge: Double = 30
    @State private var isFetchingFromHealthKit = false
    @State private var healthKitAge: Int? = nil
    @State private var showManualInput = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 标题
                Text("燃脂心率")
                    .font(.title3)
                    .fontWeight(.bold)

                Text("设置您的年龄以计算最佳燃脂区间")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Divider()

                // 方式 1：从 HealthKit 获取
                Button {
                    Task { await fetchFromHealthKit() }
                } label: {
                    HStack {
                        Image(systemName: "heart.circle.fill")
                            .foregroundColor(.red)
                        Text("从健康 App 获取年龄")
                    }
                }
                .disabled(isFetchingFromHealthKit)

                if isFetchingFromHealthKit {
                    ProgressView()
                }

                // HealthKit 获取成功
                if let age = healthKitAge {
                    VStack(spacing: 8) {
                        Text("已获取年龄：\(age) 岁")
                            .foregroundColor(.green)
                            .font(.headline)

                        Button("确认并开始") {
                            viewModel.saveProfile(age: age, source: .healthKit)
                        }
                    }
                }

                Divider()
                    .padding(.vertical, 4)

                // 方式 2：手动输入
                if !showManualInput {
                    Button("手动输入年龄") {
                        withAnimation { showManualInput = true }
                    }
                }

                if showManualInput {
                    VStack(spacing: 8) {
                        Text("年龄：\(Int(manualAge)) 岁")
                            .font(.headline)

                        Slider(value: $manualAge, in: 10...90, step: 1)
                            .tint(.blue)

                        Button("确认") {
                            viewModel.saveProfile(
                                age: Int(manualAge),
                                source: .manual
                            )
                        }
                    }
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
        }
    }

    // MARK: - 从 HealthKit 获取年龄

    private func fetchFromHealthKit() async {
        isFetchingFromHealthKit = true

        // 先确保已授权
        await viewModel.requestAuthorization()

        // 尝试获取年龄
        if let age = await viewModel.fetchAgeFromHealthKit() {
            healthKitAge = age
        } else {
            // HealthKit 无出生日期，显示手动输入
            withAnimation { showManualInput = true }
            viewModel.errorMessage = "未在健康 App 中找到出生日期，请手动输入"
        }

        isFetchingFromHealthKit = false
    }
}
