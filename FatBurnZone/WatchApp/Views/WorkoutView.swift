import SwiftUI

/// 锻炼主界面 — 两页滑动切换，内容适配手表屏幕不溢出
struct WorkoutView: View {
    @EnvironmentObject var viewModel: WorkoutViewModel

    @State private var selectedPage = 0

    /// 空燃脂区间占位（避免强制解包）
    private var zone: FatBurnZone {
        viewModel.fatBurnZone ?? FatBurnZone(lowerBound: 0, upperBound: 0)
    }

    var body: some View {
        TabView(selection: $selectedPage) {
            // ── 第 1 页：实时监测 ──
            monitorPage
                .tag(0)

            // ── 第 2 页：控制 & 摘要 ──
            controlPage
                .tag(1)
        }
        .tabViewStyle(.page)
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - 第 1 页：实时监测

    private var monitorPage: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            // 表盘
            ZoneGaugeView(heartRate: viewModel.heartRate, zone: zone)

            Spacer(minLength: 4)

            // 心率数字
            Text(viewModel.isWorkingOut ? "\(Int(viewModel.heartRate))" : "--")
                .font(.system(size: 50, weight: .bold, design: .rounded))
                .foregroundColor(heartRateColor)
                .animation(.easeInOut(duration: 0.3), value: viewModel.heartRate)

            Text("BPM")
                .font(.caption2)
                .foregroundColor(.secondary)

            Spacer(minLength: 4)

            // 卡路里 + 计时（同一行）
            if viewModel.isWorkingOut {
                HStack(spacing: 20) {
                    metricView(icon: "🔥", value: "\(Int(viewModel.activeCalories))", unit: "kcal", color: .orange)
                    metricView(icon: "⏱", value: formatted(viewModel.elapsedSeconds), unit: "", color: .white)
                }
                .padding(.vertical, 2)
            }

            // 状态横幅
            if viewModel.isWorkingOut {
                compactStatus
                    .padding(.horizontal, 12)
            } else if !viewModel.showSummary {
                Text("滑动至下一页开始")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 0)

            // 页指示器空间
            Color.clear.frame(height: 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 第 2 页：控制 & 摘要

    private var controlPage: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 0)

            // 摘要模式
            if viewModel.showSummary {
                summarySection
            } else {
                // 燃脂区间信息
                infoSection
            }

            Spacer(minLength: 0)

            // 按钮区
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
                // 开始/停止主按钮
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

            // 错误
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption2)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }

            Color.clear.frame(height: 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 16)
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

    // MARK: - 信息区

    private var infoSection: some View {
        VStack(spacing: 8) {
            Text("最佳燃脂区间")
                .font(.caption)
                .foregroundColor(.secondary)

            Text(viewModel.fatBurnZone?.formattedRange ?? "--")
                .font(.system(.title2, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(.green)

            if viewModel.isWorkingOut {
                VStack(spacing: 4) {
                    Text("🔥 \(Int(viewModel.activeCalories)) kcal")
                        .font(.caption)
                    Text("⏱ \(formatted(viewModel.elapsedSeconds))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - 紧凑状态条（极简风格）

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
                    .background(
                        Capsule()
                            .fill(tint.opacity(0.12))
                    )
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
                Text(unit)
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
            }
        }
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
