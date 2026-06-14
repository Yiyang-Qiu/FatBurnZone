import Foundation
import HealthKit

/// 心率区间计算器
enum HeartRateZoneCalculator {

    /// 计算最大心率：220 - 年龄
    static func maxHeartRate(age: Int) -> Int {
        AppConstants.maxHeartRateFormulaBase - age
    }

    /// 计算燃脂区间
    static func fatBurnZone(age: Int) -> FatBurnZone {
        let maxHR = Double(maxHeartRate(age: age))
        return FatBurnZone(
            lowerBound: maxHR * AppConstants.fatBurnLowerRatio,
            upperBound: maxHR * AppConstants.fatBurnUpperRatio
        )
    }
}

extension FatBurnZone {
    /// 便捷工厂方法
    static func calculate(age: Int) -> FatBurnZone {
        HeartRateZoneCalculator.fatBurnZone(age: age)
    }
}
