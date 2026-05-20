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
                        // 左侧刷新图标在请求进行时连续旋转,跑完后停在原位 —— 一个
                        // .linear.repeatForever 动画绑在 refreshing 状态上,通过修改
                        // rotation 触发,Swift 6 不需要写 onChange/Timer。
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
