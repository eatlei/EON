import Foundation
import UserNotifications

enum NotificationScheduler {
    /// 真正请求授权 —— 如果系统已经记住了一个决定(.authorized / .denied),
    /// 这次 requestAuthorization 不会再弹窗,只是把当前的状态回传给我们。
    /// 所以调用前后都要主动读 settings 拿真实状态。
    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )
        } catch {
            return false
        }
    }

    /// 当前授权状态(供 UI 跑权限分支用)。
    static func currentAuthorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
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

    /// 用 enum 把"预览通知"的几种结果区分开,UI 拿去分别提示用户。
    enum PreviewResult {
        case scheduled            // 已经排进队列,3 秒后到
        case denied               // 用户/系统拒绝过授权,要去 iOS 设置打开
        case failed               // 其他失败(队列满 / 模拟器异常)
    }

    /// 立刻给用户推一条"样例通知",让他看到真实的展示效果。如果没有传入订阅,
    /// 就用一组占位文案。3 秒后触发(用户来得及把 App 退到后台 / 锁屏看效果)。
    static func previewSampleNotification(for subscription: Subscription?) async -> PreviewResult {
        // 先看一下当前授权状态,decide whether to request 或 fail
        let status = await currentAuthorizationStatus()
        let granted: Bool
        switch status {
        case .notDetermined:
            // 第一次:真弹权限对话框
            granted = await requestAuthorization()
        case .denied:
            return .denied
        case .authorized, .provisional, .ephemeral:
            granted = true
        @unknown default:
            granted = false
        }
        guard granted else { return .denied }

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
        do {
            try await UNUserNotificationCenter.current().add(request)
            return .scheduled
        } catch {
            return .failed
        }
    }

    private static func notificationIdentifier(for id: UUID) -> String {
        "subscription-renewal-\(id.uuidString)"
    }
}

// MARK: - Foreground delegate

/// 默认情况下,App 在前台时通知不会显示横幅(iOS 行为)。我们的"预览样例"
/// 想给用户看到 banner,所以全局设一个 delegate,把 .banner + .sound 都准许
/// 在前台展示。delegate 方法是非主线程回调,这里不挂 @MainActor;内部也没碰
/// 跨线程不安全的状态,纯函数式返回 options。
final class NotificationForegroundDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = NotificationForegroundDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }
}
