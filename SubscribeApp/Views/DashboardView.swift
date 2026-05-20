import Charts
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: SubscriptionStore
    @State private var period: SpendPeriod = .month
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            AppScreen {
                if store.activeSubscriptions.isEmpty {
                    EmptyDashboard(onAdd: { showAdd = true })
                } else {
                    VStack(spacing: AppTheme.Space.xl) {
                        DashboardHeader(period: $period).reveal(0)
                        HeroTotal(period: period).reveal(1)
                        QuickStatsPanel(period: period).reveal(2)
                        UpcomingPanel().reveal(3)
                        ForecastPanel().reveal(4)
                        CategoryPanel().reveal(5)
                        TopSpendersPanel(period: period).reveal(6)
                        if period == .month {
                            CalendarPanel().reveal(7)
                        } else {
                            YearPanel().reveal(7)
                        }
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showAdd) {
                SubscriptionEditorView(subscription: nil)
                    .environmentObject(store)
            }
        }
    }
}

private struct DashboardHeader: View {
    @EnvironmentObject private var store: SubscriptionStore
    @Binding var period: SpendPeriod
    var body: some View {
        HStack(spacing: AppTheme.Space.m) {
            SegmentedPill(
                selection: $period,
                items: SpendPeriod.allCases.map { ($0, $0.title) }
            )
            .frame(width: 132)

            Spacer()

            Menu {
                // Alphabetical by ISO code — matches the order used in Settings → 货币.
                Picker("", selection: $store.baseCurrency) {
                    ForEach(CurrencyCode.allCases.sorted { $0.rawValue < $1.rawValue }) { c in
                        Text("\(c.rawValue) · \(c.title)").tag(c)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "globe").font(.caption.weight(.bold))
                    Text(store.baseCurrency.rawValue).font(.subheadline.weight(.bold))
                }
                .foregroundStyle(AppTheme.ink)
                .padding(.horizontal, AppTheme.Space.m).padding(.vertical, AppTheme.Space.s)
                .background(AppTheme.surface, in: Capsule())
                .overlay(Capsule().stroke(AppTheme.hairline, lineWidth: 0.5))
            }
        }
    }
}

private struct HeroTotal: View {
    @EnvironmentObject private var store: SubscriptionStore
    let period: SpendPeriod
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.s) {
            SectionLabel(text: period == .month ? "本月总额" : "今年总额")
            Text(store.converter.format(store.fullDueAmount(in: period), currency: store.baseCurrency))
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
        let n = store.fullDueCount(in: period)
        if let next = store.upcomingCharges().first {
            let date = next.date.formatted(.dateTime.month().day())
            return String(localized: "共 \(n) 笔 · 下一笔 \(next.subscription.name) \(date)")
        }
        return String(localized: "共 \(n) 笔")
    }
}

private struct UpcomingPanel: View {
    @EnvironmentObject private var store: SubscriptionStore
    @State private var expanded = false

    private let collapsedLimit = 3

    private var allCharges: [RenewalCharge] { store.upcomingCharges(limit: 100) }
    private var visibleCharges: [RenewalCharge] {
        expanded ? allCharges : Array(allCharges.prefix(collapsedLimit))
    }
    private var hiddenCount: Int { max(0, allCharges.count - collapsedLimit) }

    /// Buckets the visible charges into 本月 / 之后 so a yearly sub whose next
    /// charge is 12 months away doesn't get confused for an imminent bill.
    private struct Bucket: Identifiable { let id = UUID(); let title: String; let charges: [RenewalCharge] }
    private var buckets: [Bucket] {
        let cal = Calendar.current
        let now = Date()
        let monthEnd = cal.dateInterval(of: .month, for: now)?.end ?? now
        let thisMonth = visibleCharges.filter { $0.date < monthEnd }
        let later     = visibleCharges.filter { $0.date >= monthEnd }
        var out: [Bucket] = []
        if !thisMonth.isEmpty { out.append(Bucket(title: String(localized: "本月"), charges: thisMonth)) }
        if !later.isEmpty     { out.append(Bucket(title: String(localized: "之后"), charges: later)) }
        return out
    }

