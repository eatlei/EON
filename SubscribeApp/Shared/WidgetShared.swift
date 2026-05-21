import SwiftUI

// 主 App 与 Widget 扩展共享的这一个文件(在 project.yml 里同时挂到两个 target)。
// App 端算好一份精简快照写进 App Group;Widget 端只读这份快照。
// 真实订阅图标不塞进快照(避免 UserDefaults 膨胀),而是 App 把每个订阅图标渲染成
// PNG 写到 App Group 容器的 icons/ 目录,快照里只存 iconID,Widget 按 id 读文件。

/// 写进 App Group 的精简快照。
struct EONWidgetSnapshot: Codable {
    struct Item: Codable, Identifiable {
        var id = UUID()
        let name: String
        let amountText: String
        let dateText: String
        let daysLeft: Int
        let paid: Bool          // 这笔本周期是否已经扣过(日期早于今天)
        let letter: String      // 没有图标文件时的兜底首字母
        let colorHex: String
        let iconID: String      // 对应 App Group 容器里 icons/<iconID>.png
    }
    let monthLabel: String      // 本月本地化短名,如 "5月" / "May"
    let monthMajor: String      // 大字部分,含符号与整数,如 "$40"
    let monthMinor: String      // 小数部分两位,如 "99";无小数币种为空
    let dueCount: Int           // 本月扣费笔数
    let subscriptionCount: Int  // 活跃订阅数
    let upcoming: [Item]        // 未来的扣费(可能跨月),给"下次扣费"用
    let periodCharges: [Item]   // 本月扣费(含已扣 + 待扣),给清单用
    let updatedAt: Date

    static let placeholder = EONWidgetSnapshot(
        monthLabel: "May",
        monthMajor: "$40", monthMinor: "99",
        dueCount: 5, subscriptionCount: 6,
        upcoming: [
            .init(name: "GitHub Copilot", amountText: "$0.00", dateText: "5/18", daysLeft: 4, paid: false, letter: "G", colorHex: "5E5CE6", iconID: ""),
        ],
        periodCharges: [
            .init(name: "Surge",   amountText: "$15.00", dateText: "5/1",  daysLeft: -3, paid: true,  letter: "S", colorHex: "AF52DE", iconID: ""),
            .init(name: "iCloud+",  amountText: "$2.99", dateText: "5/1",  daysLeft: -3, paid: true,  letter: "I", colorHex: "3A8DFF", iconID: ""),
            .init(name: "Claude Code", amountText: "$20.00", dateText: "5/3", daysLeft: -1, paid: true, letter: "C", colorHex: "D97757", iconID: ""),
            .init(name: "GitHub Copilot", amountText: "$0.00", dateText: "5/18", daysLeft: 4, paid: false, letter: "G", colorHex: "5E5CE6", iconID: ""),
        ],
        updatedAt: Date()
    )
}

/// App Group 读写 + 图标文件目录。
enum EONWidgetStore {
    static let suiteName = "group.com.leon.eon"
    private static let key = "widget.snapshot.v2"

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

    /// App Group 共享容器。
    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName)
    }
    static var iconsDir: URL? {
        containerURL?.appendingPathComponent("icons", isDirectory: true)
    }
    static func iconURL(_ id: String) -> URL? {
        guard !id.isEmpty else { return nil }
        return iconsDir?.appendingPathComponent("\(id).png")
    }
}

extension Color {
    /// 从 "RRGGBB" / "#RRGGBB" 十六进制构造颜色。
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
