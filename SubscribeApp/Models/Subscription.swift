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
        case .cny: "人民币"
        case .usd: "美元"
        case .eur: "欧元"
        case .jpy: "日元"
        case .gbp: "英镑"
        case .hkd: "港币"
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
