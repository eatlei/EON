import SwiftUI
import UIKit

struct DataSyncSettingsView: View {
    @EnvironmentObject private var store: SubscriptionStore
    @State private var syncing = false
    @State private var copyConfirmed = false
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
                    Task {
                        await store.performManualICloudSync()
                        await MainActor.run { syncing = false }
                    }
                } label: {
                    HStack(spacing: 12) {
                        SettingsIcon(name: "arrow.triangle.2.circlepath")
                        Text("立即同步").foregroundStyle(syncEnabled ? AppTheme.ink : AppTheme.tertiary)
                        Spacer()
                        if syncing { ProgressView() }
                    }
                }
                .disabled(!syncEnabled)
                .buttonStyle(.plain)
            } header: { Text("iCloud") } footer: {
                Text("开启后自动同步：本机更改即时上传，其他设备的更改自动合并。真机需登录 iCloud，模拟器/未登录设备此项不生效。")
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
                        if copyConfirmed { Image(systemName: "checkmark").foregroundStyle(.secondary) }
                    }
                }
                .buttonStyle(.plain)
            } header: { Text("导出") } footer: {
                Text("数据仅在你选择的目标 App 中传输，应用不会上传到任何服务器。Markdown 含一段建议提示词，复制后直接粘到 AI 助手即可分析。")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.visible)
        .navigationTitle("数据")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Generate the export files once when this view appears so ShareLink has stable URLs.
            markdownFileURL = LLMExporter.writeMarkdownTempFile(store: store)
            jsonFileURL     = LLMExporter.writeJSONTempFile(store: store)
        }
        .onChange(of: copyConfirmed) { _, v in
            if v {
                Task { try? await Task.sleep(nanoseconds: 1_500_000_000); copyConfirmed = false }
            }
        }
    }

    private var syncEnabled: Bool { store.iCloudSyncEnabled && iCloudAvailable }
}

#Preview {
    NavigationStack { DataSyncSettingsView() }.environmentObject(SubscriptionStore())
}
