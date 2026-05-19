import Foundation

struct CurrencyConverter {
    /// 内置兜底汇率（断网/从未拉取时用）：1 单位该币种 = ? CNY
    static let builtin: [CurrencyCode: Double] = [
        .cny: 1.00,
        .usd: 7.23,
        .eur: 7.86,
        .jpy: 0.049,
        .gbp: 9.12,
        .hkd: 0.93
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
}
