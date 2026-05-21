import SwiftUI

/// 把 App 里所有的小彩蛋集中列出来,每个写清楚:做什么 + 怎么触发 + 开关。
/// 用户既能知道这些隐藏能力,也能在不喜欢的时候关掉。
///
/// 这页本身也是个彩蛋:背景挂了一个 SpriteKit 物理场景,把活跃订阅的图标
/// 都烤成小球从顶部掉下来,然后跟着设备重力滚来滚去 + 撞击震动。List 行
/// 走 Liquid Glass 半透明,球能从行底下隐约透出来。订阅为空时不画球。
struct EasterEggSettingsView: View {
    @EnvironmentObject private var store: SubscriptionStore

    var body: some View {
        ZStack {
            // 背景球。.allowsHitTesting(false) 把所有点击 / 滚动都让给 List,
            // 球纯粹是看 / 摇着玩,不能拖。
            //
            // 数据源用"全部未归档的订阅"(包括暂停的),让用户看到的球数 = 订阅
            // 列表里实际看到的条数。之前用 activeSubscriptions 会过滤掉 paused
            // 状态,导致用户"明明有 12 个订阅但只看到 6 个球"。归档订阅理所当然
            // 不出现,因为它们已经不算活跃数据。
            let ballSubs = store.subscriptions.filter { !$0.isArchived }
            if !ballSubs.isEmpty {
                EasterEggBallsView(
                    subscriptions: ballSubs,
                    solidEmoji: store.easterEggs.solidEmojiBalls
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
                // 切换纯色模式时换 id → 整个物理场景重建,球以新样式重新掉一遍。
                .id(store.easterEggs.solidEmojiBalls ? "solid" : "icon")
            }

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
                    .listRowBackground(glassRowBackground)
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
                    .listRowBackground(glassRowBackground)
                } footer: {
                    Text("每天第一次回到\"总览\"页时,你最贵的几个订阅图标会像小彩带一样从上方飘下来。一天最多一次,1.5 秒结束,只是打个招呼。")
                }

                // 3. 彩蛋页·物理球(本页这个)。说明 + 一个"纯色表情"开关。
                Section {
                    eggHeader(
                        symbol: "circle.grid.3x3.fill",
                        title: "彩蛋页 · 订阅小球",
                        trigger: "进入本页"
                    )
                    .listRowBackground(glassRowBackground)

                    Toggle(isOn: $store.easterEggs.solidEmojiBalls) {
                        eggHeader(
                            symbol: "face.smiling",
                            title: "纯色表情球",
                            trigger: "本页开关"
                        )
                    }
                    .listRowBackground(glassRowBackground)
                } footer: {
                    Text("现在屏幕下面那些小球,就是你所有活跃订阅的图标。手机歪一歪它们会滚,撞墙撞球都会有一点震动。订阅多的话只取前 \(EasterEggBallsView.ballCap) 个。开启「纯色表情球」后,小球会变成订阅主色 + 一个随机表情。")
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
            // 把 List 自己的灰底关掉,让背景的 SpriteView 显出来。每一行单独
            // 套 .glassEffect 出 Liquid Glass 质感,内容仍清晰可读。
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("小玩具")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 单行的 Liquid Glass 背景。圆角对齐 insetGrouped 的视觉。
    private var glassRowBackground: some View {
        Color.clear
            .glassEffect(
                .regular,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
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
