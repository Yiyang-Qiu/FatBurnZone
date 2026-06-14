import Foundation
import HealthKit
import Combine

/// 管理所有 HealthKit 交互：授权、年龄查询、心率实时流、锻炼会话
final class HealthKitService: NSObject, ObservableObject {

    // MARK: - 公开属性

    /// 实时心率 BPM（每秒更新）
    @Published var heartRate: Double = 0

    /// 是否正在监听心率
    @Published var isMonitoring: Bool = false

    /// 授权状态
    @Published var isAuthorized: Bool = false

    // MARK: - 私有属性

    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var heartRateQuery: HKAnchoredObjectQuery?
    private var workoutBuilder: HKLiveWorkoutBuilder?

    /// 心率数据类型的标识符
    private let heartRateType = HKQuantityType.quantityType(
        forIdentifier: .heartRate
    )!

    /// 可读取的数据类型集合
    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [heartRateType]
        // 出生日期特征
        if let dobType = HKCharacteristicType.characteristicType(
            forIdentifier: .dateOfBirth
        ) {
            types.insert(dobType)
        }
        return types
    }

    /// 可写入的数据类型集合
    private var shareTypes: Set<HKSampleType> {
        [heartRateType, HKQuantityType.workoutType()]
    }

    // MARK: - 授权

    /// 请求 HealthKit 读取和写入权限
    func requestAuthorization() async throws {
        // 检查 HealthKit 在当前设备上是否可用
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }

        try await healthStore.requestAuthorization(
            toShare: shareTypes,
            read: readTypes
        )
        // 类型转换: MainActor 保证 UI 更新安全
        await MainActor.run { isAuthorized = true }
    }

    // MARK: - 年龄获取

    /// 从 HealthKit 用户画像获取年龄
    /// - Returns: 年龄值；如果未设置出生日期则返回 nil
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

    /// 启动锻炼会话并开始监听心率
    func startWorkout() throws {
        guard isAuthorized else {
            throw HealthKitError.notAuthorized
        }

        // 配置锻炼会话
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .walking
        configuration.locationType = .indoor

        // 创建会话
        let session = try HKWorkoutSession(
            healthStore: healthStore,
            configuration: configuration
        )
        self.workoutSession = session

        // 关联 builder 用于获取实时心率
        let builder = session.associatedWorkoutBuilder()
        builder.dataSource = HKLiveWorkoutDataSource(
            healthStore: healthStore,
            workoutConfiguration: configuration
        )
        builder.delegate = self
        self.workoutBuilder = builder

        // 设置会话代理
        session.delegate = self

        // 开始
        session.startActivity(with: Date())
        builder.beginCollection(withStart: Date(), completion: { _, _ in })

        // 启动心率锚定查询
        startHeartRateQuery()

        Task { @MainActor in
            isMonitoring = true
        }
    }

    /// 停止锻炼会话
    func stopWorkout() {
        // 停止心率查询
        if let query = heartRateQuery {
            healthStore.stop(query)
            heartRateQuery = nil
        }

        // 结束 builder
        workoutBuilder?.endCollection(withEnd: Date(), completion: { _, _ in })
        workoutBuilder = nil

        // 结束会话
        workoutSession?.end()
        workoutSession = nil

        Task { @MainActor in
            isMonitoring = false
            heartRate = 0
        }
    }

    // MARK: - 心率实时查询

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

        // 当新样本到达时更新
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

    /// 解析心率样本，提取最新 BPM 值
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
        // 心率数据由 AnchoredObjectQuery 处理
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
