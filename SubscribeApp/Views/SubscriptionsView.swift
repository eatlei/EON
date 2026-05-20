import SwiftUI

struct SubscriptionsView: View {
    @EnvironmentObject private var store: SubscriptionStore
    @State private var editing: Subscription?
    @State private var search = ""
    @State private var sort: SortOption = .renewalDate

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
                                ForEach(SortOption.allCases) { Label($0.title, systemImage: $0.icon).tag($0) }
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
            VStack(alignment: .trailing, spacing: 3) {
                Text(store.converter.format(
                    subscription.monthlyCost(in: store.baseCurrency, converter: store.converter),
                    currency: store.baseCurrency))
                    .font(.amountSmall())
                    .foregroundStyle(colored ? Color.white : AppTheme.ink)
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

    /// 卡片底:基础色 + 顶亮底暗的线性渐变 + 左上角径向高光,做出"打光的塑料/玻璃"质感。
    @ViewBuilder
    private var coloredCardBackground: some View {
        if colored {
            ZStack {
                cardColor
                // 顶部柔光 → 中段透明 → 底部加深,营造表面"反光"感
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.20), location: 0.0),
                        .init(color: .white.opacity(0.04), location: 0.35),
                        .init(color: .black.opacity(0.04), location: 0.65),
                        .init(color: .black.opacity(0.28), location: 1.0),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                // 左上角软高光(像有一束光照过来)
                RadialGradient(
                    colors: [.white.opacity(0.22), .clear],
                    center: UnitPoint(x: 0.22, y: 0.18),
                    startRadius: 0, endRadius: 170
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius))
        } else {
            AppTheme.surface.clipShape(RoundedRectangle(cornerRadius: AppTheme.radius))
        }
    }

    /// 卡片边:彩色版用"上亮下淡"的描边渐变,模拟玻璃反射;素色版保持原 hairline。
    @ViewBuilder
    private var coloredCardBorder: some View {
        if colored {
            RoundedRectangle(cornerRadius: AppTheme.radius)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.40), .white.opacity(0.08), .clear],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 0.8
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
