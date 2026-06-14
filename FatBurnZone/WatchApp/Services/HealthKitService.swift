import Foundation
import HealthKit
import Combine

/// 管理所有 HealthKit 交互：授权、年龄查询、心率实时流、卡路里跟踪、锻炼会话
final class HealthKitService: NSObject, ObservableObject {

    // MARK: - 公开属性

    /// 实时心率 BPM（每秒更新）
    @Published var heartRate: Double = 0

    /// 实时活跃卡路里（千卡）
    @Published var activeCalories: Double = 0

    /// 本次锻炼总消耗卡路里（千卡）
    @Published var totalCalories: Double = 0

    /// 锻炼已过时长（秒）
    @Published var elapsedSeconds: TimeInterval = 0

    /// 是否正在监听
    @Published var isMonitoring: Bool = false

    /// 授权状态
    @Published var isAuthorized: Bool = false

    // MARK: - 私有属性

    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var heartRateQuery: HKAnchoredObjectQuery?
    private var workoutBuilder: HKLiveWorkoutBuilder?

    /// 锻炼开始时间
    private var workoutStartDate: Date?
    /// 每秒更新时长的 Timer
    private var elapsedTimer: Timer?

    /// 心率数据类型
    private let heartRateType = HKQuantityType.quantityType(
        forIdentifier: .heartRate
    )!

    /// 活跃卡路里数据类型
    private let activeEnergyType = HKQuantityType.quantityType(
        forIdentifier: .activeEnergyBurned
    )!

