import Charts
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: SubscriptionStore
    @State private var selectedPeriod: SpendPeriod = .month

    var body: some View {
        NavigationStack {
            AppScreen {
                VStack(spacing: 14) {
                    HStack(spacing: 12) {
                        PeriodSwitch(selection: $selectedPeriod)
                        CurrencyMenu(selection: $store.baseCurrency)
                    }
                    .reveal(0)

                    SummaryCard(period: selectedPeriod)
                        .reveal(1)

                    if selectedPeriod == .month {
                        MonthCalendarCard()
                            .reveal(2)
                    } else {
                        YearSpendCard()
                            .reveal(2)
                    }

                    CategoryBreakdownCard()
                        .reveal(3)

                    RenewalReceiptCard(period: selectedPeriod)
                        .reveal(4)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct PeriodSwitch: View {
    @Binding var selection: SpendPeriod

    var body: some View {
        HStack(spacing: 4) {
            ForEach(SpendPeriod.allCases) { period in
                Button {
                    withAnimation(AppDesign.spring) {
                        selection = period
                    }
                } label: {
                    Text(period.title)
                        .font(.headline.weight(.black))
                        .foregroundStyle(selection == period ? .white : AppDesign.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(selection == period ? AppDesign.ink : .clear, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(AppDesign.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppDesign.line.opacity(0.78), lineWidth: 1)
        )
    }
}

private struct SummaryCard: View {
    @EnvironmentObject private var store: SubscriptionStore
    let period: SpendPeriod

    private var amount: Double {
        store.dueAmount(in: period)
    }

    private var count: Int {
        store.dueCount(in: period)
    }

    private var nextCharge: RenewalCharge? {
        store.nextCharge(in: period)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                Label(periodLabel, systemImage: "calendar.badge.clock")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppDesign.muted)

                Spacer()

                Text("\(store.activeSubscriptions.count) active")
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(AppDesign.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppDesign.line.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(store.converter.format(amount, currency: store.baseCurrency))
                    .font(.system(size: 50, weight: .black, design: .rounded))
                    .foregroundStyle(AppDesign.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.48)
                    .contentTransition(.numericText())

                Text("\(count) 笔将在\(period.unitText)扣费")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppDesign.muted)
            }

            Divider()
                .overlay(AppDesign.line)

            if let nextCharge {
                RenewalInlineRow(charge: nextCharge, showsCheckmark: false)
            } else {
                Text("这个周期没有待扣费订阅")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppDesign.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
            }
        }
        .padding(18)
        .background(AppDesign.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppDesign.line.opacity(0.75), lineWidth: 1)
        )
        .shadow(color: AppDesign.ink.opacity(0.055), radius: 24, y: 12)
        .animation(AppDesign.spring, value: period)
        .animation(AppDesign.spring, value: amount)
    }

    private var periodLabel: String {
        switch period {
        case .month:
            Date.now.formatted(.dateTime.month(.wide))
        case .year:
            Date.now.formatted(.dateTime.year())
        }
    }
}

private struct MonthCalendarCard: View {
    @EnvironmentObject private var store: SubscriptionStore

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
    private let weekdaySymbols = Calendar.current.veryShortStandaloneWeekdaySymbols

    var body: some View {
        InsightPanel(title: "本月扣费日") {
            VStack(spacing: 12) {
                HStack {
                    ForEach(weekdaySymbols, id: \.self) { symbol in
                        Text(symbol)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(AppDesign.muted)
                            .frame(maxWidth: .infinity)
                    }
                }

                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(calendarCells, id: \.self) { day in
                        if let day {
                            CalendarDayCell(
                                day: day,
                                charges: charges(on: day)
                            )
                        } else {
                            Color.clear
                                .frame(height: 36)
                        }
                    }
                }
            }
        }
    }

    private var calendarCells: [Int?] {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: .now),
              let range = calendar.range(of: .day, in: .month, for: .now) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: interval.start)
        let leadingEmpty = firstWeekday - calendar.firstWeekday
        let offset = leadingEmpty >= 0 ? leadingEmpty : leadingEmpty + 7
        return Array(repeating: nil, count: offset) + range.map { Optional($0) }
    }

    private func charges(on day: Int) -> [RenewalCharge] {
        store.charges(in: .month).filter {
            Calendar.current.component(.day, from: $0.date) == day
        }
    }
}

private struct CalendarDayCell: View {
    let day: Int
    let charges: [RenewalCharge]

    var body: some View {
        VStack(spacing: 3) {
            Text("\(day)")
                .font(.caption.monospacedDigit().weight(charges.isEmpty ? .medium : .black))
                .foregroundStyle(charges.isEmpty ? AppDesign.muted : AppDesign.ink)

            HStack(spacing: 2) {
                ForEach(charges.prefix(3)) { charge in
                    Circle()
                        .fill(charge.subscription.category.color)
                        .frame(width: 4, height: 4)
                }
            }
            .frame(height: 5)
        }
        .frame(height: 36)
        .frame(maxWidth: .infinity)
        .background(charges.isEmpty ? AppDesign.line.opacity(0.18) : Color.blue.opacity(0.12), in: Circle())
    }
}

private struct YearSpendCard: View {
    @EnvironmentObject private var store: SubscriptionStore

    var body: some View {
        InsightPanel(title: "全年扣费分布") {
            Chart(store.monthTotalsForCurrentYear()) { point in
                BarMark(
                    x: .value("月份", point.month, unit: .month),
                    y: .value("金额", point.amount)
                )
                .foregroundStyle(point.month < Date.now ? AppDesign.line : Color.blue)
                .cornerRadius(5)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisValueLabel(format: .dateTime.month(.narrow))
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 132)
        }
    }
}

private struct RenewalReceiptCard: View {
    @EnvironmentObject private var store: SubscriptionStore
    let period: SpendPeriod

    private var charges: [RenewalCharge] {
        Array(store.charges(in: period).prefix(8))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(period == .month ? "MONTHLY RECEIPT" : "YEAR RECEIPT")
                        .font(.caption.monospaced().weight(.black))
                        .foregroundStyle(AppDesign.muted)
                    Text(period == .month ? "本月明细" : "近期明细")
                        .font(.headline.weight(.black))
                        .foregroundStyle(AppDesign.ink)
                }

                Spacer()

                Text(Date.now.formatted(.dateTime.year().month().day()))
                    .font(.caption2.monospacedDigit().weight(.bold))
                    .foregroundStyle(AppDesign.muted)
            }

            DashedDivider()

            if charges.isEmpty {
                ContentUnavailableView("暂无扣费", systemImage: "calendar.badge.checkmark")
                    .frame(height: 138)
            } else {
                VStack(spacing: 0) {
                    ForEach(charges) { charge in
                        ReceiptRow(charge: charge)
                    }
                }

                DashedDivider()

                HStack {
                    Text("TOTAL")
                        .font(.caption.monospaced().weight(.black))
                        .foregroundStyle(AppDesign.muted)
                    Spacer()
                    Text(store.converter.format(total, currency: store.baseCurrency))
                        .font(.title3.monospacedDigit().weight(.black))
                        .foregroundStyle(AppDesign.ink)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(AppDesign.surface.opacity(0.95))
                .stroke(AppDesign.line.opacity(0.72), lineWidth: 1)
        )
        .overlay(alignment: .top) {
            ReceiptTeeth()
                .fill(AppDesign.background.opacity(0.9))
                .frame(height: 10)
                .offset(y: -1)
        }
        .overlay(alignment: .bottom) {
            ReceiptTeeth()
                .fill(AppDesign.background.opacity(0.9))
                .rotationEffect(.degrees(180))
                .frame(height: 10)
                .offset(y: 1)
        }
        .shadow(color: AppDesign.ink.opacity(0.05), radius: 22, y: 12)
    }

    private var total: Double {
        charges.reduce(0) { $0 + $1.amount }
    }
}

