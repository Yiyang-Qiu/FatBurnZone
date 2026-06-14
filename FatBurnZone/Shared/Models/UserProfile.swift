import Foundation

/// 用户个人资料 — 仅存储年龄和计算出的燃脂区间
struct UserProfile: Codable {
    /// 用户年龄
    var age: Int

    /// 根据年龄计算出的燃脂区间
    var fatBurnZone: FatBurnZone {
        FatBurnZone.calculate(age: age)
    }

    /// 来源标记 — 年龄是从 HealthKit 自动获取还是手动输入
    enum AgeSource: String, Codable {
        case healthKit
        case manual
    }
    var ageSource: AgeSource

    init(age: Int, source: AgeSource) {
        self.age = age
        self.ageSource = source
    }
}
