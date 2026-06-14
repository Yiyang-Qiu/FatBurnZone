import SwiftUI

/// 燃脂区间可视化表盘 — 紧凑弧形仪表盘，指针随心率丝滑动画
struct ZoneGaugeView: View {
    let heartRate: Double
    let zone: FatBurnZone

    private var maxDisplay: Double { zone.upperBound * 1.25 }
    private var pointerRatio: Double { min(max(heartRate / maxDisplay, 0), 1) }
    private var zoneStartRatio: Double { zone.lowerBound / maxDisplay }
    private var zoneEndRatio: Double { zone.upperBound / maxDisplay }

    private let totalArc = 270.0
    private let arcStart = 135.0

    var body: some View {
        ZStack {
            // 背景弧
            arcShape(from: 0, to: 1)
                .stroke(Color.gray.opacity(0.25), style: StrokeStyle(lineWidth: 5, lineCap: .round))

            // 燃脂区间绿色高亮
            arcShape(from: zoneStartRatio, to: zoneEndRatio)
                .stroke(Color.green, style: StrokeStyle(lineWidth: 6, lineCap: .round))

            // 指针 + 小球（旋转方式，支持平滑动画）
            GaugePointer(angle: gaugeAngle(pointerRatio))
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: pointerRatio)

            // 中心点
            Circle()
                .fill(Color.white.opacity(0.3))
                .frame(width: 4, height: 4)
        }
        .frame(width: 80, height: 80)
    }

    private func gaugeAngle(_ ratio: Double) -> Angle {
        .degrees(arcStart + totalArc * ratio)
    }

    private func arcShape(from: Double, to: Double) -> some Shape {
        ArcPath(startAngle: gaugeAngle(from), endAngle: gaugeAngle(to))
    }
}

// MARK: - 指针（线 + 小球，旋转动画）

private struct GaugePointer: View {
    let angle: Angle

    var body: some View {
        // 指针线从上往下：细线 + 端点小球
        VStack(spacing: 0) {
            // 小球
            Circle()
                .fill(Color.white)
                .frame(width: 7, height: 7)

            // 指针线
            Rectangle()
                .fill(Color.white)
                .frame(width: 2, height: 30)
        }
        .offset(y: -15) // 小球靠近弧线
        .rotationEffect(angle, anchor: .bottom)
    }
}

// MARK: - 弧形路径

private struct ArcPath: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2 - 6
        path.addArc(center: center, radius: radius,
                     startAngle: startAngle, endAngle: endAngle,
                     clockwise: false)
        return path
    }
}
