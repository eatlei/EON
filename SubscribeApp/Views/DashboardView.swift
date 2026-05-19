import Charts
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: SubscriptionStore
    @State private var period: SpendPeriod = .month

    var body: some View {
        NavigationStack {
            AppScreen {
                if store.activeSubscriptions.isEmpty {
                    EmptyDashboard()
                } else {
                    VStack(spacing: AppTheme.Space.xl) {
                        DashboardHeader(period: $period).reveal(0)
                        HeroTotal(period: period).reveal(1)
                        UpcomingPanel(period: period).reveal(2)
                        CategoryPanel().reveal(3)
                        if period == .month {
                            CalendarPanel().reveal(4)
                        } else {
                            YearPanel().reveal(4)
                        }
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct DashboardHeader: View {
    @EnvironmentObject private var store: SubscriptionStore
    @Binding var period: SpendPeriod
    var body: some View {
        HStack(spacing: AppTheme.Space.m) {
            HStack(spacing: 2) {
                ForEach(SpendPeriod.allCases) { p in
                    Button {
                        withAnimation(AppTheme.spring) { period = p }
                    } label: {
                        Text(p.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(period == p ? AppTheme.surface : AppTheme.secondary)
                            .frame(maxWidth: .infinity).padding(.vertical, 8)
                            .background(period == p ? AppTheme.ink : .clear,
                                        in: RoundedRectangle(cornerRadius: AppTheme.radiusSmall))
                    }.buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.radius))
            .overlay(RoundedRectangle(cornerRadius: AppTheme.radius).stroke(AppTheme.hairline, lineWidth: 0.5))
            .frame(width: 132)

            Spacer()

            Menu {
                Picker("", selection: $store.baseCurrency) {
                    ForEach(CurrencyCode.allCases) { Text("\($0.rawValue) · \($0.title)").tag($0) }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "globe").font(.caption.weight(.bold))
                    Text(store.baseCurrency.rawValue).font(.subheadline.weight(.bold))
                }
                .foregroundStyle(AppTheme.ink)
                .padding(.horizontal, AppTheme.Space.m).padding(.vertical, AppTheme.Space.s)
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.radiusSmall))
                .overlay(RoundedRectangle(cornerRadius: AppTheme.radiusSmall).stroke(AppTheme.hairline, lineWidth: 0.5))
            }
        }
    }
}

private struct HeroTotal: View {
    @EnvironmentObject private var store: SubscriptionStore
    let period: SpendPeriod
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.s) {
            SectionLabel(text: period == .month ? "本月待扣费" : "今年待扣费")
            Text(store.converter.format(store.dueAmount(in: period), currency: store.baseCurrency))
                .font(.amountHero())
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1).minimumScaleFactor(0.5)
                .contentTransition(.numericText())
            Text(subtitle)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, AppTheme.Space.s)
        .animation(AppTheme.spring, value: period)
    }
    private var subtitle: String {
        let n = store.dueCount(in: period)
        if let next = store.nextCharge(in: period) {
            let date = next.date.formatted(.dateTime.month().day())
            return String(localized: "\(n) 笔 · 下一笔 \(next.subscription.name) \(date)")
        }
        let count = store.activeSubscriptions.count
        return String(localized: "\(count) 个订阅 · 本期无待扣费")
    }
}

private struct UpcomingPanel: View {
    @EnvironmentObject private var store: SubscriptionStore
    let period: SpendPeriod
    private var charges: [RenewalCharge] { Array(store.charges(in: period).prefix(6)) }
    var body: some View {
        Panel(title: "即将扣费") {
            if charges.isEmpty {
                Text("本期没有待扣费订阅")
                    .font(.subheadline).foregroundStyle(AppTheme.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, AppTheme.Space.s)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(charges.enumerated()), id: \.element.id) { i, c in
                        if i > 0 { Hairline() }
                        HStack(spacing: AppTheme.Space.m) {
                            CategoryGlyph(subscription: c.subscription)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(c.subscription.name).font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.ink)
                                Text("\(c.date.formatted(.dateTime.month().day())) · \(c.subscription.plan)")
                                    .font(.caption).foregroundStyle(AppTheme.secondary)
                            }
                            Spacer()
                            Text(store.converter.format(c.amount, currency: store.baseCurrency))
                                .font(.amount()).foregroundStyle(AppTheme.ink)
                        }
                        .padding(.vertical, AppTheme.Space.m)
                    }
                }
            }
        }
    }
}

private struct CategoryPanel: View {
    @EnvironmentObject private var store: SubscriptionStore
    var body: some View {
        Panel(title: "支出分类") {
            HStack(spacing: AppTheme.Space.xl) {
                Chart(store.categorySpend) { item in
                    SectorMark(angle: .value("金额", item.amount),
                               innerRadius: .ratio(0.68), angularInset: 1.5)
                        .foregroundStyle(item.category.color)
                }
                .frame(width: 116, height: 116)

                VStack(spacing: AppTheme.Space.s) {
                    ForEach(store.categorySpend.prefix(5)) { item in
                        HStack(spacing: AppTheme.Space.s) {
                            Circle().fill(item.category.color).frame(width: 7, height: 7)
                            Text(item.category.rawValue)
                                .font(.caption.weight(.semibold)).foregroundStyle(AppTheme.ink)
                            Spacer()
                            Text("\(Int((item.share * 100).rounded()))%")
                                .font(.caption.weight(.bold).monospacedDigit())
                                .foregroundStyle(AppTheme.secondary)
                        }
                    }
                }
            }
        }
    }
}

