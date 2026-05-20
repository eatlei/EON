import SwiftUI
import UIKit
import UserNotifications

struct NotificationSettingsView: View {
    @EnvironmentObject private var store: SubscriptionStore
    @Environment(\.openURL) private var openURL
    @State private var authStatus: UNAuthorizationStatus = .notDetermined
    @State private var previewing = false
    @State private var previewBadge: PreviewBadge?
    @State private var showDeniedAlert = false

    /// 把刚才预览的结果用一段短文案标在右侧,3 秒后自动撤掉。
    private enum PreviewBadge: Equatable {
        case queued
        case failed
        var text: LocalizedStringKey {
            switch self {
            case .queued: "3 秒后送达"
            case .failed: "失败,稍后重试"
            }
        }
        var color: Color {
            switch self {
            case .queued: AppTheme.accent
            case .failed: .orange
            }
        }
    }

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
                // 用户拨动开关时,真正把权限请求 / 拒绝处理跑起来:
                // - notDetermined: 直接弹系统授权对话框
                // - denied: 弹自家 alert 引导去 iOS 设置(并把开关回滚)
                // - 已授权: 把所有订阅的本地通知重新排队
                .onChange(of: store.remindersEnabled) { _, newValue in
                    guard newValue else {
                        // 关闭就把待发通知全清掉,不再打扰
                        NotificationScheduler.cancelAll()
                        return
                    }
                    Task { await handleRemindersEnabled() }
                }
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
            Section {
                Button {
                    guard !previewing else { return }
                    Task { await runPreview() }
                } label: {
                    HStack(spacing: 12) {
                        SettingsIcon(name: "eye")
                        Text("预览通知样式").foregroundStyle(AppTheme.ink)
                        Spacer()
                        if previewing {
                            ProgressView()
                        } else if let badge = previewBadge {
                            Text(badge.text).font(.caption).foregroundStyle(badge.color)
                        }
                    }
                    .contentShape(Rectangle())  // 整行可点
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
        .alert("通知被关闭了", isPresented: $showDeniedAlert) {
            Button("前往 iOS 设置") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            Button("好的", role: .cancel) { }
        } message: {
            Text("EON 当前没有通知权限,可以在 iOS 设置里手动打开。")
        }
    }

    private var statusText: String {
        switch authStatus {
        case .authorized, .provisional, .ephemeral: String(localized: "通知已开启,我们会按每个订阅的设置准时提醒你。")
        case .denied: String(localized: "通知被关闭了。可以去 iOS 设置里打开。")
        case .notDetermined: String(localized: "首次开启会弹一个权限请求,允许后才能收到提醒。")
        @unknown default: String(localized: "通知权限状态未知。")
        }
    }

    private var previewFooterText: String {
        if let sub = nextSubscriptionForPreview {
            return String(localized: "点一下后把 EON 退到后台或锁屏,3 秒后能看到样例通知(用「\(sub.name)」当模板)。")
        }
        return String(localized: "点一下后把 EON 退到后台或锁屏,3 秒后能看到一条样例通知。")
    }

    // MARK: - Actions

    /// Toggle 拨到"开"时跑的流程 —— 包揽请求权限 / 失败回滚 / 成功重排队。
    private func handleRemindersEnabled() async {
        let status = await NotificationScheduler.currentAuthorizationStatus()
        switch status {
        case .notDetermined:
            let granted = await NotificationScheduler.requestAuthorization()
            await loadStatus()
            if granted {
                store.syncReminders()
            } else {
                // 用户在系统弹窗里拒了,把开关弹回去
                await MainActor.run { store.remindersEnabled = false }
            }
        case .denied:
            // 已经被拒绝过 —— iOS 不会再弹原生权限对话框。回滚开关 + 自家 alert 引导。
            await MainActor.run {
                store.remindersEnabled = false
                showDeniedAlert = true
            }
        case .authorized, .provisional, .ephemeral:
            store.syncReminders()
        @unknown default:
            break
        }
    }

    /// 预览按钮点击 —— 拿到 PreviewResult 决定显示哪种 badge / 弹哪个 alert。
    private func runPreview() async {
        previewing = true
        let target = nextSubscriptionForPreview
        let result = await NotificationScheduler.previewSampleNotification(for: target)
        await loadStatus()
        await MainActor.run {
            previewing = false
            switch result {
            case .scheduled:
                previewBadge = .queued
            case .denied:
                previewBadge = nil
                showDeniedAlert = true
            case .failed:
                previewBadge = .failed
            }
        }
        // 4 秒后自动清 badge,保持 UI 干净
        try? await Task.sleep(nanoseconds: 4_000_000_000)
        await MainActor.run {
            if previewBadge == .queued || previewBadge == .failed {
                previewBadge = nil
            }
        }
    }

    private func loadStatus() async {
        let status = await NotificationScheduler.currentAuthorizationStatus()
        await MainActor.run { authStatus = status }
    }
}

#Preview {
    NavigationStack { NotificationSettingsView() }
        .environmentObject(SubscriptionStore())
}
