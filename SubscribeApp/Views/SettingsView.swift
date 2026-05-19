import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var store: SubscriptionStore
    @State private var authStatus: UNAuthorizationStatus = .notDetermined
    @State private var showRates = false

    var body: some View {
        NavigationStack {
            AppScreen {
                VStack(spacing: AppTheme.Space.l) {
                    Panel(title: "外观") {
                        HStack {
                            Text("主题").font(.subheadline.weight(.medium))
                                .foregroundStyle(AppTheme.secondary)
                            Spacer()
                            Picker("", selection: $store.appearance) {
                                ForEach(AppAppearance.allCases) { Text($0.title).tag($0) }
                            }.labelsHidden().tint(AppTheme.ink)
                        }
                    }

                    Panel(title: "统计") {
                        HStack {
                            Text("统一查看币种").font(.subheadline.weight(.medium))
                                .foregroundStyle(AppTheme.secondary)
                            Spacer()
                            Picker("", selection: $store.baseCurrency) {
                                ForEach(CurrencyCode.allCases) { Text("\($0.rawValue) · \($0.title)").tag($0) }
                            }.labelsHidden().tint(AppTheme.ink)
                        }
                        Hairline()
                        DisclosureGroup(isExpanded: $showRates) {
                            VStack(spacing: AppTheme.Space.s) {
                                Text("内置静态汇率，仅随应用更新调整，不会每日自动刷新。")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.tertiary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.top, AppTheme.Space.xs)
                                ForEach(CurrencyCode.allCases) { c in
                                    HStack {
                                        Text(c.rawValue).font(.caption.weight(.semibold))
                                            .foregroundStyle(AppTheme.ink)
                                        Spacer()
                                        Text("1 \(c.rawValue) = \(store.converter.cnyRates[c, default: 1], specifier: "%.3f") CNY")
                                            .font(.caption.monospacedDigit())
                                            .foregroundStyle(AppTheme.secondary)
                                    }
                                }
                            }
                            .padding(.top, AppTheme.Space.s)
                        } label: {
                            Text("内置汇率（以 CNY 为基准）")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(AppTheme.secondary)
                        }
                        .tint(AppTheme.secondary)
                    }

                    Panel(title: "续费提醒") {
                        Toggle("开启提醒", isOn: $store.remindersEnabled)
                            .tint(AppTheme.accent).font(.subheadline.weight(.medium))
                        Hairline()
                        Button {
                            Task {
                                if await NotificationScheduler.requestAuthorization() {
                                    store.syncReminders()
                                }
                                await loadStatus()
                            }
                        } label: {
                            Label("授权并同步提醒", systemImage: "bell.badge")
                                .font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.accent)
                        }
                        Text(statusText).font(.caption).foregroundStyle(AppTheme.tertiary)
                    }

                    Panel(title: "iCloud 同步") {
                        Toggle("通过 iCloud 同步订阅", isOn: $store.iCloudSyncEnabled)
                            .tint(AppTheme.accent).font(.subheadline.weight(.medium))
                        Hairline()
                        HStack {
                            Button { store.syncFromICloud() } label: {
                                Label("拉取", systemImage: "icloud.and.arrow.down")
                                    .font(.subheadline.weight(.semibold))
                            }.disabled(!store.iCloudSyncEnabled).tint(AppTheme.accent)
                            Spacer()
                            Button { store.syncToICloud() } label: {
                                Label("上传", systemImage: "icloud.and.arrow.up")
                                    .font(.subheadline.weight(.semibold))
                            }.disabled(!store.iCloudSyncEnabled).tint(AppTheme.accent)
                        }
                        Text("使用 iCloud Key-Value Store 同步当前订阅。真机需 Apple ID 与应用 iCloud 权限可用。")
                            .font(.caption).foregroundStyle(AppTheme.tertiary)
                    }

                    Panel(title: "数据") {
                        Button(role: .destructive) { store.resetSamples() } label: {
                            Label("恢复样例数据", systemImage: "arrow.counterclockwise")
                                .font(.subheadline.weight(.semibold))
                        }.tint(.red)
                    }

                    Text(appVersion)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(AppTheme.tertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, AppTheme.Space.s)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .task { await loadStatus() }
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Subscribe v\(v) (\(b))"
    }

    private var statusText: String {
        switch authStatus {
        case .authorized, .provisional, .ephemeral: "系统通知已授权，按每个订阅的提前天数提醒。"
        case .denied: "系统通知未授权，需在 iOS 设置中允许通知。"
        case .notDetermined: "尚未请求系统通知权限。"
        @unknown default: "通知权限状态未知。"
        }
    }
    private func loadStatus() async {
        authStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }
}

#Preview {
    SettingsView().environmentObject(SubscriptionStore())
}
