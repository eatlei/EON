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
    /// 用户自定义分类的 ID。当 `Subscription.customLookup` 包含这个 ID 时,
    /// 显示用 custom 的 name / color;否则回退到内置 `category` 的 title / color。
    /// 删除自定义分类时,所有引用它的订阅会被自动解绑(置为 nil)。
    var customCategoryID: UUID? = nil
    /// 订阅的"起始扣费日" —— 用来算"已经扣过几次费 / 累计花了多少钱"。
    /// 创建时默认 = nextBillingDate;之后用户即便手动改 nextBillingDate(比如
    /// 把日期往后挪躲过一笔),startDate 也保持不变,代表"我从这天开始订的"。
    /// 旧数据没有这个字段:decodeIfPresent 返回 nil,fall back 到 nextBillingDate。
    var startDate: Date? = nil
    /// 是否计入"金额统计"。关掉之后:
    ///   - 这个订阅仍然出现在订阅列表 / 日历 / 即将扣费里(它该续费还续费)
    ///   - 但 monthlyTotal / annualTotal / categorySpend / 累计支付 等聚合
    ///     都会跳过它,不打入"我个人的开销"
    /// 适用场景:公司报销的订阅、家人共享的、给客户买的等等。默认 true。
    var includeInStatistics: Bool = true
    var isArchived: Bool = false
    /// 订阅"结束日"。nil = 永久续费;非 nil = 到这天为止,
    /// 之后 SubscriptionStore.autoArchiveExpiredSubscriptions() 会把它自动归档。
    /// 旧数据没有这字段,decodeIfPresent 默认 nil,行为跟以前一致。
    var endDate: Date? = nil

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
             customCycleDays, nextBillingDate, reminderDaysBefore, status, paymentMethod, icon, isArchived,
             customCategoryID, startDate, includeInStatistics, endDate
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
        customCategoryID = try c.decodeIfPresent(UUID.self, forKey: .customCategoryID)
        startDate = try c.decodeIfPresent(Date.self, forKey: .startDate)
        includeInStatistics = try c.decodeIfPresent(Bool.self, forKey: .includeInStatistics) ?? true
        endDate = try c.decodeIfPresent(Date.self, forKey: .endDate)
    }
}

// MARK: - Billing count + lifetime spend

extension Subscription {
    /// 推断的"起始扣费日"。如果有 startDate 就用 startDate;
    /// 旧数据没有就拿 nextBillingDate 当起点 —— 至少不会算成 "未来扣费"。
    var effectiveStartDate: Date { startDate ?? nextBillingDate }

    /// 从 startDate 一直推算到 now,统计期间会发生几次扣费。
    /// startDate 当天算 1 次;后续每跨一个 cycle 加 1。还没开始扣费就返回 0。
    func billingCountElapsed(asOf now: Date = .now) -> Int {
        let cal = Calendar.current
        var date = effectiveStartDate
        guard date <= now else { return 0 }
        var count = 0
        var guardCount = 0
        while date <= now {
            count += 1
            let next = billingCycle.advance(date, by: 1, calendar: cal, customDays: customCycleDays)
            guard next > date, guardCount < 10_000 else { break }
            date = next
            guardCount += 1
        }
        return count
    }

    /// 累计支付金额(基础币种口径)= 已扣次数 × 单次价格。
    func lifetimeSpend(in base: CurrencyCode, converter: CurrencyConverter, asOf now: Date = .now) -> Double {
        let perCycle = converter.convert(price, from: currency, to: base)
        return perCycle * Double(billingCountElapsed(asOf: now))
    }
}

// MARK: - Display helpers that know about custom categories
//
// 全 App 所有需要展示订阅"分类名 / 分类色"的地方都该走这两个属性,而不是直接读
// `.category.title`/`.category.color`。当订阅持有 `customCategoryID` 且 store 已
// 把它注入到 `Subscription.customLookup` 时,这里返回 custom 的名字 / 色号。
extension Subscription {
    /// SubscriptionStore 启动时 / customCategories 变化时 mirror 进来。
    /// 因为读写都在 MainActor 上,Swift 6 用 `nonisolated(unsafe)` 安全。
    nonisolated(unsafe) static var customLookup: [UUID: CustomCategory] = [:]

    var customCategory: CustomCategory? {
        guard let id = customCategoryID else { return nil }
        return Self.customLookup[id]
    }

    /// 用于卡片标题、列表副文等所有"看起来像分类名"的地方。
    var displayCategoryTitle: String {
        customCategory?.name ?? category.title
    }

    /// 用于卡片光晕、字母牌底色、分类点等所有"看起来像分类色"的地方。
    var displayCategoryColor: Color {
        if let custom = customCategory { return custom.color }
        return category.color
    }

    /// 用作分组 / 图表分桶的稳定字符串 ID。
    /// 内置:enum.rawValue;自定义:"custom-<UUID>"。
    var displayCategoryID: String {
        if let id = customCategoryID { return "custom-\(id.uuidString)" }
        return category.rawValue
    }
}
