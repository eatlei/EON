import SwiftUI
import UIKit

struct AppearanceSettingsView: View {
    @EnvironmentObject private var store: SubscriptionStore
    @Environment(\.openURL) private var openURL
    @State private var showLanguageDialog = false
    @State private var showLanguageAppliedAlert = false

    /// 当前 App 实际使用的语言代码(取自 Bundle 或 AppleLanguages 用户偏好)。
    private var currentLanguageCode: String {
        if let saved = (UserDefaults.standard.array(forKey: "AppleLanguages") as? [String])?.first {
            return saved
        }
        return Bundle.main.preferredLocalizations.first ?? "zh-Hans"
    }

    /// 当前语言的显示名(简体中文 / English / …)。
    private var currentLanguageName: String {
        Self.supportedLanguages.first { currentLanguageCode.hasPrefix($0.code) }?.name
            ?? currentLanguageCode
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

                // 语言切换 —— 之前在 SettingsView 单独占位,现在合并进外观区,语义
                // 上跟"亮暗 / 主题色 / 卡片样式"是一组"App 怎么看 / 怎么读"的设置。
                Button {
                    showLanguageDialog = true
                } label: {
                    HStack(spacing: 12) {
                        SettingsIcon(name: "character.book.closed")
                        Text("语言").foregroundStyle(.primary)
                        Spacer()
                        Text(currentLanguageName).foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } header: {
                Text("显示")
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
        .confirmationDialog("语言", isPresented: $showLanguageDialog, titleVisibility: .visible) {
            ForEach(Self.supportedLanguages, id: \.code) { lang in
                Button(lang.name) { applyLanguage(lang.code) }
            }
            Button("在 iOS 设置里更改…") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            Button("取消", role: .cancel) { }
        }
        .alert("语言已更新", isPresented: $showLanguageAppliedAlert) {
            Button("好的", role: .cancel) { }
        } message: {
            Text("重新打开 EON 后生效。")
        }
    }

    private func applyLanguage(_ code: String) {
        UserDefaults.standard.set([code], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
        showLanguageAppliedAlert = true
    }

    /// EON 当前支持的展示语言。需要跟 project.yml 的 CFBundleLocalizations 保持一致。
    fileprivate static let supportedLanguages: [(code: String, name: String)] = [
        ("zh-Hans", "简体中文"),
        ("en",      "English"),
        ("ja",      "日本語"),
        ("ko",      "한국어"),
        ("es",      "Español"),
        ("fr",      "Français"),
        ("de",      "Deutsch"),
    ]
}

#Preview {
    NavigationStack { AppearanceSettingsView() }
        .environmentObject(SubscriptionStore())
}
