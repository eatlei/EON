import Charts
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: SubscriptionStore
    @State private var period: SpendPeriod = .month
    @State private var showAdd = false
    /// 当天首次打开 Dashboard 时,放一阵小订阅图标飘下来 —— 每天最多一次,
    /// 由 DailyWelcomeTracker 通过 UserDefaults 记录最后日期。
    @State private var showDailyWelcome = false

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
                                // 试用面板紧跟在总额下面,只有当用户标了试用
                                // 订阅时才出现 —— 提醒首次正式扣费倒计时,
                                // 免得免费试用悄悄转成付费。
                                TrialPanel().reveal(1)
                                QuickStatsPanel(period: period).reveal(2)
                                UpcomingPanel().reveal(3)
                                CategoryPanel().reveal(4)
                                // 累计支付 / 日历 / 年图 / 热力图都不挂 .reveal —— 这些
                                // 是"条件出现"的面板,挂上去之后切换 period 会从 offset
                                // y:+10 + opacity 0 重新滑入,延迟 240–280ms,在用户看
                                // 起来就是页面底部被"扯了一下"。让它们 instant snap-in
                                // 反而稳定:页面看不出抖动。
                                //
                                // 注意:.reveal 内部的 .animation(value:) 会覆盖父层
                                // .transaction 的 animation = nil,所以靠 transaction 关
                                // 不掉它 —— 只能不挂这个 modifier。
                                LifetimePanel()

                                Group {
                                    if period == .year {
                                        YearPanel()
                                    } else {
                                        CalendarPanel(scrollProxy: proxy)
                                    }
                                }
                                // .id 让切换瞬间 tear down + remount,而不让 SwiftUI
                                // 试图在不同结构间插值高度差。再叠一层 .transition(.identity)
                                // 显式声明"这次切换不要任何动画":两手都做齐才能真的没动效。
                                .id(period == .year ? "year-section" : "calendar-section")
                                .transition(.identity)
                                .transaction { $0.animation = nil }
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
                    // 吸顶 Header:不加任何底板,只保留按钮悬浮。胶囊本身已
                    // 有 .glassEffect 玻璃质感,内容滚到下面会自然透出。
                    DashboardHeader(period: $period)
                        .padding(.horizontal, AppTheme.Space.xl)
                        .padding(.top, AppTheme.Space.s)
                        .padding(.bottom, AppTheme.Space.s)
                }
            }
            // 每日彩带:挂在 NavigationStack 上,盖在所有内容之上但不拦截手势。
            // 1.8 秒后自动收起。空订阅时不放,避免对新用户莫名其妙地飘东西。
            .overlay {
                if showDailyWelcome && !store.activeSubscriptions.isEmpty {
                    DailyWelcomeConfetti(
                        // 取月费最高的 6 个当掉落素材 —— 跟 LifetimePanel top 3 同源
                        subscriptions: store.activeSubscriptions
                            .sorted {
                                $0.monthlyCost(in: store.baseCurrency, converter: store.converter) >
                                $1.monthlyCost(in: store.baseCurrency, converter: store.converter)
                            }
                            .prefix(6)
                            .map { $0 }
                    )
                    .allowsHitTesting(false)
                    .transition(.opacity)
                }
            }
            .onAppear {
                // 一天一次,空订阅页面跳过,设置里关掉了也跳过。
                if store.easterEggs.dailyWelcomeConfetti
                   && !DailyWelcomeTracker.hasShownToday()
                   && !store.activeSubscriptions.isEmpty {
                    showDailyWelcome = true
                    DailyWelcomeTracker.markShownToday()
                    // 1.8 秒后自动撤掉粒子层(粒子动画本身 ~2s 渐隐,层 1.8s 删,正好衔接)
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 2_400_000_000)
                        withAnimation(.easeOut(duration: 0.4)) {
                            showDailyWelcome = false
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
    @State private var showCurrencyPicker = false

    /// SegmentedPill 在切换时是用 withAnimation 包的赋值;但 period 这个全局
    /// state 一变,Hero/Stats/Lifetime 等所有跟 period 相关的子视图都会重算,
    /// 内部 numericText 等 contentTransition 会在 withAnimation 的 spring 上下
    /// 文里跑出来 —— 顺带把页面底部条件 Group 的高度差也插值掉。
    /// 用一个不带 animation 的本地 binding 隔离:UI 上选中态变化仍走 spring,
    /// 但绑给业务 state 的 period 写入是 non-animated。
    private var quietPeriodBinding: Binding<SpendPeriod> {
        Binding(
            get: { period },
            set: { newValue in
                var t = Transaction()
                t.animation = nil
                withTransaction(t) { period = newValue }
            }
        )
    }

    var body: some View {
        HStack(spacing: AppTheme.Space.m) {
            SegmentedPill(
                selection: quietPeriodBinding,
                items: SpendPeriod.allCases.map { ($0, $0.title) }
            )
            .frame(maxWidth: 200)  // 三档,留点空间不要顶到右边

            Spacer()

            // 货币按钮 —— 点击弹出 CurrencyPickerSheet,sheet 出现时会自动滚动
            // 到当前选中币种,而不是吊在 USD/AUD 这种字母靠前的位置让用户翻找。
            Button {
                showCurrencyPicker = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "dollarsign.circle.fill").font(.subheadline.weight(.bold))
                    Text(store.baseCurrency.rawValue).font(.subheadline.weight(.bold))
                }
                .foregroundStyle(AppTheme.ink)
                .padding(.horizontal, AppTheme.Space.m)
                .padding(.vertical, 10)
                .glassEffect(.regular, in: Capsule())
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showCurrencyPicker) {
                CurrencyPickerSheet()
                    .environmentObject(store)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
}

private struct HeroTotal: View {
    @EnvironmentObject private var store: SubscriptionStore
    let period: SpendPeriod

    private var amount: Double { store.fullDueAmount(in: period) }
    private var amountText: String {
        store.converter.formatAmountOnly(amount, currency: store.baseCurrency)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.s) {
            SectionLabel(text: heroLabel)
            // 货币符号单独画一份,小一号、baseline 跟数字底齐 —— Apple Wallet
            // / Stocks app 都是这种"小符号 + 大数字"的处理,视觉上数字才是主角。
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(store.baseCurrency.symbol)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.secondary)
                Text(amountText)
                    .font(.amountHero())
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1).minimumScaleFactor(0.5)
                // 之前用 .contentTransition(.numericText()) 让数字滚动切换,
                // 副作用是切 period 时数字宽度变化会顺带把 Hero / QuickStats
                // 卡片的宽度也插值一下 —— 这就是用户反复反映的"年 tab 拉伸"。
                // 拿掉之后切换瞬间完成,代价是失去数字滚动的小动效,值得。
            }
            // "共 N 笔订阅 · 文案":先把数量说清楚,后面挂一段根据数量变化的彩蛋
            // 小尾巴,让 Hero 既有信息量又有情绪。
            Text(subtitle)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, AppTheme.Space.s)
        // 不在这里挂 .animation(AppTheme.spring, value: period):隐式动画会
        // 让整个 Overview 切换 month/quarter/year 时被插值,YearHeatmapPanel
        // 出场也会被一起拉伸。.contentTransition(.numericText()) 已经在 Text
        // 上单独配了数字滚动效果,够用了。
    }

    /// 副标题 = "共 N 笔订阅 · <文案>"。文案分级:刻意避开带贬义 / 价值判断
    /// 的话术(没有"破产"、"花太多"、"公司还是个人"),改成中性 + 验证性的
    /// 表达 —— "你需要这些工具是合理的"。
    private var subtitle: String {
        let count = store.activeSubscriptions.count
        let flavor: String
        switch count {
        case ...1:  flavor = String(localized: "刚刚启程,慢慢添置")
        case 2...3: flavor = String(localized: "精挑细选,够用就好")
        case 4...6: flavor = String(localized: "覆盖了大部分日常需要")
        case 7...10: flavor = String(localized: "搭得挺完整的工具栈")
        case 11...15: flavor = String(localized: "全方位的数字生活配置")
        default: flavor = String(localized: "重度数字工作者的标配 ⚙️")
        }
        return String(localized: "共 \(count) 笔订阅 · \(flavor)")
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
                    // ≤ 7 天才标红提醒,超过这个窗口的扣费用普通文字展示日期就够,
                    // 不然首页满屏都是红色失去突出作用。
                    let isUrgent = days <= 7
                    Text(isUrgent ? daysCaption(days) : formatDate(c.date))
                        .font(.caption.weight(isUrgent ? .bold : .semibold))
                        .foregroundStyle(isUrgent ? Color.red : AppTheme.secondary)
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
        // 整个面板包成 NavigationLink → 跳到 CategoryDetailView。手动画了一个
        // 标题行(原本是 Panel(title:) 自带的标题区),为了在右侧能塞一个
        // chevron 提示用户"这里可以点进去"。
        NavigationLink {
            CategoryDetailView()
        } label: {
            VStack(alignment: .leading, spacing: AppTheme.Space.m) {
                HStack {
                    Text("支出分类")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.tertiary)
                }
                HStack(spacing: AppTheme.Space.xl) {
                    Chart(store.categorySpend) { item in
                        SectorMark(angle: .value("金额", item.amount),
                                   innerRadius: .ratio(0.68), angularInset: 1.5)
                            .foregroundStyle(item.color)
                    }
                    .frame(width: 116, height: 116)

                    VStack(spacing: AppTheme.Space.s) {
                        ForEach(store.categorySpend.prefix(5)) { item in
                            HStack(spacing: AppTheme.Space.s) {
                                Circle().fill(item.color).frame(width: 7, height: 7)
                                Text(item.title)
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppTheme.Space.l)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.radius))
            .glassBorder()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 累计支付面板
//
// 利用每笔订阅的 startDate + 计费周期反算"它从开始用到今天累计扣了多少钱",
// 加总展示。再列出 top 3 "贡献最大"的订阅,让用户一眼看到"我这几年最烧钱的
// 是哪几个"。是个比"月均 / 年均"更有体感的"沉没成本"视角。
private struct LifetimePanel: View {
    @EnvironmentObject private var store: SubscriptionStore

    private var total: Double { store.totalLifetimeSpend }
    private var totalCount: Int { store.totalLifetimeChargeCount }
    private var top: [Subscription] { store.subscriptionsByLifetimeSpend(limit: 3) }

    var body: some View {
        // 没真正扣过费(全是未来的)就不显示这个面板,免得空展示 ¥0。
        if total > 0 && !top.isEmpty {
            Panel(title: "累计支付") {
                VStack(alignment: .leading, spacing: AppTheme.Space.m) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(store.converter.format(total, currency: store.baseCurrency))
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .foregroundStyle(AppTheme.ink)
                            .contentTransition(.numericText())
                            .lineLimit(1).minimumScaleFactor(0.6)
                        Text(String(localized: "覆盖 \(store.activeSubscriptions.count) 个订阅 · 共 \(totalCount) 笔扣费"))
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondary)
                    }

                    Hairline()

                    VStack(spacing: 0) {
                        ForEach(Array(top.enumerated()), id: \.element.id) { i, sub in
                            if i > 0 { Hairline() }
                            row(rank: i + 1, sub: sub)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func row(rank: Int, sub: Subscription) -> some View {
        let lifetime = sub.lifetimeSpend(in: store.baseCurrency, converter: store.converter)
        let count = sub.billingCountElapsed()
        HStack(spacing: AppTheme.Space.m) {
            // 第 1 名给 accent 高亮,后面用 tertiary,自然形成"领奖台"感
            Text("\(rank)")
                .font(.caption.weight(.heavy).monospacedDigit())
                .foregroundStyle(rank == 1 ? AppTheme.accent : AppTheme.tertiary)
                .frame(width: 14, alignment: .center)
            CategoryGlyph(subscription: sub, size: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text(sub.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                Text(String(localized: "已扣 \(count) 次"))
                    .font(.caption2)
                    .foregroundStyle(AppTheme.secondary)
            }
            Spacer()
            Text(store.converter.format(lifetime, currency: store.baseCurrency))
                .font(.amount()).foregroundStyle(AppTheme.ink)
        }
        .padding(.vertical, AppTheme.Space.s)
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
                            // 没有扣费的日子点了不会选中(否则会出现"空选中态
                            // 闪一下又恢复"的残影);有扣费的日子才允许 toggle。
                            let isInteractive = !cs.isEmpty
                            Button {
                                guard isInteractive else { return }
                                // selectedDay 的过渡由外层 ZStack 的 .animation(value:)
                                // 接管,这里只做赋值,避免双重动画导致的残影。
                                selectedDay = (selectedDay == day) ? nil : day
                            } label: {
                                VStack(spacing: 0) {  // 圆点紧贴数字
                                    // iOS Calendar 风格 —— 今天用主题色实心圆 + 白色数字,
                                    // 圆稍大(30pt)+ 字加粗,远远扫一眼就能找到"今天"。
                                    ZStack {
                                        if isToday {
                                            Circle()
                                                .fill(AppTheme.accent)
                                                .frame(width: 30, height: 30)
                                                .shadow(color: AppTheme.accent.opacity(0.35),
                                                        radius: 4, x: 0, y: 1)
                                        }
                                        Text("\(day)")
                                            .font(
                                                .system(
                                                    size: isToday ? 15 : 13,
                                                    weight: isToday ? .heavy
                                                            : (cs.isEmpty ? .regular : .bold),
                                                    design: .rounded
                                                ).monospacedDigit()
                                            )
                                            .foregroundStyle(
                                                isToday ? Color.white
                                                : (cs.isEmpty ? AppTheme.tertiary : AppTheme.ink)
                                            )
                                    }
                                    .frame(width: 30, height: 30)

                                    // 圆点占位高度固定为 5,即便没有扣费也保留位
                                    // 子,所有单元格高度一致,网格不会跳。
                                    HStack(spacing: 2) {
                                        ForEach(cs.prefix(3)) { c in
                                            Circle().fill(c.subscription.displayCategoryColor).frame(width: 4, height: 4)
                                        }
                                    }.frame(height: 5)
                                }
                                .frame(height: 40).frame(maxWidth: .infinity)
                                .background(
                                    isSelected && !isToday ? AppTheme.accent.opacity(0.30)
                                    : (!cs.isEmpty && !isToday ? AppTheme.accent.opacity(0.14) : .clear),
                                    in: RoundedRectangle(cornerRadius: AppTheme.radiusSmall)
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(!isInteractive)
                        } else {
                            Color.clear.frame(height: 38)
                        }
                    }
                }

                // 点中某天 + 那天有扣费,展开看具体哪些订阅。整块嵌一个浅
                // surface 子卡 + 内描边,跟外面的 Panel 形成"层级",比直接
                // 摊在网格下面更有"详情面板"的味道。
                //
                // 注意:用 ZStack { if ... } 模式而不是 Panel 顶层 if,这样收起时
                // ZStack 内的 view 平滑 fade-out 不会留"残影"。配合 .animation
                // (value: selectedDay) 把动画上下文绑定在 selectedDay 这个 key 上,
                // 月份切换的 spring 不会顺带触发详情卡的过渡。
                ZStack {
                    if let day = selectedDay,
                       let interval = Calendar.current.dateInterval(of: .month, for: monthAnchor),
                       let dayDate = Calendar.current.date(byAdding: .day, value: day - 1, to: interval.start),
                       let charges = byDay[day], !charges.isEmpty {
                        detailCard(dayDate: dayDate, charges: charges)
                            .id(detailID)
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.22), value: selectedDay)
            }
            .animation(AppTheme.spring, value: monthAnchor)
            .onChange(of: monthAnchor) { _, _ in
                // 月份切换时立刻清掉选中的"那一天",但用普通赋值 ——
                // 上面的 ZStack 已经用 .animation(value: selectedDay) 接管了过渡。
                selectedDay = nil
            }
            .onChange(of: selectedDay) { _, newValue in
                // 只在 newValue 非空(= 用户刚选了某天)时把详情滚到视口中部。
                // 取消选中(newValue == nil)就不滚,避免"收起的同时跳一下"。
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
                                Circle().fill(c.subscription.displayCategoryColor).frame(width: 6, height: 6)
                                Text(c.subscription.displayCategoryTitle)
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
            // BarMark 默认会撑满 Chart 的可用宽度,12 根柱子被拉得又粗又胖看着
            // 很突兀。给一个固定宽度 = 16pt × 12 月 + 间隔,Chart 加 .chartPlotStyle
            // 控制 plot 区域宽度,整体收一收更精致。同时高度也降一点(128 → 96)。
            Chart(store.monthTotalsForCurrentYear()) { p in
                BarMark(x: .value("月", p.month, unit: .month),
                        y: .value("金额", p.amount),
                        width: .fixed(16))
                    .foregroundStyle(
                        Calendar.current.compare(p.month, to: .now, toGranularity: .month) == .orderedAscending
                            ? AppTheme.tertiary : AppTheme.accent
                    )
                    .cornerRadius(4)
            }
            .chartXAxis { AxisMarks(values: .stride(by: .month)) { _ in
                AxisValueLabel(format: .dateTime.month(.narrow))
            } }
            .chartYAxis(.hidden)
            .frame(height: 96)
            .frame(maxWidth: .infinity)
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

// MARK: - Quick stats (1×3 数字面板)
//
// 三张并排的数字卡:活跃订阅数 / 当前周期的均摊金额 / 平均每个订阅。
// "均摊金额"会跟 period 联动(月 → 月均、季 → 季均、年 → 年均),不再
// 跟 Hero 顶部的总额 + 顶部切换器三重重复展示同一信息。
private struct QuickStatsPanel: View {
    @EnvironmentObject private var store: SubscriptionStore
    let period: SpendPeriod

    private var activeCount: Int { store.activeSubscriptions.count }
    private var archivedCount: Int { store.archivedSubscriptions.count }
    private var monthly: Double { store.monthlyTotal }
    /// 当前周期口径下的"全期总额"(月 = 月均、季 = 月均*3、年 = 年均)
    private var periodicTotal: Double {
        switch period {
        case .month:   return monthly
        case .quarter: return monthly * 3
        case .year:    return monthly * 12
        }
    }
    private var averagePerSub: Double {
        guard activeCount > 0 else { return 0 }
        return periodicTotal / Double(activeCount)
    }
    private var trialCount: Int {
        store.activeSubscriptions.filter { $0.status == .trial }.count
    }
    private var autoCount: Int {
        store.activeSubscriptions.filter { $0.status == .active }.count
    }
    private var manualCount: Int {
        store.activeSubscriptions.filter { $0.status == .manual }.count
    }

    /// 周期均摊卡片的标题文案 —— 跟 Hero 的"本月 / 本季 / 今年"不冲突,
    /// 用"摊到 X"这种更日常的口吻,提示这是一个 derived value。
    private var periodicLabel: LocalizedStringKey {
        switch period {
        case .month:   "月均"
        case .quarter: "季均"
        case .year:    "年均"
        }
    }
    private var periodicHint: String {
        switch period {
        case .month:   String(localized: "全部摊到每月")
        case .quarter: String(localized: "全部摊到每季")
        case .year:    String(localized: "全部摊到每年")
        }
    }
    private var averageHint: String {
        switch period {
        case .month:   String(localized: "每个订阅·月")
        case .quarter: String(localized: "每个订阅·季")
        case .year:    String(localized: "每个订阅·年")
        }
    }
    /// 活跃卡的副文本:有试用就提示试用数;否则展示自动 / 手动的拆分,
    /// 没有的话再 fall back 到归档计数,总有一行有用信息可读。
    private var activeHint: String {
        if trialCount > 0 {
            return String(localized: "含 \(trialCount) 个试用")
        }
        if autoCount > 0 && manualCount > 0 {
            return String(localized: "\(autoCount) 自动 · \(manualCount) 手动")
        }
        if autoCount > 0 { return String(localized: "全部自动续费") }
        if manualCount > 0 { return String(localized: "全部手动续费") }
        if archivedCount > 0 { return String(localized: "另有 \(archivedCount) 个归档") }
        return String(localized: "运行中")
    }

    var body: some View {
        // 顶部 Hero 已经展示了当前周期的"总额"+ "订阅数量彩蛋",所以这里不再放"活跃
        // 订阅"卡(信息重复)。剩两张:周期均摊金额 + 平均每个订阅。两张卡视觉更稳定,
        // 切换 period 也不容易引起页面拉伸。
        HStack(spacing: AppTheme.Space.m) {
            StatCard(label: periodicLabel,
                     value: store.converter.format(periodicTotal, currency: store.baseCurrency),
                     hint: periodicHint)
            StatCard(label: "平均每个",
                     value: store.converter.format(averagePerSub, currency: store.baseCurrency),
                     hint: averageHint)
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
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1).minimumScaleFactor(0.55)
            // 不挂 contentTransition:切 period 时数字宽度变化会让卡片宽度
            // 也跟着插值,视觉上是 "Overview 在拉伸" —— 用户多次反馈的现象。
            if let hint {
                Text(hint)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.tertiary)
                    .lineLimit(1).minimumScaleFactor(0.7)
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

// MARK: - 试用倒计时面板

/// 只在用户至少有一个 `.trial` 订阅时显示;空则整个面板不渲染(连标题也不出)。
/// 每行 = 一个试用订阅,大号"X 天"剩余、订阅名、首次正式扣费的金额和日期。
private struct TrialPanel: View {
    @EnvironmentObject private var store: SubscriptionStore

    private var trials: [Subscription] { store.trialSubscriptions }

    private func daysUntil(_ date: Date) -> Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let target = cal.startOfDay(for: date)
        return cal.dateComponents([.day], from: today, to: target).day ?? 0
    }

    var body: some View {
        if !trials.isEmpty {
            Panel(title: "试用倒计时") {
                VStack(spacing: 0) {
                    ForEach(Array(trials.enumerated()), id: \.element.id) { i, sub in
                        if i > 0 { Hairline() }
                        row(sub)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func row(_ sub: Subscription) -> some View {
        let days = max(0, daysUntil(sub.nextBillingDate))
        // 试用快到期或已过期,数字用红色突出
        let isUrgent = days <= 3
        let firstCharge = store.converter.convert(
            sub.price, from: sub.currency, to: store.baseCurrency
        )
        HStack(spacing: AppTheme.Space.m) {
            CategoryGlyph(subscription: sub, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(sub.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                HStack(spacing: 4) {
                    Text(String(localized: "首次扣费"))
                        .font(.caption).foregroundStyle(AppTheme.secondary)
                    Text(store.converter.format(firstCharge, currency: store.baseCurrency))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                    Text("·")
                        .font(.caption).foregroundStyle(AppTheme.tertiary)
                    Text(sub.nextBillingDate.formatted(.dateTime.month().day()))
                        .font(.caption).foregroundStyle(AppTheme.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(days)")
                    .font(.system(size: 24, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(isUrgent ? Color.red : AppTheme.accent)
                    .contentTransition(.numericText())
                Text(String(localized: "天"))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.tertiary)
            }
        }
        .padding(.vertical, AppTheme.Space.s)
    }
}

// MARK: - 支出趋势(占位,已下线)
//
// 早期的 SpendTrendPanel 在用户反馈"看不懂"后整块下线,不再渲染。
// 留下相关 store 方法(recentMonthTotals / monthTotal)备未来重新启用。

#if false
private struct _DeprecatedSpendTrendPanel: View {
    @EnvironmentObject private var store: SubscriptionStore

    private var history: [ForecastMonth] { store.recentMonthTotals(6) }
    private var thisMonth: Double { history.last?.amount ?? 0 }
    private var lastMonth: Double {
        guard history.count >= 2 else { return 0 }
        return history[history.count - 2].amount
    }
    private var delta: Double { thisMonth - lastMonth }
    private var percent: Double {
        guard lastMonth > 0 else { return 0 }
        return delta / lastMonth
    }
    private var isUp: Bool { delta > 0.01 }
    private var isDown: Bool { delta < -0.01 }
    private var deltaColor: Color {
        if isUp { return .red }   // 花得更多 = 警示色
        if isDown { return .green }
        return AppTheme.secondary
    }
    private var arrow: String {
        if isUp { return "arrow.up.right" }
        if isDown { return "arrow.down.right" }
        return "minus"
    }

    var body: some View {
        Panel(title: "支出趋势") {
            VStack(alignment: .leading, spacing: AppTheme.Space.m) {
                HStack(alignment: .firstTextBaseline, spacing: AppTheme.Space.s) {
                    HStack(spacing: 4) {
                        Image(systemName: arrow)
                            .font(.caption.weight(.heavy))
                        Text(deltaText)
                            .font(.subheadline.weight(.bold).monospacedDigit())
                    }
                    .foregroundStyle(deltaColor)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(deltaColor.opacity(0.14), in: Capsule())

                    Text(comparisonText)
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondary)
                    Spacer()
                }

                // 迷你折线 + 当前点高亮
                if history.count >= 2 {
                    Chart(history) { p in
                        LineMark(
                            x: .value("month", p.month, unit: .month),
                            y: .value("amount", p.amount)
                        )
                        .foregroundStyle(AppTheme.accent)
                        .lineStyle(StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("month", p.month, unit: .month),
                            y: .value("amount", p.amount)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppTheme.accent.opacity(0.28), AppTheme.accent.opacity(0.0)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)

                        if p.month == history.last?.month {
                            PointMark(
                                x: .value("month", p.month, unit: .month),
                                y: .value("amount", p.amount)
                            )
                            .foregroundStyle(AppTheme.accent)
                            .symbolSize(80)
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .month)) { _ in
                            AxisValueLabel(format: .dateTime.month(.narrow))
                                .font(.caption2)
                        }
                    }
                    .chartYAxis(.hidden)
                    .frame(height: 90)
                }
            }
        }
    }

    private var deltaText: String {
        let sign = isUp ? "+" : (isDown ? "-" : "")
        let absDelta = store.converter.format(abs(delta), currency: store.baseCurrency)
        if lastMonth > 0 {
            let pct = Int((abs(percent) * 100).rounded())
            return "\(sign)\(absDelta) (\(sign)\(pct)%)"
        }
        return "\(sign)\(absDelta)"
    }

    private var comparisonText: String {
        if lastMonth == 0 {
            return String(localized: "上月无支出")
        }
        if isUp {
            return String(localized: "比上月多")
        }
        if isDown {
            return String(localized: "比上月少")
        }
        return String(localized: "与上月持平")
    }
}
#endif

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
