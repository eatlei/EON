import SwiftUI
import UIKit

struct SettingsView: View {
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
        NavigationStack {
            List {
                Section {
                    NavigationLink { AppearanceSettingsView() } label: {
                        HStack(spacing: 12) {
                            SettingsIcon(name: "paintpalette")
                            Text("外观")
                        }
                    }
                    NavigationLink { CurrencySettingsView() } label: {
                        HStack(spacing: 12) {
                            SettingsIcon(name: "dollarsign.circle")
                            Text("货币")
                            Spacer()
                            Text(store.baseCurrency.rawValue).foregroundStyle(.secondary)
                        }
                    }
                    NavigationLink { NotificationSettingsView() } label: {
                        HStack(spacing: 12) {
                            SettingsIcon(name: "bell")
                            Text("通知")
                        }
                    }
                    NavigationLink { CategorySettingsView() } label: {
                        HStack(spacing: 12) {
                            SettingsIcon(name: "tag")
                            Text("分类")
                        }
                    }
                    Button {
                        showLanguageDialog = true
                    } label: {
                        HStack(spacing: 12) {
                            SettingsIcon(name: "character.book.closed")
                            Text("语言")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(currentLanguageName)
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                Section {
                    NavigationLink { PaymentMethodsView() } label: {
                        HStack(spacing: 12) {
                            SettingsIcon(name: "creditcard")
                            Text("支付方式")
                        }
                    }
                    NavigationLink { ArchivedSubscriptionsView() } label: {
                        HStack(spacing: 12) {
                            SettingsIcon(name: "archivebox")
                            Text("归档订阅")
                        }
                    }
                    NavigationLink { DataSyncSettingsView() } label: {
                        HStack(spacing: 12) {
                            SettingsIcon(name: "externaldrive")
                            Text("iCloud 与数据")
                        }
                    }
                }

                Section {
                    NavigationLink { AboutView() } label: {
                        HStack(spacing: 12) {
                            SettingsIcon(name: "info.circle")
                            Text("关于")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.visible)
            .navigationTitle("设置")
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
    SettingsView().environmentObject(SubscriptionStore())
}
