import SwiftUI
import UserNotifications

@main
struct SubscribeApp: App {
    @StateObject private var store = SubscriptionStore()

    init() {
        // 全局挂前台通知 delegate —— 预览通知 / 提前提醒在 App 前台时也能看到
        // banner + sound,而不是默默地塞进通知中心。
        UNUserNotificationCenter.current().delegate = NotificationForegroundDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .preferredColorScheme(store.appearance.colorScheme)
        }
    }
}