private struct CategoryBreakdownCard: View {
    @EnvironmentObject private var store: SubscriptionStore

    var body: some View {
        InsightPanel(title: "支出分类") {
            HStack(spacing: 16) {
                Chart(store.categorySpend) { item in
                    SectorMark(
                        angle: .value("金额", item.amount),
                        innerRadius: .ratio(0.62),
                        angularInset: 2
                    )
                    .foregroundStyle(item.category.color)
                    .cornerRadius(4)
                }
                .frame(width: 142, height: 142)

                VStack(spacing: 9) {
                    ForEach(store.categorySpend.prefix(5)) { item in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(item.category.color)
                                .frame(width: 8, height: 8)

                            Text(item.category.rawValue)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppDesign.ink)

                            Spacer()

                            Text("\(Int((item.share * 100).rounded()))%")
                                .font(.caption.monospacedDigit().weight(.black))
                                .foregroundStyle(AppDesign.muted)
                        }
                    }
                }
            }
        }
    }
}

private struct ReceiptRow: View {
    @EnvironmentObject private var store: SubscriptionStore
    let charge: RenewalCharge

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(charge.date.formatted(.dateTime.day(.twoDigits)))
                .font(.caption.monospacedDigit().weight(.black))
                .foregroundStyle(AppDesign.muted)
                .frame(width: 24, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(charge.subscription.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppDesign.ink)
                    .lineLimit(1)

                Text(charge.subscription.plan)
                    .font(.caption2)
                    .foregroundStyle(AppDesign.muted)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(store.converter.format(charge.amount, currency: store.baseCurrency))
                .font(.subheadline.monospacedDigit().weight(.black))
                .foregroundStyle(AppDesign.ink)
        }
        .padding(.vertical, 8)
    }
}

