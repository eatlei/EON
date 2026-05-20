import Charts
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: SubscriptionStore
    @State private var period: SpendPeriod = .month
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            Group {
                if store.activeSubscriptions.isEmpty {
                    AppScreen { EmptyDashboard(onAdd: { showAdd = true }) }
                } else {
                    // 自定义滚动容器:页面内容滚动时,顶部的 DashboardHeader
                    // 通过 safeAreaInset 吸顶,并附带 Liquid Glass 背景。
                    // ScrollViewReader 让日历点击时能滚动到详情位置。
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: AppTheme.Space.xl) {
                                HeroTotal(period: period).reveal(0)
                                QuickStatsPanel(period: period).reveal(1)
                                UpcomingPanel().reveal(2)
                                CategoryPanel().reveal(3)
                                if period == .year {
                                    YearPanel().reveal(4)
                                } else {
                                    // 月 + 季 都用日历(季模式下日历仍然只
                                    // 显示当前月,因为日历本来就是月维度的)。
                                    CalendarPanel(scrollProxy: proxy).reveal(4)
                                }
                            }
                            .padding(.horizontal, AppTheme.Space.xl)
                            .padding(.top, AppTheme.Space.m)
                            .padding(.bottom, AppTheme.dockClearance)
                        }
                        .scrollDismissesKeyboard(.interactively)
                        .background(AppTheme.canvas.ignoresSafeArea())
                    }
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if !store.activeSubscriptions.isEmpty {
                    DashboardHeader(period: $period)
                        .padding(.horizontal, AppTheme.Space.xl)
                        .padding(.top, AppTheme.Space.s)
                        .padding(.bottom, AppTheme.Space.m)
                        .background(.thinMaterial)
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
            .frame(maxWidth: 200)  // 三档,留点空间不要顶到右边

            Spacer()

            Menu {
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
                .padding(.horizontal, AppTheme.Space.m)
                .padding(.vertical, 10)
                .glassEffect(.regular, in: Capsule())
            }
        }
    }
}

private struct HeroTotal: View {
    @EnvironmentObject private var store: SubscriptionStore
    let period: SpendPeriod
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.s) {
            SectionLabel(text: heroLabel)
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

    private var heroLabel: LocalizedStringKey {
        switch period {
        case .month:   "本月总额"
        case .quarter: "本季总额"
        case .year:    "今年总额"
        }
    }
}

private struct UpcomingPanel: View {
    @EnvironmentObject private var store: SubscriptionStore

    private var charges: [RenewalCharge] { store.upcomingCharges(limit: 3) }

