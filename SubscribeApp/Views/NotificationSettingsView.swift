import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @EnvironmentObject private var store: SubscriptionStore
    @State private var authStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        List {
            Section {
                Toggle(isOn: $store.remindersEnabled) {
                    HStack(spacing: 12) {
                        SettingsIcon(name: "bell")
                        Text("开启提醒")
                    }
                }
                Button {
                    Task {
                        if await NotificationScheduler.requestAuthorization() {
                            store.syncReminders()
                        }
                        await loadStatus()
                    }
                } label: {
                    HStack(spacing: 12) {
                        SettingsIcon(name: "bell.badge")
                        Text("授权并同步提醒").foregroundStyle(AppTheme.ink)
                    }
                }
                .buttonStyle(.plain)
            } footer: {
                Text(statusText)
            }

            Section {
                Stepper(value: $store.defaultReminderDays, in: 0...30) {
                    HStack(spacing: 12) {
                        SettingsIcon(name: "calendar.badge.clock")
                        Text(String(localized: "新建订阅默认提前 \(store.defaultReminderDays) 天提醒"))
                    }
                }
            } footer: {
                Text("新建订阅默认就用这个提醒天数。")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.visible)
        .navigationTitle("通知")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadStatus() }
    }

    private var statusText: String {
        switch authStatus {
        case .authorized, .provisional, .ephemeral: String(localized: "通知已开启,我们会按每个订阅的设置准时提醒你。")
        case .denied: String(localized: "通知被关闭了。可以去 iOS 设置里打开。")
        case .notDetermined: String(localized: "还没有开启通知。点上面的按钮申请权限。")
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
