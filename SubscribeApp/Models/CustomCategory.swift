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
    /// 8 个内置分类已经占用了 indigo / blue / pink / cyan / mint / orange / green
    /// / gray 这一组,所以再挑的色号是跟它们 hex 上明显不冲突的另一批,叠加
    /// "排除已用色"的逻辑后,用户仍然能挑到 8~10 种独立颜色。
    static let palette: [String] = [
        "#3D9CFF",  // blue        (跟内置 .blue 撞,在排除盘里会禁用)
        "#5856D6",  // indigo      (跟内置 .ai 撞)
        "#AF52DE",  // purple      ✓ 自定义专属
        "#FF375F",  // pink        (跟内置 .entertainment 撞)
        "#FF453A",  // red         ✓ 自定义专属
        "#FF8A00",  // orange      (跟内置 .learning 撞)
        "#FFCC00",  // yellow      ✓ 自定义专属
        "#34C759",  // green       (跟内置 .finance 撞)
        "#00C2C7",  // teal/mint   (跟内置 .developer 撞)
        "#5AC8FA",  // sky/cyan    (跟内置 .cloud 撞)
        "#8E8E93",  // gray        (跟内置 .other 撞)
        "#A2845E",  // brown       ✓ 自定义专属
        // 额外补的"自定义专属"色,确保内置占满之后用户还有 ~8 个选项
        "#FF6B6B",  // coral       ✓
        "#E91E63",  // magenta     ✓
        "#7C4DFF",  // royal       ✓
        "#00BFA5",  // jade        ✓
        "#2E7D32",  // forest      ✓
        "#0288D1",  // ocean       ✓
        "#C2185B",  // wine        ✓
        "#455A64",  // slate       ✓
    ]

    /// 内置分类已占用的色号(小写 hex),用于在调色盘里禁用。
    /// 跟 `SubscriptionCategory.color` 的 SwiftUI semantic color 一一对应。
    static let builtInOccupiedHexes: Set<String> = [
        "#3d9cff",  // blue
        "#5856d6",  // indigo
        "#ff375f",  // pink
        "#ff8a00",  // orange
        "#34c759",  // green
        "#00c2c7",  // mint/teal
        "#5ac8fa",  // cyan/sky
        "#8e8e93",  // gray
    ]

    /// 整 App 允许的自定义分类上限。8 个内置 + 12 个自定义 = 20 个,
    /// 选择器里也能舒服展示。
    static let maxCount = 12
}
