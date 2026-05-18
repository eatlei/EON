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
        content.title = "订阅即将续费"
        content.body = "\(subscription.name) 将在 \(subscription.reminderDaysBefore) 天后续费。"
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

    private static func notificationIdentifier(for id: UUID) -> String {
        "subscription-renewal-\(id.uuidString)"
    }
}
