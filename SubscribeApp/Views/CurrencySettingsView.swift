import SwiftUI

struct CurrencySettingsView: View {
    @EnvironmentObject private var store: SubscriptionStore
    @State private var refreshing = false

    private var sortedCurrencies: [CurrencyCode] {
        CurrencyCode.allCases.sorted { $0.rawValue < $1.rawValue }
    }

    var body: some View {
        List {
            Section {
                ForEach(sortedCurrencies) { c in
                    Button {
                        store.baseCurrency = c
                    } label: {
                        HStack {
                            Text("\(c.rawValue) · \(c.title)").foregroundStyle(.primary)
                            Spacer()
                            if store.baseCurrency == c {
                                Image(systemName: "checkmark").foregroundStyle(.primary)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("默认币种")
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
                    HStack(spacing: 12) {
                        SettingsIcon(name: "chart.line.uptrend.xyaxis")
                        Text("汇率明细")
                    }
                }

                Button {
                    guard !refreshing else { return }
                    refreshing = true
                    let start = Date()
                    Task {
                        await store.refreshRates()
                        // 即便后台请求秒回,也保证图标至少转完一整圈,
                        // 让用户看得到"我点了它"的视觉反馈。
                        let elapsed = Date().timeIntervalSince(start)
                        let minSpin: TimeInterval = 0.9
                        if elapsed < minSpin {
                            try? await Task.sleep(nanoseconds: UInt64((minSpin - elapsed) * 1_000_000_000))
                        }
                        await MainActor.run { refreshing = false }
                    }
                } label: {
                    HStack(spacing: 12) {
                        // 旋转角度只跟 refreshing 翻转,配合 0.9s 节奏的 repeatForever。
                        // 短请求会被上面的 sleep 拉到 0.9s,所以肉眼一定能看到一圈。
                        SettingsIcon(name: "arrow.clockwise")
                            .rotationEffect(.degrees(refreshing ? 360 : 0))
                            .animation(
                                refreshing
                                    ? .linear(duration: 0.9).repeatForever(autoreverses: false)
                                    : .default,
                                value: refreshing
                            )
                        Text("立即刷新汇率").foregroundStyle(AppTheme.ink)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            } footer: {
                Text("每天自动同步最新汇率,订阅价格会跟着浮动。\(rateUpdatedText)")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.visible)
        .navigationTitle("货币")
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.refreshRatesIfStale() }
    }

    private var rateUpdatedText: String {
        guard let d = store.ratesUpdatedAt else { return String(localized: "（暂用内置汇率）") }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        let dateStr = f.string(from: d)
        return String(localized: "上次更新 \(dateStr)。")
    }
}

#Preview {
    NavigationStack { CurrencySettingsView() }
        .environmentObject(SubscriptionStore())
}
