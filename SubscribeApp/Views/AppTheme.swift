import SwiftUI

enum AppTheme {
    // Surfaces — 纸感暖白，无渐变
    static let canvas = Color(red: 0.984, green: 0.980, blue: 0.973)   // #FBFAF8
    static let surface = Color.white
    static let hairline = Color(red: 0.90, green: 0.89, blue: 0.87)

    // Text
    static let ink = Color(red: 0.102, green: 0.102, blue: 0.110)      // #1A1A1C
    static let secondary = Color(red: 0.52, green: 0.52, blue: 0.55)
    static let tertiary = Color(red: 0.70, green: 0.70, blue: 0.72)

    // 单一克制强调色
    static let accent = Color(red: 0.18, green: 0.45, blue: 0.42)

    // 圆角
    static let radius: CGFloat = 12
    static let radiusSmall: CGFloat = 8

    /// Bottom clearance for screens that sit under ContentView's dock (tab pill + floating add button).
    static let dockClearance: CGFloat = 112

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

/// 全屏滚动容器：纯色画布，无渐变
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

/// 极淡边界的面板：白底 + 统一圆角 + 0.5pt 发丝线，无重阴影
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
                .stroke(AppTheme.hairline, lineWidth: 0.5)
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
        Rectangle().fill(AppTheme.hairline).frame(height: 0.5)
    }
}

/// 分类字母头像（颜色只在这种小圆点上出现）
struct CategoryGlyph: View {
    let subscription: Subscription
    var size: CGFloat = 38
    var body: some View {
        Text(String(subscription.name.prefix(1)).uppercased())
            .font(.system(size: size * 0.42, weight: .heavy, design: .rounded))
            .foregroundStyle(subscription.category.color)
            .frame(width: size, height: size)
            .background(subscription.category.color.opacity(0.14),
                        in: RoundedRectangle(cornerRadius: AppTheme.radiusSmall))
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
