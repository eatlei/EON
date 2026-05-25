import SwiftUI
import UIKit

// MARK: - 图标选择数据模型

/// App 图标选项。rawValue 对应 UIApplication.setAlternateIconName 传入的名称
/// (nil = 主图标);section 决定在列表里的归属。
enum AppIconOption: Equatable {
    // 通用 ——— 跟随系统 / 永久亮色 / 永久暗色
    case auto           // nil → 使用自带亮/暗双图的 AppIcon,系统自动切换
    case alwaysLight    // AppIcon-AlwaysLight
    case alwaysDark     // AppIcon-AlwaysDark

    // 人格图标
    case persona(PersonalityType)

    /// 传给 setAlternateIconName 的名字
    var iconName: String? {
        switch self {
        case .auto:             return nil
        case .alwaysLight:      return "AppIcon-AlwaysLight"
        case .alwaysDark:       return "AppIcon-AlwaysDark"
        case .persona(let t):
            // curator 没有专属图,退回旧的占位图
            return t == .curator ? "AppIcon-Persona" : "AppIcon-Persona-\(t.rawValue)"
        }
    }

    /// UI 展示名称
    var label: String {
        switch self {
        case .auto:             return "自动"
        case .alwaysLight:      return "浅色"
        case .alwaysDark:       return "深色"
        case .persona(let t):   return t.name
        }
    }

    /// 从系统当前备用图标名还原枚举
    static func current() -> AppIconOption {
        let name = UIApplication.shared.alternateIconName
        switch name {
        case nil:                       return .auto
        case "AppIcon-AlwaysLight":     return .alwaysLight
        case "AppIcon-AlwaysDark":      return .alwaysDark
        default:
            // 解析 "AppIcon-Persona-xxx"
            if let rawValue = name?.replacingOccurrences(of: "AppIcon-Persona-", with: ""),
               rawValue != name,   // 确保有替换发生
               let type = PersonalityType(rawValue: rawValue) {
                return .persona(type)
            }
            if name == "AppIcon-Persona" { return .persona(.curator) }
            return .auto
        }
    }
}

// MARK: - 主视图

struct AppearanceSettingsView: View {
    @EnvironmentObject private var store: SubscriptionStore
    @State private var selectedIcon: AppIconOption = .current()

