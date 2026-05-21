import Foundation
import SwiftUI
import UIKit
import WidgetKit

@MainActor
final class SubscriptionStore: ObservableObject {
    @Published var subscriptions: [Subscription] {
        didSet {
            save()
            syncReminders()
            updateWidgetSnapshot()
        }
    }

    @Published var baseCurrency: CurrencyCode {
        didSet { saveSettings(); updateWidgetSnapshot() }
    }

    @Published var remindersEnabled: Bool {
        didSet {
            saveSettings()
            syncReminders()
        }
    }

    @Published var iCloudSyncEnabled: Bool {
        didSet {
            saveSettings()
            if iCloudSyncEnabled {
                syncFromICloud()
            }
        }
    }

    @Published var appearance: AppAppearance = .system {
        didSet { saveSettings() }
    }

    @Published var accentTheme: AccentTheme = .blue {
        didSet { AppTheme.accentTheme = accentTheme; saveSettings() }
    }

    @Published var paymentMethods: [String] = Settings.defaultPaymentMethods {
        didSet { saveSettings() }
    }

    @Published private(set) var lastSyncedAt: Date? = nil

    @Published var defaultReminderDays: Int = 3 {
        didSet { saveSettings() }
    }

    @Published var coloredSubscriptionCards: Bool = true {
        didSet { saveSettings() }
    }

    /// 全局触觉反馈开关。默认开。改动时同步给 Haptics.enabled,让所有走 Haptics
    /// 的反馈点立即生效。
    @Published var hapticsEnabled: Bool = true {
        didSet { Haptics.enabled = hapticsEnabled; saveSettings() }
    }

    /// 用户在"分类管理"里给分类起的自定义名字。Key 是 SubscriptionCategory.rawValue,
    /// 空串视为未自定义。改动会立即 mirror 到 SubscriptionCategory.nameOverrides 上,
    /// 这样全 App 所有读 title 的地方自动跟进。
    @Published var categoryNameOverrides: [String: String] = [:] {
        didSet {
            SubscriptionCategory.nameOverrides = categoryNameOverrides
            saveSettings()
        }
    }

    /// 用户自建的分类列表。改动会同步刷新 `Subscription.customLookup`,
    /// 这样全 App 所有 `displayCategoryTitle/Color` 立刻跟进。
    @Published var customCategories: [CustomCategory] = [] {
        didSet {
            Subscription.customLookup = Dictionary(uniqueKeysWithValues: customCategories.map { ($0.id, $0) })
            saveSettings()
        }
    }

    /// 三个小彩蛋的开关。默认全开,用户可以在"设置 → 彩蛋"里独立关闭其中任意一个。
    @Published var easterEggs: EasterEggPrefs = EasterEggPrefs() {
        didSet { saveSettings() }
    }

    @Published private(set) var cnyRates: [CurrencyCode: Double] = CurrencyConverter.builtin
    @Published private(set) var ratesUpdatedAt: Date?
    var converter: CurrencyConverter { CurrencyConverter(cnyRates: cnyRates) }

    private var isApplyingRemote = false
    private var kvsObserver: NSObjectProtocol?
    private var foregroundObserver: NSObjectProtocol?

    private let subscriptionsKey = "subscriptions.v1"
    private let settingsKey = "settings.v1"
    private let iCloudSubscriptionsKey = "icloud.subscriptions.v1"
    private let ratesKey = "rates.v1"
    private let lastSyncedAtKey = "icloud.lastSyncedAt.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: subscriptionsKey),
           let decoded = try? JSONDecoder.subscriptionDecoder.decode([Subscription].self, from: data) {
            subscriptions = decoded
        } else {
            subscriptions = [Self.example]
        }

        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let settings = try? JSONDecoder().decode(Settings.self, from: data) {
            baseCurrency = settings.baseCurrency
            remindersEnabled = settings.remindersEnabled
            iCloudSyncEnabled = settings.iCloudSyncEnabled
            appearance = settings.appearance
            paymentMethods = settings.paymentMethods
            accentTheme = settings.accentTheme
            defaultReminderDays = settings.defaultReminderDays
            coloredSubscriptionCards = settings.coloredSubscriptionCards
            categoryNameOverrides = settings.categoryNameOverrides
            customCategories = settings.customCategories
            easterEggs = settings.easterEggs
            hapticsEnabled = settings.hapticsEnabled
        } else {
            baseCurrency = .cny
            remindersEnabled = true
            iCloudSyncEnabled = false
        }
        // 把持久化的开关同步给全局 Haptics,避免首帧之前的反馈不受控。
        Haptics.enabled = hapticsEnabled
        // Mirror category overrides into the enum's static lookup so every read
        // of SubscriptionCategory.title sees the user's customised names.
        SubscriptionCategory.nameOverrides = categoryNameOverrides
        Subscription.customLookup = Dictionary(uniqueKeysWithValues: customCategories.map { ($0.id, $0) })

