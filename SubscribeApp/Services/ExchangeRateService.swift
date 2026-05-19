import Foundation

/// 每日汇率拉取（open.er-api.com，免费免 key，base=CNY）。
enum ExchangeRateService {
    private struct Response: Decodable {
        let result: String
        let rates: [String: Double]
    }

    /// 返回与内置表同口径的 cnyRates：1 单位该币种 = ? CNY。
    static func fetchCNYRates() async throws -> [CurrencyCode: Double] {
        let url = URL(string: "https://open.er-api.com/v6/latest/CNY")!
        var req = URLRequest(url: url)
        req.timeoutInterval = 12
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        guard decoded.result == "success" else { throw URLError(.cannotParseResponse) }
        // API: rates[X] = 1 CNY 值多少 X；我们要 cnyRates[X] = 1 X 值多少 CNY = 1 / rates[X]
        var out: [CurrencyCode: Double] = [.cny: 1.0]
        for c in CurrencyCode.allCases where c != .cny {
            if let perCNY = decoded.rates[c.rawValue], perCNY > 0 {
                out[c] = 1.0 / perCNY
            }
        }
        // 至少要拿到一半以上币种才算有效，否则视为失败用兜底
        guard out.count >= (CurrencyCode.allCases.count / 2 + 1) else {
            throw URLError(.cannotParseResponse)
        }
        return out
    }
}
