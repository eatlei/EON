import SwiftUI

struct SubscriptionsView: View {
    @EnvironmentObject private var store: SubscriptionStore
    @State private var editing: Subscription?
    @State private var search = ""
    @State private var sort: SortOption = .renewalDate
    @State private var cycleFilter: BillingCycle? = nil

    private var rows: [Subscription] {
        let f = store.subscriptions.filter { sub in
            guard !sub.isArchived else { return false }
            if let cf = cycleFilter, sub.billingCycle != cf { return false }
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
                            Section(header: Text("筛选周期")) {
                                Picker("", selection: $cycleFilter) {
                                    Text("全部").tag(BillingCycle?.none)
                                    ForEach(BillingCycle.allCases) { c in
                                        Text(c.title).tag(Optional(c))
                                    }
                                }
                            }
                            Section(header: Text("排序")) {
                                Picker("", selection: $sort) {
                                    ForEach(SortOption.allCases) {
                                        Label($0.title, systemImage: $0.icon).tag($0)
                                    }
                                }
                            }
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "line.3.horizontal.decrease.circle")
                                    .font(.subheadline.weight(.bold)).foregroundStyle(AppTheme.ink)
                                    .frame(width: 44, height: 44)
                                    .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.radius))
                                    .overlay(RoundedRectangle(cornerRadius: AppTheme.radius).stroke(AppTheme.hairline, lineWidth: 0.5))
                                if cycleFilter != nil {
                                    Circle()
                                        .fill(AppTheme.accent)
                                        .frame(width: 8, height: 8)
                                        .offset(x: -6, y: 6)
                                }
                            }
                        }
                    }
                    .reveal(0)

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
                                        onArchive: { store.archive(ids: [sub.id]) },
                                        onDelete: { store.delete(ids: [sub.id]) }
                                    )
                                }
                                .buttonStyle(.plain).reveal(i + 1)
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

private struct Row: View {
    @EnvironmentObject private var store: SubscriptionStore
    let subscription: Subscription
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
                Text("\(subscription.plan) · \(subscription.category.title) · \(subscription.billingCycle.title)")
                    .font(.caption)
                    .foregroundStyle(colored ? Color.white.opacity(0.78) : AppTheme.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: AppTheme.Space.s)
            VStack(alignment: .trailing, spacing: 4) {
                // 显示**本周期**实际金额(按用户当前 baseCurrency 换算),配上 /月 /年 /季
                // 这种短后缀,一眼就能区分订阅是月付/年付/季付/周付/自定义。
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(store.converter.format(
                        store.converter.convert(subscription.price,
                                                from: subscription.currency,
                                                to: store.baseCurrency),
                        currency: store.baseCurrency))
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(colored ? Color.white : AppTheme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .shadow(color: colored ? .black.opacity(0.30) : .clear, radius: 2, x: 0, y: 1)
                    Text(subscription.billingCycle.shortSuffix(customDays: subscription.customCycleDays))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(colored ? Color.white.opacity(0.72) : AppTheme.secondary)
                }
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
                // 1. 深色底(不分浅色/深色模式,卡片本身就是"暗色玻璃"风,跟 Apple 一致)
                Color(red: 0.10, green: 0.11, blue: 0.14)

                // 2. 顶部极淡 sheen + 底部一抹更深的阴影,给一点点立体感
                LinearGradient(
                    colors: [.white.opacity(0.04), .clear, .black.opacity(0.18)],
                    startPoint: .top, endPoint: .bottom
                )

                // 3. 关键:左侧的彩色径向光晕(icon 色),从图标位置发散,右半边几乎消失
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

                // 4. 顶部一道更细微的反光,让卡片像有玻璃表面
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

    /// 卡片边:彩色版用极淡的白色描边(玻璃感),素色版保持原 hairline。
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