        AppTheme.accentTheme = accentTheme

        if let d = UserDefaults.standard.object(forKey: lastSyncedAtKey) as? Date {
            lastSyncedAt = d
        }

        if iCloudSyncEnabled {
            syncFromICloud()
        }
        if let data = UserDefaults.standard.data(forKey: ratesKey),
           let cached = try? JSONDecoder().decode(CachedRates.self, from: data) {
            var loaded: [CurrencyCode: Double] = [:]
            for (k, v) in cached.rates {
                if let code = CurrencyCode(rawValue: k) { loaded[code] = v }
            }
            if !loaded.isEmpty {
                loaded[.cny] = 1.0
                cnyRates = loaded
                ratesUpdatedAt = cached.updatedAt
            }
        }
        syncReminders()
        // 启动时跑一遍"到期归档" —— 旧设备上一直开着 App 没动也得追得回来。
        autoArchiveExpiredSubscriptions()
        updateWidgetSnapshot()
        Task { await refreshRatesIfStale() }
        startSyncObservers()
    }

    /// 把所有"设置了 endDate 且已经到日"的订阅自动归档。
    /// init 调一次,App 回到前台时再调一次 —— 跨午夜会触发,无需用户手动。
    /// 命中后会顺手 syncReminders() 取消那条已归档订阅的本地通知。
    func autoArchiveExpiredSubscriptions(asOf now: Date = .now) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        var changed = false
        subscriptions = subscriptions.map { sub in
            guard !sub.isArchived,
                  let end = sub.endDate,
                  cal.startOfDay(for: end) <= today else { return sub }
            var s = sub
            s.isArchived = true
            changed = true
            return s
        }
        if changed { syncReminders() }
    }

    var activeSubscriptions: [Subscription] {
        subscriptions.filter { $0.isActive && !$0.isArchived }
    }

    var archivedSubscriptions: [Subscription] {
        subscriptions.filter(\.isArchived)
    }

    /// 进入"金额聚合"的子集 —— 活跃 + 未归档 + 用户没把 includeInStatistics 关掉。
    /// 几乎所有 ¥ 数字的来源(monthlyTotal / categorySpend / lifetimeSpend / 各种
    /// 图表)都走这个,而不是 activeSubscriptions。展示用的列表 / 日历 / 提醒还是
    /// 用 activeSubscriptions —— 关闭统计不代表关闭这个订阅。
    var statisticsCountableSubscriptions: [Subscription] {
        activeSubscriptions.filter { $0.includeInStatistics }
    }

    var monthlyTotal: Double {
        statisticsCountableSubscriptions.reduce(0) {
            $0 + $1.monthlyCost(in: baseCurrency, converter: converter)
        }
    }

    var annualTotal: Double {
        monthlyTotal * 12
    }

    var upcoming: [Subscription] {
        activeSubscriptions
            .sorted { $0.nextBillingDate < $1.nextBillingDate }
            .prefix(6)
            .map { $0 }
    }

    func total(for category: SubscriptionCategory) -> Double {
        statisticsCountableSubscriptions
            .filter { $0.category == category && $0.customCategoryID == nil }
            .reduce(0) { $0 + $1.monthlyCost(in: baseCurrency, converter: converter) }
    }

    /// 按"displayCategoryID"分桶聚合金额 —— 自定义分类有自己的桶,内置分类
    /// 走 enum.rawValue。每个桶顺便带上展示标题 / 颜色,饼图直接消费。
    /// 只统计 includeInStatistics 为 true 的订阅。
    var categorySpend: [CategorySpend] {
        let total = monthlyTotal
        var buckets: [String: Double] = [:]
        var meta: [String: (title: String, color: Color)] = [:]
        for sub in statisticsCountableSubscriptions {
            let id = sub.displayCategoryID
            buckets[id, default: 0] += sub.monthlyCost(in: baseCurrency, converter: converter)
            if meta[id] == nil {
                meta[id] = (sub.displayCategoryTitle, sub.displayCategoryColor)
            }
        }
        return buckets.compactMap { id, amount -> CategorySpend? in
            guard amount > 0, let m = meta[id] else { return nil }
            return CategorySpend(
                id: id, title: m.title, color: m.color,
                amount: amount,
                share: total == 0 ? 0 : amount / total
            )
        }
        .sorted { $0.amount > $1.amount }
    }

    // MARK: - Lifetime spend (cumulative billing)

    /// 整个活跃订阅集合"从各自起始日累计扣过的钱"之和(基础币种)。
    /// 用统计口径(includeInStatistics)。
    var totalLifetimeSpend: Double {
        statisticsCountableSubscriptions.reduce(0) { acc, sub in
            acc + sub.lifetimeSpend(in: baseCurrency, converter: converter)
        }
    }

    /// 总扣费次数 —— 跟 totalLifetimeSpend 同口径,用作"已经为这些订阅付过 N 笔"
    /// 的一行文案。
    var totalLifetimeChargeCount: Int {
        statisticsCountableSubscriptions.reduce(0) { $0 + $1.billingCountElapsed() }
    }

    /// 按累计支付金额排序的活跃订阅 —— Overview 的 Lifetime 面板用来挑 top N。
    func subscriptionsByLifetimeSpend(limit: Int = 3) -> [Subscription] {
        statisticsCountableSubscriptions
            .sorted {
                $0.lifetimeSpend(in: baseCurrency, converter: converter) >
                $1.lifetimeSpend(in: baseCurrency, converter: converter)
            }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Custom categories CRUD

    /// 还能再加几个 custom 分类(达到上限就返回 0)。
    var customCategorySlotsLeft: Int {
        max(0, CustomCategory.maxCount - customCategories.count)
    }

    func addCustomCategory(name: String, colorHex: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, customCategorySlotsLeft > 0 else { return }
        customCategories.append(CustomCategory(name: trimmed, colorHex: colorHex))
    }

    func updateCustomCategory(_ updated: CustomCategory) {
        guard let i = customCategories.firstIndex(where: { $0.id == updated.id }) else { return }
        customCategories[i] = updated
    }

    /// 删除一个 custom 分类。引用它的订阅会被自动解绑(customCategoryID 置 nil),
    /// 它们会回到自己的内置 `category` 上显示。
    func deleteCustomCategory(id: UUID) {
        customCategories.removeAll { $0.id == id }
        subscriptions = subscriptions.map { sub in
            guard sub.customCategoryID == id else { return sub }
            var s = sub
            s.customCategoryID = nil
            return s
        }
    }

    func interval(for period: SpendPeriod) -> DateInterval {
        let component: Calendar.Component
        switch period {
        case .month:   component = .month
        case .quarter: component = .quarter
        case .year:    component = .year
        }
        return Calendar.current.dateInterval(of: component, for: .now)
            ?? DateInterval(start: .now, duration: 0)
    }

    func charges(in period: SpendPeriod) -> [RenewalCharge] {
        let interval = interval(for: period)
        // 进金额聚合的口径 —— 关掉"计入统计"的订阅不在这里出现
        return statisticsCountableSubscriptions.flatMap { subscription in
            projectedCharges(for: subscription, from: interval.start, to: interval.end)
        }
        .sorted { $0.date < $1.date }
    }

    /// 任意月份的扣费日（含倒推过去月份）；仅供扣费日历使用，不影响 Hero/分类/年图。
    func charges(inMonthContaining date: Date) -> [RenewalCharge] {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: date) else { return [] }
        return activeSubscriptions
            .flatMap { projectedChargesBidirectional(for: $0, from: interval.start, to: interval.end) }
            .sorted { $0.date < $1.date }
    }

    /// 整个周期内的全部扣费（含本期已扣，双向推算）——用于首页总额。
    /// 只统计 includeInStatistics 为 true 的订阅。
    func fullCharges(in period: SpendPeriod) -> [RenewalCharge] {
        let iv = interval(for: period)
        return statisticsCountableSubscriptions
            .flatMap { projectedChargesBidirectional(for: $0, from: iv.start, to: iv.end) }
            .sorted { $0.date < $1.date }
    }
    func fullDueAmount(in period: SpendPeriod) -> Double {
        fullCharges(in: period).reduce(0) { $0 + $1.amount }
    }
    func fullDueCount(in period: SpendPeriod) -> Int {
        fullCharges(in: period).count
    }

    /// 双向推算：从 nextBillingDate 按周期向前/向后走，覆盖任意 [start,end) 窗口（过去月份也能得到"本该扣费"的日子）。
    private func projectedChargesBidirectional(for subscription: Subscription, from start: Date, to end: Date) -> [RenewalCharge] {
        let calendar = Calendar.current
        var chargeDate = subscription.nextBillingDate
        var charges: [RenewalCharge] = []

        // 下次扣费在窗口之后（看过去月份）→ 按周期向回倒推到窗口前/内
        var backGuard = 0
        while chargeDate >= end {
            let prev = subscription.billingCycle.advance(chargeDate, by: -1, calendar: calendar, customDays: subscription.customCycleDays)
            guard prev < chargeDate, backGuard < 5000 else { break }
            chargeDate = prev; backGuard += 1
        }
        // 仍早于窗口起点 → 按周期前进
        var fwdGuard = 0
        while chargeDate < start {
            let next = subscription.billingCycle.advance(chargeDate, by: 1, calendar: calendar, customDays: subscription.customCycleDays)
            guard next > chargeDate, fwdGuard < 5000 else { break }
            chargeDate = next; fwdGuard += 1
        }
        // 收集 [start, end)
        var collectGuard = 0
        while chargeDate < end {
            if chargeDate >= start {
                charges.append(RenewalCharge(
                    subscription: subscription,
                    date: chargeDate,
                    amount: converter.convert(subscription.price, from: subscription.currency, to: baseCurrency)
                ))
            }
            let next = subscription.billingCycle.advance(chargeDate, by: 1, calendar: calendar, customDays: subscription.customCycleDays)
            guard next > chargeDate, collectGuard < 5000 else { break }
            chargeDate = next; collectGuard += 1
        }
        return charges
    }

    func dueAmount(in period: SpendPeriod) -> Double {
        charges(in: period).reduce(0) { $0 + $1.amount }
    }

    func dueCount(in period: SpendPeriod) -> Int {
        charges(in: period).count
    }

    func nextCharge(in period: SpendPeriod) -> RenewalCharge? {
        charges(in: period).first { $0.date >= .now } ?? charges(in: period).first
    }

    /// 每个有效订阅的"下一笔未来扣费"（date >= 现在，日历精确），按日期升序，最多 limit 条。每个订阅最多 1 条。
    /// 接下来 `days` 天内每个订阅会发生的所有扣费 —— 同一订阅在窗口里可能出现多次
    /// (周付订阅就会出现 ~4 次)。专供 Overview 上的 30 天预览柱图使用。
    func chargesInNext(_ days: Int) -> [RenewalCharge] {
        // 同 upcomingCharges 的修复:用 startOfDay 作为"现在",避免今天 00:00
        // 被当成已经过去。否则今天到期的订阅会被跳到下一个周期。
        let cal = Calendar.current
        let now = cal.startOfDay(for: Date())
        guard let end = cal.date(byAdding: .day, value: days, to: now) else { return [] }
        return activeSubscriptions
            .flatMap { projectedCharges(for: $0, from: now, to: end) }
            .sorted { $0.date < $1.date }
    }

    func upcomingCharges(limit: Int = 6) -> [RenewalCharge] {
        // 关键:用 startOfDay,不要用 Date()。
        // nextBillingDate 存的是 00:00,Date() 是当下时刻(比如 21:53)。
        // 如果 nextBillingDate 正好是今天,d (00:00) < now (21:53) 永远成立,
        // 循环会把 d 推到下一个 cycle —— 对年付订阅就是直接跳到"明年同一天"。
        // 用 startOfDay 之后,今天的 bill 在凌晨 00:00 之前都被视作"未到来",
        // 当前/即将续费的判断回归直觉。
        let calendar = Calendar.current
        let now = calendar.startOfDay(for: Date())
        return activeSubscriptions.compactMap { sub -> RenewalCharge? in
            var d = sub.nextBillingDate
            var guardCount = 0
            while d < now {
                let next = sub.billingCycle.advance(d, by: 1, calendar: calendar, customDays: sub.customCycleDays)
                guard next > d, guardCount < 5000 else { break }
                d = next; guardCount += 1
            }
            guard d >= now else { return nil }
            return RenewalCharge(
                subscription: sub,
                date: d,
                amount: converter.convert(sub.price, from: sub.currency, to: baseCurrency))
        }
        .sorted { $0.date < $1.date }
        .prefix(limit)
        .map { $0 }
    }

    // MARK: - Spend trend (同比 / 环比 + 6 个月迷你折线)

    /// 任意一个月份的全部扣费总额(基于该月起止双向推算,跟 Hero 数字保持一致)。
    func monthTotal(_ monthAnchor: Date) -> Double {
        let cal = Calendar.current
        guard let iv = cal.dateInterval(of: .month, for: monthAnchor) else { return 0 }
        return statisticsCountableSubscriptions
            .flatMap { projectedChargesBidirectional(for: $0, from: iv.start, to: iv.end) }
            .reduce(0) { $0 + $1.amount }
    }

    /// 过去 `count` 个月(含本月)的逐月总额,按时间升序。供迷你折线图使用。
    func recentMonthTotals(_ count: Int = 6) -> [ForecastMonth] {
        let cal = Calendar.current
        let thisMonthStart = cal.dateInterval(of: .month, for: .now)?.start ?? .now
        return (0..<count).reversed().compactMap { offset -> ForecastMonth? in
            guard let m = cal.date(byAdding: .month, value: -offset, to: thisMonthStart) else { return nil }
            return ForecastMonth(month: m, amount: monthTotal(m))
        }
    }

    // MARK: - Trial countdown

    /// 当前所有试用中的订阅,按"距首次正式扣费的天数"升序。空数组 = 不显示面板。
    var trialSubscriptions: [Subscription] {
        activeSubscriptions
            .filter { $0.status == .trial }
            .sorted { $0.nextBillingDate < $1.nextBillingDate }
    }

    // MARK: - Yearly heatmap (366 days × amount)

    /// 当年每一天的扣费总额(无扣费的日子值为 0)。日期 = 当地日历 00:00。
    /// 用于 12×31 热力图。返回顺序按日期升序。
    func dailyTotalsForCurrentYear() -> [(date: Date, amount: Double)] {
        let cal = Calendar.current
        let iv = interval(for: .year)
        let all = statisticsCountableSubscriptions
            .flatMap { projectedChargesBidirectional(for: $0, from: iv.start, to: iv.end) }
        // 把扣费按"当日 startOfDay"聚合
        var bucket: [Date: Double] = [:]
        for c in all {
            let d = cal.startOfDay(for: c.date)
            bucket[d, default: 0] += c.amount
        }
        // 遍历每一天产出 (date, amount)
        var out: [(Date, Double)] = []
        var cursor = iv.start
        while cursor < iv.end {
            out.append((cursor, bucket[cal.startOfDay(for: cursor)] ?? 0))
            guard let next = cal.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return out
    }

    func monthTotalsForCurrentYear() -> [ForecastMonth] {
        let calendar = Calendar.current
        let yearStart = interval(for: .year).start

        return (0..<12).map { offset in
            let month = calendar.date(byAdding: .month, value: offset, to: yearStart) ?? yearStart
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: month) ?? month
            // 年柱图按统计口径,不包含被排除的订阅
            let amount = statisticsCountableSubscriptions.flatMap {
                projectedCharges(for: $0, from: month, to: nextMonth)
            }
            .reduce(0) { $0 + $1.amount }

            return ForecastMonth(month: month, amount: amount)
        }
    }

    func upsert(_ subscription: Subscription) {
        if let index = subscriptions.firstIndex(where: { $0.id == subscription.id }) {
            subscriptions[index] = subscription
        } else {
            subscriptions.append(subscription)
        }
    }

    func archive(ids: [UUID]) { applyArchived(ids, true) }

    func restore(ids: [UUID]) { applyArchived(ids, false) }

    private func applyArchived(_ ids: [UUID], _ value: Bool) {
        subscriptions = subscriptions.map { sub in
            guard ids.contains(sub.id) else { return sub }
            var s = sub
            s.isArchived = value
            return s
        }
    }

    func delete(ids: [UUID]) {
        for sub in subscriptions where ids.contains(sub.id) {
            if case .image(let iconId) = sub.icon { IconStore.delete(iconId) }
        }
        subscriptions.removeAll { ids.contains($0.id) }
    }

    func addPaymentMethod(_ raw: String) {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !paymentMethods.contains(name) else { return }
        paymentMethods.append(name)
    }

    func removePaymentMethods(at offsets: IndexSet) {
        paymentMethods.remove(atOffsets: offsets)
    }

    func syncToICloud() {
        guard iCloudSyncEnabled, !isApplyingRemote,
              let data = try? JSONEncoder.subscriptionEncoder.encode(subscriptions) else { return }

        NSUbiquitousKeyValueStore.default.set(data, forKey: iCloudSubscriptionsKey)
        NSUbiquitousKeyValueStore.default.synchronize()
        lastSyncedAt = Date()
        saveLastSyncedAt()
    }

    func syncFromICloud() {
        guard iCloudSyncEnabled else { return }

        NSUbiquitousKeyValueStore.default.synchronize()
        guard let data = NSUbiquitousKeyValueStore.default.data(forKey: iCloudSubscriptionsKey),
              let decoded = try? JSONDecoder.subscriptionDecoder.decode([Subscription].self, from: data) else {
            syncToICloud()
            return
        }
        guard decoded != subscriptions else { return }
        isApplyingRemote = true
        subscriptions = decoded
        isApplyingRemote = false
        lastSyncedAt = Date()
        saveLastSyncedAt()
    }

    /// 用户在数据页点"立即同步"时调用。先拉云端、再推本地；任一环节失败也不抛出。
    func performManualICloudSync() async {
        syncFromICloud()
        syncToICloud()
        lastSyncedAt = Date()
        saveLastSyncedAt()
    }

    private func saveLastSyncedAt() {
        if let d = lastSyncedAt { UserDefaults.standard.set(d, forKey: lastSyncedAtKey) }
    }

    private func startSyncObservers() {
        kvsObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.syncFromICloud() }
        }
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.syncFromICloud()
                // 回到前台时也跑一次到期归档,跨午夜的订阅这时就会自动下架。
                self?.autoArchiveExpiredSubscriptions()
            }
        }
    }

    private func projectedCharges(for subscription: Subscription, from start: Date, to end: Date) -> [RenewalCharge] {
        let calendar = Calendar.current
        var chargeDate = subscription.nextBillingDate
        var charges: [RenewalCharge] = []
        var guardCount = 0
        func step() -> Bool {
            let next = subscription.billingCycle.advance(chargeDate, by: 1, calendar: calendar, customDays: subscription.customCycleDays)
            guard next > chargeDate, guardCount < 5000 else { return false }
            chargeDate = next; guardCount += 1; return true
        }
        while chargeDate < start { if !step() { return charges } }
        while chargeDate < end {
            if chargeDate >= start {
                charges.append(RenewalCharge(
                    subscription: subscription,
                    date: chargeDate,
                    amount: converter.convert(subscription.price, from: subscription.currency, to: baseCurrency)))
            }
            if !step() { break }
        }
        return charges
    }

    private func save() {
        if let data = try? JSONEncoder.subscriptionEncoder.encode(subscriptions) {
            UserDefaults.standard.set(data, forKey: subscriptionsKey)
        }
        syncToICloud()
    }

    private func saveSettings() {
        let settings = Settings(
            baseCurrency: baseCurrency,
            remindersEnabled: remindersEnabled,
            iCloudSyncEnabled: iCloudSyncEnabled,
            appearance: appearance,
            paymentMethods: paymentMethods,
            accentTheme: accentTheme,
            defaultReminderDays: defaultReminderDays,
            coloredSubscriptionCards: coloredSubscriptionCards,
            categoryNameOverrides: categoryNameOverrides,
            customCategories: customCategories,
            easterEggs: easterEggs,
            hapticsEnabled: hapticsEnabled
        )
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: settingsKey)
        }
    }

    func syncReminders() {
        NotificationScheduler.cancelAll()
        if remindersEnabled {
            NotificationScheduler.rescheduleAll(subscriptions)
        }
    }

    /// 把展示用的数据算成一份快照写进 App Group,供桌面 / 锁屏 widget 读取,
    /// 然后请 WidgetKit 刷新时间线。订阅 / 币种变化时都会调一次。
    /// 真实图标渲染成 PNG 写到共享容器 icons/<id>.png,快照里只存 id。
    func updateWidgetSnapshot() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        // 先把要用到的图标渲染并写进 App Group 容器(按 id 去重)。
        var writtenIcons = Set<String>()
        if let dir = EONWidgetStore.iconsDir {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        func ensureIcon(_ sub: Subscription) -> String {
            let idStr = sub.id.uuidString
            guard !writtenIcons.contains(idStr) else { return idStr }
            writtenIcons.insert(idStr)
            if let data = NotificationIconRenderer.pngData(for: sub),
               let url = EONWidgetStore.iconURL(idStr) {
                try? data.write(to: url, options: .atomic)
            }
            return idStr
        }

        func makeItem(_ c: RenewalCharge) -> EONWidgetSnapshot.Item {
            let days = cal.dateComponents([.day], from: today,
                                          to: cal.startOfDay(for: c.date)).day ?? 0
            return EONWidgetSnapshot.Item(
                name: c.subscription.name,
                amountText: converter.format(c.amount, currency: baseCurrency),
                dateText: c.date.formatted(.dateTime.month().day()),
                daysLeft: max(0, days),
                paid: days < 0,
                letter: String(c.subscription.name.prefix(1)).uppercased(),
                colorHex: UIColor(c.subscription.displayCategoryColor).eonHexString,
                iconID: ensureIcon(c.subscription)
            )
        }

        let upcoming = upcomingCharges(limit: 5).map(makeItem)
        let month = charges(inMonthContaining: Date())
            .sorted { $0.date < $1.date }
            .prefix(12)
            .map(makeItem)
        let monthTotal = charges(inMonthContaining: Date()).reduce(0.0) { $0 + $1.amount }
        let (major, minor) = splitAmountForWidget(monthTotal)

        let snapshot = EONWidgetSnapshot(
            monthLabel: Date().formatted(.dateTime.month(.abbreviated)),
            monthMajor: major,
            monthMinor: minor,
            dueCount: charges(inMonthContaining: Date()).count,
            subscriptionCount: activeSubscriptions.count,
            upcoming: upcoming,
            periodCharges: Array(month),
            updatedAt: Date()
        )
        EONWidgetStore.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// 把金额拆成"符号+整数"和"两位小数",供 widget 把小数画小一号。
    /// 日元等无小数币种返回空小数。
    private func splitAmountForWidget(_ value: Double) -> (String, String) {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = 0
        nf.usesGroupingSeparator = true
        let intText = nf.string(from: NSNumber(value: floor(value))) ?? "\(Int(value))"
        let major = baseCurrency.symbol + intText
        if baseCurrency == .jpy { return (major, "") }
        let cents = Int(((value - floor(value)) * 100).rounded())
        return (major, String(format: "%02d", cents))
    }

    /// 距上次更新超过 24 小时（或从未更新）则后台刷新一次。
    func refreshRatesIfStale() async {
        if let last = ratesUpdatedAt, Date().timeIntervalSince(last) < 24 * 3600 { return }
        await refreshRates()
    }

    /// 立即拉取最新汇率；失败则保留当前（缓存或内置）值，不报错打断。
    func refreshRates() async {
        guard let fresh = try? await ExchangeRateService.fetchCNYRates() else { return }
        cnyRates = fresh
        let now = Date()
        ratesUpdatedAt = now
        let payload = CachedRates(rates: Dictionary(uniqueKeysWithValues: fresh.map { ($0.key.rawValue, $0.value) }),
                                  updatedAt: now)
        if let data = try? JSONEncoder().encode(payload) {
            UserDefaults.standard.set(data, forKey: ratesKey)
        }
    }
}

