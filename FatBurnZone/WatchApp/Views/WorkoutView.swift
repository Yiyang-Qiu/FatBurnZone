import SwiftUI

/// 锻炼主界面
struct WorkoutView: View {
    @EnvironmentObject var viewModel: WorkoutViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // 燃脂区间标签
                if let zone = viewModel.fatBurnZone {
                    Text("燃脂区间 \(zone.formattedRange)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // 实时心率 + 表盘
                ZoneGaugeView(
                    heartRate: viewModel.heartRate,
                    zone: viewModel.fatBurnZone ?? FatBurnZone(
                        lowerBound: 0,
                        upperBound: 0
                    )
                )
                .padding(.vertical, 4)

                // 心率数字
                VStack(spacing: 2) {
                    Text(
                        viewModel.isWorkingOut
                            ? "\(Int(viewModel.heartRate))"
                            : "--"
                    )
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundColor(heartRateColor)

                    Text("BPM")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    if !viewModel.isWorkingOut && viewModel.heartRate == 0 {
                        Text("点击下方按钮开始监测")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                // 状态提示
                if viewModel.isWorkingOut {
                    statusBanner
                        .padding(.horizontal, 8)
                }

                // 开始/停止按钮
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

                // 错误提示
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

    // MARK: - 颜色

    private var heartRateColor: Color {
        switch viewModel.zoneStatus {
        case .inZone:
            return .green
        case .below:
            return .blue
        case .above:
            return .red
        }
    }

    private var statusBannerColor: Color {
        switch viewModel.zoneStatus {
        case .inZone:
            return .green
        case .below:
            return .blue
        case .above:
            return .red
        }
    }
}
