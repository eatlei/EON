import SwiftUI

// 主 App 与 Widget 扩展共享的这一个文件(在 project.yml 里同时挂到两个 target)。
// App 端算好一份精简快照写进 App Group;Widget 端只读这份快照,不依赖任何模型,
// 进程隔离也能拿到数据。

/// 写进 App Group 的精简快照。只放展示用的字符串 + 少量数字,不含敏感原始数据。
struct EONWidgetSnapshot: Codable {
    struct Item: Codable, Identifiable {
        var id = UUID()
        let name: String
        let amountText: String
        let dateText: String
        let daysLeft: Int
        let letter: String
        let colorHex: String
    }
    let monthTotalText: String
    let subscriptionCount: Int
    let upcoming: [Item]
    let updatedAt: Date

    /// 占位数据(widget 画廊预览 / 还没写过快照时用)。
    static let placeholder = EONWidgetSnapshot(
        monthTotalText: "¥128",
        subscriptionCount: 6,
        upcoming: [
            .init(name: "ChatGPT", amountText: "¥20", dateText: "5/21", daysLeft: 0, letter: "C", colorHex: "5E5CE6"),
            .init(name: "Netflix", amountText: "¥68", dateText: "5/24", daysLeft: 3, letter: "N", colorHex: "E50914"),
            .init(name: "iCloud",  amountText: "¥6",  dateText: "5/28", daysLeft: 7, letter: "I", colorHex: "3A8DFF"),
        ],
        updatedAt: Date()
    )
}

/// App Group 读写。App 写、Widget 读,key 一致即可。
enum EONWidgetStore {
    static let suiteName = "group.com.leon.eon"
    private static let key = "widget.snapshot.v1"

    static func save(_ snapshot: EONWidgetSnapshot) {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    static func load() -> EONWidgetSnapshot? {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(EONWidgetSnapshot.self, from: data)
    }
}

extension Color {
    /// 从 "RRGGBB" / "#RRGGBB" 十六进制构造颜色。Widget 端独立解析,不依赖 App 的
    /// AppTheme(那在主 target 里,扩展访问不到)。
    init(eonHex hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r = Double((v >> 16) & 0xFF) / 255
        let g = Double((v >> 8) & 0xFF) / 255
        let b = Double(v & 0xFF) / 255
        self = Color(red: r, green: g, blue: b)
    }
}
