import SwiftUI

/// 锻炼主界面 — 两页滑动切换，每页支持表冠/触屏滚动
struct WorkoutView: View {
    @EnvironmentObject var viewModel: WorkoutViewModel
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    @State private var selectedPage = 0

    private var zone: FatBurnZone {
        viewModel.fatBurnZone ?? FatBurnZone(lowerBound: 0, upperBound: 0)
    }

    var body: some View {
        TabView(selection: $selectedPage) {
            monitorPage.tag(0)
            controlPage.tag(1)
        }
        .tabViewStyle(.page)
        .ignoresSafeArea(edges: .bottom)
        .animation(.easeInOut(duration: 0.4), value: isLuminanceReduced)
    }

    // MARK: - 第 1 页：实时监测

    private var monitorPage: some View {
        ScrollView {
            VStack(spacing: 8) {
                // 表盘
                ZoneGaugeView(heartRate: viewModel.heartRate, zone: zone)

                // 心率数字
                Text(displayHeartRate)
                    .font(.system(size: isLuminanceReduced ? 64 : 50,
                                  weight: .bold, design: .rounded))
                    .foregroundColor(isLuminanceReduced ? .white : heartRateColor)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.heartRate)
                    .contentTransition(.numericText())

                // 熄屏时只保留表盘 + 心率数字，隐藏其余元素
                if !isLuminanceReduced {
                    Text("BPM")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    if viewModel.isWorkingOut {
                        HStack(spacing: 20) {
                            metricView(icon: "🔥", value: "\(Int(viewModel.activeCalories))", unit: "kcal", color: .orange)
                            metricView(icon: "⏱", value: formatted(viewModel.elapsedSeconds), unit: "", color: .white)
                        }
                    }

                    if viewModel.isWorkingOut {
                        compactStatus
                            .padding(.horizontal, 8)
                    } else if !viewModel.showSummary {
                        Text("← 滑动至下一页开始 →")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - 第 2 页：控制 & 摘要

    private var controlPage: some View {
        ScrollView {
            VStack(spacing: 12) {
                // 摘要 / 信息
                if viewModel.showSummary {
                    summarySection
                } else {
                    infoSection
                }

                // 按钮
                if viewModel.showSummary {
                    Button {
                        viewModel.startWorkout()
                        selectedPage = 0
                    } label: {
                        Label("重新开始", systemImage: "arrow.clockwise.circle.fill")
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)

                    Button {
                        viewModel.dismissSummary()
                    } label: {
                        Text("完成")
                            .font(.caption)
                    }
                } else {
                    Button {
                        if viewModel.isWorkingOut {
                            viewModel.stopWorkout()
                        } else {
                            viewModel.startWorkout()
                            selectedPage = 0
                        }
                    } label: {
                        Label(
                            viewModel.isWorkingOut ? "停止锻炼" : "开始锻炼",
                            systemImage: viewModel.isWorkingOut ? "stop.circle.fill" : "play.circle.fill"
                        )
                        .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(viewModel.isWorkingOut ? .red : .green)
                }

                // 错误提示 — 始终可见，不会被遮挡
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption2)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - 摘要区

    private var summarySection: some View {
        VStack(spacing: 8) {
            Text("🏁 锻炼完成")
                .font(.headline)

            HStack {
                Text("总消耗").font(.caption).foregroundColor(.secondary)
                Spacer()
                Text("\(Int(viewModel.totalCalories))").font(.title3).fontWeight(.bold).foregroundColor(.orange)
                + Text(" kcal").font(.caption).foregroundColor(.secondary)
            }

            HStack {
                Text("时长").font(.caption).foregroundColor(.secondary)
                Spacer()
                Text(formatted(viewModel.elapsedSeconds)).font(.body).fontWeight(.medium)
            }

            HStack {
                Text("燃脂区间").font(.caption).foregroundColor(.secondary)
                Spacer()
                Text(viewModel.fatBurnZone?.formattedRange ?? "--").font(.caption)
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.12))
        .cornerRadius(12)
    }

    // MARK: - 信息区（公式 & 区间）

    private var infoSection: some View {
        VStack(spacing: 8) {
            if let profile = viewModel.userProfile {
                HStack {
                    Text("年龄").font(.caption2).foregroundColor(.secondary)
                    Spacer()
                    Text("\(profile.age) 岁").font(.caption2)
                }

                HStack {
                    Text("最大心率").font(.caption2).foregroundColor(.secondary)
                    Spacer()
                    Text("220 - \(profile.age) = \(220 - profile.age)").font(.caption2)
                }
                .padding(.bottom, 2)
            }

            Text("燃脂区间 \(viewModel.fatBurnZone?.formattedRange ?? "--")")
                .font(.system(.title3, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(.green)

            Text("最大心率 × 60% ~ 70%")
                .font(.system(size: 9))
                .foregroundColor(.secondary)

            if viewModel.isWorkingOut {
                Divider()
                HStack(spacing: 16) {
                    Text("🔥 \(Int(viewModel.activeCalories)) kcal").font(.caption)
                    Text("⏱ \(formatted(viewModel.elapsedSeconds))").font(.caption)
                }
            }

            Divider()
            Button {
                viewModel.resetProfile()
            } label: {
                Text("重新设置年龄")
                    .font(.caption2)
            }
        }
    }

    // MARK: - 紧凑状态条

    private var compactStatus: some View {
        let (label, tint): (String, Color) = {
            if let message = viewModel.alertMessage {
                return (message, alertBannerColor)
            } else if viewModel.zoneStatus == .inZone {
                return ("燃脂最佳", .green)
            } else {
                return ("", .clear)
            }
        }()

        return Group {
            if !label.isEmpty {
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(tint)
                    .padding(.vertical, 3)
                    .padding(.horizontal, 10)
                    .background(Capsule().fill(tint.opacity(0.12)))
            }
        }
    }

    // MARK: - 辅助组件

    private func metricView(icon: String, value: String, unit: String, color: Color) -> some View {
        HStack(spacing: 2) {
            Text(icon)
            Text(value)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(color)
            if !unit.isEmpty {
                Text(unit).font(.system(size: 8)).foregroundColor(.secondary)
            }
        }
    }

    // MARK: - 格式化 & 计算

    private var displayHeartRate: String {
        if viewModel.isWorkingOut && viewModel.heartRate > 0 { return "\(Int(viewModel.heartRate))" }
        if viewModel.isWorkingOut { return "···" }
        return "--"
    }

    private func formatted(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - 颜色

    private var heartRateColor: Color {
        switch viewModel.zoneStatus {
        case .inZone: return .green
        case .below: return .orange
        case .above: return .red
        }
    }

    private var alertBannerColor: Color {
        switch viewModel.zoneStatus {
        case .inZone: return .green
        case .below: return .orange
        case .above: return .red
        }
    }
}