private struct CalendarPanel: View {
    @EnvironmentObject private var store: SubscriptionStore
    @State private var monthAnchor: Date = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    private let symbols = Calendar.current.veryShortStandaloneWeekdaySymbols

    private var currentMonthStart: Date {
        Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now
    }
    private var isCurrentMonth: Bool {
        Calendar.current.isDate(monthAnchor, equalTo: currentMonthStart, toGranularity: .month)
    }
    private func monthLabel(_ d: Date) -> String {
        d.formatted(.dateTime.year().month(.wide))
    }
    private func step(_ delta: Int) {
        if let d = Calendar.current.date(byAdding: .month, value: delta, to: monthAnchor),
           let s = Calendar.current.dateInterval(of: .month, for: d)?.start {
            monthAnchor = s
        }
    }

    var body: some View {
        let byDay = Dictionary(grouping: store.charges(inMonthContaining: monthAnchor)) {
            Calendar.current.component(.day, from: $0.date)
        }
        return Panel {
            VStack(spacing: AppTheme.Space.m) {
                HStack(spacing: AppTheme.Space.s) {
                    Button { step(-1) } label: {
                        Image(systemName: "chevron.left")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppTheme.secondary)
                            .frame(width: 30, height: 30)
                            .contentShape(Rectangle())
                    }.buttonStyle(.plain)

                    Spacer()

                    Menu {
                        ForEach((-24...24), id: \.self) { off in
                            if let d = Calendar.current.date(byAdding: .month, value: off, to: currentMonthStart) {
                                Button(monthLabel(d)) {
                                    if let s = Calendar.current.dateInterval(of: .month, for: d)?.start {
                                        monthAnchor = s
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Text(monthLabel(monthAnchor))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.ink)
                            Image(systemName: "chevron.down")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(AppTheme.secondary)
                        }
                    }

                    if !isCurrentMonth {
                        Button { monthAnchor = currentMonthStart } label: {
                            Text("本月")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(AppTheme.accent)
                        }.buttonStyle(.plain)
                    }

                    Spacer()

                    Button { step(1) } label: {
                        Image(systemName: "chevron.right")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppTheme.secondary)
                            .frame(width: 30, height: 30)
                            .contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }

                HStack {
                    ForEach(symbols, id: \.self) { s in
                        Text(s).font(.caption2.weight(.semibold))
                            .foregroundStyle(AppTheme.tertiary).frame(maxWidth: .infinity)
                    }
                }
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(Array(cells.enumerated()), id: \.offset) { _, day in
                        if let day {
                            let cs = byDay[day] ?? []
                            VStack(spacing: 3) {
                                Text("\(day)")
                                    .font(.caption.monospacedDigit().weight(cs.isEmpty ? .regular : .bold))
                                    .foregroundStyle(cs.isEmpty ? AppTheme.tertiary : AppTheme.ink)
                                HStack(spacing: 2) {
                                    ForEach(cs.prefix(3)) { c in
                                        Circle().fill(c.subscription.category.color).frame(width: 4, height: 4)
                                    }
                                }.frame(height: 4)
                            }
                            .frame(height: 34).frame(maxWidth: .infinity)
                            .background(cs.isEmpty ? Color.clear : AppTheme.accent.opacity(0.22),
                                        in: RoundedRectangle(cornerRadius: AppTheme.radiusSmall))
                        } else {
                            Color.clear.frame(height: 34)
                        }
                    }
                }
            }
            .animation(AppTheme.spring, value: monthAnchor)
        }
    }

    private var cells: [Int?] {
        let cal = Calendar.current
        guard let interval = cal.dateInterval(of: .month, for: monthAnchor),
              let range = cal.range(of: .day, in: .month, for: monthAnchor) else { return [] }
        let firstWeekday = cal.component(.weekday, from: interval.start)
        let lead = firstWeekday - cal.firstWeekday
        let offset = lead >= 0 ? lead : lead + 7
        return Array(repeating: nil, count: offset) + range.map { Optional($0) }
    }
}

private struct YearPanel: View {
    @EnvironmentObject private var store: SubscriptionStore
    var body: some View {
        Panel(title: "全年扣费分布") {
            Chart(store.monthTotalsForCurrentYear()) { p in
                BarMark(x: .value("月", p.month, unit: .month),
                        y: .value("金额", p.amount))
                    .foregroundStyle(
                        Calendar.current.compare(p.month, to: .now, toGranularity: .month) == .orderedAscending
                            ? AppTheme.tertiary : AppTheme.accent
                    )
                    .cornerRadius(4)
            }
            .chartXAxis { AxisMarks(values: .stride(by: .month)) { _ in
                AxisValueLabel(format: .dateTime.month(.narrow)) } }
            .chartYAxis(.hidden)
            .frame(height: 128)
        }
    }
}

private struct EmptyDashboard: View {
    var body: some View {
        VStack(spacing: AppTheme.Space.m) {
            Image(systemName: "tray").font(.system(size: 44, weight: .light))
                .foregroundStyle(AppTheme.tertiary)
            Text("还没有订阅").font(.title3.weight(.bold)).foregroundStyle(AppTheme.ink)
            Text("点右下角的 + 添加第一个订阅，\n这里会显示你的支出概览。")
                .font(.subheadline).foregroundStyle(AppTheme.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.top, 120)
    }
}

#Preview {
    DashboardView().environmentObject(SubscriptionStore())
}
