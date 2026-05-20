import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @EnvironmentObject private var store: SubscriptionStore
    @State private var authStatus: UNAuthorizationStatus = .notDetermined
    @State private var previewing = false
    /// 预览预约成功后给一个 toast 状态 —— 提示用户"3 秒后会推过来"。
    @State private var previewQueued = false

    /// 取下次会续费的订阅,作为预览通知的"模板"。
    private var nextSubscriptionForPreview: Subscription? {
        store.activeSubscriptions
            .filter { $0.isActive && $0.reminderDaysBefore > 0 }
            .sorted { $0.nextBillingDate < $1.nextBillingDate }
            .first
    }

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

            // 预览模块:点一下、把 App 退到后台或锁屏,3 秒后能收到一条样例通知。
            // 模板取下一笔会续费的订阅,跟真实提醒长得一模一样;没订阅时用占位文案。
            Section {
                Button {
                    guard !previewing else { return }
                    previewing = true
                    let target = nextSubscriptionForPreview
                    Task {
                        await NotificationScheduler.previewSampleNotification(for: target)
                        await MainActor.run {
                            previewing = false
                            previewQueued = true
                        }
                        // 3 秒后通知就推完了,把 toast 收掉
                        try? await Task.sleep(nanoseconds: 4_000_000_000)
                        await MainActor.run { previewQueued = false }
                    }
                } label: {
                    HStack(spacing: 12) {
                        SettingsIcon(name: "eye")
                        Text("预览通知样式").foregroundStyle(AppTheme.ink)
                        Spacer()
                        if previewing {
                            ProgressView()
                        } else if previewQueued {
                            Text("3 秒后送达").font(.caption).foregroundStyle(AppTheme.accent)
                        }
                    }
                }
                .buttonStyle(.plain)
            } footer: {
                Text(previewFooterText)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.visible)
        .navigationTitle("通知")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadStatus() }
    }

    /// 预览按钮下方的解释 —— 当能拿到"下一笔订阅"时,顺便告诉用户用的是哪一条
    /// 作为预览模板,免得用户疑惑"为什么是这个名字"。
    private var previewFooterText: String {
        if let sub = nextSubscriptionForPreview {
            return String(localized: "点一下后把 EON 退到后台或锁屏,3 秒后能看到样例通知(用「\(sub.name)」当模板)。")
        }
        return String(localized: "点一下后把 EON 退到后台或锁屏,3 秒后能看到一条样例通知。")
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
