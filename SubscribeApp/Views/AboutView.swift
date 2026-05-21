import SwiftUI
import UIKit
import StoreKit

enum AppLinks {
    // TODO: replace with the published URLs once available.
    static let privacyPolicy = URL(string: "https://example.com/eon/privacy")!
    static let termsOfUse    = URL(string: "https://example.com/eon/terms")!
    static let appStoreID    = "0000000000" // TODO: set after first App Store release
    static var appStoreReviewURL: URL { URL(string: "itms-apps://itunes.apple.com/app/id\(appStoreID)?action=write-review")! }
    static var appStoreShareURL: URL { URL(string: "https://apps.apple.com/app/id\(appStoreID)")! }
}

struct AboutView: View {
    @Environment(\.openURL) private var openURL
    /// iOS 16+ 的 in-app 评分入口 —— 由系统决定何时真正展示弹窗(同一版本一年最多 3 次),
    /// 我们调用它就行,不需要自己手写表单或者跳 App Store。
    @Environment(\.requestReview) private var requestReview
    @StateObject private var tips = TipStore()
    @State private var showTips = false

    private var versionText: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(v) (\(b))"
    }

    private var iconImage: UIImage? {
        // AppIcon is not directly loadable via UIImage(named:) at runtime; try a few common names.
        for name in ["AppIcon", "AppIcon60x60", "AppIcon-60x60", "AppIcon@2x"] {
            if let img = UIImage(named: name) { return img }
        }
        return nil
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: AppTheme.Space.s) {
                    Group {
                        if let img = iconImage {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Image(systemName: "app.fill")
                                .resizable()
                                .scaledToFit()
                                .foregroundStyle(AppTheme.accent)
                                .padding(10)
                        }
                    }
                    .frame(width: 128, height: 128)   // 从 80 加到 128,跟 iOS 设置页里的 App icon 视觉量级对齐
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(AppTheme.hairline, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
                    .padding(.top, AppTheme.Space.s)

                    Text("EON")
                        .font(.title.bold())
                    Text(versionText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppTheme.Space.m)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section {
                Link(destination: AppLinks.privacyPolicy) {
                    HStack(spacing: 12) {
                        SettingsIcon(name: "hand.raised")
                        Text("隐私政策").foregroundStyle(AppTheme.ink)
                    }
                }
                Link(destination: AppLinks.termsOfUse) {
                    HStack(spacing: 12) {
                        SettingsIcon(name: "doc.text")
                        Text("使用条款").foregroundStyle(AppTheme.ink)
                    }
                }
                NavigationLink {
                    AcknowledgmentsView()
                } label: {
                    HStack(spacing: 12) {
                        SettingsIcon(name: "heart.text.square")
                        Text("致谢")
                    }
                }
            } header: {
                Text("法律")
            }

            Section {
                Button {
                    // 直接在 App 内调起系统评分弹窗,不再跳出去 App Store。
                    // 系统会按自己的频控决定要不要真正展示,我们调用就完事。
                    requestReview()
                } label: {
                    HStack(spacing: 12) {
                        SettingsIcon(name: "star.bubble")
                        Text("给 EON 打个分").foregroundStyle(AppTheme.ink)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                ShareLink(item: AppLinks.appStoreShareURL) {
                    HStack(spacing: 12) {
                        SettingsIcon(name: "square.and.arrow.up")
                        Text("分享 EON").foregroundStyle(AppTheme.ink)
                    }
                }
            } header: {
                Text("应用商店")
            }

            Section {
                Button {
                    openURL(feedbackMailURL())
                } label: {
                    HStack(spacing: 12) {
                        SettingsIcon(name: "envelope")
                        Text("发送反馈").foregroundStyle(AppTheme.ink)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Button {
                    showTips = true
                } label: {
                    HStack(spacing: 12) {
                        SettingsIcon(name: "heart")
                        Text("支持开发者").foregroundStyle(AppTheme.ink)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } header: {
                Text("支持")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.visible)
        .navigationTitle("关于")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showTips) { TipSheet(tips: tips) }
        .task { await tips.load() }
    }

    private func deviceModelIdentifier() -> String {
        var sys = utsname()
        uname(&sys)
        let mirror = Mirror(reflecting: sys.machine)
        let id = mirror.children.reduce(into: "") { result, element in
            if let value = element.value as? Int8, value != 0 {
                result.append(Character(UnicodeScalar(UInt8(value))))
            }
        }
        return id.isEmpty ? "Unknown" : id
    }

    private func feedbackMailURL() -> URL {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        let ios = UIDevice.current.systemVersion
        let model = deviceModelIdentifier()
        let intro = String(localized: "请在此描述你的问题或建议：")
        let body = """
        \(intro)


        ——
        App: EON v\(v) (\(b))
        iOS: \(ios)
        Device: \(model)
        """
        let subject = String(localized: "EON 反馈")
        var c = URLComponents()
        c.scheme = "mailto"
        c.path = "eatpoc@gmail.com"
        c.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        return c.url ?? URL(string: "mailto:eatpoc@gmail.com")!
    }
}

struct AcknowledgmentsView: View {
    var body: some View {
        List {
            Section {
                Text("暂无第三方依赖。")
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.visible)
        .navigationTitle("致谢")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { AboutView() }
        .environmentObject(SubscriptionStore())
}
