import SwiftUI

struct SubscriptionsView: View {
    @EnvironmentObject private var store: SubscriptionStore
    @State private var editing: Subscription?
    @State private var search = ""
    @State private var sort: SortOption = .renewalDate
    /// 视图换算口径:把所有订阅的金额换算到这个周期下展示(月/季/年)。
    /// 例:年付订阅 ¥120 在"按月"下显示 ¥10/月,在"按季"下显示 ¥30/季。
    @State private var viewPeriod: ViewPeriod = .monthly

    private var rows: [Subscription] {
        let f = store.subscriptions.filter { sub in
            guard !sub.isArchived else { return false }
            return search.isEmpty
                || sub.name.localizedCaseInsensitiveContains(search)
                || sub.plan.localizedCaseInsensitiveContains(search)
                || sub.category.rawValue.localizedCaseInsensitiveContains(search)
        }
        switch sort {
        case .renewalDate: return f.sorted { $0.nextBillingDate < $1.nextBillingDate }
        case .duration: return f.sorted {
            $0.billingCycle.days(customDays: $0.customCycleDays) > $1.billingCycle.days(customDays: $1.customCycleDays) }
        case .cost: return f.sorted {
            $0.monthlyCost(in: store.baseCurrency, converter: store.converter)
            > $1.monthlyCost(in: store.baseCurrency, converter: store.converter) }
        case .name: return f.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    var body: some View {
        NavigationStack {
            AppScreen {
                VStack(spacing: AppTheme.Space.l) {
                    HStack(spacing: AppTheme.Space.s) {
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
                        .padding(AppTheme.Space.m)
                        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.radius))
                        .overlay(RoundedRectangle(cornerRadius: AppTheme.radius).stroke(AppTheme.hairline, lineWidth: 0.5))

                        Menu {
                            Picker("", selection: $sort) {
                                ForEach(SortOption.allCases) {
                                    Label($0.title, systemImage: $0.icon).tag($0)
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.subheadline.weight(.bold)).foregroundStyle(AppTheme.ink)
                                .frame(width: 44, height: 44)
                                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.radius))
                                .overlay(RoundedRectangle(cornerRadius: AppTheme.radius).stroke(AppTheme.hairline, lineWidth: 0.5))
                        }
                    }
                    .reveal(0)

                    // 月/季/年 三档切换 — 整页所有金额按所选口径换算后再展示。
                    // 跟首页 Month/Year 切换、图标库的来源切换共用 SegmentedPill 样式。
                    SegmentedPill(
                        selection: $viewPeriod,
                        items: ViewPeriod.allCases.map { ($0, $0.title) }
                    )
                    .reveal(1)

                    if rows.isEmpty {
                        VStack(spacing: AppTheme.Space.m) {
                            Image(systemName: "rectangle.stack").font(.system(size: 40, weight: .light))
                                .foregroundStyle(AppTheme.tertiary)
                            Text(search.isEmpty ? "还没有订阅" : "没有匹配的订阅")
                                .font(.headline).foregroundStyle(AppTheme.ink)
                        }.frame(maxWidth: .infinity).padding(.top, 100).reveal(2)
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
                                .buttonStyle(.plain).reveal(i + 2)
                            }
                        }
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $editing) { SubscriptionEditorView(subscription: $0) }
        }
    }
}

private enum SortOption: String, CaseIterable, Identifiable {
    case renewalDate, duration, cost, name
    var id: String { rawValue }
    var title: String {
        switch self {
        case .renewalDate: String(localized: "按时间"); case .duration: String(localized: "按周期长度")
        case .cost: String(localized: "按费用"); case .name: String(localized: "按名称")
        }
    }
    var icon: String {
        switch self {
        case .renewalDate: "calendar"; case .duration: "timer"
        case .cost: "banknote"; case .name: "textformat"
        }
    }
}

