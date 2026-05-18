import Foundation

struct CurrencyConverter {
    let cnyRates: [CurrencyCode: Double] = [
        .cny: 1.00,
        .usd: 7.23,
        .eur: 7.86,
        .jpy: 0.049,
        .gbp: 9.12,
        .hkd: 0.93
    ]

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
