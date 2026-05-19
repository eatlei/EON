import Foundation

struct AppStoreApp: Identifiable, Hashable {
    let id: Int          // trackId
    let name: String     // trackName
    let artworkURL: URL  // 512 upscaled icon
}

enum AppStoreRegion: String, CaseIterable, Identifiable {
    case cn, us, jp, gb, hk, de

    var id: String { rawValue }
    var title: String {
        switch self {
        case .cn: "中国"
        case .us: "美国"
        case .jp: "日本"
        case .gb: "英国"
        case .hk: "香港"
        case .de: "德国"
        }
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