    var body: some View {
        Panel(title: "即将扣费") {
            if charges.isEmpty {
                Text("暂无即将扣费")
                    .font(.subheadline).foregroundStyle(AppTheme.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, AppTheme.Space.s)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(charges.enumerated()), id: \.element.id) { i, c in
                        if i > 0 { Hairline() }
                        row(c)
                    }
                }
            }
        }
    }

    /// 从今天到目标日期的整天数 —— 用日历的 startOfDay 算,跨夜不会算成 0。
    private func daysUntil(_ date: Date) -> Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let target = cal.startOfDay(for: date)
        return cal.dateComponents([.day], from: today, to: target).day ?? 0
    }

    private func daysCaption(_ days: Int) -> String {
        if days <= 0 { return String(localized: "今天扣费") }
        if days == 1 { return String(localized: "明天扣费") }
        return String(localized: "还有 \(days) 天")
    }

    /// 跨年的扣费补上年份;当年只显示月日。
    private func formatDate(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.component(.year, from: date) == cal.component(.year, from: Date()) {
            return date.formatted(.dateTime.month().day())
        }
        return date.formatted(.dateTime.year().month().day())
    }

    @ViewBuilder
    private func row(_ c: RenewalCharge) -> some View {
        let days = daysUntil(c.date)
        HStack(spacing: AppTheme.Space.m) {
            CategoryGlyph(subscription: c.subscription)
            VStack(alignment: .leading, spacing: 2) {
                Text(c.subscription.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                HStack(spacing: 4) {
                    Text(daysCaption(days))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.accent)
                    Text("·")
                        .font(.caption).foregroundStyle(AppTheme.tertiary)
                    Text(formatDate(c.date))
                        .font(.caption).foregroundStyle(AppTheme.secondary)
                    if !c.subscription.plan.isEmpty {
                        Text("·")
                            .font(.caption).foregroundStyle(AppTheme.tertiary)
                        Text(c.subscription.plan)
                            .font(.caption).foregroundStyle(AppTheme.secondary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer()
            Text(store.converter.format(c.amount, currency: store.baseCurrency))
                .font(.amount()).foregroundStyle(AppTheme.ink)
        }
        .padding(.vertical, AppTheme.Space.m)
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
    /// 外层 ScrollView 的 proxy —— 点中某一天后用它把详情滚到屏幕顶部,
    /// 避免详情被吸顶 Header 或屏幕底部遮挡。
    let scrollProxy: ScrollViewProxy
    @State private var monthAnchor: Date = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now
    /// 用户点过的那一天(nil 表示未选,只看到"今天"高亮)。换月时自动重置。
    @State private var selectedDay: Int? = nil
    @State private var showMonthPicker = false
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    private let symbols = Calendar.current.veryShortStandaloneWeekdaySymbols

    /// 详情面板的 ScrollView ID —— 点中某天后用它来 scrollTo。
    private let detailID = "calendarDetail"

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

                // 点中某天 + 那天有扣费,展开看具体哪些订阅。整块嵌一个浅
                // surface 子卡 + 内描边,跟外面的 Panel 形成"层级",比直接
                // 摊在网格下面更有"详情面板"的味道。
                if let day = selectedDay,
                   let interval = Calendar.current.dateInterval(of: .month, for: monthAnchor),
                   let dayDate = Calendar.current.date(byAdding: .day, value: day - 1, to: interval.start),
                   let charges = byDay[day], !charges.isEmpty {
                    detailCard(dayDate: dayDate, charges: charges)
                        .id(detailID)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(AppTheme.spring, value: monthAnchor)
            .animation(AppTheme.spring, value: selectedDay)
            .onChange(of: monthAnchor) { _, _ in selectedDay = nil }
            .onChange(of: selectedDay) { _, newValue in
                // 点中一个有扣费的日期才滚动,避免取消选中也滚一下。
                guard newValue != nil else { return }
                withAnimation(AppTheme.spring) {
                    scrollProxy.scrollTo(detailID, anchor: .center)
                }
            }
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

    /// 高级感的日详情子卡:大号日期 + 当日金额徽章,行间用细分隔,
    /// 每行图标(36pt)+ 名称/套餐 + 金额。整体压在 surface 上 + glassBorder。
    @ViewBuilder
    private func detailCard(dayDate: Date, charges: [RenewalCharge]) -> some View {
        let total = charges.reduce(0.0) { $0 + $1.amount }
        VStack(alignment: .leading, spacing: AppTheme.Space.m) {
            HStack(alignment: .firstTextBaseline, spacing: AppTheme.Space.s) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(dayDate.formatted(.dateTime.day()))
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppTheme.ink)
                        .contentTransition(.numericText())
                    Text(dayDate.formatted(.dateTime.weekday(.wide).month(.abbreviated)))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.secondary)
                }
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "creditcard.fill")
                        .font(.caption2.weight(.bold))
                    Text(store.converter.format(total, currency: store.baseCurrency))
                        .font(.subheadline.weight(.bold).monospacedDigit())
                }
                .foregroundStyle(AppTheme.accent)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(AppTheme.accent.opacity(0.14), in: Capsule())
            }

            VStack(spacing: 0) {
                ForEach(Array(charges.enumerated()), id: \.element.id) { i, c in
                    if i > 0 { Hairline().padding(.leading, 36 + AppTheme.Space.m) }
                    HStack(spacing: AppTheme.Space.m) {
                        CategoryGlyph(subscription: c.subscription, size: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(c.subscription.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.ink)
                            HStack(spacing: 4) {
                                Circle().fill(c.subscription.category.color).frame(width: 6, height: 6)
                                Text(c.subscription.category.title)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.secondary)
                                if !c.subscription.plan.isEmpty {
                                    Text("·")
                                        .font(.caption).foregroundStyle(AppTheme.tertiary)
                                    Text(c.subscription.plan)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                        Spacer()
                        Text(store.converter.format(c.amount, currency: store.baseCurrency))
                            .font(.amount()).foregroundStyle(AppTheme.ink)
                    }
                    .padding(.vertical, AppTheme.Space.s)
                }
            }
        }
        .padding(AppTheme.Space.m)
        .background(
            AppTheme.canvas.opacity(0.6),
            in: RoundedRectangle(cornerRadius: AppTheme.radiusSmall)
        )
        .glassBorder(cornerRadius: AppTheme.radiusSmall)
        .padding(.top, AppTheme.Space.s)
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
