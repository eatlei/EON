import SwiftUI

struct SubscriptionsView: View {
    @EnvironmentObject private var store: SubscriptionStore
    @State private var editing: Subscription?
    @State private var search = ""
    @State private var sort: SortOption = .addedNewest
    /// 视图换算口径:把所有订阅的金额换算到这个周期下展示(月/季/年)。
    /// 例:年付订阅 ¥120 在"按月"下显示 ¥10/月,在"按季"下显示 ¥30/季。
    @State private var viewPeriod: ViewPeriod = .monthly
    /// 随机排序用的盐。用户每次在菜单里点"随机",这个值就换一遍 → 同 sort 选项
    /// 但订阅顺序刷新。.sorted 的对象是 hash("\(id)-\(seed)"),所以同一 seed
    /// 下排序是稳定的(每次 view 重渲不会跳)。
    @State private var randomSeed: Int = 0

    private var rows: [Subscription] {
        let f = store.subscriptions.filter { sub in
            guard !sub.isArchived else { return false }
            return search.isEmpty
                || sub.name.localizedCaseInsensitiveContains(search)
                || sub.plan.localizedCaseInsensitiveContains(search)
                || sub.displayCategoryTitle.localizedCaseInsensitiveContains(search)
                || sub.category.rawValue.localizedCaseInsensitiveContains(search)
        }
        switch sort {
        case .addedNewest:
            // 最新加的排最上;老数据没 startDate 的退到 nextBillingDate 当替身。
            return f.sorted { $0.effectiveStartDate > $1.effectiveStartDate }
        case .duration:
            return f.sorted {
                $0.billingCycle.days(customDays: $0.customCycleDays)
                > $1.billingCycle.days(customDays: $1.customCycleDays)
            }
        case .costHighLow:
            return f.sorted {
                $0.monthlyCost(in: store.baseCurrency, converter: store.converter)
                > $1.monthlyCost(in: store.baseCurrency, converter: store.converter)
            }
        case .costLowHigh:
            return f.sorted {
                $0.monthlyCost(in: store.baseCurrency, converter: store.converter)
                < $1.monthlyCost(in: store.baseCurrency, converter: store.converter)
            }
        case .name:
            return f.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .random:
            // 哈希盐稳定 + 同 seed 下顺序不抖。换 seed 才会出新顺序。
            let seed = randomSeed
            return f.sorted {
                "\($0.id.uuidString)-\(seed)".hashValue
                < "\($1.id.uuidString)-\(seed)".hashValue
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Space.l) {
                    // 搜索框跟随页面滚动,不再吸顶 —— 仅在用户主动滚回顶部
                    // 才看得到,避免占住固定可视区。
                    searchBar.reveal(0)

                    if rows.isEmpty {
                        VStack(spacing: AppTheme.Space.m) {
                            Image(systemName: "rectangle.stack").font(.system(size: 40, weight: .light))
                                .foregroundStyle(AppTheme.tertiary)
                            Text(search.isEmpty ? "还没有订阅" : "没有匹配的订阅")
                                .font(.headline).foregroundStyle(AppTheme.ink)
                        }.frame(maxWidth: .infinity).padding(.top, 100).reveal(1)
                    } else {
                        LazyVStack(spacing: AppTheme.Space.m) {
                            ForEach(Array(rows.enumerated()), id: \.element.id) { i, sub in
                                Button { editing = sub } label: {
                                    Row(
                                        subscription: sub,
                                        viewPeriod: viewPeriod,
                                        onArchive: { store.archive(ids: [sub.id]) },
                                        onDelete: { store.delete(ids: [sub.id]) }
                                    )
                                }
                                .buttonStyle(.plain)
                                .reveal(i + 1)
                            }
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Space.xl)
                .padding(.top, AppTheme.Space.m)
                .padding(.bottom, AppTheme.dockClearance)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppTheme.canvas.ignoresSafeArea())
            .safeAreaInset(edge: .top, spacing: 0) {
                // 吸顶只保留 月/季/年 + 排序按钮,不带底板,跟 Overview 一致。
                stickyHeader
                    .padding(.horizontal, AppTheme.Space.xl)
                    .padding(.top, AppTheme.Space.s)
                    .padding(.bottom, AppTheme.Space.s)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $editing) { SubscriptionEditorView(subscription: $0) }
        }
    }

    /// 吸顶部分:仅 月/季/年 胶囊 + 排序圆按钮,没有底板。
    @ViewBuilder
    private var stickyHeader: some View {
        HStack(spacing: AppTheme.Space.m) {
            SegmentedPill(
                selection: $viewPeriod,
                items: ViewPeriod.allCases.map { ($0, $0.title) }
            )
            .frame(maxWidth: 200)   // 跟 Overview 同款最小宽度

            Spacer()

            Menu {
                // 普通几种排序方式 —— Picker 风格,选中态由 .pickerStyle(.inline) 自动打勾
                Picker(selection: $sort) {
                    ForEach(SortOption.allCases.filter { $0 != .random }) { opt in
                        Label(opt.title, systemImage: opt.icon).tag(opt)
                    }
                } label: { EmptyView() }
                .pickerStyle(.inline)

                Divider()

                // 随机排序单独一个按钮 —— 点一下就刷新 randomSeed,即便当前
                // 已经选中 random 也能"再随机一次"(Picker 模式下重复点同
                // 一选项不会触发任何事件,这里走 Button 路径绕开它)。
                Button {
                    randomSeed = Int.random(in: Int.min...Int.max)
                    sort = .random
                } label: {
                    Label(
                        sort == .random
                            ? String(localized: "再随机一次")
                            : SortOption.random.title,
                        systemImage: SortOption.random.icon
                    )
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.ink)
                    .frame(width: 40, height: 40)
                    .glassEffect(.regular, in: Capsule())
            }
        }
    }

    /// 搜索框 —— 跟着内容滚动,顶部初始可见,滚下去就消失。
    @ViewBuilder
    private var searchBar: some View {
        HStack(spacing: AppTheme.Space.s) {
            Image(systemName: "magnifyingglass").foregroundStyle(AppTheme.tertiary)
            TextField("搜索名称、套餐或分类", text: $search)
                .textInputAutocapitalization(.never)
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(AppTheme.tertiary)
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, AppTheme.Space.m)
        .padding(.vertical, 10)
        .background(AppTheme.surface, in: Capsule())
        .overlay(Capsule().stroke(AppTheme.hairline, lineWidth: 0.5))
    }
}

private enum SortOption: String, CaseIterable, Identifiable {
    /// 按添加时间(startDate)倒序 —— 最新加的在最上。之前叫 renewalDate
    /// 是按 nextBillingDate 排,语义偏 "下次扣费",改名 + 改字段后更直观。
    case addedNewest
    /// 按周期长度从长到短(周付 < 月付 < 季付 < 年付,这里反向显示 → 最长在前)
    case duration
    /// 按月费高到低
    case costHighLow
    /// 按月费低到高
    case costLowHigh
    /// 按名称 A → Z
    case name
    /// 完全随机 —— 用 randomSeed 当哈希盐,每次"重新随机"时换种子,
    /// 同一批订阅在用户保持 .random 期间排序稳定。
    case random