/// 列表换算口径(把任意周期的订阅都摊到指定时间单位下展示)。
enum ViewPeriod: String, CaseIterable, Identifiable, Hashable {
    case monthly, quarterly, yearly
    var id: String { rawValue }
    var title: String {
        switch self {
        case .monthly:   String(localized: "每月")
        case .quarterly: String(localized: "每季度")
        case .yearly:    String(localized: "每年")
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
    let subscription: Subscription
    let viewPeriod: ViewPeriod
    let onArchive: () -> Void
    let onDelete: () -> Void

    private var colored: Bool { store.coloredSubscriptionCards }

    /// 卡片底色:.tile 取色号,.image 取图像平均色,均回退分类色。
    private var cardColor: Color {
        switch subscription.icon {
        case .tile(_, let hex):
            return hex.map { Color(hexString: $0) } ?? subscription.category.color
        case .image(let id):
            if let ui = IconStore.averageColor(id) { return Color(uiColor: ui) }
            return subscription.category.color
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
        if plan.isEmpty { return subscription.category.title }
        return "\(plan) · \(subscription.category.title)"
    }

    var body: some View {
        HStack(spacing: AppTheme.Space.m) {
            CategoryGlyph(subscription: subscription, size: 44)
                .shadow(color: colored ? .black.opacity(0.25) : .clear,
                        radius: 6, x: 0, y: 3)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(subscription.name).font(.subheadline.weight(.semibold))
                        .foregroundStyle(colored ? Color.white : AppTheme.ink)
                        .shadow(color: colored ? .black.opacity(0.30) : .clear, radius: 2, x: 0, y: 1)
                    if subscription.status == .trial {
                        Text("试用").font(.caption2.weight(.bold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(
                                colored ? Color.white.opacity(0.22) : AppTheme.accent.opacity(0.14),
                                in: Capsule()
                            )
                            .foregroundStyle(colored ? Color.white : AppTheme.accent)
                    }
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(colored ? Color.white.opacity(0.78) : AppTheme.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: AppTheme.Space.s)
            VStack(alignment: .trailing, spacing: 4) {
                // 不再展示 /月 /季 /年 后缀 —— 整页顶部的视图切换已经表明了口径,
                // 在每张卡片上再写一次是冗余。
                Text(store.converter.format(displayedAmount, currency: store.baseCurrency))
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(colored ? Color.white : AppTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .shadow(color: colored ? .black.opacity(0.30) : .clear, radius: 2, x: 0, y: 1)
                Text(subscription.nextBillingDate.formatted(.dateTime.month().day()))
                    .font(.caption2)
                    .foregroundStyle(colored ? Color.white.opacity(0.72) : AppTheme.tertiary)
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
                    .foregroundStyle(colored ? Color.white.opacity(0.7) : AppTheme.tertiary)
                    .frame(width: 28, height: 36)
            }
        }
        .padding(AppTheme.Space.l)
        .background(coloredCardBackground)
        .overlay(coloredCardBorder)
        .opacity(subscription.isActive ? 1 : 0.5)
    }

    /// 参考 iOS 26 Apple Arcade / Library 卡片风格:深色底 + 左侧从图标色发散的径向光晕,
    /// 越往右越暗,直到接近纯深色。色彩只作"个性提示"而不是 dominant fill,既有性格
    /// 又克制高级。
    @ViewBuilder
    private var coloredCardBackground: some View {
        if colored {
            ZStack {
                Color(red: 0.10, green: 0.11, blue: 0.14)
                LinearGradient(
                    colors: [.white.opacity(0.04), .clear, .black.opacity(0.18)],
                    startPoint: .top, endPoint: .bottom
                )
                RadialGradient(
                    stops: [
                        .init(color: cardColor.opacity(0.95), location: 0.0),
                        .init(color: cardColor.opacity(0.55), location: 0.35),
                        .init(color: cardColor.opacity(0.18), location: 0.7),
                        .init(color: .clear,                  location: 1.0),
                    ],
                    center: UnitPoint(x: 0.13, y: 0.50),
                    startRadius: 0,
                    endRadius: 240
                )
                LinearGradient(
                    colors: [.white.opacity(0.06), .clear],
                    startPoint: .top, endPoint: .center
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius))
        } else {
            AppTheme.surface.clipShape(RoundedRectangle(cornerRadius: AppTheme.radius))
        }
    }

    @ViewBuilder
    private var coloredCardBorder: some View {
        if colored {
            RoundedRectangle(cornerRadius: AppTheme.radius)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.18), .white.opacity(0.04), .clear],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 0.6
                )
        } else {
            RoundedRectangle(cornerRadius: AppTheme.radius)
                .stroke(AppTheme.hairline, lineWidth: 0.5)
        }
    }
}

#Preview {
    SubscriptionsView().environmentObject(SubscriptionStore())
}
