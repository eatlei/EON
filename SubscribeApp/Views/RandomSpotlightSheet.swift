import SwiftUI

/// 摇一摇彩蛋:在任意页面摇手机,从活跃订阅里随机抽一个,用大卡片展示出来,
/// 让用户做一个 "留着 / 归档" 的决策。配合 medium haptic 给"翻牌"的仪式感。
/// 空订阅列表时不弹。
struct RandomSpotlightSheet: View {
    @EnvironmentObject private var store: SubscriptionStore
    @Environment(\.dismiss) private var dismiss

    /// 当前被聚焦的订阅。允许"再来一次"重新抽。
    @State private var spotlight: Subscription
    /// 触发 SensoryFeedback 的计数器,每次重新抽 +1。
    @State private var shuffleTick: Int = 0
    /// 进场瞬间 +1,给一个 success 反馈 —— 跟 ContentView 上的 shake heavy
    /// haptic 接力,形成"摇到了!"的双段触觉。
    @State private var appearTick: Int = 0

    init(initial: Subscription) {
        _spotlight = State(initialValue: initial)
    }

    /// 滚动到 >= 今天的"真·下次扣费日"。直接用 spotlight.nextBillingDate 的话,
    /// 老订阅(锚点早就过去)会恒为负数 → 永远显示"已逾期",这正是之前的 bug。
    private var upcomingBillingDate: Date { spotlight.upcomingBillingDate() }

    private var daysToBill: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let target = cal.startOfDay(for: upcomingBillingDate)
        return cal.dateComponents([.day], from: today, to: target).day ?? 0
    }

    private var lifetimeText: String {
        let amount = spotlight.lifetimeSpend(in: store.baseCurrency, converter: store.converter)
        return store.converter.format(amount, currency: store.baseCurrency)
    }

    private var billingCountText: String {
        let count = spotlight.billingCountElapsed()
        return String(localized: "\(count) 次")
    }

    private var nextBillingText: String {
        if daysToBill <= 0 { return String(localized: "今天") }
        if daysToBill == 1 { return String(localized: "明天") }
        return String(localized: "还有 \(daysToBill) 天")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.canvas.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: AppTheme.Space.xl) {
                        header
                        statsCard
                        actions
                    }
                    .padding(.horizontal, AppTheme.Space.xl)
                    .padding(.top, AppTheme.Space.l)
                    .padding(.bottom, AppTheme.Space.xxl)
                    .readableWidth(540)
                }
            }
            .navigationTitle("🎲 摇出来的")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: shuffleTick)
            .sensoryFeedback(.success, trigger: appearTick)
            .onAppear { appearTick &+= 1 }
        }
    }

    // MARK: - Header (big icon + name + flavor)

    @ViewBuilder
    private var header: some View {
        VStack(spacing: AppTheme.Space.m) {
            ZStack {
                // 在大图标背后画一圈淡淡的同色光晕,跟订阅自己的色调挂钩
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [spotlight.displayCategoryColor.opacity(0.35), .clear],
                            center: .center, startRadius: 0, endRadius: 120
                        )
                    )
                    .frame(width: 220, height: 220)
                CategoryGlyph(subscription: spotlight, size: 100)
                    .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 6)
                    // 用 id 强制每次换 spotlight 时重建,让 SwiftUI 跑入场动画
                    .id(spotlight.id)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }

            VStack(spacing: 4) {
                Text(spotlight.name)
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(AppTheme.ink)
                    .contentTransition(.opacity)
                Text(spotlight.displayCategoryTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(spotlight.displayCategoryColor)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(spotlight.displayCategoryColor.opacity(0.14), in: Capsule())
            }

            Text("它该留着,还是该砍掉?")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Stats card

    @ViewBuilder
    private var statsCard: some View {
        VStack(spacing: 0) {
            statRow(label: "下次扣费", value: nextBillingText,
                    detail: upcomingBillingDate.formatted(.dateTime.year().month().day()))
            Hairline()
            statRow(label: "累计已支付", value: lifetimeText, detail: nil)
            Hairline()
            statRow(label: "已扣费次数", value: billingCountText, detail: nil)
            Hairline()
            statRow(label: "扣费周期", value: spotlight.billingCycle.title, detail: nil)
        }
        .padding(AppTheme.Space.m)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.radius))
        .glassBorder()
    }

    @ViewBuilder
    private func statRow(label: LocalizedStringKey, value: String, detail: String?) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondary)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(value)
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(AppTheme.ink)
                if let detail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.tertiary)
                }
            }
        }
        .padding(.vertical, AppTheme.Space.s)
    }

    // MARK: - Decision buttons

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: AppTheme.Space.m) {
            HStack(spacing: AppTheme.Space.m) {
                // "再摇一次":换一个抽样
                Button {
                    reroll()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "die.face.5")
                        Text("再来一个")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.radius))
                    .glassBorder()
                }
                .buttonStyle(.plain)

                // "留着":赞许地关闭
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("留着吧")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: AppTheme.radius))
                }
                .buttonStyle(.plain)
            }

            // 全宽红色"归档"按钮,跟"留着"对位但视觉权重稍低
            Button {
                store.archive(ids: [spotlight.id])
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "archivebox")
                    Text("归档了 · 砍掉这笔")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: AppTheme.radius))
            }
            .buttonStyle(.plain)
        }
    }

    private func reroll() {
        // 从剩余的活跃订阅里随机抽一个,尽量不重复当前那位
        let pool = store.activeSubscriptions.filter { $0.id != spotlight.id }
        if let picked = pool.randomElement() {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                spotlight = picked
            }
            shuffleTick &+= 1
        }
    }
}
