import Foundation
import SwiftUI

enum CurrencyCode: String, CaseIterable, Codable, Identifiable {
    case cny = "CNY"
    case usd = "USD"
    case eur = "EUR"
    case jpy = "JPY"
    case gbp = "GBP"
    case hkd = "HKD"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cny: String(localized: "人民币")
        case .usd: String(localized: "美元")
        case .eur: String(localized: "欧元")
        case .jpy: String(localized: "日元")
        case .gbp: String(localized: "英镑")
        case .hkd: String(localized: "港币")
        }
    }

    var symbol: String {
        switch self {
        case .cny: "¥"
        case .usd: "$"
        case .eur: "€"
        case .jpy: "¥"
        case .gbp: "£"
        case .hkd: "HK$"
        }
    }
}

enum SubscriptionCategory: String, CaseIterable, Codable, Identifiable {
    case ai = "AI"
    case productivity = "效率"
    case entertainment = "影音"
    case cloud = "云服务"
    case developer = "开发"
    case learning = "学习"
    case finance = "财务"
    case other = "其他"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ai: String(localized: "AI")
        case .productivity: String(localized: "效率")
        case .entertainment: String(localized: "影音")
        case .cloud: String(localized: "云服务")
        case .developer: String(localized: "开发")
        case .learning: String(localized: "学习")
        case .finance: String(localized: "财务")
        case .other: String(localized: "其他")
        }
    }

    var color: Color {
        switch self {
        case .ai: .indigo
        case .productivity: .blue
        case .entertainment: .pink
        case .cloud: .cyan
        case .developer: .mint
        case .learning: .orange
        case .finance: .green
        case .other: .gray
        }
    }
}

enum BillingCycle: String, CaseIterable, Codable, Identifiable {
    case weekly = "每周"
    case monthly = "每月"
    case quarterly = "每季度"
    case yearly = "每年"
    case custom = "自定义"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weekly: String(localized: "每周")
        case .monthly: String(localized: "每月")
        case .quarterly: String(localized: "每季度")
        case .yearly: String(localized: "每年")
        case .custom: String(localized: "自定义")
        }
    }

    func monthlyMultiplier(customDays: Int) -> Double {
        switch self {
        case .weekly: 52.0 / 12.0
        case .monthly: 1
        case .quarterly: 1.0 / 3.0
        case .yearly: 1.0 / 12.0
        case .custom: 30.4375 / Double(max(customDays, 1))
        }
    }

    func days(customDays: Int) -> Int {
        switch self {
        case .weekly: 7
        case .monthly: 30
        case .quarterly: 91
        case .yearly: 365
        case .custom: max(customDays, 1)
        }
    }
}

enum RenewalStatus: String, CaseIterable, Codable, Identifiable {
    case active = "自动续费"
    case manual = "手动续费"
    case trial = "试用期"
    case paused = "已暂停"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .active: String(localized: "自动续费")
        case .manual: String(localized: "手动续费")
        case .trial: String(localized: "试用期")
        case .paused: String(localized: "已暂停")
        }
    }
}

struct Subscription: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var plan: String
    var category: SubscriptionCategory
    var price: Double
    var currency: CurrencyCode
    var billingCycle: BillingCycle
    var customCycleDays: Int
    var nextBillingDate: Date
    var reminderDaysBefore: Int
    var status: RenewalStatus
    var paymentMethod: String
    var icon: SubscriptionIcon = .category

    var isActive: Bool {
        status != .paused
    }

    func monthlyCost(in targetCurrency: CurrencyCode, converter: CurrencyConverter) -> Double {
        converter.convert(price, from: currency, to: targetCurrency) * billingCycle.monthlyMultiplier(customDays: customCycleDays)
    }

    func annualCost(in targetCurrency: CurrencyCode, converter: CurrencyConverter) -> Double {
        monthlyCost(in: targetCurrency, converter: converter) * 12
    }
}

enum SubscriptionIcon: Codable, Hashable {
    case category
    case symbol(String)
    case image(String)
}

extension Subscription {
    private enum CodingKeys: String, CodingKey {
        case id, name, plan, category, price, currency, billingCycle,
             customCycleDays, nextBillingDate, reminderDaysBefore, status, paymentMethod, icon
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        plan = try c.decode(String.self, forKey: .plan)
        category = try c.decode(SubscriptionCategory.self, forKey: .category)
        price = try c.decode(Double.self, forKey: .price)
        currency = try c.decode(CurrencyCode.self, forKey: .currency)
        billingCycle = try c.decode(BillingCycle.self, forKey: .billingCycle)
        customCycleDays = try c.decode(Int.self, forKey: .customCycleDays)
        nextBillingDate = try c.decode(Date.self, forKey: .nextBillingDate)
        reminderDaysBefore = try c.decode(Int.self, forKey: .reminderDaysBefore)
        status = try c.decode(RenewalStatus.self, forKey: .status)
        paymentMethod = try c.decode(String.self, forKey: .paymentMethod)
        icon = try c.decodeIfPresent(SubscriptionIcon.self, forKey: .icon) ?? .category
    }
}
