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

private func dynRGB(_ light: UInt32, _ dark: UInt32) -> Color {
    func ui(_ v: UInt32) -> UIColor {
        UIColor(red: CGFloat((v >> 16) & 0xFF) / 255.0,
                green: CGFloat((v >> 8) & 0xFF) / 255.0,
                blue: CGFloat(v & 0xFF) / 255.0, alpha: 1)
    }
    return dynColor(light: ui(light), dark: ui(dark))
}

enum AccentTheme: String, CaseIterable, Codable, Identifiable {
    case blue, indigo, purple, pink, red, orange, green, teal
    var id: String { rawValue }
    var title: String {
        switch self {
        case .blue:   String(localized: "蓝")
        case .indigo: String(localized: "靛蓝")
        case .purple: String(localized: "紫")
        case .pink:   String(localized: "粉")
        case .red:    String(localized: "红")
        case .orange: String(localized: "橙")
        case .green:  String(localized: "绿")
        case .teal:   String(localized: "青")
        }
    }
    var color: Color {
        switch self {
        case .blue:   dynRGB(0x1E73E0, 0x3D9CFF)   // == current default accent (unchanged look)
        case .indigo: dynRGB(0x4B45C6, 0x6E6BE8)
        case .purple: dynRGB(0x8A38D6, 0xB266F0)
        case .pink:   dynRGB(0xE0327A, 0xFF5C9A)
        case .red:    dynRGB(0xD83A3A, 0xFF5C5C)
        case .orange: dynRGB(0xE07A12, 0xFF9F2E)
        case .green:  dynRGB(0x1F9D4D, 0x34C759)
        case .teal:   dynRGB(0x0E9AA0, 0x2BC8CE)
        }
    }
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

    /// 用户可选主题色（全部读写均在主线程/UI 上下文，故 nonisolated(unsafe) 安全）
    nonisolated(unsafe) static var accentTheme: AccentTheme = .blue
    static var accent: Color { accentTheme.color }

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
        .scrollDismissesKeyboard(.interactively)
        .background(AppTheme.canvas.ignoresSafeArea())
    }
}

/// 玻璃材质 Panel — 用于 immersive 背景上的表单分组。
/// `.regularMaterial` 会自动适配底色亮度,保证文字始终可读。
struct MaterialPanel<Content: View>: View {
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
                    .foregroundStyle(.primary)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Space.l)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppTheme.radius))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radius)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
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
                    glyphTile(.letter, color: subscription.category.color)
                }
            case .tile(let glyph, let colorHex):
                let bg = colorHex.map { Color(hexString: $0) } ?? subscription.category.color
                glyphTile(glyph, color: bg)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.28))
    }

    @ViewBuilder
    private func glyphTile(_ glyph: TileGlyph, color: Color) -> some View {
        switch glyph {
        case .letter:
            Text(String(subscription.name.prefix(1)).uppercased())
                .font(.system(size: size * 0.44, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(color)
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: size * 0.46, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(color)
        }
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

struct SettingsLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 12) {
            configuration.icon
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(AppTheme.secondary)
                .frame(width: 22, alignment: .center)
            configuration.title
                .foregroundStyle(AppTheme.ink)
        }
    }
}

extension LabelStyle where Self == SettingsLabelStyle {
    static var settings: SettingsLabelStyle { SettingsLabelStyle() }
}

/// 设置页通用前置图标：固定 16pt、灰色、22pt 居中框宽。任何 List 行都用这个，**不要**用 Label(..., systemImage:)。
struct SettingsIcon: View {
    let name: String
    var body: some View {
        Image(systemName: name)
            .font(.system(size: 16, weight: .regular))
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(AppTheme.secondary)
            .frame(width: 22, alignment: .center)
    }
}
