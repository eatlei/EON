import Foundation

struct AppStoreApp: Identifiable, Hashable {
    let id: Int          // trackId
    let name: String     // trackName
    let artworkURL: URL  // 512 upscaled icon
}

enum AppStoreRegion: String, CaseIterable, Identifiable {
    case cn, us, jp, gb, hk, de, kr, fr, es

    var id: String { rawValue }
    var title: String {
        switch self {
        case .cn: String(localized: "中国")
        case .us: String(localized: "美国")
        case .jp: String(localized: "日本")
        case .gb: String(localized: "英国")
        case .hk: String(localized: "香港")
        case .de: String(localized: "德国")
        case .kr: String(localized: "韩国")
        case .fr: String(localized: "法国")
        case .es: String(localized: "西班牙")
        }
    }

    /// 根据用户当前 App 语言挑一个最贴近的 App Store 区。挑不到就退到 .us
    /// —— 美区是 iTunes Search API 覆盖最完整的库,任何用户最起码都能搜得动。
    /// 调用时机:打开 IconPicker 默认 region。后续用户在面板里可以手动改。
    static var preferred: AppStoreRegion {
        // AppleLanguages 是用户在 App 内手动选过的优先;否则取 Bundle 的首选语种。
        let lang = (UserDefaults.standard.array(forKey: "AppleLanguages") as? [String])?.first
            ?? Bundle.main.preferredLocalizations.first ?? "en"
        // 注意顺序:先 zh-Hant 再 zh-Hans 再 zh,免得 hasPrefix("zh") 把繁体也吞了
        if lang.hasPrefix("zh-Hant") { return .hk }   // 繁中没有 .tw 选项时,香港区最接近
        if lang.hasPrefix("zh-Hans") { return .cn }
        if lang.hasPrefix("zh") { return .cn }
        if lang.hasPrefix("ja") { return .jp }
        if lang.hasPrefix("ko") { return .kr }
        if lang.hasPrefix("de") { return .de }
        if lang.hasPrefix("fr") { return .fr }
        if lang.hasPrefix("es") { return .es }
        if lang.hasPrefix("en-GB") { return .gb }
        if lang.hasPrefix("en") { return .us }
        return .us
    }
}

enum AppStoreIconService {
    private struct SearchResponse: Decodable {
        struct Item: Decodable {
            let trackId: Int
            let trackName: String
            let artworkUrl100: String?
            let artworkUrl60: String?
        }
        let results: [Item]
    }

    /// 在指定地区 App Store 按关键词搜索 App，返回带 512 图标地址的结果。
    static func search(term: String, region: AppStoreRegion) async throws -> [AppStoreApp] {
        let q = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        var comps = URLComponents(string: "https://itunes.apple.com/search")!
        comps.queryItems = [
            URLQueryItem(name: "term", value: q),
            URLQueryItem(name: "country", value: region.rawValue),
            URLQueryItem(name: "entity", value: "software"),
            URLQueryItem(name: "limit", value: "24")
        ]
        guard let url = comps.url else { return [] }
        var req = URLRequest(url: url)
        req.timeoutInterval = 12
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
        return decoded.results.compactMap { item in
            guard let raw = item.artworkUrl100 ?? item.artworkUrl60,
                  let big = URL(string: upscale(raw)) else { return nil }
            return AppStoreApp(id: item.trackId, name: item.trackName, artworkURL: big)
        }
    }

    /// 下载选中 App 的图标原始数据。
    static func fetchArtwork(_ app: AppStoreApp) async throws -> Data {
        var req = URLRequest(url: app.artworkURL)
        req.timeoutInterval = 15
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    /// iTunes 图标地址形如 ".../100x100bb.jpg" / "60x60bb.png" → 升到 512。
    private static func upscale(_ s: String) -> String {
        s.replacingOccurrences(of: "100x100", with: "512x512")
            .replacingOccurrences(of: "60x60", with: "512x512")
    }
}