    /// 跨年的扣费补上年份(明年/2027 年的就一眼看得出来),当年就只显示月日。
    private func formatDate(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.component(.year, from: date) == cal.component(.year, from: Date()) {
            return date.formatted(.dateTime.month().day())
        }
        return date.formatted(.dateTime.year().month().day())
    }

    var body: some View {
        Panel(title: "即将扣费") {
            if allCharges.isEmpty {
                Text("暂无即将扣费")
                    .font(.subheadline).foregroundStyle(AppTheme.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, AppTheme.Space.s)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(buckets.enumerated()), id: \.element.id) { bi, bucket in
                        // Group label — skip the leading divider for the very first bucket.
                        if bi > 0 { Hairline() }
                        HStack {
                            Text(bucket.title)
                                .font(.caption.weight(.bold))
                                .tracking(0.6)
                                .textCase(.uppercase)
                                .foregroundStyle(AppTheme.tertiary)
                            Spacer()
                        }
                        .padding(.top, bi == 0 ? 0 : AppTheme.Space.s)
                        .padding(.bottom, 2)

                        ForEach(Array(bucket.charges.enumerated()), id: \.element.id) { i, c in
                            if i > 0 { Hairline() }
                            HStack(spacing: AppTheme.Space.m) {
                                CategoryGlyph(subscription: c.subscription)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(c.subscription.name).font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.ink)
                                    Text("\(formatDate(c.date)) · \(c.subscription.plan)")
                                        .font(.caption).foregroundStyle(AppTheme.secondary)
                                }
                                Spacer()
                                Text(store.converter.format(c.amount, currency: store.baseCurrency))
                                    .font(.amount()).foregroundStyle(AppTheme.ink)
                            }
                            .padding(.vertical, AppTheme.Space.m)
                        }
                    }

