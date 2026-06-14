import SwiftUI

/// 锻炼主界面
struct WorkoutView: View {
    @EnvironmentObject var viewModel: WorkoutViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                // MARK: - 锻炼结束摘要

                if viewModel.showSummary {
                    summaryCard
                }

                // MARK: - 燃脂区间标签

                if let zone = viewModel.fatBurnZone {
                    Text("燃脂区间 \(zone.formattedRange)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // MARK: - 实时心率表盘

                ZoneGaugeView(
                    heartRate: viewModel.heartRate,
                    zone: viewModel.fatBurnZone ?? FatBurnZone(
                        lowerBound: 0,
                        upperBound: 0
                    )
                )
                .padding(.vertical, 4)

                // MARK: - 心率数字

                VStack(spacing: 2) {
                    Text(
                        viewModel.isWorkingOut
                            ? "\(Int(viewModel.heartRate))"
                            : "--"
                    )
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(heartRateColor)

                    Text("BPM")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // MARK: - 锻炼指标行：卡路里 + 时长

                if viewModel.isWorkingOut {
                    HStack(spacing: 16) {
                        // 卡路里
                        metricLabel(
                            icon: "🔥",
                            value: "\(Int(viewModel.activeCalories))",
                            unit: "kcal",
                            color: .orange
                        )
                        // 时长
                        metricLabel(
                            icon: "⏱",
                            value: formattedElapsed(viewModel.elapsedSeconds),
                            unit: "",
                            color: .white
                        )
                    }
                }

                // MARK: - 状态提示

                if viewModel.isWorkingOut {
                    statusBanner
                        .padding(.horizontal, 4)
                }

                // MARK: - 按钮

                if !viewModel.showSummary {
                    Button {
                        if viewModel.isWorkingOut {
                            viewModel.stopWorkout()
                        } else {
                            viewModel.startWorkout()
                        }
                    } label: {
                        Label(
                            viewModel.isWorkingOut ? "停止" : "开始锻炼",
                            systemImage: viewModel.isWorkingOut
                                ? "stop.circle.fill" : "play.circle.fill"
                        )
                        .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(viewModel.isWorkingOut ? .red : .green)
                }

                if viewModel.showSummary {
                    Button {
                        viewModel.startWorkout()
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
                }

                // MARK: - 错误提示

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption2)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .padding()
        }
    }

    // MARK: - 锻炼摘要卡片

    @ViewBuilder
    private var summaryCard: some View {
        VStack(spacing: 6) {
            Text("🏁 锻炼完成")
                .font(.headline)

            HStack {
                Text("总消耗")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(viewModel.totalCalories))")
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
                    + Text(" kcal")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("时长")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(formattedElapsed(viewModel.elapsedSeconds))
                    .font(.body)
                    .fontWeight(.medium)
            }

            HStack {
                Text("燃脂区间")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(viewModel.fatBurnZone?.formattedRange ?? "--")
                    .font(.caption)
            }
            .padding(.bottom, 4)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - 指标标签

    private func metricLabel(
        icon: String,
        value: String,
        unit: String,
        color: Color
    ) -> some View {
        HStack(spacing: 2) {
            Text(icon)
            Text(value)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(color)
            if !unit.isEmpty {
                Text(unit)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - 状态横幅

    @ViewBuilder
    private var statusBanner: some View {
        if let message = viewModel.alertMessage {
            Text(message)
                .font(.caption)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .padding(8)
                .frame(maxWidth: .infinity)
                .background(statusBannerColor.opacity(0.15))
                .cornerRadius(8)
        } else if viewModel.zoneStatus == .inZone && viewModel.isWorkingOut {
            Text("🟢 燃脂最佳状态")
                .font(.caption)
                .fontWeight(.medium)
                .padding(8)
                .frame(maxWidth: .infinity)
                .background(Color.green.opacity(0.15))
                .cornerRadius(8)
        }
    }

    // MARK: - 格式化

    private func formattedElapsed(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let mins = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", mins, secs)
    }

    // MARK: - 颜色

    private var heartRateColor: Color {
        switch viewModel.zoneStatus {
        case .inZone: return .green
        case .below: return .blue
        case .above: return .red
        }
    }

    private var statusBannerColor: Color {
        switch viewModel.zoneStatus {
        case .inZone: return .green
        case .below: return .blue
        case .above: return .red
        }
    }
}
