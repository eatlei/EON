import UIKit

/// 全 App 触觉反馈的统一入口。所有"我们主动触发"的震动都走这里,好处是:
/// 用户在设置里关掉 hapticsEnabled 之后,一处 gate 全局生效,不用去每个调用点改。
///
/// `enabled` 由 SubscriptionStore 在启动 / 开关变化时写入(镜像 Settings.hapticsEnabled)。
/// 默认 true。所有方法都是 @MainActor —— UIFeedbackGenerator 要求主线程。
@MainActor
enum Haptics {
    static var enabled = true

    /// 轻点:按钮 / 选择类操作。
    static func tap(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        guard enabled else { return }
        let g = UIImpactFeedbackGenerator(style: style)
        g.impactOccurred()
    }

    /// 成功:完成一笔操作(打赏成功、保存、加到提醒等)。
    static func success() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// 警告 / 失败。
    static func warning() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    /// 选择切换(分段控件、picker 之类的轻 tick)。
    static func selection() {
        guard enabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    /// 强冲击(摇一摇这类"有能量感"的时刻)。
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .heavy,
                       intensity: CGFloat = 1.0) {
        guard enabled else { return }
        let g = UIImpactFeedbackGenerator(style: style)
        g.impactOccurred(intensity: intensity)
    }
}
