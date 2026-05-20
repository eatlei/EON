import SwiftUI

struct CurrencySettingsView: View {
    @EnvironmentObject private var store: SubscriptionStore
    @State private var refreshing = false
    @State private var refreshedToastShown = false

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
                        await MainActor.run {
                            refreshing = false
                            refreshedToastShown = true
                        }
                    }
                } label: {
                    HStack(spacing: 12) {
                        // 旋转走 SpinningIcon —— 持续转;结束时平滑转完最后一圈,
                        // 不再有"360 回弹到 0"的回退动效。
                        SpinningIcon(name: "arrow.clockwise", isSpinning: refreshing)
                        Text("立即刷新汇率").foregroundStyle(AppTheme.ink)
                        Spacer()
                    }
                    // 整行 hit area —— SwiftUI Button 默认 hit area 是文本内容包围盒,
                    // List 里那一行剩下的灰区点不到。给 label 内 HStack 加 contentShape
                    // 后,整行宽度都吃点击事件。下文每个 Button.label 都用同一个套路。
                    .contentShape(Rectangle())
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
        .toolbarVisibility(.hidden, for: .tabBar)
        .task { await store.refreshRatesIfStale() }
        .toast($refreshedToastShown, text: "汇率已更新")
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
