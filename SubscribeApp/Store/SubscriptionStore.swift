import Foundation
import SwiftUI

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
                syncToICloud()
            }
        }
    }

    @Published var appearance: AppAppearance = .system {
        didSet { saveSettings() }
    }

    let converter = CurrencyConverter()

    private let subscriptionsKey = "subscriptions.v1"
    private let settingsKey = "settings.v1"
    private let iCloudSubscriptionsKey = "icloud.subscriptions.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: subscriptionsKey),
           let decoded = try? JSONDecoder.subscriptionDecoder.decode([Subscription].self, from: data) {
            subscriptions = decoded
        } else {
            subscriptions = Self.samples
        }

        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let settings = try? JSONDecoder().decode(Settings.self, from: data) {
            baseCurrency = settings.baseCurrency
            remindersEnabled = settings.remindersEnabled
            iCloudSyncEnabled = settings.iCloudSyncEnabled
            appearance = settings.appearance
        } else {
            baseCurrency = .cny
            remindersEnabled = true
            iCloudSyncEnabled = false
        }

        if iCloudSyncEnabled {
            syncFromICloud()
        }
        syncReminders()
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
        subscriptions.removeAll { ids.contains($0.id) }
    }

    func resetSamples() {
        subscriptions = Self.samples
    }

    func syncToICloud() {
        guard iCloudSyncEnabled,
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

        subscriptions = decoded
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
            appearance: appearance
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
}

private struct Settings: Codable {
    var baseCurrency: CurrencyCode
    var remindersEnabled: Bool
    var iCloudSyncEnabled: Bool
    var appearance: AppAppearance

    init(baseCurrency: CurrencyCode, remindersEnabled: Bool, iCloudSyncEnabled: Bool, appearance: AppAppearance) {
        self.baseCurrency = baseCurrency
        self.remindersEnabled = remindersEnabled
        self.iCloudSyncEnabled = iCloudSyncEnabled
        self.appearance = appearance
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        baseCurrency = try c.decodeIfPresent(CurrencyCode.self, forKey: .baseCurrency) ?? .cny
        remindersEnabled = try c.decodeIfPresent(Bool.self, forKey: .remindersEnabled) ?? true
        iCloudSyncEnabled = try c.decodeIfPresent(Bool.self, forKey: .iCloudSyncEnabled) ?? false
        appearance = try c.decodeIfPresent(AppAppearance.self, forKey: .appearance) ?? .system
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
    static let samples: [Subscription] = [
        Subscription(
            name: "ChatGPT",
            plan: "Plus",
            category: .ai,
            price: 20,
            currency: .usd,
            billingCycle: .monthly,
            customCycleDays: 30,
            nextBillingDate: Calendar.current.date(byAdding: .day, value: 8, to: .now) ?? .now,
            reminderDaysBefore: 3,
            status: .active,
            paymentMethod: "Visa 0821"
        ),
        Subscription(
            name: "Netflix",
            plan: "Standard",
            category: .entertainment,
            price: 99,
            currency: .hkd,
            billingCycle: .monthly,
            customCycleDays: 30,
            nextBillingDate: Calendar.current.date(byAdding: .day, value: 13, to: .now) ?? .now,
            reminderDaysBefore: 5,
            status: .active,
            paymentMethod: "Apple Pay"
        ),
        Subscription(
            name: "iCloud+",
            plan: "2 TB",
            category: .cloud,
            price: 68,
            currency: .cny,
            billingCycle: .monthly,
            customCycleDays: 30,
            nextBillingDate: Calendar.current.date(byAdding: .day, value: 19, to: .now) ?? .now,
            reminderDaysBefore: 7,
            status: .active,
            paymentMethod: "支付宝"
        ),
        Subscription(
            name: "Notion",
            plan: "Plus",
            category: .productivity,
            price: 96,
            currency: .usd,
            billingCycle: .yearly,
            customCycleDays: 365,
            nextBillingDate: Calendar.current.date(byAdding: .day, value: 61, to: .now) ?? .now,
            reminderDaysBefore: 14,
            status: .active,
            paymentMethod: "Mastercard 1106"
        )
    ]
}
