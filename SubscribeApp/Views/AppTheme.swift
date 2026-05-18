import SwiftUI

enum AppTheme {
    // Surfaces — 冷调深色，无暖味
    static let canvas = Color(red: 0.055, green: 0.063, blue: 0.078)   // #0E1014
    static let surface = Color(red: 0.102, green: 0.114, blue: 0.141)  // #1A1D24 (非玻璃处的深色基)
    static let hairline = Color.white.opacity(0.08)

    // Text
    static let ink = Color(red: 0.949, green: 0.957, blue: 0.973)      // #F2F4F8
    static let secondary = Color(red: 0.608, green: 0.627, blue: 0.671) // #9BA0AB
    static let tertiary = Color(red: 0.369, green: 0.388, blue: 0.431)  // #5E636E

    // 单一高饱和强调（冷调电蓝）
    static let accent = Color(red: 0.239, green: 0.612, blue: 1.0)      // #3D9CFF

    // 圆角（更大）
    static let radius: CGFloat = 16
    static let radiusSmall: CGFloat = 12

    /// Extra bottom breathing room; native TabView already insets content for its Liquid Glass tab bar.
    static let dockClearance: CGFloat = 16

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

/// 全屏滚动容器：冷调深色画布
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

/// Liquid Glass 面板：玻璃材质 + 统一大圆角 + 极淡边界
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
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: AppTheme.radius))
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
            .background(subscription.category.color.opacity(0.22),
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
