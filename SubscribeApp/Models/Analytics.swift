import Foundation
import SwiftUI

enum SpendPeriod: String, CaseIterable, Identifiable {
    case month
    case year

    var id: String { rawValue }

    var title: String {
        switch self {
        case .month: "月"
        case .year: "年"
        }
    }

    var unitText: String {
        switch self {
        case .month: "本月"
        case .year: "今年"
        }
    }
}

struct RenewalCharge: Identifiable {
    var id: String {
        "\(subscription.id.uuidString)-\(Int(date.timeIntervalSince1970))"
    }

    let subscription: Subscription
    let date: Date
    let amount: Double
}

struct CategorySpend: Identifiable {
    var id: SubscriptionCategory { category }
    let category: SubscriptionCategory
    let amount: Double
    let share: Double
}

struct CurrencyExposure: Identifiable {
    var id: CurrencyCode { currency }
    let currency: CurrencyCode
    let amount: Double
    let share: Double
}

struct CycleSpend: Identifiable {
    var id: BillingCycle { cycle }
    let cycle: BillingCycle
    let amount: Double
    let count: Int
}

struct ForecastMonth: Identifiable {
    var id: Date { month }
    let month: Date
    let amount: Double
}

struct RenewalWindow: Identifiable {
    let id: String
    let title: String
    let count: Int
    let amount: Double
    let tint: Color
}

struct StatusCount: Identifiable {
    var id: RenewalStatus { status }
    let status: RenewalStatus
    let count: Int
}
