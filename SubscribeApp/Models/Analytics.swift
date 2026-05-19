import Foundation
import SwiftUI

enum SpendPeriod: String, CaseIterable, Identifiable {
    case month
    case year

    var id: String { rawValue }

    var title: String {
        switch self {
        case .month: String(localized: "月")
        case .year: String(localized: "年")
        }
    }

    var unitText: String {
        switch self {
        case .month: String(localized: "本月")
        case .year: String(localized: "今年")
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

struct ForecastMonth: Identifiable {
    var id: Date { month }
    let month: Date
    let amount: Double
}
