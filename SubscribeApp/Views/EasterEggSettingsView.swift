import SwiftUI

/// 把 App 里所有的小彩蛋集中列出来,每个写清楚:做什么 + 怎么触发 + 开关。
/// 用户既能知道这些隐藏能力,也能在不喜欢的时候关掉。
struct EasterEggSettingsView: View {
    @EnvironmentObject private var store: SubscriptionStore

    var body: some View {
        List {
            // 1. 摇一摇聚焦
            Section {
                Toggle(isOn: $store.easterEggs.shakeSpotlight) {
                    eggHeader(
                        symbol: "iphone.gen3.radiowaves.left.and.right",
                        title: "摇一摇 · 聚焦订阅",
                        trigger: "摇手机"
                    )
                }
            } footer: {
                Text("摇一下手机,从活跃订阅里随机抽一个出来,弹出一张大卡片,用来快速决策\"这个我还要不要\"。配合震动反馈,有翻牌仪式感。")
            }

            // 2. 每日首启彩带
            Section {
                Toggle(isOn: $store.easterEggs.dailyWelcomeConfetti) {
                    eggHeader(
                        symbol: "sparkles",
                        title: "每日首启 · 订阅彩带",
                        trigger: "每天第一次打开总览"
                    )
                }
            } footer: {
                Text("每天第一次回到\"总览\"页时,你最贵的几个订阅图标会像小彩带一样从上方飘下来。一天最多一次,1.5 秒结束,只是打个招呼。")
            }

            Section {
                EmptyView()
            } footer: {
                Text("彩蛋只是小玩具,不影响任何统计或数据。觉得碍事关掉就行。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.visible)
        .navigationTitle("彩蛋")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 每个彩蛋的标题行 = SF Symbol + 名字 + 触发方式徽章
    @ViewBuilder
    private func eggHeader(symbol: String, title: LocalizedStringKey, trigger: LocalizedStringKey) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 28, height: 28)
                .background(AppTheme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                Text(trigger)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack { EasterEggSettingsView() }
        .environmentObject(SubscriptionStore())
}
