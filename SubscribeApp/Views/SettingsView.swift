import SwiftUI
import StoreKit
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var store: SubscriptionStore
    @State private var authStatus: UNAuthorizationStatus = .notDetermined
    @State private var refreshing = false
    @StateObject private var tips = TipStore()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Menu {
                        ForEach(CurrencyCode.allCases) { c in
                            Button {
                                store.baseCurrency = c
                            } label: {
                                if store.baseCurrency == c {
                                    Label("\(c.rawValue) · \(c.title)", systemImage: "checkmark")
                                } else {
                                    Text("\(c.rawValue) · \(c.title)")
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Label("默认币种", systemImage: "dollarsign.circle")
                            Spacer()
                            Text(store.baseCurrency.rawValue)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Picker(selection: $store.appearance) {
                        ForEach(AppAppearance.allCases) { Text($0.title).tag($0) }
                    } label: {
                        Label("外观", systemImage: "circle.lefthalf.filled")
                    }
                    .pickerStyle(.menu)

                    NavigationLink {
                        PaymentMethodsView()
                    } label: {
                        Label("支付方式", systemImage: "creditcard")
                    }
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
                    Button(role: .destructive) {
                        store.resetSamples()
                    } label: {
                        Label("恢复样例数据", systemImage: "arrow.counterclockwise")
                    }
                } header: {
                    Text("数据与同步")
                } footer: {
                    Text("使用 iCloud Key-Value Store 同步当前订阅。真机需 Apple ID 与应用 iCloud 权限可用。")
                }

                Section {
                    if !tips.loaded {
                        HStack {
                            Label("支持开发者", systemImage: "heart")
                            Spacer()
                            ProgressView()
                        }
                    } else if tips.products.isEmpty {
                        Label("打赏暂不可用", systemImage: "heart")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(tips.products.enumerated()), id: \.element.id) { idx, product in
                            Button {
                                Task { await tips.purchase(product) }
                            } label: {
                                HStack {
                                    Label(product.displayName, systemImage: tipIcon(idx))
                                    Spacer()
                                    if tips.purchasingID == product.id {
                                        ProgressView()
                                    } else {
                                        Text(product.displayPrice)
                                            .foregroundStyle(.secondary)
                                            .monospacedDigit()
                                    }
                                }
                            }
                            .disabled(tips.purchasingID != nil)
                        }
                    }
                } header: {
                    Text("支持开发者")
                } footer: {
                    Text("打赏完全自愿，用于支持后续开发，不解锁任何功能。")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.visible)
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .tint(AppTheme.accent)
            .task {
                await loadStatus()
                await store.refreshRatesIfStale()
                await tips.load()
            }
            .alert("感谢支持！", isPresented: $tips.thanksShown) {
                Button("好的", role: .cancel) { }
            } message: {
                Text("你的支持是持续更新的动力。")
            }
        }
    }

    private var rateUpdatedText: String {
        guard let d = store.ratesUpdatedAt else { return String(localized: "（暂用内置汇率）") }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        let dateStr = f.string(from: d)
        return String(localized: "上次更新 \(dateStr)。")
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

    private func tipIcon(_ index: Int) -> String {
        ["cup.and.saucer", "takeoutbag.and.cup.and.straw", "fork.knife", "gift"][safe: index] ?? "heart"
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    SettingsView().environmentObject(SubscriptionStore())
}
