import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @EnvironmentObject private var store: SubscriptionStore
    @State private var authStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        List {
            Section {
                Toggle(isOn: $store.remindersEnabled) {
                    Label("开启提醒", systemImage: "bell")
                }
                Button {
                    Task {
                        if await NotificationScheduler.requestAuthorization() {
                            store.syncReminders()
                        }
                        await loadStatus()
                    }
                } label: {
                    Label("授权并同步提醒", systemImage: "bell.badge")
                }
                .tint(AppTheme.accent)
            } footer: {
                Text(statusText)
            }

            Section {
                Stepper(value: $store.defaultReminderDays, in: 0...30) {
                    Label(String(localized: "新建订阅默认提前 \(store.defaultReminderDays) 天提醒"),
                          systemImage: "calendar.badge.clock")
                }
            } footer: {
                Text("决定新建订阅时默认提前几天提醒。")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.visible)
        .navigationTitle("通知")
        .navigationBarTitleDisplayMode(.inline)
        .labelStyle(.settings)
        .task { await loadStatus() }
    }

    private var statusText: String {
        switch authStatus {
        case .authorized, .provisional, .ephemeral: String(localized: "系统通知已授权，按每个订阅的提前天数提醒。")
        case .denied: String(localized: "系统通知未授权，需在 iOS 设置中允许通知。")
        case .notDetermined: String(localized: "尚未请求系统通知权限。")
        @unknown default: String(localized: "通知权限状态未知。")
        }
    }

    private func loadStatus() async {
        authStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }
}

#Preview {
    NavigationStack { NotificationSettingsView() }
        .environmentObject(SubscriptionStore())
}
