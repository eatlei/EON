import Foundation

@MainActor
enum LLMExporter {
    // MARK: Markdown (primary, LLM-friendly)
    static func markdown(store: SubscriptionStore, withPrompt: Bool) -> String {
        let conv = store.converter
        let base = store.baseCurrency
        let now = Date()
        let stamp = ISO8601DateFormatter().string(from: now)
        let active = store.activeSubscriptions
        let monthly = active.reduce(0.0) { $0 + $1.monthlyCost(in: base, converter: conv) }
        let annual = monthly * 12

        var lines: [String] = []
        lines.append("# EON Subscriptions Export")
        lines.append("")
        lines.append("- **Exported:** \(stamp)")
        lines.append("- **Base currency:** \(base.rawValue) (\(base.symbol))")
        lines.append("- **Active subscriptions:** \(active.count)")
        lines.append("- **Archived:** \(store.archivedSubscriptions.count)")
        lines.append("")
        lines.append("## Summary")
        lines.append("- Monthly total: \(format(monthly, base))")
        lines.append("- Annual total: \(format(annual, base))")
        if !active.isEmpty {
            lines.append("- Average per subscription / month: \(format(monthly / Double(active.count), base))")
        }
        lines.append("")
        // Category breakdown
        lines.append("### By category (monthly, in \(base.rawValue))")
        lines.append("| Category | Count | Monthly | Share |")
        lines.append("|---|---:|---:|---:|")
        // 按"显示分类标题"分桶 —— 内置和 custom 共用同一张表,跟 App 内饼图口径一致。
        let byCat = Dictionary(grouping: active, by: { $0.displayCategoryTitle })
        let catRows = byCat.map { (title, subs) -> (String, Int, Double) in
            let s = subs.reduce(0.0) { $0 + $1.monthlyCost(in: base, converter: conv) }
            return (title, subs.count, s)
        }.sorted { $0.2 > $1.2 }
        for (title, count, sum) in catRows {
            let share = monthly == 0 ? 0 : (sum / monthly) * 100
            lines.append("| \(title) | \(count) | \(format(sum, base)) | \(String(format: "%.1f%%", share)) |")
        }
        lines.append("")
        // Detail
        lines.append("## Subscriptions")
        lines.append("| Name | Plan | Category | Price | Cycle | Next billing | Status | Payment | Monthly (\(base.rawValue)) |")
        lines.append("|---|---|---|---:|---|---|---|---|---:|")
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        for s in active.sorted(by: { $0.nextBillingDate < $1.nextBillingDate }) {
            let priceNative = "\(s.currency.symbol) \(String(format: "%.2f", s.price))"
            let cycle = s.billingCycle == .custom ? "Every \(s.customCycleDays)d" : s.billingCycle.title
            let next = df.string(from: s.nextBillingDate)
            let m = s.monthlyCost(in: base, converter: conv)
            let payment = s.paymentMethod.isEmpty ? "—" : s.paymentMethod
            let plan = s.plan.isEmpty ? "—" : s.plan
            lines.append("| \(s.name) | \(plan) | \(s.displayCategoryTitle) | \(priceNative) | \(cycle) | \(next) | \(s.status.title) | \(payment) | \(format(m, base)) |")
        }
        if withPrompt {
            lines.append("")
            lines.append("---")
            lines.append("")
            // 提示词跟 App 当前语言走 —— 用户把 App 切到英文就出英文提示词,
            // 拷给 ChatGPT / Claude 不会出现"中英混杂"。基础币种用本地符号
            // 替换"¥",让"控制在 200 以内"的预算建议也对得上用户语言/口径。
            lines.append("## " + String(localized: "AI 提示词参考(可编辑后粘贴到 AI)"))
            lines.append("- " + String(localized: "帮我找出可以削减或合并的订阅,估算每月可省多少。"))
            lines.append("- " + String(localized: "把我的月费控制在 \(base.symbol)200 以内,建议砍掉哪些?"))
            lines.append("- " + String(localized: "按性价比/使用频率打分排序,并指出哪些非必要。"))
            lines.append("- " + String(localized: "预测未来 60 天的实际扣费日期与总额。"))
            lines.append("- " + String(localized: "检查是否有功能重复的订阅(例如多个视频/音乐服务)。"))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: JSON (power-user / programmatic)
    static func json(store: SubscriptionStore) throws -> String {
        struct Out: Encodable {
            let exportedAt: Date
            let baseCurrency: String
            let monthlyTotal: Double
            let annualTotal: Double
            let subscriptions: [Subscription]
            let archived: [Subscription]
        }
        let payload = Out(
            exportedAt: Date(),
            baseCurrency: store.baseCurrency.rawValue,
            monthlyTotal: store.monthlyTotal,
            annualTotal: store.annualTotal,
            subscriptions: store.activeSubscriptions,
            archived: store.archivedSubscriptions
        )
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try enc.encode(payload)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    // MARK: file helpers
    static func writeMarkdownTempFile(store: SubscriptionStore) -> URL? {
        let text = markdown(store: store, withPrompt: true)
        return writeTemp(text, name: "EON-Subscriptions.md")
    }
    static func writeJSONTempFile(store: SubscriptionStore) -> URL? {
        guard let text = try? json(store: store) else { return nil }
        return writeTemp(text, name: "EON-Subscriptions.json")
    }
    private static func writeTemp(_ content: String, name: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do { try content.write(to: url, atomically: true, encoding: .utf8); return url } catch { return nil }
    }

    private static func format(_ amount: Double, _ c: CurrencyCode) -> String {
        "\(c.symbol) \(String(format: "%.2f", amount))"
    }
}