                    if hiddenCount > 0 {
                        Hairline()
                        Button {
                            withAnimation(AppTheme.spring) { expanded.toggle() }
                        } label: {
                            HStack(spacing: 4) {
                                Spacer()
                                Text(expanded
                                     ? String(localized: "收起")
                                     : String(localized: "更多 \(hiddenCount) 项"))
                                    .font(.caption.weight(.semibold))
                                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                                    .font(.caption2.weight(.bold))
                                Spacer()
                            }
                            .foregroundStyle(AppTheme.accent)
                            .padding(.vertical, AppTheme.Space.m)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
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
                            Text(item.category.title)
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
    /// 用户点过的那一天(nil 表示未选,只看到"今天"高亮)。换月时自动重置。
    @State private var selectedDay: Int? = nil
    @State private var showMonthPicker = false
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    private let symbols = Calendar.current.veryShortStandaloneWeekdaySymbols

    private var currentMonthStart: Date {
        Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now
    }
    private var isCurrentMonth: Bool {
        Calendar.current.isDate(monthAnchor, equalTo: currentMonthStart, toGranularity: .month)
    }
    /// 显示的月份里"今天"是几号(不是这个月则返回 nil)。
    private var todayInVisibleMonth: Int? {
        guard isCurrentMonth else { return nil }
        return Calendar.current.component(.day, from: .now)
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

                    // 点月份名打开"年 + 12 个月按钮"的弹窗,比下拉列表好选得多。
                    Button {
                        showMonthPicker = true
                    } label: {
                        HStack(spacing: 5) {
                            Text(monthLabel(monthAnchor))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.ink)
                            Image(systemName: "chevron.down")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(AppTheme.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

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
                    // veryShortStandaloneWeekdaySymbols repeats letters (S/M/T/W/T/F/S),
                    // so we can't use `id: \.self` — SwiftUI dedupes and the columns
                    // collapse. Pair each symbol with its index for a unique ID.
                    ForEach(Array(symbols.enumerated()), id: \.offset) { _, s in
                        Text(s).font(.caption2.weight(.semibold))
                            .foregroundStyle(AppTheme.tertiary).frame(maxWidth: .infinity)
                    }
                }
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(Array(cells.enumerated()), id: \.offset) { _, day in
                        if let day {
                            let cs = byDay[day] ?? []
                            let isToday = todayInVisibleMonth == day
                            let isSelected = selectedDay == day
                            Button {
                                selectedDay = (selectedDay == day) ? nil : day
                            } label: {
                                VStack(spacing: 3) {
                                    // iOS Calendar 风格 —— 今天是一颗实心 accent 圆,圈住数字,
                                    // 其他状态全部走单元格底色,不会跟"今天"撞色。
                                    ZStack {
                                        if isToday {
                                            Circle()
                                                .fill(AppTheme.accent)
                                                .frame(width: 26, height: 26)
                                        }
                                        Text("\(day)")
                                            .font(.caption.monospacedDigit().weight(isToday || !cs.isEmpty ? .bold : .regular))
                                            .foregroundStyle(
                                                isToday ? .white
                                                : (cs.isEmpty ? AppTheme.tertiary : AppTheme.ink)
                                            )
                                    }
                                    .frame(width: 26, height: 26)

                                    HStack(spacing: 2) {
                                        ForEach(cs.prefix(3)) { c in
                                            Circle().fill(c.subscription.category.color).frame(width: 4, height: 4)
                                        }
                                    }.frame(height: 4)
                                }
                                .frame(height: 38).frame(maxWidth: .infinity)
                                .background(
                                    isSelected && !isToday ? AppTheme.accent.opacity(0.30)
                                    : (!cs.isEmpty && !isToday ? AppTheme.accent.opacity(0.14) : .clear),
                                    in: RoundedRectangle(cornerRadius: AppTheme.radiusSmall)
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        } else {
                            Color.clear.frame(height: 38)
                        }
                    }
                }

                // 点中某天 + 那天有扣费,展开看具体哪些订阅
                if let day = selectedDay,
                   let interval = Calendar.current.dateInterval(of: .month, for: monthAnchor),
                   let dayDate = Calendar.current.date(byAdding: .day, value: day - 1, to: interval.start),
                   let charges = byDay[day], !charges.isEmpty {
                    Hairline()
                    HStack {
                        Text(dayDate.formatted(.dateTime.month().day().weekday(.wide)))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.ink)
                        Spacer()
                        Text(store.converter.format(
                            charges.reduce(0) { $0 + $1.amount },
                            currency: store.baseCurrency))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.accent)
                    }
                    .padding(.top, AppTheme.Space.s)

                    VStack(spacing: AppTheme.Space.s) {
                        ForEach(charges) { c in
                            HStack(spacing: AppTheme.Space.s) {
                                CategoryGlyph(subscription: c.subscription, size: 28)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(c.subscription.name)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(AppTheme.ink)
                                    if !c.subscription.plan.isEmpty {
                                        Text(c.subscription.plan)
                                            .font(.caption2)
                                            .foregroundStyle(AppTheme.secondary)
                                    }
                                }
                                Spacer()
                                Text(store.converter.format(c.amount, currency: store.baseCurrency))
                                    .font(.caption.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(AppTheme.ink)
                            }
                        }
                    }
                }
            }
            .animation(AppTheme.spring, value: monthAnchor)
            .animation(AppTheme.spring, value: selectedDay)
            .onChange(of: monthAnchor) { _, _ in selectedDay = nil }
        }
        .sheet(isPresented: $showMonthPicker) {
            MonthPickerSheet(monthAnchor: $monthAnchor)
                .presentationDetents([.height(360)])
                .presentationDragIndicator(.visible)
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

// MARK: - 30 天预览面板

/// 把今后 30 天的每笔扣费画成柱状图,按分类色上色。让用户一眼看到
/// "下个月的支出节奏",哪几天会大额出账,哪几天没事。
private struct ForecastPanel: View {
    @EnvironmentObject private var store: SubscriptionStore

    private var charges: [RenewalCharge] { store.chargesInNext(30) }
    private var total: Double { charges.reduce(0) { $0 + $1.amount } }

    var body: some View {
        if !charges.isEmpty {
            Panel(title: "30 天预览") {
                VStack(alignment: .leading, spacing: AppTheme.Space.s) {
                    Chart(charges) { c in
                        BarMark(
                            x: .value("date", c.date, unit: .day),
                            y: .value("amount", c.amount)
                        )
                        .foregroundStyle(c.subscription.category.color)
                        .cornerRadius(3)
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                            AxisValueLabel(
                                format: .dateTime.month(.abbreviated).day(),
                                centered: false
                            )
                            .font(.caption2)
                        }
                    }
                    .chartYAxis(.hidden)
                    .frame(height: 120)

                    HStack {
                        Text(String(localized: "共 \(charges.count) 笔"))
                            .font(.caption).foregroundStyle(AppTheme.secondary)
                        Spacer()
                        Text(store.converter.format(total, currency: store.baseCurrency))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.ink)
                    }
                }
            }
        }
    }
}

// MARK: - 选月份弹窗

/// 替换原本"-24 到 +24 个月"的下拉列表。改成一个年份步进 + 12 月按钮网格,
/// 一次只看一个年,跨年点头部箭头切换,空间小、选起来直观很多。
private struct MonthPickerSheet: View {
    @Binding var monthAnchor: Date
    @Environment(\.dismiss) private var dismiss
    @State private var year: Int

