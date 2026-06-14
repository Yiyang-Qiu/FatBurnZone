import Foundation
import WatchKit
import Combine

/// 管理触觉反馈和视觉提醒，包含防抖和冷却机制
final class NotificationService: ObservableObject {

    // MARK: - 公开属性

    /// 当前需要显示给用户的状态消息
    @Published var alertMessage: String?

    /// 当前区间状态
    @Published var zoneStatus: HeartRateZoneStatus = .inZone

    // MARK: - 私有状态

    /// 连续处于同一异常状态的开始时间
    private var abnormalStateStartTime: Date?

    /// 当前跟踪的异常状态
    private var trackedAbnormalStatus: HeartRateZoneStatus?

    /// 上次发送通知的时间
    private var lastNotificationTime: Date?

    /// 订阅取消器
    private var cancellables = Set<AnyCancellable>()

    // MARK: - 初始化

    init() {
        // 当回到 inZone 时清除异常状态
        $zoneStatus
            .sink { [weak self] status in
                if status == .inZone {
                    self?.resetAbnormalTracking()
                    self?.alertMessage = nil
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - 核心方法

    /// 根据给离心率判断并更新状态，必要时触发通知
    /// - Parameters:
    ///   - heartRate: 当前心率 BPM
    ///   - zone: 燃脂区间
    func evaluate(heartRate: Double, against zone: FatBurnZone) {
        let newStatus = zone.status(for: heartRate)

        // 更新发布的状态
        if newStatus != zoneStatus {
            zoneStatus = newStatus
        }

        switch newStatus {
        case .inZone:
            // 回到燃脂区间，清除异常跟踪和提示
            resetAbnormalTracking()
            alertMessage = nil

        case .below, .above:
            // 跟踪异常状态的持续时间
            trackAbnormalStatus(newStatus)

            // 检查是否应该发送通知
            if shouldSendNotification() {
                sendNotification(for: newStatus)
            }
        }
    }

    // MARK: - 私有方法

    /// 跟踪异常状态的持续时间
    private func trackAbnormalStatus(_ status: HeartRateZoneStatus) {
        let now = Date()

        // 如果是新的异常状态或首次跟踪
        if trackedAbnormalStatus != status || abnormalStateStartTime == nil {
            abnormalStateStartTime = now
            trackedAbnormalStatus = status
        }

        // 检查持续时间是否达标
        if let startTime = abnormalStateStartTime {
            let elapsed = now.timeIntervalSince(startTime)
            if elapsed < AppConstants.notificationDebounceSeconds {
                // 没到防抖时间，更新提示但不通知
                alertMessage = buildPreviewMessage(for: status, elapsed: elapsed)
            }
        }
    }

    /// 判断是否应该发送触觉通知
    private func shouldSendNotification() -> Bool {
        guard let startTime = abnormalStateStartTime,
              let status = trackedAbnormalStatus else {
            return false
        }

        let now = Date()
        let elapsed = now.timeIntervalSince(startTime)

        // 条件 1：连续停留超过防抖阈值（5 秒）
        guard elapsed >= AppConstants.notificationDebounceSeconds else {
            return false
        }

        // 条件 2：距上次通知超过冷却时间（30 秒）
        if let lastTime = lastNotificationTime {
            let cooldown = now.timeIntervalSince(lastTime)
            guard cooldown >= AppConstants.notificationCooldownSeconds else {
                return false
            }
        }

        return true
    }

    /// 发送触觉 + 视觉通知
    private func sendNotification(for status: HeartRateZoneStatus) {
        lastNotificationTime = Date()

        switch status {
        case .below:
            alertMessage = "心率偏低 · 增大坡度"
        case .above:
            alertMessage = "心率偏高 · 降低坡度"
        case .inZone:
            break
        }

        // 触觉反馈
        WKInterfaceDevice.current().play(.notification)
    }

    /// 构建通知前的预览消息
    private func buildPreviewMessage(
        for status: HeartRateZoneStatus,
        elapsed: TimeInterval
    ) -> String? {
        let remaining = Int(
            ceil(AppConstants.notificationDebounceSeconds - elapsed)
        )
        guard remaining > 0 else { return nil }

        switch status {
        case .below:
            return "偏低 · \(remaining)s"
        case .above:
            return "偏高 · \(remaining)s"
        case .inZone:
            return nil
        }
    }

    /// 重置异常状态跟踪
    private func resetAbnormalTracking() {
        abnormalStateStartTime = nil
        trackedAbnormalStatus = nil
    }
}