    var id: String { rawValue }

    var title: String {
        switch self {
        case .addedNewest: String(localized: "按添加时间")
        case .duration:    String(localized: "按周期长度")
        case .costHighLow: String(localized: "按费用 · 高 → 低")
        case .costLowHigh: String(localized: "按费用 · 低 → 高")
        case .name:        String(localized: "按名称")
        case .random:      String(localized: "随机")
        }
    }

    var icon: String {
        switch self {
        case .addedNewest: "calendar.badge.plus"
        case .duration:    "timer"
        case .costHighLow: "arrow.down.to.line"
        case .costLowHigh: "arrow.up.to.line"
        case .name:        "textformat"
        case .random:      "shuffle"
        }
    }
}

/// 列表换算口径(把任意周期的订阅都摊到指定时间单位下展示)。
enum ViewPeriod: String, CaseIterable, Identifiable, Hashable {
    case monthly, quarterly, yearly
    var id: String { rawValue }
    /// 用 "周期·X" 短 key,跟 Overview 的 SpendPeriod 共享缩写翻译,胶囊宽度一致。
    var title: String {
        switch self {
        case .monthly:   String(localized: "周期·月")
        case .quarterly: String(localized: "周期·季")
        case .yearly:    String(localized: "周期·年")
        }
    }
    /// 月费乘上这个系数 = 该周期对应金额。
    var monthlyMultiplier: Double {
        switch self {
        case .monthly: 1
        case .quarterly: 3
        case .yearly: 12
        }
    }
    /// 金额后的紧凑后缀。
    var suffix: String {
        switch self {
        case .monthly:   String(localized: "/月")
        case .quarterly: String(localized: "/季")
        case .yearly:    String(localized: "/年")
        }
    }
}

private struct Row: View {
    @EnvironmentObject private var store: SubscriptionStore
    @Environment(\.colorScheme) private var colorScheme
    let subscription: Subscription
    let viewPeriod: ViewPeriod
    let onArchive: () -> Void
    let onDelete: () -> Void

    private var colored: Bool { store.coloredSubscriptionCards }
    private var isDark: Bool { colorScheme == .dark }

    /// 卡片底色:.tile 取色号,.image 取图像平均色,均回退分类色(自定义优先)。
    private var cardColor: Color {
        switch subscription.icon {
        case .tile(_, let hex):
            return hex.map { Color(hexString: $0) } ?? subscription.displayCategoryColor
        case .image(let id):
            if let ui = IconStore.averageColor(id) { return Color(uiColor: ui) }
            return subscription.displayCategoryColor
        }
    }

    /// 在当前 viewPeriod 口径下,该订阅折算到的金额(已换算到 baseCurrency)。
    private var displayedAmount: Double {
        let monthly = subscription.monthlyCost(in: store.baseCurrency, converter: store.converter)
        return monthly * viewPeriod.monthlyMultiplier
    }

