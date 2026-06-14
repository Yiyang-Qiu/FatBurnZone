import Foundation
import Combine
import SwiftUI

/// 核心 ViewModel — 管理锻炼状态、连接 HealthKit 和通知服务
@MainActor
final class WorkoutViewModel: ObservableObject {

    // MARK: - 用户配置

    /// 用户个人资料
    @Published var userProfile: UserProfile?

    /// 是否已完成首次设置
    @Published var isSetupComplete: Bool = false

    /// 从 UserDefaults 缓存加载的年龄
    @AppStorage(AppConstants.userAgeKey) private var storedAge: Int = 0
    @AppStorage(AppConstants.userAgeSourceKey) private var storedAgeSource: String = ""

    // MARK: - 锻炼状态

    /// 当前实时心率
    @Published var heartRate: Double = 0

    /// 是否为锻炼中
    @Published var isWorkingOut: Bool = false

    /// 当前燃脂区间（基于年龄计算）
    @Published var fatBurnZone: FatBurnZone?

    /// 当前区间状态
    @Published var zoneStatus: HeartRateZoneStatus = .inZone

    /// 通知提示消息
    @Published var alertMessage: String?

    /// HealthKit 授权状态
    @Published var isAuthorized: Bool = false

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - 服务

    private let healthKitService = HealthKitService()
    private let notificationService = NotificationService()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - 初始化

    init() {
        setupBindings()
        loadCachedProfile()
    }

    private func setupBindings() {
        // 监听 HealthKit 心率变化
        healthKitService.$heartRate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hr in
                self?.heartRate = hr
                self?.processHeartRateUpdate(hr)
            }
            .store(in: &cancellables)

        // 监听 HealthKit 监控状态
        healthKitService.$isMonitoring
            .receive(on: DispatchQueue.main)
            .assign(to: &$isWorkingOut)

        // 监听 HealthKit 授权状态
        healthKitService.$isAuthorized
            .receive(on: DispatchQueue.main)
            .assign(to: &$isAuthorized)

        // 监听通知服务的提示消息
        notificationService.$alertMessage
            .receive(on: DispatchQueue.main)
            .assign(to: &$alertMessage)

        // 监听通知服务的区间状态
        notificationService.$zoneStatus
            .receive(on: DispatchQueue.main)
            .assign(to: &$zoneStatus)
    }

    // MARK: - 用户配置

    /// 从缓存加载用户资料
    private func loadCachedProfile() {
        guard storedAge > 0 else {
            isSetupComplete = false
            return
        }
        let source: UserProfile.AgeSource = storedAgeSource == "healthKit"
            ? .healthKit : .manual
        userProfile = UserProfile(age: storedAge, source: source)
        fatBurnZone = userProfile?.fatBurnZone
        isSetupComplete = true
    }

    /// 保存用户资料
    func saveProfile(age: Int, source: UserProfile.AgeSource) {
        userProfile = UserProfile(age: age, source: source)
        fatBurnZone = userProfile?.fatBurnZone
        storedAge = age
        storedAgeSource = source == .healthKit ? "healthKit" : "manual"
        isSetupComplete = true
    }

    /// 尝试从 HealthKit 获取年龄
    func fetchAgeFromHealthKit() async -> Int? {
        do {
            return try healthKitService.fetchAgeFromHealthKit()
        } catch {
            print("[WorkoutViewModel] 获取年龄失败: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - HealthKit 授权

    /// 请求 HealthKit 授权
    func requestAuthorization() async {
        do {
            try await healthKitService.requestAuthorization()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - 锻炼控制

    /// 开始锻炼
    func startWorkout() {
        guard let profile = userProfile else {
            errorMessage = "请先设置年龄"
            return
        }

        // 刷新燃脂区间
        fatBurnZone = profile.fatBurnZone

        do {
            try healthKitService.startWorkout()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 停止锻炼
    func stopWorkout() {
        healthKitService.stopWorkout()
    }

    // MARK: - 心率处理

    /// 处理每次心率更新
    private func processHeartRateUpdate(_ hr: Double) {
        guard hr > 0, let zone = fatBurnZone else { return }
        notificationService.evaluate(heartRate: hr, against: zone)
    }

    /// 清除错误
    func clearError() {
        errorMessage = nil
    }
}
