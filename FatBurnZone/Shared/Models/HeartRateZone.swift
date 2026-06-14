import Foundation

/// 当前心率所处的燃脂区间状态
enum HeartRateZoneStatus: String, Codable {
    /// 低于最佳燃脂区间 — 运动强度不够
    case below
    /// 处于最佳燃脂区间 — 脂肪燃烧效率最高
    case inZone
    /// 高于最佳燃脂区间 — 运动强度过大
    case above
}

/// 燃脂区间计算结果
struct FatBurnZone {
    /// 区间下限 BPM（60% 最大心率）
    let lowerBound: Double
    /// 区间上限 BPM（70% 最大心率）
    let upperBound: Double

    /// 判断给离心率是否在区间内
    func status(for heartRate: Double) -> HeartRateZoneStatus {
        if heartRate < lowerBound {
            return .below
        } else if heartRate > upperBound {
            return .above
        } else {
            return .inZone
        }
    }

    /// 格式化的区间描述，例如 "120 - 140 BPM"
    var formattedRange: String {
        "\(Int(lowerBound)) – \(Int(upperBound)) BPM"
    }
}
