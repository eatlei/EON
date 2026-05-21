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

            // App 图标切换:通用 / 订阅人格(目前为占位图标)。
            Section {
                Picker(selection: $usePersonaIcon) {
                    Text("通用").tag(false)
                    Text("订阅人格").tag(true)
                } label: {
                    HStack(spacing: 12) {
                        SettingsIcon(name: "app.badge")
                        Text("App 图标")
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: usePersonaIcon) { _, persona in
                    applyAppIcon(persona: persona)
                }
            } header: {
                Text("图标")
            } footer: {
                Text("「订阅人格」目前是占位图标,后续会替换成跟你人格匹配的专属图标。切换时系统会弹一下确认。")
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
}

#Preview {
    NavigationStack { AppearanceSettingsView() }
        .environmentObject(SubscriptionStore())
}