private struct CachedRates: Codable {
    var rates: [String: Double]
    var updatedAt: Date
}

private struct Settings: Codable {
    var baseCurrency: CurrencyCode
    var remindersEnabled: Bool
    var iCloudSyncEnabled: Bool
    var appearance: AppAppearance
    var paymentMethods: [String]
    var accentTheme: AccentTheme
    var defaultReminderDays: Int
    var coloredSubscriptionCards: Bool
    var categoryNameOverrides: [String: String]
    var customCategories: [CustomCategory]
    var easterEggs: EasterEggPrefs
    var hapticsEnabled: Bool

    static let defaultPaymentMethods = ["支付宝", "微信支付", "Apple Pay", "Visa", "Mastercard", "银联", "PayPal"]

    init(baseCurrency: CurrencyCode, remindersEnabled: Bool, iCloudSyncEnabled: Bool,
         appearance: AppAppearance, paymentMethods: [String], accentTheme: AccentTheme,
         defaultReminderDays: Int, coloredSubscriptionCards: Bool,
         categoryNameOverrides: [String: String],
         customCategories: [CustomCategory],
         easterEggs: EasterEggPrefs,
         hapticsEnabled: Bool = true) {
        self.baseCurrency = baseCurrency
        self.remindersEnabled = remindersEnabled
        self.iCloudSyncEnabled = iCloudSyncEnabled
        self.appearance = appearance
        self.paymentMethods = paymentMethods
        self.accentTheme = accentTheme
        self.defaultReminderDays = defaultReminderDays
        self.coloredSubscriptionCards = coloredSubscriptionCards
        self.categoryNameOverrides = categoryNameOverrides
        self.customCategories = customCategories
        self.easterEggs = easterEggs
        self.hapticsEnabled = hapticsEnabled
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        baseCurrency = try c.decodeIfPresent(CurrencyCode.self, forKey: .baseCurrency) ?? .cny
        remindersEnabled = try c.decodeIfPresent(Bool.self, forKey: .remindersEnabled) ?? true
        iCloudSyncEnabled = try c.decodeIfPresent(Bool.self, forKey: .iCloudSyncEnabled) ?? false
        appearance = try c.decodeIfPresent(AppAppearance.self, forKey: .appearance) ?? .system
        let pm = try c.decodeIfPresent([String].self, forKey: .paymentMethods) ?? Settings.defaultPaymentMethods
        paymentMethods = pm.isEmpty ? Settings.defaultPaymentMethods : pm
        accentTheme = try c.decodeIfPresent(AccentTheme.self, forKey: .accentTheme) ?? .blue
        defaultReminderDays = try c.decodeIfPresent(Int.self, forKey: .defaultReminderDays) ?? 3
        coloredSubscriptionCards = try c.decodeIfPresent(Bool.self, forKey: .coloredSubscriptionCards) ?? true
        categoryNameOverrides = try c.decodeIfPresent([String: String].self, forKey: .categoryNameOverrides) ?? [:]
        customCategories = try c.decodeIfPresent([CustomCategory].self, forKey: .customCategories) ?? []
        easterEggs = try c.decodeIfPresent(EasterEggPrefs.self, forKey: .easterEggs) ?? EasterEggPrefs()
        hapticsEnabled = try c.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? true
    }
}

