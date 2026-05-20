import Foundation
import SwiftUI

enum CurrencyCode: String, CaseIterable, Codable, Identifiable {
    case cny = "CNY"
    case usd = "USD"
    case eur = "EUR"
    case jpy = "JPY"
    case gbp = "GBP"
    case hkd = "HKD"
    case aud = "AUD"
    case cad = "CAD"
    case chf = "CHF"
    case krw = "KRW"
    case sgd = "SGD"
    case twd = "TWD"
    case inr = "INR"
    case brl = "BRL"
    case mxn = "MXN"
    case thb = "THB"
    case nzd = "NZD"
    case sek = "SEK"
    case nok = "NOK"
    case dkk = "DKK"
    case `try` = "TRY"
    case aed = "AED"
    case myr = "MYR"
    case php = "PHP"
    case vnd = "VND"
    case idr = "IDR"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cny: String(localized: "人民币")
        case .usd: String(localized: "美元")
        case .eur: String(localized: "欧元")
        case .jpy: String(localized: "日元")
        case .gbp: String(localized: "英镑")
        case .hkd: String(localized: "港币")
        case .aud: String(localized: "澳元")
        case .cad: String(localized: "加元")
        case .chf: String(localized: "瑞士法郎")
        case .krw: String(localized: "韩元")
        case .sgd: String(localized: "新加坡元")
        case .twd: String(localized: "新台币")
        case .inr: String(localized: "印度卢比")
        case .brl: String(localized: "巴西雷亚尔")
        case .mxn: String(localized: "墨西哥比索")
        case .thb: String(localized: "泰铢")
        case .nzd: String(localized: "新西兰元")
        case .sek: String(localized: "瑞典克朗")
        case .nok: String(localized: "挪威克朗")
        case .dkk: String(localized: "丹麦克朗")
        case .`try`: String(localized: "土耳其里拉")
        case .aed: String(localized: "阿联酋迪拉姆")
        case .myr: String(localized: "马来西亚林吉特")
        case .php: String(localized: "菲律宾比索")
        case .vnd: String(localized: "越南盾")
        case .idr: String(localized: "印尼盾")
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
        case .aud: "A$"
        case .cad: "C$"
        case .chf: "CHF"
        case .krw: "₩"
        case .sgd: "S$"
        case .twd: "NT$"
        case .inr: "₹"
        case .brl: "R$"
        case .mxn: "Mex$"
        case .thb: "฿"
        case .nzd: "NZ$"
        case .sek: "kr"
        case .nok: "kr"
        case .dkk: "kr"
        case .`try`: "₺"
        case .aed: "AED"
        case .myr: "RM"
        case .php: "₱"
        case .vnd: "₫"
        case .idr: "Rp"
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

    /// 用户在设置 → 分类 里自定义的标题。Key 是 rawValue,Value 是用户起的名字。
    /// 商店启动时灌入,所有 .title 的读取都先看这里。enum 的 rawValue(持久化键)
    /// 永远不变,只改显示名 —— 不会破坏已有数据。
    nonisolated(unsafe) static var nameOverrides: [String: String] = [:]

    var title: String {
        if let custom = Self.nameOverrides[rawValue], !custom.isEmpty { return custom }
        return defaultTitle
    }

    var defaultTitle: String {
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

    /// 在金额后展示的紧凑单位后缀(例:"/月" "/年")。custom 周期带上天数。
    func shortSuffix(customDays: Int) -> String {
        switch self {
        case .weekly:    return String(localized: "/周")
        case .monthly:   return String(localized: "/月")
        case .quarterly: return String(localized: "/季")
        case .yearly:    return String(localized: "/年")
        case .custom:    return String(localized: "/\(max(customDays, 1))天")
        }
    }

    /// 按"自然周期"前进/后退 count 个周期（count 可为负）。月/季/年走日历，避免 30/91/365 天近似导致的日期漂移。
    func advance(_ date: Date, by count: Int, calendar: Calendar, customDays: Int) -> Date {
        switch self {
        case .weekly:    return calendar.date(byAdding: .day,   value: 7 * count, to: date) ?? date
        case .monthly:   return calendar.date(byAdding: .month, value: count,      to: date) ?? date
        case .quarterly: return calendar.date(byAdding: .month, value: 3 * count,  to: date) ?? date
        case .yearly:    return calendar.date(byAdding: .year,  value: count,      to: date) ?? date
        case .custom:    return calendar.date(byAdding: .day,   value: max(customDays, 1) * count, to: date) ?? date
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
    var icon: SubscriptionIcon = .default
    var isArchived: Bool = false

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

enum TileGlyph: Hashable {
    case letter
    case symbol(String)
}

enum SubscriptionIcon: Hashable {
    case tile(glyph: TileGlyph, colorHex: String?)   // colorHex == nil ⇒ 用分类色
    case image(String)                                // 上传 / App Store 下载的图片文件 ID

    static let `default` = SubscriptionIcon.tile(glyph: .letter, colorHex: nil)
}

extension SubscriptionIcon: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind, glyph, symbolName, colorHex, imageID   // new shape
        case category, symbol, monogram, image            // legacy keys
    }
    private struct LegacyPayload: Codable { let _0: String? }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        // New shape (discriminated by "kind")
        if let kind = try c.decodeIfPresent(String.self, forKey: .kind) {
            switch kind {
            case "image":
                self = .image(try c.decodeIfPresent(String.self, forKey: .imageID) ?? "")
            case "tile":
                let colorHex = try c.decodeIfPresent(String.self, forKey: .colorHex)
                let g = try c.decodeIfPresent(String.self, forKey: .glyph) ?? "letter"
                if g == "symbol",
                   let name = try c.decodeIfPresent(String.self, forKey: .symbolName), !name.isEmpty {
                    self = .tile(glyph: .symbol(name), colorHex: colorHex)
                } else {
                    self = .tile(glyph: .letter, colorHex: colorHex)
                }
            default:
                self = .default
            }
            return
        }

        // Legacy shapes
        if c.contains(.category) {
            self = .tile(glyph: .letter, colorHex: nil)
        } else if c.contains(.symbol) {
            let p = try c.decode(LegacyPayload.self, forKey: .symbol)
            self = .tile(glyph: .symbol(p._0 ?? ""), colorHex: nil)
        } else if c.contains(.monogram) {
            let p = try c.decode(LegacyPayload.self, forKey: .monogram)
            self = .tile(glyph: .letter, colorHex: p._0)
        } else if c.contains(.image) {
            let p = try c.decode(LegacyPayload.self, forKey: .image)
            self = .image(p._0 ?? "")
        } else {
            self = .default
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .image(let id):
            try c.encode("image", forKey: .kind)
            try c.encode(id, forKey: .imageID)
        case .tile(let glyph, let colorHex):
            try c.encode("tile", forKey: .kind)
            try c.encodeIfPresent(colorHex, forKey: .colorHex)
            switch glyph {
            case .letter:
                try c.encode("letter", forKey: .glyph)
            case .symbol(let name):
                try c.encode("symbol", forKey: .glyph)
                try c.encode(name, forKey: .symbolName)
            }
        }
    }
}

extension Subscription {
    private enum CodingKeys: String, CodingKey {
        case id, name, plan, category, price, currency, billingCycle,
             customCycleDays, nextBillingDate, reminderDaysBefore, status, paymentMethod, icon, isArchived
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
        icon = (try? c.decode(SubscriptionIcon.self, forKey: .icon)) ?? .default
        isArchived = try c.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
    }
}