private struct DashedDivider: View {
    var body: some View {
        Rectangle()
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
            .foregroundStyle(AppDesign.line)
            .frame(height: 1)
    }
}

private struct ReceiptTeeth: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))

        let toothWidth: CGFloat = 12
        var x = rect.minX
        while x <= rect.maxX {
            path.addLine(to: CGPoint(x: min(x + toothWidth / 2, rect.maxX), y: rect.maxY))
            path.addLine(to: CGPoint(x: min(x + toothWidth, rect.maxX), y: rect.minY))
            x += toothWidth
        }

        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

private struct RenewalInlineRow: View {
    @EnvironmentObject private var store: SubscriptionStore
    let charge: RenewalCharge
    let showsCheckmark: Bool

    var body: some View {
        HStack(spacing: 12) {
            SubscriptionGlyph(subscription: charge.subscription)

            VStack(alignment: .leading, spacing: 3) {
                Text(charge.subscription.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppDesign.ink)
                    .lineLimit(1)

                Text(charge.date.formatted(.dateTime.month(.abbreviated).day()) + " · " + charge.subscription.plan)
                    .font(.caption)
                    .foregroundStyle(AppDesign.muted)
                    .lineLimit(1)
            }

            Spacer()

            Text(store.converter.format(charge.amount, currency: store.baseCurrency))
                .font(.headline.monospacedDigit().weight(.black))
                .foregroundStyle(AppDesign.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            if showsCheckmark {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 11)
    }
}

private struct SubscriptionGlyph: View {
    let subscription: Subscription

    var body: some View {
        ZStack {
            Circle()
                .fill(subscription.category.color.opacity(0.16))
            Circle()
                .stroke(subscription.category.color.opacity(0.45), lineWidth: 2)
            Text(String(subscription.name.prefix(1)).uppercased())
                .font(.caption.weight(.black))
                .foregroundStyle(subscription.category.color)
        }
        .frame(width: 38, height: 38)
    }
}

struct CurrencyMenu: View {
    @Binding var selection: CurrencyCode

    var body: some View {
        Menu {
            Picker("统一币种", selection: $selection) {
                ForEach(CurrencyCode.allCases) { currency in
                    Text("\(currency.rawValue) · \(currency.title)").tag(currency)
                }
            }
        } label: {
            Label(selection.rawValue, systemImage: "globe.asia.australia.fill")
                .font(.caption.weight(.black))
                .foregroundStyle(AppDesign.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
                .background(AppDesign.surface, in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppDesign.line.opacity(0.78), lineWidth: 1)
                )
        }
    }
}
