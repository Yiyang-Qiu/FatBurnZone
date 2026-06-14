import Foundation

/// 应用全局常量
enum AppConstants {
    /// 最大心率公式：220 - 年龄
    static let maxHeartRateFormulaBase = 220

    /// 燃脂区间下限（60% 最大心率）
    static let fatBurnLowerRatio = 0.60

    /// 燃脂区间上限（70% 最大心率）
    static let fatBurnUpperRatio = 0.70

    /// 连续处于异常区间的秒数后才触发通知（防抖）
    static let notificationDebounceSeconds: TimeInterval = 5

    /// 两次通知之间的最小间隔秒数
    static let notificationCooldownSeconds: TimeInterval = 30

    /// UserDefaults key
    static let userAgeKey = "user_profile_age"
    static let userAgeSourceKey = "user_profile_age_source"
}
