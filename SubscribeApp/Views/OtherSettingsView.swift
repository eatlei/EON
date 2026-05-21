import SwiftUI
import UIKit

/// 「其他」设置:不属于外观、也不属于订阅 / 数据 / 关于的通用 App 级开关。
/// 目前收纳「语言」与「触觉反馈」——它们决定 App 怎么读、怎么回应你,放在一起。
struct OtherSettingsView: View {
    @EnvironmentObject private var store: SubscriptionStore
    @Environment(\.openURL) private var openURL
    @State private var showLanguageDialog = false
    /// 切语言后的"正在重启"全屏 HUD —— Bundle 的本地化表只有进程冷启动才会重读,
    /// 所以这里走 exit(0) 真重启:HUD 给用户 0.6s 视觉缓冲再退出,避免"啪一下"的突兀感。
    @State private var restarting = false

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
                Text("语言")
            }

            Section {
                Toggle(isOn: $store.hapticsEnabled) {
                    HStack(spacing: 12) {
                        SettingsIcon(name: "hand.tap")
                        Text("触觉反馈")
                    }
                }
            } header: {
                Text("反馈")
            } footer: {
                Text("点按、打赏、摇一摇、彩蛋小球碰撞等操作会有轻微震动。关闭后 EON 不再主动触发任何震动。")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.visible)
        .navigationTitle("其他")
        .navigationBarTitleDisplayMode(.inline)
        // 之前用 confirmationDialog 在 iPad / 大屏上会渲染成带气泡指针的 popover,
        // 但 row 上根本没有 anchor view,指针指向乱飞。改成 .sheet + 自定义列表,
        // 跨设备表现一致,语言选项也能滚动显示。
        .sheet(isPresented: $showLanguageDialog) {
            LanguagePickerSheet(
                languages: Self.supportedLanguages,
                currentCode: currentLanguageCode,
                onPick: { code in
                    showLanguageDialog = false
                    applyLanguage(code)
                },
                onOpenSystemSettings: {
                    showLanguageDialog = false
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        // 重启 HUD —— 盖满全屏,把当前界面遮住,避免用户在 exit(0) 前
        // 一瞬间看到旧语言的 UI 闪一下。
        .overlay {
            if restarting {
                ZStack {
                    Color.black.opacity(0.45).ignoresSafeArea()
                    VStack(spacing: 14) {
                        ProgressView().tint(.white).scaleEffect(1.2)
                        Text("正在重启 EON…")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 28).padding(.vertical, 22)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: restarting)
    }

    private func applyLanguage(_ code: String) {
        UserDefaults.standard.set([code], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
        // 立刻把"正在重启"HUD 推上来,然后短暂等 0.6s 让动画 + ProgressView 跑一下,
        // 再调 exit(0) 真正结束进程。下次用户点开图标,Bundle 会按新的 AppleLanguages
        // 重读本地化表,整个 App 就是新语言了。
        restarting = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            exit(0)
        }
    }

    /// EON 当前支持的展示语言。需要跟 project.yml 的 CFBundleLocalizations 保持一致。
    fileprivate static let supportedLanguages: [(code: String, name: String)] = [
        ("zh-Hans", "简体中文"),
        ("zh-Hant", "繁體中文"),
        ("en",      "English"),
        ("ja",      "日本語"),
        ("ko",      "한국어"),
        ("es",      "Español"),
        ("fr",      "Français"),
        ("de",      "Deutsch"),
    ]
}

// MARK: - 语言选择 sheet

/// 语言选择面板。用 sheet + List 实现,iPhone / iPad 都呈现成底部弹层,
/// 不会出现 confirmationDialog 在 popover 模式下气泡指针乱指的问题。
private struct LanguagePickerSheet: View {
    let languages: [(code: String, name: String)]
    let currentCode: String
    let onPick: (String) -> Void
    let onOpenSystemSettings: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(languages, id: \.code) { lang in
                        Button {
                            onPick(lang.code)
                        } label: {
                            HStack {
                                Text(lang.name).foregroundStyle(.primary)
                                Spacer()
                                if currentCode.hasPrefix(lang.code) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(AppTheme.accent)
                                        .font(.subheadline.weight(.bold))
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } footer: {
                    Text("切换后 EON 会重启一次以套用新语言。")
                }

                Section {
                    Button(action: onOpenSystemSettings) {
                        HStack(spacing: 12) {
                            SettingsIcon(name: "gear")
                            Text("在 iOS 设置里更改…").foregroundStyle(.primary)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("语言")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    NavigationStack { OtherSettingsView() }
        .environmentObject(SubscriptionStore())
}