    var body: some View {
        List {
            // ── 显示 ─────────────────────────────────────────────────────
            Section {
                Picker(selection: $store.appearance) {
                    ForEach(AppAppearance.allCases) { Text($0.title).tag($0) }
                } label: {
                    HStack(spacing: 12) {
                        SettingsIcon(name: "circle.lefthalf.filled")
                        Text("外观")
                    }
                }
                .pickerStyle(.menu)

                DisclosureGroup {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 44), spacing: AppTheme.Space.m)],
                        spacing: AppTheme.Space.m
                    ) {
                        ForEach(AccentTheme.allCases) { theme in
                            Button {
                                store.accentTheme = theme
                            } label: {
                                Circle()
                                    .fill(theme.color)
                                    .frame(width: 34, height: 34)
                                    .overlay(
                                        Image(systemName: "checkmark")
                                            .font(.caption.weight(.black))
                                            .foregroundStyle(.white)
                                            .opacity(store.accentTheme == theme ? 1 : 0)
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary.opacity(store.accentTheme == theme ? 0.85 : 0),
                                                    lineWidth: 2)
                                            .padding(-3)
                                    )
                                    .accessibilityLabel(Text(theme.title))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, AppTheme.Space.s)
                } label: {
                    HStack(spacing: 12) {
                        SettingsIcon(name: "paintpalette")
                        Text("主题色")
                        Spacer()
                        Circle()
                            .fill(store.accentTheme.color)
                            .frame(width: 18, height: 18)
                    }
                }
            } header: {
                Text("显示")
            }

            // ── App 图标 ──────────────────────────────────────────────────
            Section {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: AppTheme.Space.xl) {
                        // 通用:跟随系统 / 永久亮色 / 永久暗色
                        iconCategory(title: "通用") {
                            ForEach([AppIconOption.auto, .alwaysLight, .alwaysDark], id: \.label) { opt in
                                iconTile(option: opt)
                            }
                        }

                        // 人格图标:11 种(curator 暂无专属图,不列出)
                        iconCategory(title: "人格图标") {
                            ForEach(PersonalityType.allCases.filter { $0 != .curator }) { type in
                                iconTile(option: .persona(type))
                            }
                        }
                    }
                    .padding(.vertical, AppTheme.Space.s)
                } label: {
                    HStack(spacing: 12) {
                        SettingsIcon(name: "app.badge")
                        Text("App 图标")
                        Spacer()
                        Text(selectedIcon.label)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("图标")
            } footer: {
                Text("「通用」图标支持跟随系统在亮/暗色间自动切换,也可固定为浅色或深色。「人格图标」会展示你的订阅人格专属风格。切换时系统会弹一下确认提示。")
            }

            // ── 卡片 ──────────────────────────────────────────────────────
            Section {
                Toggle(isOn: $store.coloredSubscriptionCards) {
                    HStack(spacing: 12) {
                        SettingsIcon(name: "square.grid.2x2.fill")
                        Text("彩色订阅卡片")
                    }
                }
            } header: {
                Text("卡片")
            } footer: {
                Text("让每张订阅卡片渲染上图标的主色调。关闭则回到默认浅色卡片。")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.visible)
        .navigationTitle("外观")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 子组件

    /// 分类行:标题 + 横向可滚动的图标列表
    private func iconCategory<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.s) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Space.m) {
                    content()
                }
            }
        }
    }

    /// 单个图标方块
    private func iconTile(option: AppIconOption) -> some View {
        let selected = selectedIcon == option
        return Button {
            applyIcon(option)
        } label: {
            VStack(spacing: 6) {
                iconThumb(option)
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    // strokeBorder 完全在形状内部绘制,不会溢出到外部被裁切
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                selected ? AppTheme.accent : AppTheme.hairline,
                                lineWidth: selected ? 3 : 1
                            )
                    )
                    // 角标放在图标外层 ZStack 里,避免被 clipShape 截断
                    .overlay(alignment: .bottomTrailing) {
                        if selected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.white, AppTheme.accent)
                                .offset(x: 6, y: 6)   // 稍微突出到角落,视觉更自然
                        }
                    }
                Text(option.label)
                    .font(.caption2)
                    .foregroundStyle(selected ? AppTheme.ink : AppTheme.secondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .padding(.bottom, 4)   // 给角标预留空间,不会撑开相邻间距
    }

    /// 图标缩略图:从 Preview-*.imageset 读取(专为此用途生成的 180px 缩略图)。
    /// .appiconset 无法在运行时通过 UIImage(named:) 加载,需要单独的 imageset。
    @ViewBuilder
    private func iconThumb(_ option: AppIconOption) -> some View {
        let previewName: String = {
            switch option {
            case .auto:         return "Preview-AlwaysLight"   // 自动选项用亮色版做预览
            case .alwaysLight:  return "Preview-AlwaysLight"
            case .alwaysDark:   return "Preview-AlwaysDark"
            case .persona(let t): return "Preview-Persona-\(t.rawValue)"
            }
        }()

        if let ui = UIImage(named: previewName) {
            Image(uiImage: ui).resizable().scaledToFill()
        } else {
            iconFallback(option: option)
        }
    }

    @ViewBuilder
    private func iconFallback(option: AppIconOption) -> some View {
        switch option {
        case .auto:
            iconGradient(symbol: "sparkles", colors: [.blue, .indigo])
        case .alwaysLight:
            iconGradient(symbol: "sun.max.fill", colors: [Color(hex: 0xF5C06A), Color(hex: 0xF0A030)])
        case .alwaysDark:
            iconGradient(symbol: "moon.fill", colors: [Color(hex: 0x1C1C2E), Color(hex: 0x2C2C4A)])
        case .persona(let t):
            iconGradient(symbol: t.fallbackSymbol, colors: [t.tint, t.tint.opacity(0.6)])
        }
    }

    private func iconGradient(symbol: String, colors: [Color]) -> some View {
        ZStack {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    // MARK: - 切换逻辑

    private func applyIcon(_ option: AppIconOption) {
        guard selectedIcon != option else { return }
        guard UIApplication.shared.supportsAlternateIcons else { return }
        let name = option.iconName
        guard UIApplication.shared.alternateIconName != name else {
            selectedIcon = option
            return
        }
        Haptics.tap()
        UIApplication.shared.setAlternateIconName(name) { error in
            if error == nil {
                DispatchQueue.main.async { selectedIcon = option }
            }
        }
    }
}

// MARK: - Color hex helper (局部使用)

private extension Color {
    init(hex: UInt32) {
        self.init(
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8)  & 0xFF) / 255,
            blue:  Double( hex        & 0xFF) / 255
        )
    }
}

#Preview {
    NavigationStack { AppearanceSettingsView() }
        .environmentObject(SubscriptionStore())
}
