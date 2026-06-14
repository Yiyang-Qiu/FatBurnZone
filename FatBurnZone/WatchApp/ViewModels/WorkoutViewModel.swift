import Foundation
import Combine
import SwiftUI

/// 核心 ViewModel — 管理锻炼状态、连接 HealthKit 和通知服务
@MainActor
final class WorkoutViewModel: ObservableObject {

    // MARK: - 用户配置

    @Published var userProfile: UserProfile?
    @Published var isSetupComplete: Bool = false

    @AppStorage(AppConstants.userAgeKey) private var storedAge: Int = 0
    @AppStorage(AppConstants.userAgeSourceKey) private var storedAgeSource: String = ""

    // MARK: - 锻炼状态

    @Published var heartRate: Double = 0
    @Published var activeCalories: Double = 0
    @Published var totalCalories: Double = 0
    @Published var elapsedSeconds: TimeInterval = 0
    @Published var isWorkingOut: Bool = false
    @Published var showSummary: Bool = false
    @Published var fatBurnZone: FatBurnZone?
    @Published var zoneStatus: HeartRateZoneStatus = .inZone
    @Published var alertMessage: String?
    @Published var isAuthorized: Bool = false
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
        healthKitService.$heartRate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hr in
                self?.heartRate = hr
                self?.processHeartRateUpdate(hr)
            }
            .store(in: &cancellables)

        healthKitService.$activeCalories
            .receive(on: DispatchQueue.main)
            .assign(to: &$activeCalories)

        healthKitService.$totalCalories
            .receive(on: DispatchQueue.main)
            .assign(to: &$totalCalories)

        healthKitService.$elapsedSeconds
            .receive(on: DispatchQueue.main)
            .assign(to: &$elapsedSeconds)

        healthKitService.$isMonitoring
            .receive(on: DispatchQueue.main)
            .sink { [weak self] monitoring in
                self?.isWorkingOut = monitoring
                if !monitoring && self?.totalCalories ?? 0 > 0 {
                    self?.showSummary = true
                }
            }
            .store(in: &cancellables)

        healthKitService.$isAuthorized
            .receive(on: DispatchQueue.main)
            .assign(to: &$isAuthorized)

        notificationService.$alertMessage
            .receive(on: DispatchQueue.main)
            .assign(to: &$alertMessage)

        notificationService.$zoneStatus
            .receive(on: DispatchQueue.main)
            .assign(to: &$zoneStatus)
    }

    // MARK: - 用户配置

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

    func saveProfile(age: Int, source: UserProfile.AgeSource) {
        userProfile = UserProfile(age: age, source: source)
        fatBurnZone = userProfile?.fatBurnZone
        storedAge = age
        storedAgeSource = source == .healthKit ? "healthKit" : "manual"
        isSetupComplete = true
    }

    func fetchAgeFromHealthKit() async -> Int? {
        do {
            return try healthKitService.fetchAgeFromHealthKit()
        } catch {
            print("[WorkoutViewModel] 获取年龄失败: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - HealthKit 授权

    func requestAuthorization() async {
        do {
            try await healthKitService.requestAuthorization()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - 锻炼控制

    func startWorkout() {
        guard let profile = userProfile else {
            errorMessage = "请先设置年龄"
            return
        }

        fatBurnZone = profile.fatBurnZone
        showSummary = false
        totalCalories = 0

        do {
            try healthKitService.startWorkout()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stopWorkout() {
        healthKitService.stopWorkout()
    }

    func dismissSummary() {
        showSummary = false
        totalCalories = 0
    }

    /// 重置年龄配置，回到设置页
    func resetProfile() {
        storedAge = 0
        storedAgeSource = ""
        userProfile = nil
        fatBurnZone = nil
        isSetupComplete = false
    }

    // MARK: - 心率处理

    private func processHeartRateUpdate(_ hr: Double) {
        guard hr > 0, let zone = fatBurnZone else { return }
        notificationService.evaluate(heartRate: hr, against: zone)
    }

    func clearError() {
        errorMessage = nil
    }
}
