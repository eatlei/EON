import Foundation
import SwiftUI

enum SpendPeriod: String, CaseIterable, Identifiable {
    case month
    case quarter
    case year

    var id: String { rawValue }

    /// 用于 SegmentedPill 上的紧凑标签。"周期·X" 系列 key 在各语种上都是 1~3
    /// 字符的缩写(EN: Mo/Qtr/Yr;ES: Mes/Trim/Año;…)避免英/法/德把胶囊撑爆。
    var title: String {
        switch self {
        case .month:   String(localized: "周期·月")
        case .quarter: String(localized: "周期·季")
        case .year:    String(localized: "周期·年")
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

/// 一笔分类支出聚合 —— 同时承载内置 enum 分类和用户自建的 custom 分类。
/// `id` 来自 `Subscription.displayCategoryID`,在饼图 + 图例里做稳定 key。
struct CategorySpend: Identifiable {
    let id: String
    let title: String
    let color: Color
    let amount: Double
    let share: Double
}

struct ForecastMonth: Identifiable {
    var id: Date { month }
    let month: Date
    let amount: Double
}
