import Foundation
import SwiftUI

/// 用户在"设置 → 分类"里新建的自定义分类。
///
/// 之所以独立于 `SubscriptionCategory` 枚举:
/// - 枚举的 `rawValue` 是持久化键,不能改,所以无法在运行时增删。
/// - 自定义分类按 UUID 持久化,即使用户改名 / 改色,引用它的订阅不会失效。
///
/// 订阅持有 `customCategoryID: UUID?`。当 ID 命中 store 里的 `customCategories`
/// 时,优先用这里的 name / 色号显示,否则回退到内置 enum `category` 的 title / color。
struct CustomCategory: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var colorHex: String

    init(id: UUID = UUID(), name: String, colorHex: String) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
    }

    var color: Color { Color(hexString: colorHex) }
}

extension CustomCategory {
    /// 新建分类时给用户挑色用的预设盘 —— 跟分类色风格一致,跨明暗模式都好看。
    static let palette: [String] = [
        "#3D9CFF",  // blue
        "#5856D6",  // indigo
        "#AF52DE",  // purple
        "#FF375F",  // pink
        "#FF453A",  // red
        "#FF8A00",  // orange
        "#FFCC00",  // yellow
        "#34C759",  // green
        "#00C2C7",  // teal
        "#5AC8FA",  // sky
        "#8E8E93",  // gray
        "#A2845E",  // brown
    ]

    /// 整 App 允许的自定义分类上限。8 个内置 + 12 个自定义 = 20 个,
    /// 选择器里也能舒服展示。
    static let maxCount = 12
}
