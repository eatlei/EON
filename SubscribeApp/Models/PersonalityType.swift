import Foundation
import SwiftUI

/// "订阅 MBTI" 的 11 种人格类型。
/// 8 种主导分类型 + 3 种特殊型(订阅极少 / 各类均衡 / 高频加订阅)。
/// 严格不带任何价值判断或歧视倾向 —— 文案都是温和、轻松的视角。
enum PersonalityType: String, CaseIterable, Identifiable {
    // 主导分类(订阅在某一分类下占比 ≥ 30% 时触发)
    case ai              // 主导 = AI
    case productivity    // 主导 = 效率
    case entertainment   // 主导 = 影音
    case cloud           // 主导 = 云服务
    case developer       // 主导 = 开发
    case learning        // 主导 = 学习
    case finance         // 主导 = 财务
    case eclectic        // 主导 = 其他,或没有任何分类占到 30%

    // 特殊情况
    case beginner        // 活跃订阅 < 3 条
    case balanced        // 5 个及以上分类各自占 ≥ 10%
    case dailyAdder      // 近 7 天里至少 5 天都加了新订阅

    var id: String { rawValue }

    /// 资源图名:用户拿提示词去 ChatGPT 生成图后,改名扔进 Assets.xcassets
    /// 用 "personality-ai" / "personality-productivity" 这种命名,View 会自动
    /// 拾起;没有图的时候用占位渐变 + SF Symbol 兜底。
    var imageAssetName: String { "personality-\(rawValue)" }

    /// 占位用的 SF Symbol —— 每种人格的"视觉灵魂"。真图加上之前用它。
    var fallbackSymbol: String {
        switch self {
        case .ai:            "brain.head.profile.fill"
        case .productivity:  "checkmark.seal.fill"
        case .entertainment: "play.tv.fill"
        case .cloud:         "cloud.fill"
        case .developer:     "chevron.left.forwardslash.chevron.right"
        case .learning:      "book.fill"
        case .finance:       "chart.line.uptrend.xyaxis"
        case .eclectic:      "shippingbox.fill"
        case .beginner:      "leaf.fill"
        case .balanced:      "circle.grid.3x3.fill"
        case .dailyAdder:    "calendar.badge.plus"
        }
    }

    /// 主题色 —— 占位图的径向光晕从这色起手。
    var tint: Color {
        switch self {
        case .ai:            .indigo
        case .productivity:  .blue
        case .entertainment: .pink
        case .cloud:         .cyan
        case .developer:     .mint
        case .learning:      .orange
        case .finance:       .green
        case .eclectic:      .purple
        case .beginner:      .mint
        case .balanced:      .teal
        case .dailyAdder:    .yellow
        }
    }

    /// 人格名(显示给用户的标题)。
    var name: String {
        switch self {
        case .ai:            String(localized: "AI 先驱")
        case .productivity:  String(localized: "效率猎人")
        case .entertainment: String(localized: "沙发观察家")
        case .cloud:         String(localized: "云端游民")
        case .developer:     String(localized: "代码匠人")
        case .learning:      String(localized: "终身学习者")
        case .finance:       String(localized: "理财规划师")
        case .eclectic:      String(localized: "兴趣收藏家")
        case .beginner:      String(localized: "数字极简者")
        case .balanced:      String(localized: "平衡大师")
        case .dailyAdder:    String(localized: "探索狂热者")
        }
    }

    /// 一句口号,自带表情。
    var tagline: String {
        switch self {
        case .ai:            String(localized: "你的助手们都长着算法的脸 🧠")
        case .productivity:  String(localized: "每一分钟都被工具温柔安排了 ✅")
        case .entertainment: String(localized: "下班后,你交给屏幕来照顾 🎬")
        case .cloud:         String(localized: "你的人生都漂在云上 ☁️")
        case .developer:     String(localized: "工具栈比代码栈还要丰富 ⌨️")
        case .learning:      String(localized: "课买得比上得快,但也在前进 📚")
        case .finance:       String(localized: "你把人生跑成了一个 Excel 📊")
        case .eclectic:      String(localized: "兴趣广得令人羡慕 🎒")
        case .beginner:      String(localized: "刚刚启程,留白也是一种美 🌱")
        case .balanced:      String(localized: "各司其职,生活有序而完整 ⚖️")
        case .dailyAdder:    String(localized: "今天又订阅了什么新东西? ✨")
        }
    }

