import Foundation
import UserNotifications

/// 涨跌通知服务
final class NotificationService {
    static let shared = NotificationService()

    private var notifiedFunds: Set<String> = []
    private var lastResetDate: String = ""

    private init() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// 检查基金涨跌是否超过阈值并发送通知
    func checkAndNotify(funds: [Fund], threshold: Double) {
        guard threshold > 0 else { return }

        for fund in funds {
            let absChange = abs(fund.changePercent)
            let key = "\(fund.fundcode)_\(fund.gztime)"

            guard absChange >= threshold, !notifiedFunds.contains(key) else { continue }

            notifiedFunds.insert(key)
            sendNotification(fund: fund)
        }
    }

    /// 每日首次调用时自动清理已通知记录
    func resetDailyIfNeeded() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())

        if today != lastResetDate {
            notifiedFunds.removeAll()
            lastResetDate = today
        }
    }

    private func sendNotification(fund: Fund) {
        let content = UNMutableNotificationContent()
        let sign = fund.changePercent >= 0 ? "+" : ""
        let direction = fund.changePercent >= 0 ? "上涨" : "下跌"
        content.title = "\(fund.name) \(direction)提醒"
        content.body = "当前涨跌幅 \(sign)\(fund.gszzl)%，估算净值 \(fund.gsz)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "fund_\(fund.fundcode)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
