import Foundation

struct CurrencyConverter {
    /// 内置兜底汇率（断网/从未拉取时用）：1 单位该币种 = ? CNY
    static let builtin: [CurrencyCode: Double] = [
        .cny: 1.0,
        .usd: 7.20,  .eur: 7.80,  .jpy: 0.047, .gbp: 9.10,  .hkd: 0.92,
        .aud: 4.65,  .cad: 5.27,  .chf: 8.10,  .krw: 0.0053, .sgd: 5.35,
        .twd: 0.225, .inr: 0.085, .brl: 1.42,  .mxn: 0.40,  .thb: 0.196,
        .nzd: 4.30,  .sek: 0.67,  .nok: 0.68,  .dkk: 1.04,  .`try`: 0.18,
        .aed: 1.96,  .myr: 1.55,  .php: 0.124, .vnd: 0.000285, .idr: 0.00045,
    ]

    let cnyRates: [CurrencyCode: Double]

    init(cnyRates: [CurrencyCode: Double] = CurrencyConverter.builtin) {
        self.cnyRates = cnyRates
    }

    func convert(_ amount: Double, from source: CurrencyCode, to target: CurrencyCode) -> Double {
        guard source != target else { return amount }
        let sourceInCNY = cnyRates[source, default: 1]
        let targetInCNY = cnyRates[target, default: 1]
        return amount * sourceInCNY / targetInCNY
    }

    func format(_ amount: Double, currency: CurrencyCode) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency.rawValue
        formatter.maximumFractionDigits = currency == .jpy ? 0 : 2
        return formatter.string(from: NSNumber(value: amount)) ?? "\(currency.symbol)\(String(format: "%.2f", amount))"
    }

    /// 只输出数字部分(不带货币符号),供 Hero 这种"要把符号单独画小一号"的
    /// 场景。日元等没有小数的币种保留 0 位。
    func formatAmountOnly(_ amount: Double, currency: CurrencyCode) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = currency == .jpy ? 0 : 2
        formatter.minimumFractionDigits = currency == .jpy ? 0 : 2
        formatter.usesGroupingSeparator = true
        return formatter.string(from: NSNumber(value: amount)) ?? String(format: "%.2f", amount)
    }
}