    /// 详细描述,2-3 句。
    var detail: String {
        switch self {
        case .ai:
            return String(localized: "豆包、Kimi、即梦 都在你的订阅栏里安家。早上跟 AI 写代码,晚上跟 AI 写日记 —— 智能时代的常住居民,大概就长你这样。")
        case .productivity:
            return String(localized: "Notion、Things、Obsidian、Raycast,你的工具像精密的齿轮咬合在一起。每个 task 都有它的位置,每个想法都不会丢。")
        case .entertainment:
            return String(localized: "爱奇艺、腾讯视频、网易云音乐、漫画 App —— 你的休闲时间被精挑细选的内容填得满满当当。沙发就是你的剧院。")
        case .cloud:
            return String(localized: "iCloud、Dropbox、Google One、Backblaze… 你的数据漂在天上,设备坏了也不慌。云端就是你的随身硬盘。")
        case .developer:
            return String(localized: "GitHub、JetBrains、Linear、Vercel、Cursor —— 你的 Mac 上每一个 App 都是为代码服务的。Bug 永远会有,工具不能少。")
        case .learning:
            return String(localized: "Duolingo、Coursera、Masterclass、Skillshare —— 你相信每一个订阅都是对未来自己的投资。永不停歇地往前走。")
        case .finance:
            return String(localized: "记账 App、理财软件、投资平台,你认真对待每一分钱。你的人生有 budget、有 forecast、有月度 review。")
        case .eclectic:
            return String(localized: "你的订阅栏五花八门:健身、冥想、播客、菜谱、宠物… 没有一条清晰主线,但每一样都让生活更立体。")
        case .beginner:
            return String(localized: "你的订阅栏还很干净。也许你刚下载 EON,也许你天生就是数字极简者 —— 无论哪种,你都掌握着选择权。")
        case .balanced:
            return String(localized: "你的订阅在 5 个以上分类里均匀分布,工作、生活、学习、娱乐都没有偏废 —— 这才是高级的数字生活。")
        case .dailyAdder:
            return String(localized: "你最近平均每天都在添加新订阅,可能在探索新工具,也可能在尝试新生活方式。EON 不评判,只默默记下你的轨迹。")
        }
    }
}

// MARK: - Detection

extension SubscriptionStore {
    /// 根据当前订阅情况推断出来的"订阅人格"。
    /// 优先级:beginner > dailyAdder > balanced > 主导分类 > eclectic。
    var personality: PersonalityType {
        let subs = activeSubscriptions

        // 1) 订阅极少 —— 视为"刚启程"。
        guard subs.count >= 3 else { return .beginner }

        // 2) 频繁添加 —— 近 7 天里至少 5 天加过新订阅。
        let cal = Calendar.current
        let weekAgo = cal.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recentAddDays = Set(subs.compactMap { sub -> Date? in
            let start = sub.effectiveStartDate
            guard start >= weekAgo, start <= Date() else { return nil }
            return cal.startOfDay(for: start)
        })
        if recentAddDays.count >= 5 { return .dailyAdder }

        // 3) 均衡 —— 5 个及以上分类各自占 ≥ 10%。
        let spends = categorySpend
        let significant = spends.filter { $0.share >= 0.10 }
        if significant.count >= 5 { return .balanced }

        // 4) 主导分类 —— 头部分类占 ≥ 30%,落到对应人格;否则是兴趣广泛的折中型。
        guard let top = spends.first, top.share >= 0.30 else { return .eclectic }
        switch top.id {
        case SubscriptionCategory.ai.rawValue:            return .ai
        case SubscriptionCategory.productivity.rawValue:  return .productivity
        case SubscriptionCategory.entertainment.rawValue: return .entertainment
        case SubscriptionCategory.cloud.rawValue:         return .cloud
        case SubscriptionCategory.developer.rawValue:     return .developer
        case SubscriptionCategory.learning.rawValue:      return .learning
        case SubscriptionCategory.finance.rawValue:       return .finance
        case SubscriptionCategory.other.rawValue:         return .eclectic
        default:                                          return .eclectic
        }
    }
}