    /// 副标题:精简显示。优先「套餐 · 分类」;套餐为空时只展示分类。
    /// 周期不再展示在这里,因为整页已经统一了换算口径(/月 /季 /年)。
    private var subtitle: String {
        let plan = subscription.plan.trimmingCharacters(in: .whitespaces)
        if plan.isEmpty { return subscription.displayCategoryTitle }
        return "\(plan) · \(subscription.displayCategoryTitle)"
    }

    var body: some View {
        HStack(spacing: AppTheme.Space.m) {
            CategoryGlyph(subscription: subscription, size: 44)
                .shadow(color: colored ? .black.opacity(isDark ? 0.25 : 0.10) : .clear,
                        radius: 6, x: 0, y: 3)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(subscription.name).font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                    if subscription.status == .trial {
                        Text("试用").font(.caption2.weight(.bold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(AppTheme.accent.opacity(0.14), in: Capsule())
                            .foregroundStyle(AppTheme.accent)
                    }
                    // 用户明确关闭了"计入统计" → 用一个低调灰色徽章告诉他,
                    // 免得回头看着 Hero 总额对不上发懵。
                    if !subscription.includeInStatistics {
                        Text("不计入")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(AppTheme.tertiary.opacity(0.18), in: Capsule())
                            .foregroundStyle(AppTheme.secondary)
                    }
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: AppTheme.Space.s)
            VStack(alignment: .trailing, spacing: 4) {
                // 不再展示 /月 /季 /年 后缀 —— 整页顶部的视图切换已经表明了口径,
                // 在每张卡片上再写一次是冗余。
                Text(store.converter.format(displayedAmount, currency: store.baseCurrency))
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                // "已扣 N 次"小徽章 —— 默默告诉用户这笔订阅累计已经付过几次费,
                // 跟下方的下次扣费日叠在一起,垂直空间也不太挤。
                let billed = subscription.billingCountElapsed()
                if billed > 0 {
                    Text(String(localized: "已扣 \(billed) 次"))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(AppTheme.secondary)
                }
                Text(subscription.nextBillingDate.formatted(.dateTime.month().day()))
                    .font(.caption2)
                    .foregroundStyle(AppTheme.tertiary)
            }
            Menu {
                Button { onArchive() } label: {
                    Label("归档", systemImage: "archivebox")
                }
                Divider()
                Button(role: .destructive, action: onDelete) {
                    Label("删除", systemImage: "trash")
                }
                .tint(.red)
            } label: {
                Image(systemName: "ellipsis").font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.tertiary)
                    .frame(width: 28, height: 36)
            }
        }
        .padding(AppTheme.Space.l)
        .background(coloredCardBackground)
        .glassBorder()
        .opacity(subscription.isActive ? 1 : 0.5)
    }

    /// 卡片底色 = AppTheme.surface(自动适配明暗模式)+ icon 主色径向光晕。
    /// 光晕透明度在浅色模式下显著降低,避免在白底页面里"突兀"。
    /// 深色模式还保留 Apple Library 那种"暗玻璃 + 浓色光晕"的味道。
    @ViewBuilder
    private var coloredCardBackground: some View {
        if colored {
            ZStack {
                AppTheme.surface

                // 深色模式才需要的顶部 sheen + 底部 shadow(浅色模式上加这层就脏了)
                if isDark {
                    LinearGradient(
                        colors: [.white.opacity(0.04), .clear, .black.opacity(0.18)],
                        startPoint: .top, endPoint: .bottom
                    )
                }

                // 左侧色彩光晕 —— 加密 stop 数量、扩大 endRadius,让右半边的衰减
                // 更平滑,不再有"突然消失"的硬边。
                RadialGradient(
                    stops: [
                        .init(color: cardColor.opacity(isDark ? 0.95 : 0.38), location: 0.00),
                        .init(color: cardColor.opacity(isDark ? 0.70 : 0.27), location: 0.20),
                        .init(color: cardColor.opacity(isDark ? 0.45 : 0.18), location: 0.40),
                        .init(color: cardColor.opacity(isDark ? 0.25 : 0.10), location: 0.60),
                        .init(color: cardColor.opacity(isDark ? 0.10 : 0.04), location: 0.80),
                        .init(color: cardColor.opacity(isDark ? 0.03 : 0.01), location: 0.92),
                        .init(color: .clear,                                  location: 1.00),
                    ],
                    center: UnitPoint(x: 0.13, y: 0.50),
                    startRadius: 0,
                    endRadius: 320  // 比卡片宽更大一点,让边缘自然消逝在卡片外
                )

                // 深色模式上的玻璃反光高光 —— 浅色下加白色高光等于没加,直接跳过。
                if isDark {
                    LinearGradient(
                        colors: [.white.opacity(0.06), .clear],
                        startPoint: .top, endPoint: .center
                    )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius))
        } else {
            AppTheme.surface.clipShape(RoundedRectangle(cornerRadius: AppTheme.radius))
        }
    }

}

#Preview {
    SubscriptionsView().environmentObject(SubscriptionStore())
}
