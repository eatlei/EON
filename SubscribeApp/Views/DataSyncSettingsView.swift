import SwiftUI
import UIKit

struct DataSyncSettingsView: View {
    @EnvironmentObject private var store: SubscriptionStore
    @State private var syncing = false
    @State private var copyConfirmed = false
    @State private var syncedToastShown = false
    @State private var markdownFileURL: URL? = nil
    @State private var jsonFileURL: URL? = nil

    private var iCloudAvailable: Bool { FileManager.default.ubiquityIdentityToken != nil }
    private var lastSyncText: String {
        guard let d = store.lastSyncedAt else { return String(localized: "从未同步") }
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short
        return f.string(from: d)
    }

    var body: some View {
        List {
            // iCloud
            Section {
                Toggle(isOn: $store.iCloudSyncEnabled) {
                    HStack(spacing: 12) { SettingsIcon(name: "icloud"); Text("自动同步") }
                }
                HStack(spacing: 12) {
                    SettingsIcon(name: iCloudAvailable ? "checkmark.icloud" : "exclamationmark.icloud")
                    Text("iCloud 账户")
                    Spacer()
                    Text(iCloudAvailable ? String(localized: "可用") : String(localized: "未登录"))
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 12) {
                    SettingsIcon(name: "clock.arrow.circlepath")
                    Text("上次同步")
                    Spacer()
                    Text(lastSyncText).foregroundStyle(.secondary)
                }
                Button {
                    guard !syncing else { return }
                    syncing = true
                    let start = Date()
                    Task {
                        await store.performManualICloudSync()
                        // 同步操作秒回也常见(只 push KVS),给图标至少 0.9s 转一圈
                        // 才退出 loading 态 —— 否则用户感觉"什么都没发生"。
                        let elapsed = Date().timeIntervalSince(start)
                        let minSpin: TimeInterval = 0.9
                        if elapsed < minSpin {
                            try? await Task.sleep(nanoseconds: UInt64((minSpin - elapsed) * 1_000_000_000))
                        }
                        await MainActor.run {
                            syncing = false
                            syncedToastShown = true
                        }
                    }
                } label: {
                    HStack(spacing: 12) {
                        SpinningIcon(name: "arrow.triangle.2.circlepath", isSpinning: syncing)
                        Text("立即同步").foregroundStyle(syncEnabled ? AppTheme.ink : AppTheme.tertiary)
                        Spacer()
                    }
                    .contentShape(Rectangle())  // 整行可点
                }
                .disabled(!syncEnabled)
                .buttonStyle(.plain)
            } header: { Text("iCloud") } footer: {
                Text("开启后,你在任何一台设备上的修改都会同步到其他设备。需登录 iCloud,模拟器看不到效果。")
            }

            // Export
            Section {
                if let url = markdownFileURL {
                    ShareLink(item: url, preview: SharePreview("EON Subscriptions", image: Image(systemName: "doc.text"))) {
                        HStack(spacing: 12) { SettingsIcon(name: "square.and.arrow.up"); Text("分享为 Markdown（适合 AI）").foregroundStyle(AppTheme.ink) }
                    }
                }
                if let url = jsonFileURL {
                    ShareLink(item: url, preview: SharePreview("EON Subscriptions", image: Image(systemName: "curlybraces"))) {
                        HStack(spacing: 12) { SettingsIcon(name: "curlybraces"); Text("分享为 JSON").foregroundStyle(AppTheme.ink) }
                    }
                }
                Button {
                    let text = LLMExporter.markdown(store: store, withPrompt: true)
                    UIPasteboard.general.string = text
                    copyConfirmed = true
                } label: {
                    HStack(spacing: 12) {
                        SettingsIcon(name: "doc.on.clipboard")
                        Text("复制（含 AI 提示词）").foregroundStyle(AppTheme.ink)
                        Spacer()
                    }
                    .contentShape(Rectangle())  // 整行可点
                }
                .buttonStyle(.plain)
            } header: { Text("导出") } footer: {
                Text("数据只发到你选择的 App,EON 不会上传到任何服务器。Markdown 末尾带了一段提示词,粘到 ChatGPT / Claude 就能直接分析你的订阅。")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.visible)
        .navigationTitle("iCloud 与数据")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Generate the export files once when this view appears so ShareLink has stable URLs.
            markdownFileURL = LLMExporter.writeMarkdownTempFile(store: store)
            jsonFileURL     = LLMExporter.writeJSONTempFile(store: store)
        }
        // 两个明确反馈的 toast,分别给"复制"和"同步成功"用。位置在页面最顶,
        // 跨越 List 区域显示。
        .toast($copyConfirmed, text: "已复制到剪贴板")
        .toast($syncedToastShown, text: "已同步到 iCloud")
    }

    private var syncEnabled: Bool { store.iCloudSyncEnabled && iCloudAvailable }
}

#Preview {
    NavigationStack { DataSyncSettingsView() }.environmentObject(SubscriptionStore())
}
