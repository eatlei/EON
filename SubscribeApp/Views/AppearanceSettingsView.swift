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

    /// UI 展示名称(完整)
    var label: String {
        switch self {
        case .auto:             return "自动"
        case .alwaysLight:      return "浅色"
        case .alwaysDark:       return "深色"
        case .persona(let t):   return t.name
        }
    }

    /// 图标格里显示的短名称 —— 最多 4 汉字,保持排列整齐
    var tileLabel: String {
        switch self {
        case .auto:             return "自动"
        case .alwaysLight:      return "浅色"
        case .alwaysDark:       return "深色"
        case .persona(let t):
            switch t {
            case .ai:            return "AI 先驱"
            case .productivity:  return "效率猎人"
            case .entertainment: return "观察家"
            case .cloud:         return "云端游民"
            case .developer:     return "代码匠人"
            case .learning:      return "学习者"
            case .finance:       return "理财师"
            case .eclectic:      return "收藏家"
            case .beginner:      return "极简者"
            case .balanced:      return "平衡大师"
            case .dailyAdder:    return "探索者"
            case .curator:       return "策展人"
            }
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
                    // 通用 / 人格图标共用同一套列宽,视觉对齐
                    let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)
                    VStack(alignment: .leading, spacing: AppTheme.Space.l) {
                        // 通用:3 项,用同宽列的 HStack,右侧 Spacer 撑满行宽
                        sectionLabel("通用")
                        HStack(spacing: 10) {
                            ForEach([AppIconOption.auto, .alwaysLight, .alwaysDark], id: \.tileLabel) { opt in
                                iconTile(option: opt)
                            }
                            // 占满剩余一列,让 3 列与下方 4 列等宽对齐
                            Color.clear.frame(maxWidth: .infinity)
                        }

                        // 人格图标:11 种,4 列多行排布
                        sectionLabel("人格图标")
                        LazyVGrid(columns: columns, spacing: 14) {
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

    /// 分类小标题
    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppTheme.secondary)
    }

    /// 单个图标方块 —— frame(maxWidth:.infinity) 让它撑满 Grid / HStack 列宽
    private func iconTile(option: AppIconOption) -> some View {
        let selected = selectedIcon == option
        return Button {
            applyIcon(option)
        } label: {
            VStack(spacing: 5) {
                iconThumb(option)
                    .aspectRatio(1, contentMode: .fit)   // 保持 1:1,随列宽自适应
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                selected ? AppTheme.accent : AppTheme.hairline,
                                lineWidth: selected ? 3 : 1
                            )
                    )
                    .overlay(alignment: .bottomTrailing) {
                        if selected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(.white, AppTheme.accent)
                                .offset(x: 5, y: 5)
                        }
                    }
                Text(option.tileLabel)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(selected ? AppTheme.ink : AppTheme.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)   // 撑满列宽,各列图标尺寸完全一致
        }
        .buttonStyle(.plain)
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