/// 彩蛋开关合在一个 Codable 结构里,跟 Settings 一起持久化。
/// 新增彩蛋时只要往这里加字段就够了,不会影响老数据(decodeIfPresent fall back)。
/// 老的 `dragToArchive` 字段被移除了(整个左滑归档功能撤了) —— 老数据里如果
/// 仍存有这个 key,Codable 默认会安静忽略多余 key,不需要做额外迁移。
struct EasterEggPrefs: Codable, Equatable {
    var shakeSpotlight: Bool
    var dailyWelcomeConfetti: Bool
    /// 彩蛋页小球的"纯色表情"模式。开启后小球不再画订阅图标,而是用订阅的主色
    /// 做成纯色球 + 一个随机表情。默认关(显示真实图标),纯属玩。
    var solidEmojiBalls: Bool

    init(shakeSpotlight: Bool = true,
         dailyWelcomeConfetti: Bool = true,
         solidEmojiBalls: Bool = false) {
        self.shakeSpotlight = shakeSpotlight
        self.dailyWelcomeConfetti = dailyWelcomeConfetti
        self.solidEmojiBalls = solidEmojiBalls
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        shakeSpotlight = try c.decodeIfPresent(Bool.self, forKey: .shakeSpotlight) ?? true
        dailyWelcomeConfetti = try c.decodeIfPresent(Bool.self, forKey: .dailyWelcomeConfetti) ?? true
        solidEmojiBalls = try c.decodeIfPresent(Bool.self, forKey: .solidEmojiBalls) ?? false
    }
}

private extension UIColor {
    /// 取 "RRGGBB" 十六进制(给 widget 快照存色用,widget 端再用 Color(eonHex:) 还原)。
    var eonHexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X",
                      Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
    }
}

private extension JSONDecoder {
    static var subscriptionDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

private extension JSONEncoder {
    static var subscriptionEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension SubscriptionStore {
    static let example = Subscription(
        name: "Example",
        plan: "Plus",
        category: .other,
        price: 9.9,
        currency: .cny,
        billingCycle: .monthly,
        customCycleDays: 30,
        nextBillingDate: Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now,
        reminderDaysBefore: 3,
        status: .active,
        paymentMethod: "",
        icon: .default,
        isArchived: false
    )
}

