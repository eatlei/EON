import Foundation
import SwiftUI
import UIKit

@MainActor
final class SubscriptionStore: ObservableObject {
    @Published var subscriptions: [Subscription] {
        didSet {
            save()
            syncReminders()
        }
    }

    @Published var baseCurrency: CurrencyCode {
        didSet { saveSettings() }
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

    @Published var paymentMethods: [String] = Settings.defaultPaymentMethods {
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

    init() {
        if let data = UserDefaults.standard.data(forKey: subscriptionsKey),
           let decoded = try? JSONDecoder.subscriptionDecoder.decode([Subscription].self, from: data) {
            subscriptions = decoded
        } else {
            subscriptions = []
        }

        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let settings = try? JSONDecoder().decode(Settings.self, from: data) {
            baseCurrency = settings.baseCurrency
            remindersEnabled = settings.remindersEnabled
            iCloudSyncEnabled = settings.iCloudSyncEnabled
            appearance = settings.appearance
            paymentMethods = settings.paymentMethods
        } else {
            baseCurrency = .cny
            remindersEnabled = true
            iCloudSyncEnabled = false
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
        Task { await refreshRatesIfStale() }
        startSyncObservers()
    }

    var activeSubscriptions: [Subscription] {
        subscriptions.filter(\.isActive)
    }

    var monthlyTotal: Double {
        activeSubscriptions.reduce(0) {
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
        activeSubscriptions
            .filter { $0.category == category }
            .reduce(0) { $0 + $1.monthlyCost(in: baseCurrency, converter: converter) }
    }

    var categorySpend: [CategorySpend] {
        SubscriptionCategory.allCases.compactMap { category in
            let amount = total(for: category)
            guard amount > 0 else { return nil }
            return CategorySpend(category: category, amount: amount, share: monthlyTotal == 0 ? 0 : amount / monthlyTotal)
        }
        .sorted { $0.amount > $1.amount }
    }

    func interval(for period: SpendPeriod) -> DateInterval {
        let component: Calendar.Component = period == .month ? .month : .year
        return Calendar.current.dateInterval(of: component, for: .now) ?? DateInterval(start: .now, duration: 0)
    }

    func charges(in period: SpendPeriod) -> [RenewalCharge] {
        let interval = interval(for: period)
        return activeSubscriptions.flatMap { subscription in
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
    func fullCharges(in period: SpendPeriod) -> [RenewalCharge] {
        let iv = interval(for: period)
        return activeSubscriptions
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
        let cycleDays = subscription.billingCycle.days(customDays: subscription.customCycleDays)
        var charges: [RenewalCharge] = []

        // 下次扣费在窗口之后（看过去月份）→ 按周期向回倒推到窗口前/内
        while chargeDate >= end {
            guard let prev = calendar.date(byAdding: .day, value: -cycleDays, to: chargeDate) else { break }
            chargeDate = prev
        }
        // 仍早于窗口起点 → 按周期前进
        while chargeDate < start {
            guard let next = calendar.date(byAdding: .day, value: cycleDays, to: chargeDate) else { break }
            chargeDate = next
        }
        // 收集 [start, end)
        while chargeDate < end {
            if chargeDate >= start {
                charges.append(RenewalCharge(
                    subscription: subscription,
                    date: chargeDate,
                    amount: converter.convert(subscription.price, from: subscription.currency, to: baseCurrency)
                ))
            }
            guard let next = calendar.date(byAdding: .day, value: cycleDays, to: chargeDate) else { break }
            chargeDate = next
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

    func monthTotalsForCurrentYear() -> [ForecastMonth] {
        let calendar = Calendar.current
        let yearStart = interval(for: .year).start

        return (0..<12).map { offset in
            let month = calendar.date(byAdding: .month, value: offset, to: yearStart) ?? yearStart
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: month) ?? month
            let amount = activeSubscriptions.flatMap {
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
            Task { @MainActor in self?.syncFromICloud() }
        }
    }

    private func projectedCharges(for subscription: Subscription, from start: Date, to end: Date) -> [RenewalCharge] {
        let calendar = Calendar.current
        var chargeDate = subscription.nextBillingDate
        let cycleDays = subscription.billingCycle.days(customDays: subscription.customCycleDays)
        var charges: [RenewalCharge] = []

        while chargeDate < start {
            chargeDate = calendar.date(byAdding: .day, value: cycleDays, to: chargeDate) ?? end
        }

        while chargeDate < end {
            if chargeDate >= start {
                charges.append(RenewalCharge(
                    subscription: subscription,
                    date: chargeDate,
                    amount: converter.convert(subscription.price, from: subscription.currency, to: baseCurrency)
                ))
            }
            chargeDate = calendar.date(byAdding: .day, value: cycleDays, to: chargeDate) ?? end
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
            paymentMethods: paymentMethods
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

    static let defaultPaymentMethods = ["支付宝", "微信支付", "Apple Pay", "Visa", "Mastercard", "银联", "PayPal"]

    init(baseCurrency: CurrencyCode, remindersEnabled: Bool, iCloudSyncEnabled: Bool,
         appearance: AppAppearance, paymentMethods: [String]) {
        self.baseCurrency = baseCurrency
        self.remindersEnabled = remindersEnabled
        self.iCloudSyncEnabled = iCloudSyncEnabled
        self.appearance = appearance
        self.paymentMethods = paymentMethods
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        baseCurrency = try c.decodeIfPresent(CurrencyCode.self, forKey: .baseCurrency) ?? .cny
        remindersEnabled = try c.decodeIfPresent(Bool.self, forKey: .remindersEnabled) ?? true
        iCloudSyncEnabled = try c.decodeIfPresent(Bool.self, forKey: .iCloudSyncEnabled) ?? false
        appearance = try c.decodeIfPresent(AppAppearance.self, forKey: .appearance) ?? .system
        let pm = try c.decodeIfPresent([String].self, forKey: .paymentMethods) ?? Settings.defaultPaymentMethods
        paymentMethods = pm.isEmpty ? Settings.defaultPaymentMethods : pm
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