    init(monthAnchor: Binding<Date>) {
        self._monthAnchor = monthAnchor
        let cal = Calendar.current
        self._year = State(initialValue: cal.component(.year, from: monthAnchor.wrappedValue))
    }

    private var anchorYear: Int { Calendar.current.component(.year, from: monthAnchor) }
    private var anchorMonth: Int { Calendar.current.component(.month, from: monthAnchor) }
    private var currentYear: Int { Calendar.current.component(.year, from: .now) }
    private var currentMonth: Int { Calendar.current.component(.month, from: .now) }

    var body: some View {
        VStack(spacing: AppTheme.Space.l) {
            // Year stepper
            HStack {
                yearStepperButton(systemName: "chevron.left") { year -= 1 }
                Spacer()
                Text(verbatim: "\(year)")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppTheme.ink)
                    .contentTransition(.numericText())
                Spacer()
                yearStepperButton(systemName: "chevron.right") { year += 1 }
            }
            .padding(.horizontal, AppTheme.Space.l)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: AppTheme.Space.m), count: 3),
                spacing: AppTheme.Space.m
            ) {
                ForEach(1...12, id: \.self) { m in
                    monthButton(m)
                }
            }
            .padding(.horizontal, AppTheme.Space.l)

            Spacer(minLength: 0)
        }
        .padding(.top, AppTheme.Space.xl)
        .background(AppTheme.canvas.ignoresSafeArea())
        .animation(AppTheme.spring, value: year)
    }

    @ViewBuilder
    private func yearStepperButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.ink)
                .frame(width: 40, height: 40)
                .background(AppTheme.surface, in: Circle())
                .overlay(Circle().stroke(AppTheme.hairline, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func monthButton(_ m: Int) -> some View {
        let isSelected = (year == anchorYear && m == anchorMonth)
        let isCurrent  = (year == currentYear && m == currentMonth)
        Button {
            let comps = DateComponents(year: year, month: m, day: 1)
            if let d = Calendar.current.date(from: comps) {
                monthAnchor = d
                dismiss()
            }
        } label: {
            VStack(spacing: 2) {
                Text(monthShortName(m))
                    .font(.subheadline.weight(.semibold))
                if isCurrent && !isSelected {
                    Circle()
                        .fill(AppTheme.accent)
                        .frame(width: 4, height: 4)
                } else {
                    Color.clear.frame(width: 4, height: 4)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                isSelected ? AppTheme.ink : AppTheme.surface,
                in: RoundedRectangle(cornerRadius: AppTheme.radius)
            )
            .foregroundStyle(isSelected ? AppTheme.surface : AppTheme.ink)
            .glassBorder(cornerRadius: AppTheme.radius)
        }
        .buttonStyle(.plain)
    }

    private func monthShortName(_ m: Int) -> String {
        let f = DateFormatter()
        f.locale = .current
        return f.shortStandaloneMonthSymbols[m - 1]
    }
}

// MARK: - Quick stats (2×2 数字面板)

/// 把"活跃订阅数 / 本月总额 / 今年总额 / 平均"4 个最常看的数字摆在一起,
/// 让用户翻开 Overview 第一眼就能掌握全局,不用扫所有卡片。
private struct QuickStatsPanel: View {
    @EnvironmentObject private var store: SubscriptionStore
    let period: SpendPeriod

    private var activeCount: Int { store.activeSubscriptions.count }
    private var monthly: Double { store.monthlyTotal }
    private var annual: Double { store.annualTotal }
    private var averagePerSub: Double {
        guard activeCount > 0 else { return 0 }
        return monthly / Double(activeCount)
    }
    private var trialCount: Int {
        store.activeSubscriptions.filter { $0.status == .trial }.count
    }

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: AppTheme.Space.m),
                      GridItem(.flexible(), spacing: AppTheme.Space.m)],
            spacing: AppTheme.Space.m
        ) {
            StatCard(label: "活跃订阅",
                     value: "\(activeCount)",
                     hint: trialCount > 0 ? String(localized: "\(trialCount) 个试用") : nil)
            StatCard(label: "月均",
                     value: store.converter.format(monthly, currency: store.baseCurrency),
                     hint: String(localized: "全部摊到每月"))
            StatCard(label: "年均",
                     value: store.converter.format(annual, currency: store.baseCurrency),
                     hint: String(localized: "全部摊到每年"))
            StatCard(label: "平均每个",
                     value: store.converter.format(averagePerSub, currency: store.baseCurrency),
                     hint: String(localized: "按月"))
        }
    }
}

