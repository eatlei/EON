import SwiftUI

enum AppTheme {
    // Surfaces — 近黑底 + 深色实心卡片（参考 Subo）
    static let canvas = Color(red: 0.039, green: 0.039, blue: 0.047)   // #0A0A0C
    static let surface = Color(red: 0.090, green: 0.094, blue: 0.110)  // #17181C 深色实心卡
    static let hairline = Color.white.opacity(0.08)

    // Text
    static let ink = Color(red: 0.957, green: 0.961, blue: 0.969)      // #F4F5F7
    static let secondary = Color(red: 0.545, green: 0.557, blue: 0.592) // #8B8E97
    static let tertiary = Color(red: 0.333, green: 0.345, blue: 0.388)  // #555863

    // 单一高饱和强调（电蓝）
    static let accent = Color(red: 0.239, green: 0.612, blue: 1.0)      // #3D9CFF

    // 圆角
    static let radius: CGFloat = 18
    static let radiusSmall: CGFloat = 12

    /// 内容底部留白，避开自绘单行 bar
    static let dockClearance: CGFloat = 96

    // 间距阶
    enum Space {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 28
    }

    static let spring = Animation.spring(response: 0.42, dampingFraction: 0.86)
}

extension Font {
    static func amountHero() -> Font { .system(size: 52, weight: .heavy, design: .rounded) }
    static func amount() -> Font { .system(size: 17, weight: .bold, design: .rounded) }
    static func amountSmall() -> Font { .system(size: 14, weight: .bold, design: .rounded) }
}

/// 全屏滚动容器：近黑画布
struct AppScreen<Content: View>: View {
    var bottomPadding: CGFloat = AppTheme.dockClearance
    @ViewBuilder var content: Content
    init(bottomPadding: CGFloat = AppTheme.dockClearance, @ViewBuilder content: () -> Content) {
        self.bottomPadding = bottomPadding
        self.content = content()
    }
    var body: some View {
        ScrollView {
            content
                .padding(.horizontal, AppTheme.Space.xl)
                .padding(.top, AppTheme.Space.m)
                .padding(.bottom, bottomPadding)
        }
        .background(AppTheme.canvas.ignoresSafeArea())
    }
}

/// 深色实心卡片：surface + 1px 细边，干净利落（参考 Subo，不用玻璃）
struct Panel<Content: View>: View {
    var title: String? = nil
    @ViewBuilder var content: Content
    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.m) {
            if let title {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Space.l)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.radius))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radius)
                .stroke(AppTheme.hairline, lineWidth: 1)
        )
    }
}

struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.bold))
            .tracking(0.8)
            .foregroundStyle(AppTheme.tertiary)
    }
}

struct Hairline: View {
    var body: some View {
        Rectangle().fill(AppTheme.hairline).frame(height: 1)
    }
}

/// 分类图标块：实心品牌色 + 白色首字母（像 App 图标，参考 Subo）
struct CategoryGlyph: View {
    let subscription: Subscription
    var size: CGFloat = 38
    var body: some View {
        Text(String(subscription.name.prefix(1)).uppercased())
            .font(.system(size: size * 0.44, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(subscription.category.color,
                        in: RoundedRectangle(cornerRadius: size * 0.28))
    }
}

struct RevealModifier: ViewModifier {
    let index: Int
    @State private var shown = false
    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 10)
            .animation(AppTheme.spring.delay(Double(index) * 0.04), value: shown)
            .onAppear { if !shown { shown = true } }
    }
}

extension View {
    func reveal(_ index: Int) -> some View { modifier(RevealModifier(index: index)) }
}
