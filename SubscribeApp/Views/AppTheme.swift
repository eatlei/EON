import SwiftUI
import UIKit

enum AppAppearance: String, CaseIterable, Codable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: String(localized: "跟随系统")
        case .light: String(localized: "浅色")
        case .dark: String(localized: "深色")
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

private func dynColor(light: UIColor, dark: UIColor) -> Color {
    Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
}

extension Color {
    init(hexString: String) {
        let s = hexString.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r = Double((v >> 16) & 0xFF) / 255.0
        let g = Double((v >> 8) & 0xFF) / 255.0
        let b = Double(v & 0xFF) / 255.0
        self = Color(red: r, green: g, blue: b)
    }
}

enum AppTheme {
    // 动态色：浅色 / 深色（Subo 风深色 + 干净浅色镜像）
    static let canvas = dynColor(
        light: UIColor(red: 0.957, green: 0.961, blue: 0.969, alpha: 1),   // #F4F5F7
        dark:  UIColor(red: 0.039, green: 0.039, blue: 0.047, alpha: 1))    // #0A0A0C
    static let surface = dynColor(
        light: UIColor(red: 1.000, green: 1.000, blue: 1.000, alpha: 1),    // #FFFFFF
        dark:  UIColor(red: 0.090, green: 0.094, blue: 0.110, alpha: 1))    // #17181C
    static let hairline = dynColor(
        light: UIColor(white: 0, alpha: 0.10),
        dark:  UIColor(white: 1, alpha: 0.08))

    static let ink = dynColor(
        light: UIColor(red: 0.082, green: 0.086, blue: 0.102, alpha: 1),    // #15161A
        dark:  UIColor(red: 0.957, green: 0.961, blue: 0.969, alpha: 1))    // #F4F5F7
    static let secondary = dynColor(
        light: UIColor(red: 0.424, green: 0.435, blue: 0.467, alpha: 1),    // #6C6F77
        dark:  UIColor(red: 0.545, green: 0.557, blue: 0.592, alpha: 1))    // #8B8E97
    static let tertiary = dynColor(
        light: UIColor(red: 0.627, green: 0.639, blue: 0.675, alpha: 1),    // #A0A3AC
        dark:  UIColor(red: 0.333, green: 0.345, blue: 0.388, alpha: 1))    // #555863

    static let accent = dynColor(
        light: UIColor(red: 0.118, green: 0.451, blue: 0.878, alpha: 1),    // #1E73E0
        dark:  UIColor(red: 0.239, green: 0.612, blue: 1.000, alpha: 1))    // #3D9CFF

    static let radius: CGFloat = 18
    static let radiusSmall: CGFloat = 12

    /// 原生 TabView 已为系统 tab bar 自动内缩内容，这里只留一点呼吸位
    static let dockClearance: CGFloat = 8

    enum Space {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 28
    }

    static let spring = Animation.spring(response: 0.42, dampingFraction: 0.86)

    static let monogramColors: [String] = [
        "#3D9CFF", "#5856D6", "#FF375F", "#FF8A00",
        "#34C759", "#00C2C7", "#AF52DE", "#8E8E93"
    ]
}

extension Font {
    static func amountHero() -> Font { .system(size: 52, weight: .heavy, design: .rounded) }
    static func amount() -> Font { .system(size: 17, weight: .bold, design: .rounded) }
    static func amountSmall() -> Font { .system(size: 14, weight: .bold, design: .rounded) }
}

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

struct Panel<Content: View>: View {
    var title: LocalizedStringKey? = nil
    @ViewBuilder var content: Content
    init(title: LocalizedStringKey? = nil, @ViewBuilder content: () -> Content) {
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
    let text: LocalizedStringKey
    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .tracking(0.8)
            .textCase(.uppercase)
            .foregroundStyle(AppTheme.tertiary)
    }
}

struct Hairline: View {
    var body: some View {
        Rectangle().fill(AppTheme.hairline).frame(height: 1)
    }
}

/// 订阅图标：按 subscription.icon 渲染（默认分类色块首字母；可为 SF Symbol 或本地图片）
struct CategoryGlyph: View {
    let subscription: Subscription
    var size: CGFloat = 38
    var body: some View {
        Group {
            switch subscription.icon {
            case .image(let id):
                if let ui = IconStore.loadUIImage(id) {
                    Image(uiImage: ui).resizable().scaledToFill()
                } else {
                    letterTile(subscription.category.color)
                }
            case .symbol(let name):
                Image(systemName: name)
                    .font(.system(size: size * 0.46, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: size, height: size)
                    .background(subscription.category.color)
            case .monogram(let hex):
                letterTile(Color(hexString: hex))
            case .category:
                letterTile(subscription.category.color)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.28))
    }

    private func letterTile(_ bg: Color) -> some View {
        Text(String(subscription.name.prefix(1)).uppercased())
            .font(.system(size: size * 0.44, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(bg)
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
