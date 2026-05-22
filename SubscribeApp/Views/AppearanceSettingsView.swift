import SwiftUI
import UIKit

struct AppearanceSettingsView: View {
    @EnvironmentObject private var store: SubscriptionStore
    /// App 图标选择:false = 通用(默认),true = 订阅人格(当前为占位图标)。
    /// 初值读系统当前的备用图标名,保证页面跟实际图标一致。
    @State private var usePersonaIcon: Bool = (UIApplication.shared.alternateIconName != nil)

    /// 切换 App 图标。nil = 恢复默认图标;否则切到备用图标 AppIcon-Persona。
    private func applyAppIcon(persona: Bool) {
        let name: String? = persona ? "AppIcon-Persona" : nil
        guard UIApplication.shared.supportsAlternateIcons,
              UIApplication.shared.alternateIconName != name else { return }
        Haptics.tap()
        UIApplication.shared.setAlternateIconName(name) { _ in }
    }

    private func selectIcon(persona: Bool) {
        guard usePersonaIcon != persona else { return }
        usePersonaIcon = persona
        applyAppIcon(persona: persona)
    }

    /// 运行时取主图标预览(AppIcon 不能直接 UIImage(named:),试几个常见名)。
    private var appIconImage: UIImage? {
        for name in ["AppIcon", "AppIcon60x60", "AppIcon-60x60", "AppIcon@2x"] {
            if let img = UIImage(named: name) { return img }
        }
        return nil
    }

    var body: some View {
        List {
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
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: AppTheme.Space.m)], spacing: AppTheme.Space.m) {
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
                                            .stroke(Color.primary.opacity(store.accentTheme == theme ? 0.85 : 0), lineWidth: 2)
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

            // App 图标切换:点开后在下方分两类展开 —— 通用 / 人格图标(占位)。
            Section {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: AppTheme.Space.l) {
                        iconCategory(title: "通用") {
                            iconTile(selected: !usePersonaIcon, label: "通用") {
                                generalThumb
                            } action: { selectIcon(persona: false) }
                        }
                        iconCategory(title: "人格图标") {
                            iconTile(selected: usePersonaIcon, label: "占位") {
                                personaThumb
                            } action: { selectIcon(persona: true) }
                        }
                    }
                    .padding(.vertical, AppTheme.Space.s)
                } label: {
                    HStack(spacing: 12) {
                        SettingsIcon(name: "app.badge")
                        Text("App 图标")
                        Spacer()
                        Text(usePersonaIcon ? "人格图标" : "通用")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("图标")
            } footer: {
                Text("「人格图标」目前是占位图标,后续会替换成跟你人格匹配的专属图标。切换时系统会弹一下确认。")
            }

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

    // MARK: - 图标选择器小部件

    /// 一个分类:小标题 + 一排可选图标。
    private func iconCategory<Content: View>(title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.s) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.secondary)
            HStack(spacing: AppTheme.Space.m) {
                content()
            }
        }
    }

    /// 单个图标方块:缩略图 + 选中态(主题色描边 + 角标对号)+ 名称。
    private func iconTile<Thumb: View>(selected: Bool, label: LocalizedStringKey, @ViewBuilder thumb: () -> Thumb, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                thumb()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(selected ? AppTheme.accent : AppTheme.hairline,
                                    lineWidth: selected ? 2.5 : 1)
                    )
                    .overlay(alignment: .bottomTrailing) {
                        if selected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(.white, AppTheme.accent)
                                .padding(3)
                        }
                    }
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(selected ? AppTheme.ink : AppTheme.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var generalThumb: some View {
        if let ui = appIconImage {
            Image(uiImage: ui).resizable().scaledToFill()
        } else {
            ZStack {
                AppTheme.accent
                Text(verbatim: "EON")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
    }

    private var personaThumb: some View {
        ZStack {
            LinearGradient(colors: [AppTheme.accent, AppTheme.accent.opacity(0.6)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: "sparkles")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

#Preview {
    NavigationStack { AppearanceSettingsView() }
        .environmentObject(SubscriptionStore())
}
