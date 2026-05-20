import Foundation
import SwiftUI

enum SpendPeriod: String, CaseIterable, Identifiable {
    case month
    case quarter
    case year

    var id: String { rawValue }

    var title: String {
        switch self {
        case .month:   String(localized: "月")
        case .quarter: String(localized: "季")
        case .year:    String(localized: "年")
        }
    }

    /// 用于 Hero 标题的"本月 / 本季 / 今年"。
    var unitText: String {
        switch self {
        case .month:   String(localized: "本月")
        case .quarter: String(localized: "本季")
        case .year:    String(localized: "今年")
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
