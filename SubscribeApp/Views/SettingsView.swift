import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var store: SubscriptionStore
    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        NavigationStack {
            Form {
                Section("统计") {
                    Picker("统一查看币种", selection: $store.baseCurrency) {
                        ForEach(CurrencyCode.allCases) { currency in
                            Text("\(currency.rawValue) · \(currency.title)").tag(currency)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("内置汇率")
                            .font(.subheadline.weight(.semibold))
                        ForEach(CurrencyCode.allCases) { currency in
                            HStack {
                                Text(currency.rawValue)
                                Spacer()
                                Text("1 \(currency.rawValue) = \(store.converter.cnyRates[currency, default: 1], specifier: "%.3f") CNY")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.caption)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("续费提醒") {
                    Toggle("开启提醒", isOn: $store.remindersEnabled)

                    Button {
                        Task {
                            let granted = await NotificationScheduler.requestAuthorization()
                            if granted {
                                NotificationScheduler.rescheduleAll(store.subscriptions)
                            }
                            await loadAuthorizationStatus()
                        }
                    } label: {
                        Label("授权并同步提醒", systemImage: "bell.badge.fill")
                    }

                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("iCloud 同步") {
                    Toggle("通过 iCloud 同步订阅", isOn: $store.iCloudSyncEnabled)

                    HStack {
                        Button {
                            store.syncFromICloud()
                        } label: {
                            Label("拉取", systemImage: "icloud.and.arrow.down")
                        }
                        .disabled(!store.iCloudSyncEnabled)

                        Spacer()

                        Button {
                            store.syncToICloud()
                        } label: {
                            Label("上传", systemImage: "icloud.and.arrow.up")
                        }
                        .disabled(!store.iCloudSyncEnabled)
                    }

                    Text("开启后会使用 iCloud Key-Value Store 同步当前订阅数据。真机需要 Apple ID、iCloud Drive 和应用 iCloud 权限可用。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("数据") {
                    Button(role: .destructive) {
                        store.resetSamples()
                    } label: {
                        Label("恢复样例数据", systemImage: "arrow.counterclockwise")
                    }
                }
            }
            .navigationTitle("设置")
            .task {
                await loadAuthorizationStatus()
            }
        }
    }

    private var statusText: String {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            "系统通知已授权，会按每个订阅设置的提前天数提醒。"
        case .denied:
            "系统通知未授权，需要在 iOS 设置中允许通知。"
        case .notDetermined:
            "尚未请求系统通知权限。"
        @unknown default:
            "通知权限状态未知。"
        }
    }

    private func loadAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }
}
