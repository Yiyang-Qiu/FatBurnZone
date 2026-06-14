import SwiftUI
import HealthKit

/// iOS 配套 App — 年龄设置和燃脂区间预览
struct SettingsView: View {
    @AppStorage(AppConstants.userAgeKey) private var storedAge: Int = 0

    @State private var manualAge: Double = 30
    @State private var healthKitAge: Int? = nil
    @State private var isFetching = false

    private let healthStore = HKHealthStore()

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - 年龄设置

                Section("年龄设置") {
                    if let age = healthKitAge {
                        HStack {
                            Text("健康 App 年龄")
                            Spacer()
                            Text("\(age) 岁")
                                .foregroundColor(.green)
                        }
                    }

                    HStack {
                        Text("手动输入")
                        Spacer()
                        Text("\(Int(manualAge)) 岁")
                    }

                    Slider(value: $manualAge, in: 10...90, step: 1)
                        .onChange(of: manualAge) { _, newValue in
                            storedAge = Int(newValue)
                        }

                    Button {
                        Task { await fetchAgeFromHealthKit() }
                    } label: {
                        HStack {
                            if isFetching {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text("从健康 App 获取")
                        }
                    }
                    .disabled(isFetching)
                }

                // MARK: - 燃脂区间预览

                Section("燃脂区间预览") {
                    let zone = HeartRateZoneCalculator.fatBurnZone(
                        age: Int(manualAge)
                    )

                    HStack {
                        Text("最大心率")
                        Spacer()
                        Text("\(HeartRateZoneCalculator.maxHeartRate(age: Int(manualAge))) BPM")
                    }

                    HStack {
                        Text("最佳燃脂区间")
                        Spacer()
                        Text(zone.formattedRange)
                            .foregroundColor(.green)
                    }
                }

                // MARK: - 说明

                Section("使用说明") {
                    Text("""
                    1. 在此设置您的年龄（或从健康 App 获取）
                    2. 在 Apple Watch 上打开「燃脂心率」App
                    3. 开始爬坡锻炼，点击「开始锻炼」
                    4. App 会实时监测心率并通过触觉提醒您调整强度
                    """)
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .navigationTitle("燃脂心率")
            .task {
                // 从 Watch App 的缓存读取年龄
                if storedAge > 0 {
                    manualAge = Double(storedAge)
                }
            }
        }
    }

    // MARK: - HealthKit

    private func fetchAgeFromHealthKit() async {
        isFetching = true

        // 请求授权
        let readTypes: Set<HKObjectType> = {
            var types = Set<HKObjectType>()
            if let dob = HKCharacteristicType.characteristicType(
                forIdentifier: .dateOfBirth
            ) {
                types.insert(dob)
            }
            return types
        }()

        do {
            try await healthStore.requestAuthorization(
                toShare: [],
                read: readTypes
            )

            let dobComponents = try healthStore.dateOfBirthComponents()
            if let dob = dobComponents.date,
               let age = Calendar.current.dateComponents(
                   [.year],
                   from: dob,
                   to: Date()
               ).year {
                healthKitAge = age
                manualAge = Double(age)
                storedAge = age
            }
        } catch {
            print("获取年龄失败: \(error.localizedDescription)")
        }

        isFetching = false
    }
}
