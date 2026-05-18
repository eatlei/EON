import SwiftUI

struct SubscriptionsView: View {
    @EnvironmentObject private var store: SubscriptionStore
    @State private var editingSubscription: Subscription?
    @State private var searchText = ""
    @State private var sortOption: SubscriptionSortOption = .renewalDate

    private var filteredSubscriptions: [Subscription] {
        let filtered = store.subscriptions
            .filter { subscription in
                searchText.isEmpty ||
                    subscription.name.localizedCaseInsensitiveContains(searchText) ||
                    subscription.plan.localizedCaseInsensitiveContains(searchText) ||
                    subscription.category.rawValue.localizedCaseInsensitiveContains(searchText)
            }

        switch sortOption {
        case .renewalDate:
            return filtered.sorted { $0.nextBillingDate < $1.nextBillingDate }
        case .duration:
            return filtered.sorted {
                $0.billingCycle.days(customDays: $0.customCycleDays) > $1.billingCycle.days(customDays: $1.customCycleDays)
            }
        case .cost:
            return filtered.sorted {
                $0.monthlyCost(in: store.baseCurrency, converter: store.converter) >
                    $1.monthlyCost(in: store.baseCurrency, converter: store.converter)
            }
        case .name:
            return filtered.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    var body: some View {
        NavigationStack {
            AppScreen {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 10) {
                        searchField
                        sortMenu
                    }
                        .reveal(0)

                    if filteredSubscriptions.isEmpty {
                        ContentUnavailableView("暂无订阅", systemImage: "rectangle.stack.badge.plus")
                            .frame(minHeight: 320)
                            .reveal(1)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(Array(filteredSubscriptions.enumerated()), id: \.element.id) { index, subscription in
                                Button {
                                    editingSubscription = subscription
                                } label: {
                                    SubscriptionCard(subscription: subscription) {
                                        store.delete(ids: [subscription.id])
                                    }
                                }
                                .buttonStyle(.plain)
                                .reveal(index + 1)
                            }
                        }
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $editingSubscription) { subscription in
                SubscriptionEditorView(subscription: subscription)
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppDesign.muted)

            TextField("搜索名称、套餐或分类", text: $searchText)
                .textInputAutocapitalization(.never)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppDesign.muted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity)
        .background(AppDesign.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppDesign.line.opacity(0.75), lineWidth: 1)
        )
    }

    private var sortMenu: some View {
        Menu {
            Picker("排序", selection: $sortOption) {
                ForEach(SubscriptionSortOption.allCases) { option in
                    Label(option.title, systemImage: option.systemImage)
                        .tag(option)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.headline.weight(.black))
                .foregroundStyle(AppDesign.ink)
                .frame(width: 48, height: 48)
                .background(AppDesign.surface, in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppDesign.line.opacity(0.75), lineWidth: 1)
                )
        }
        .accessibilityLabel("排序")
    }
}

private enum SubscriptionSortOption: String, CaseIterable, Identifiable {
    case renewalDate
    case duration
    case cost
    case name

    var id: String { rawValue }

    var title: String {
        switch self {
        case .renewalDate: "按时间"
        case .duration: "按持续时间"
        case .cost: "按费用"
        case .name: "按名称"
        }
    }

    var systemImage: String {
        switch self {
        case .renewalDate: "calendar"
        case .duration: "timer"
        case .cost: "banknote"
        case .name: "textformat"
        }
    }
}

private struct SubscriptionCard: View {
    @EnvironmentObject private var store: SubscriptionStore
    let subscription: Subscription
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(subscription.category.color.opacity(0.14))
                    Text(String(subscription.name.prefix(1)).uppercased())
                        .font(.headline.bold())
                        .foregroundStyle(subscription.category.color)
                }
                .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 7) {
                        Text(subscription.name)
                            .font(.headline)
                            .foregroundStyle(AppDesign.ink)

                        if subscription.status == .trial {
                            Text("试用")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(AppDesign.amber.opacity(0.14), in: Capsule())
                                .foregroundStyle(AppDesign.amber)
                        }
                    }

                    Text("\(subscription.plan) · \(subscription.category.rawValue) · \(subscription.billingCycle.rawValue)")
                        .font(.caption)
                        .foregroundStyle(AppDesign.muted)
                        .lineLimit(1)
                }

                Spacer(minLength: 10)

                Menu {
                    Button(role: .destructive, action: onDelete) {
                        Label("删除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.headline)
                        .foregroundStyle(AppDesign.muted)
                        .frame(width: 32, height: 32)
                }
            }

            HStack(spacing: 10) {
                SmallStat(
                    title: "月成本",
                    value: store.converter.format(
                        subscription.monthlyCost(in: store.baseCurrency, converter: store.converter),
                        currency: store.baseCurrency
                    )
                )
                SmallStat(title: "使用", value: "\(subscription.usageScore)/5")
                SmallStat(title: "续费", value: subscription.nextBillingDate.formatted(.dateTime.month(.twoDigits).day(.twoDigits)))
            }
        }
        .padding(15)
        .background(AppDesign.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(subscription.category.color.opacity(subscription.isActive ? 0.22 : 0.08), lineWidth: 1)
        )
        .shadow(color: AppDesign.ink.opacity(0.04), radius: 18, y: 9)
        .opacity(subscription.isActive ? 1 : 0.58)
    }
}

private struct SmallStat: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(AppDesign.muted)
            Text(value)
                .font(.caption.monospacedDigit().weight(.bold))
                .foregroundStyle(AppDesign.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(AppDesign.line.opacity(0.22), in: RoundedRectangle(cornerRadius: 8))
    }
}
