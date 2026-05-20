import Foundation
import UserNotifications

enum NotificationScheduler {
    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    static func scheduleReminder(for subscription: Subscription) {
        removeReminder(for: subscription.id)

        guard subscription.isActive, subscription.reminderDaysBefore > 0 else { return }

        let reminderDate = Calendar.current.date(
            byAdding: .day,
            value: -subscription.reminderDaysBefore,
            to: subscription.nextBillingDate
        ) ?? subscription.nextBillingDate

        guard reminderDate > Date() else { return }

        var components = Calendar.current.dateComponents([.year, .month, .day], from: reminderDate)
        components.hour = 9
        components.minute = 0

        let content = UNMutableNotificationContent()
        content.title = String(localized: "订阅即将续费")
        content.body = String(localized: "\(subscription.name) 将在 \(subscription.reminderDaysBefore) 天后续费。")
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: notificationIdentifier(for: subscription.id),
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    static func removeReminder(for id: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [notificationIdentifier(for: id)]
        )
    }

    static func rescheduleAll(_ subscriptions: [Subscription]) {
        for subscription in subscriptions {
            scheduleReminder(for: subscription)
        }
    }

    static func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// 立刻给用户推一条"样例通知",让他看到真实的展示效果。如果没有传入订阅,
    /// 就用一组占位文案。3 秒后触发(用户来得及把 App 退到后台 / 锁屏看效果)。
    /// 同时也尝试请求一下权限,免得用户没授权啥都看不到。
    static func previewSampleNotification(for subscription: Subscription?) async {
        // 没授权先请求一下,提示弹窗会自然弹出来。
        let granted = await requestAuthorization()
        guard granted else { return }

        let content = UNMutableNotificationContent()
        if let sub = subscription {
            content.title = String(localized: "订阅即将续费")
            content.body = String(localized: "\(sub.name) 将在 \(max(sub.reminderDaysBefore, 1)) 天后续费。")
        } else {
            content.title = String(localized: "通知预览")
            content.body = String(localized: "这就是订阅到期前你会收到的提醒样子。")
        }
        content.sound = .default

        // 3 秒延迟:让用户来得及把 App 推到后台或者锁屏。
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        let request = UNNotificationRequest(
            identifier: "preview-sample-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    private static func notificationIdentifier(for id: UUID) -> String {
        "subscription-renewal-\(id.uuidString)"
    }
}
