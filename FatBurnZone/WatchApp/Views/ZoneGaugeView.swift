import SwiftUI

/// 燃脂区间可视化表盘 — 弧形仪表盘
struct ZoneGaugeView: View {
    /// 当前心率 BPM
    let heartRate: Double

    /// 燃脂区间
    let zone: FatBurnZone

    /// 超过此值表盘不再延伸（最大心率的 90%）
    private var maxDisplayValue: Double {
        zone.upperBound * 1.3
    }

    /// 指针角度（0° 在顶部偏左，总弧度 ~270°）
    private var pointerAngle: Angle {
        let ratio = min(heartRate / maxDisplayValue, 1.0)
        // 转换为 135° ~ 405°（即从 7 点位置顺时针到 5 点位置）
        let degrees = 135 + ratio * 270
        return .degrees(degrees)
    }

    /// 燃脂区间在表盘上的起止角度
    private var zoneStartAngle: Angle {
        let ratio = zone.lowerBound / maxDisplayValue
        return .degrees(135 + ratio * 270)
    }

    private var zoneEndAngle: Angle {
        let ratio = zone.upperBound / maxDisplayValue
        return .degrees(135 + ratio * 270)
    }

    var body: some View {
        ZStack {
            // 背景弧线（满刻度）
            ArcShape(startAngle: .degrees(135), endAngle: .degrees(405))
                .stroke(
                    Color.gray.opacity(0.2),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )

            // 燃脂区间高亮弧线（绿色）
            ArcShape(startAngle: zoneStartAngle, endAngle: zoneEndAngle)
                .stroke(
                    Color.green,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )

            // 指针
            Circle()
                .fill(Color.white)
                .frame(width: 8, height: 8)
                .offset(y: -38) // 在弧形内侧
                .rotationEffect(pointerAngle, anchor: .center)
        }
        .frame(width: 100, height: 100)
    }
}

/// 自定义弧形路径
private struct ArcShape: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2 - 4

        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        return path
    }
}