private struct StatCard: View {
    let label: LocalizedStringKey
    let value: String
    let hint: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.secondary)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1).minimumScaleFactor(0.6)
            if let hint {
                Text(hint)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.tertiary)
            } else {
                // 占位保高度统一,免得有 hint 的卡和没 hint 的卡高低不齐
                Text(" ").font(.caption2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Space.m)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.radiusSmall))
        .glassBorder(cornerRadius: AppTheme.radiusSmall)
    }
}

// MARK: - Top spenders 面板

/// Top 5 月费最高的订阅,按当前 period 切换显示月/年金额。让用户一眼看到
/// "钱主要花在哪儿",做"砍订阅"决策时最有用的一个面板。
private struct TopSpendersPanel: View {
    @EnvironmentObject private var store: SubscriptionStore
    let period: SpendPeriod

    private var top: [Subscription] {
        store.activeSubscriptions
            .sorted {
                $0.monthlyCost(in: store.baseCurrency, converter: store.converter)
                > $1.monthlyCost(in: store.baseCurrency, converter: store.converter)
            }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        if !top.isEmpty {
            Panel(title: "最贵的订阅") {
                VStack(spacing: 0) {
                    ForEach(Array(top.enumerated()), id: \.element.id) { i, sub in
                        if i > 0 { Hairline() }
                        HStack(spacing: AppTheme.Space.m) {
                            Text("\(i + 1)")
                                .font(.caption.weight(.heavy).monospacedDigit())
                                .foregroundStyle(AppTheme.tertiary)
                                .frame(width: 14, alignment: .center)
                            CategoryGlyph(subscription: sub, size: 30)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(sub.name).font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.ink)
                                Text(sub.category.title)
                                    .font(.caption).foregroundStyle(AppTheme.secondary)
                            }
                            Spacer()
                            Text(store.converter.format(
                                amount(for: sub),
                                currency: store.baseCurrency))
                                .font(.amount()).foregroundStyle(AppTheme.ink)
                        }
                        .padding(.vertical, AppTheme.Space.s)
                    }
                }
            }
        }
    }

    private func amount(for sub: Subscription) -> Double {
        let monthly = sub.monthlyCost(in: store.baseCurrency, converter: store.converter)
        return period == .year ? monthly * 12 : monthly
    }
}

private struct EmptyDashboard: View {
    let onAdd: () -> Void
    var body: some View {
        VStack(spacing: AppTheme.Space.m) {
            Image(systemName: "tray").font(.system(size: 44, weight: .light))
                .foregroundStyle(AppTheme.tertiary)
            Text("还没有订阅").font(.title3.weight(.bold)).foregroundStyle(AppTheme.ink)
            Text("添加你的第一个订阅,这里会显示完整支出概览。")
                .font(.subheadline).foregroundStyle(AppTheme.secondary)
                .multilineTextAlignment(.center)
            Button(action: onAdd) {
                Label("添加订阅", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppTheme.Space.xl)
                    .padding(.vertical, AppTheme.Space.m)
                    .background(AppTheme.accent, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, AppTheme.Space.s)
        }
        .frame(maxWidth: .infinity).padding(.top, 120)
    }
}


#Preview {
    DashboardView().environmentObject(SubscriptionStore())
}
