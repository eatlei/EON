import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var store: SubscriptionStore
    @State private var authStatus: UNAuthorizationStatus = .notDetermined
    @State private var showAbout = false
    @State private var refreshing = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker(selection: $store.baseCurrency) {
                        ForEach(CurrencyCode.allCases) { Text("\($0.rawValue) · \($0.title)").tag($0) }
                    } label: {
                        Label("默认币种", systemImage: "dollarsign.circle")
                    }
                    .pickerStyle(.menu)

                    Picker(selection: $store.appearance) {
                        ForEach(AppAppearance.allCases) { Text($0.title).tag($0) }
                    } label: {
                        Label("外观", systemImage: "circle.lefthalf.filled")
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("通用")
                }

                Section {
                    DisclosureGroup {
                        ForEach(CurrencyCode.allCases) { c in
                            HStack {
                                Text(c.rawValue)
                                Spacer()
                                Text("1 \(c.rawValue) = \(store.cnyRates[c, default: 1], specifier: "%.4f") CNY")
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            .font(.subheadline)
                        }
                    } label: {
                        Label("汇率明细", systemImage: "chart.line.uptrend.xyaxis")
                    }

                    Button {
                        guard !refreshing else { return }
                        refreshing = true
                        Task {
                            await store.refreshRates()
                            await MainActor.run { refreshing = false }
                        }
                    } label: {
                        HStack {
                            Label("立即刷新汇率", systemImage: "arrow.clockwise")
                            Spacer()
                            if refreshing { ProgressView() }
                        }
                    }
                } header: {
                    Text("汇率")
                } footer: {
                    Text("汇率每天自动刷新，可能导致订阅价格变动。\(rateUpdatedText)")
                }

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
                } header: {
                    Text("通知")
                } footer: {
                    Text(statusText)
                }

                Section {
                    Toggle(isOn: $store.iCloudSyncEnabled) {
                        Label("通过 iCloud 同步订阅", systemImage: "icloud")
                    }
                    Button {
                        store.syncFromICloud()
                    } label: {
                        Label("从 iCloud 拉取", systemImage: "icloud.and.arrow.down")
                    }
                    .disabled(!store.iCloudSyncEnabled)
                    Button {
                        store.syncToICloud()
                    } label: {
                        Label("上传到 iCloud", systemImage: "icloud.and.arrow.up")
                    }
                    .disabled(!store.iCloudSyncEnabled)
                } header: {
                    Text("iCloud")
                } footer: {
                    Text("使用 iCloud Key-Value Store 同步当前订阅。真机需 Apple ID 与应用 iCloud 权限可用。")
                }

                Section {
                    Button(role: .destructive) {
                        store.resetSamples()
                    } label: {
                        Label("恢复样例数据", systemImage: "arrow.counterclockwise")
                    }
                } header: {
                    Text("数据")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.visible)
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .tint(AppTheme.accent)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关于") { showAbout = true }
                }
            }
            .sheet(isPresented: $showAbout) { AboutView() }
            .task {
                await loadStatus()
                await store.refreshRatesIfStale()
            }
        }
    }

    private var rateUpdatedText: String {
        guard let d = store.ratesUpdatedAt else { return "（暂用内置汇率）" }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return "上次更新 \(f.string(from: d))。"
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

private struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(v) (\(b))"
    }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("名称"); Spacer(); Text("Subscribe").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("版本"); Spacer(); Text(version).foregroundStyle(.secondary).monospacedDigit()
                    }
                } footer: {
                    Text("订阅管理 · 多币种 · 每日汇率")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("关于")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    SettingsView().environmentObject(SubscriptionStore())
}
