import SwiftUI
import StoreKit
import UserNotifications
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var store: SubscriptionStore
    @Environment(\.openURL) private var openURL
    @State private var authStatus: UNAuthorizationStatus = .notDetermined
    @State private var refreshing = false
    @StateObject private var tips = TipStore()
    @State private var showTips = false

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
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(store.baseCurrency.rawValue)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }

                    Picker(selection: $store.appearance) {
                        ForEach(AppAppearance.allCases) { Text($0.title).tag($0) }
                    } label: {
                        Label("外观", systemImage: "circle.lefthalf.filled")
                    }
                    .pickerStyle(.menu)

                    DisclosureGroup {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: AppTheme.Space.m)], spacing: AppTheme.Space.m) {
                            ForEach(AccentTheme.allCases) { theme in
                                Button {
                                    store.accentTheme = theme
                                } label: {
                                    Circle()
                                        .fill(theme.color)
                                        .frame(width: 34, height: 34)
                                        .overlay(
                                            Image(systemName: "checkmark")
                                                .font(.caption.weight(.black))
                                                .foregroundStyle(.white)
                                                .opacity(store.accentTheme == theme ? 1 : 0)
                                        )
                                        .overlay(
                                            Circle()
                                                .stroke(Color.primary.opacity(store.accentTheme == theme ? 0.85 : 0), lineWidth: 2)
                                                .padding(-3)
                                        )
                                        .accessibilityLabel(Text(theme.title))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, AppTheme.Space.s)
                    } label: {
                        HStack {
                            Label("主题色", systemImage: "paintpalette")
                                .foregroundStyle(.primary)
                            Spacer()
                            Circle()
                                .fill(store.accentTheme.color)
                                .frame(width: 18, height: 18)
                        }
                    }

                    NavigationLink {
                        PaymentMethodsView()
                    } label: {
                        Label("支付方式", systemImage: "creditcard")
                    }
                    NavigationLink {
                        ArchivedSubscriptionsView()
                    } label: {
                        Label("归档订阅", systemImage: "archivebox")
                    }
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
                } footer: {
                    Text(statusText)
                }

                Section {
                    Toggle(isOn: $store.iCloudSyncEnabled) {
                        Label("通过 iCloud 同步订阅", systemImage: "icloud")
                    }
                } footer: {
                    Text("开启后自动同步：本机更改即时上传，其他设备的更改自动合并。真机需 Apple ID 与应用 iCloud 权限。")
                }

                Section {
                    Button {
                        openURL(feedbackMailURL())
                    } label: {
                        HStack {
                            Label("发送反馈", systemImage: "envelope")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                } footer: {
                    Text("邮件会自动附带版本与设备信息，便于定位问题。")
                }

                Section {
                    Button {
                        showTips = true
                    } label: {
                        HStack {
                            Label("支持开发者", systemImage: "heart")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
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
            .sheet(isPresented: $showTips) { TipSheet(tips: tips) }
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

    private func deviceModelIdentifier() -> String {
        var sys = utsname()
        uname(&sys)
        let mirror = Mirror(reflecting: sys.machine)
        let id = mirror.children.reduce(into: "") { result, element in
            if let value = element.value as? Int8, value != 0 {
                result.append(Character(UnicodeScalar(UInt8(value))))
            }
        }
        return id.isEmpty ? "Unknown" : id
    }

    private func feedbackMailURL() -> URL {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        let ios = UIDevice.current.systemVersion
        let model = deviceModelIdentifier()
        let intro = String(localized: "请在此描述你的问题或建议：")
        let body = """
        \(intro)


        ——
        App: EON v\(v) (\(b))
        iOS: \(ios)
        Device: \(model)
        """
        let subject = String(localized: "EON 反馈")
        var c = URLComponents()
        c.scheme = "mailto"
        c.path = "eatpoc@gmail.com"
        c.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        return c.url ?? URL(string: "mailto:eatpoc@gmail.com")!
    }
}

private struct TipSheet: View {
    @ObservedObject var tips: TipStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if !tips.loaded {
                        HStack { Text("加载中…"); Spacer(); ProgressView() }
                    } else if tips.products.isEmpty {
                        Text("打赏暂不可用").foregroundStyle(.secondary)
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
                    Text("选择金额")
                } footer: {
                    Text("打赏完全自愿，用于支持后续开发，不解锁任何功能。")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("支持开发者")
            .navigationBarTitleDisplayMode(.inline)
            .tint(AppTheme.accent)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .alert("感谢支持！", isPresented: $tips.thanksShown) {
                Button("好的", role: .cancel) { dismiss() }
            } message: {
                Text("你的支持是持续更新的动力。")
            }
            .task { await tips.load() }
        }
    }

    private func tipIcon(_ index: Int) -> String {
        ["cup.and.saucer", "fork.knife", "gift"][safe: index] ?? "heart"
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
