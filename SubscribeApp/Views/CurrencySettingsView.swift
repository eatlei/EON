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
                    Task {
                        await store.refreshRates()
                        await MainActor.run { refreshing = false }
                    }
                } label: {
                    HStack(spacing: 12) {
                        SettingsIcon(name: "arrow.clockwise")
                        Text("立即刷新汇率").foregroundStyle(AppTheme.ink)
                        Spacer()
                        if refreshing { ProgressView() }
                    }
                }
                .buttonStyle(.plain)
            } footer: {
                Text("汇率每天自动刷新，可能导致订阅价格变动。\(rateUpdatedText)")
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
