import Foundation
import SwiftUI

@MainActor
final class SubscriptionStore: ObservableObject {
    @Published var subscriptions: [Subscription] {
        didSet {
            save()
            NotificationScheduler.rescheduleAll(subscriptions)
        }
    }

    @Published var baseCurrency: CurrencyCode {
        didSet { saveSettings() }
    }

    @Published var remindersEnabled: Bool {
        didSet { saveSettings() }
    }

    @Published var iCloudSyncEnabled: Bool {
        didSet {
            saveSettings()
            if iCloudSyncEnabled {
                syncToICloud()
            }
        }
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
        } else {
            baseCurrency = .cny
            remindersEnabled = true
            iCloudSyncEnabled = false
        }

        if iCloudSyncEnabled {
            syncFromICloud()
        }
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

    var averageMonthlyCost: Double {
        guard !activeSubscriptions.isEmpty else { return 0 }
        return monthlyTotal / Double(activeSubscriptions.count)
    }

    var averageUsageScore: Double {
        guard !activeSubscriptions.isEmpty else { return 0 }
        return Double(activeSubscriptions.reduce(0) { $0 + $1.usageScore }) / Double(activeSubscriptions.count)
    }

    var averageImportanceScore: Double {
        guard !activeSubscriptions.isEmpty else { return 0 }
        return Double(activeSubscriptions.reduce(0) { $0 + $1.importanceScore }) / Double(activeSubscriptions.count)
    }

    var categorySpend: [CategorySpend] {
        SubscriptionCategory.allCases.compactMap { category in
            let amount = total(for: category)
            guard amount > 0 else { return nil }
            return CategorySpend(category: category, amount: amount, share: monthlyTotal == 0 ? 0 : amount / monthlyTotal)
        }
        .sorted { $0.amount > $1.amount }
    }

    var currencyExposure: [CurrencyExposure] {
        CurrencyCode.allCases.compactMap { currency in
            let amount = activeSubscriptions
                .filter { $0.currency == currency }
                .reduce(0) { $0 + $1.monthlyCost(in: baseCurrency, converter: converter) }
            guard amount > 0 else { return nil }
            return CurrencyExposure(currency: currency, amount: amount, share: monthlyTotal == 0 ? 0 : amount / monthlyTotal)
        }
        .sorted { $0.amount > $1.amount }
    }

    var cycleSpend: [CycleSpend] {
        BillingCycle.allCases.compactMap { cycle in
            let subscriptions = activeSubscriptions.filter { $0.billingCycle == cycle }
            let amount = subscriptions.reduce(0) {
                $0 + $1.monthlyCost(in: baseCurrency, converter: converter)
            }
            guard !subscriptions.isEmpty else { return nil }
            return CycleSpend(cycle: cycle, amount: amount, count: subscriptions.count)
        }
        .sorted { $0.amount > $1.amount }
    }

    var topSubscriptions: [Subscription] {
        activeSubscriptions
            .sorted {
                $0.monthlyCost(in: baseCurrency, converter: converter) >
                    $1.monthlyCost(in: baseCurrency, converter: converter)
            }
            .prefix(5)
            .map { $0 }
    }

    var statusCounts: [StatusCount] {
        RenewalStatus.allCases.compactMap { status in
            let count = subscriptions.filter { $0.status == status }.count
            return count == 0 ? nil : StatusCount(status: status, count: count)
        }
    }

    var forecast: [ForecastMonth] {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .month, for: .now)?.start ?? .now

        return (0..<6).map { offset in
            let month = calendar.date(byAdding: .month, value: offset, to: start) ?? start
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: month) ?? month
            let amount = activeSubscriptions.reduce(0) { partial, subscription in
                partial + projectedCharge(for: subscription, from: month, to: nextMonth)
            }
            return ForecastMonth(month: month, amount: amount)
        }
    }

    var renewalWindows: [RenewalWindow] {
        [
            renewalWindow(id: "7", title: "7 天内", days: 7, tint: .red),
            renewalWindow(id: "30", title: "30 天内", days: 30, tint: .orange),
            renewalWindow(id: "90", title: "90 天内", days: 90, tint: .blue)
        ]
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

    func delete(at offsets: IndexSet) {
        let sorted = subscriptions.sorted { $0.nextBillingDate < $1.nextBillingDate }
        let ids = offsets.map { sorted[$0].id }
        delete(ids: ids)
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

    private func renewalWindow(id: String, title: String, days: Int, tint: Color) -> RenewalWindow {
        let endDate = Calendar.current.date(byAdding: .day, value: days, to: .now) ?? .now
        let filtered = activeSubscriptions.filter {
            $0.nextBillingDate >= .now && $0.nextBillingDate <= endDate
        }
        let amount = filtered.reduce(0) {
            $0 + converter.convert($1.price, from: $1.currency, to: baseCurrency)
        }
        return RenewalWindow(id: id, title: title, count: filtered.count, amount: amount, tint: tint)
    }

    private func projectedCharge(for subscription: Subscription, from start: Date, to end: Date) -> Double {
        projectedCharges(for: subscription, from: start, to: end).reduce(0) { $0 + $1.amount }
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
            iCloudSyncEnabled: iCloudSyncEnabled
        )
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: settingsKey)
        }
    }
}

private struct Settings: Codable {
    var baseCurrency: CurrencyCode
    var remindersEnabled: Bool
    var iCloudSyncEnabled: Bool
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
            paymentMethod: "Visa 0821",
            seats: 1,
            usageScore: 5,
            importanceScore: 5,
            notes: "高频使用，用于写作、代码和信息整理。"
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
            paymentMethod: "Apple Pay",
            seats: 2,
            usageScore: 2,
            importanceScore: 2,
            notes: "最近使用偏低，主要在周末观看。"
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
            paymentMethod: "支付宝",
            seats: 5,
            usageScore: 5,
            importanceScore: 5,
            notes: "和家庭照片备份绑定。"
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
            paymentMethod: "Mastercard 1106",
            seats: 1,
            usageScore: 4,
            importanceScore: 4,
            notes: "年付，主要用于项目资料和数据库。"
        )
    ]
}