    /// 可读取的数据类型集合
    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [
            heartRateType,
            activeEnergyType,
        ]
        if let dobType = HKCharacteristicType.characteristicType(
            forIdentifier: .dateOfBirth
        ) {
            types.insert(dobType)
        }
        return types
    }

    /// 可写入的数据类型集合
    private var shareTypes: Set<HKSampleType> {
        [heartRateType, activeEnergyType, HKQuantityType.workoutType()]
    }

    // MARK: - 授权

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }

        try await healthStore.requestAuthorization(
            toShare: shareTypes,
            read: readTypes
        )
        await MainActor.run { isAuthorized = true }
    }

    // MARK: - 年龄获取

    func fetchAgeFromHealthKit() throws -> Int? {
        let dobComponents = try healthStore.dateOfBirthComponents()

        guard let dateOfBirth = dobComponents.date,
              let age = Calendar.current.dateComponents(
                  [.year],
                  from: dateOfBirth,
                  to: Date()
              ).year else {
            return nil
        }
        return age
    }

    // MARK: - 锻炼控制

    func startWorkout() throws {
        guard isAuthorized else {
            throw HealthKitError.notAuthorized
        }

        // 先同步获取最近一次心率，避免开始后显示 0 等待十几秒
        fetchLatestHeartRate { [weak self] latestBPM in
            Task { @MainActor in
                if let bpm = latestBPM {
                    self?.heartRate = bpm
                }
            }
        }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .walking
        configuration.locationType = .indoor

        let session = try HKWorkoutSession(
            healthStore: healthStore,
            configuration: configuration
        )
        self.workoutSession = session

        let builder = session.associatedWorkoutBuilder()
        builder.dataSource = HKLiveWorkoutDataSource(
            healthStore: healthStore,
            workoutConfiguration: configuration
        )
        builder.delegate = self
        self.workoutBuilder = builder

        session.delegate = self

        let now = Date()
        workoutStartDate = now
        session.startActivity(with: now)
        builder.beginCollection(withStart: now, completion: { _, _ in })

        startHeartRateQuery()
        startElapsedTimer()

        Task { @MainActor in
            isMonitoring = true
            activeCalories = 0
            totalCalories = 0
            elapsedSeconds = 0
        }
    }

    func stopWorkout() {
        // 停止前从 builder 获取最终总卡路里
        if let builder = workoutBuilder {
            let kcalUnit = HKUnit.kilocalorie()
            if let energyStat = builder.statistics(
                for: activeEnergyType
            ) {
                let total = energyStat.sumQuantity()?.doubleValue(
                    for: kcalUnit
                ) ?? 0
                Task { @MainActor [weak self] in
                    self?.totalCalories = total
                }
            }
        }

        stopElapsedTimer()

        if let query = heartRateQuery {
            healthStore.stop(query)
            heartRateQuery = nil
        }

        workoutBuilder?.endCollection(withEnd: Date(), completion: { _, _ in })
        workoutBuilder = nil

        workoutSession?.end()
        workoutSession = nil

        Task { @MainActor [weak self] in
            self?.isMonitoring = false
            self?.heartRate = 0
            self?.activeCalories = 0
        }
    }

    // MARK: - 时长计时器

    private func startElapsedTimer() {
        elapsedTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0,
            repeats: true
        ) { [weak self] _ in
            guard let self, let start = self.workoutStartDate else { return }
            Task { @MainActor [weak self] in
                self?.elapsedSeconds = Date().timeIntervalSince(start)
            }
        }
    }

    private func stopElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }

    // MARK: - 心率实时查询

    /// 快速获取最近一条心率样本，用于锻炼开始时立即显示
    private func fetchLatestHeartRate(completion: @escaping (Double?) -> Void) {
        let predicate = HKQuery.predicateForSamples(
            withStart: Date().addingTimeInterval(-300), // 最近 5 分钟
            end: Date(),
            options: []
        )
        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierEndDate,
            ascending: false
        )

        let query = HKSampleQuery(
            sampleType: heartRateType,
            predicate: predicate,
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, error in
            guard error == nil,
                  let sample = samples?.first as? HKQuantitySample else {
                completion(nil)
                return
            }
            let bpm = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
            completion(bpm)
        }

        healthStore.execute(query)
    }

    private func startHeartRateQuery() {
        let predicate = HKQuery.predicateForSamples(
            withStart: Date(),
            end: nil,
            options: .strictStartDate
        )

        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: predicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, error in
            if let error = error {
                print("[HealthKitService] 心率查询错误: \(error.localizedDescription)")
                return
            }
            self?.processHeartRateSamples(samples)
        }

        query.updateHandler = { [weak self] _, samples, _, _, error in
            if let error = error {
                print("[HealthKitService] 心率更新错误: \(error.localizedDescription)")
                return
            }
            self?.processHeartRateSamples(samples)
        }

        healthStore.execute(query)
        self.heartRateQuery = query
    }

    private func processHeartRateSamples(_ samples: [HKSample]?) {
        guard let quantitySamples = samples as? [HKQuantitySample],
              let latest = quantitySamples.last else {
            return
        }

        let bpm = latest.quantity.doubleValue(
            for: HKUnit(from: "count/min")
        )

        Task { @MainActor [weak self] in
            self?.heartRate = bpm
        }
    }
}

// MARK: - HKWorkoutSessionDelegate

extension HealthKitService: HKWorkoutSessionDelegate {

    func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        if toState == .ended {
            Task { @MainActor [weak self] in
                self?.isMonitoring = false
            }
        }
    }

    func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {
        print("[HealthKitService] 锻炼会话错误: \(error.localizedDescription)")
        Task { @MainActor [weak self] in
            self?.isMonitoring = false
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension HealthKitService: HKLiveWorkoutBuilderDelegate {

    func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        guard collectedTypes.contains(activeEnergyType) else { return }

        let kcalUnit = HKUnit.kilocalorie()
        if let energyStat = workoutBuilder.statistics(
            for: activeEnergyType
        ) {
            let calories = energyStat.sumQuantity()?.doubleValue(
                for: kcalUnit
            ) ?? 0
            Task { @MainActor [weak self] in
                self?.activeCalories = calories
            }
        }
    }

    func workoutBuilderDidCollectEvent(
        _ workoutBuilder: HKLiveWorkoutBuilder
    ) {
        // 无需处理
    }
}

// MARK: - 错误类型

enum HealthKitError: LocalizedError {
    case notAvailable
    case notAuthorized

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit 在当前设备上不可用"
        case .notAuthorized:
            return "请先授权 HealthKit 访问权限"
        }
    }
}
