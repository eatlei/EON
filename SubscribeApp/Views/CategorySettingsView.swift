import SwiftUI

/// 分类管理:列出 EON 内置的 8 个分类,允许用户给每个起一个自定义名字。
/// 持久化只改"显示名"(SubscriptionCategory.nameOverrides 字典),enum 的
/// rawValue / color / 持久化键完全不动 —— 已经存进数据库的订阅不会受影响。
struct CategorySettingsView: View {
    @EnvironmentObject private var store: SubscriptionStore
    @State private var editing: SubscriptionCategory?
    @State private var draftName: String = ""

    var body: some View {
        List {
            Section {
                ForEach(SubscriptionCategory.allCases) { cat in
                    Button {
                        editing = cat
                        draftName = store.categoryNameOverrides[cat.rawValue] ?? ""
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(cat.color)
                                .frame(width: 14, height: 14)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(cat.title)
                                    .foregroundStyle(.primary)
                                if cat.title != cat.defaultTitle {
                                    Text(cat.defaultTitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if cat.title != cat.defaultTitle {
                                Button {
                                    store.categoryNameOverrides[cat.rawValue] = nil
                                } label: {
                                    Image(systemName: "arrow.uturn.backward.circle")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } footer: {
                Text("点一下任意分类可以改名。颜色和原名固定不变,改名只影响显示。")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.visible)
        .navigationTitle("分类")
        .navigationBarTitleDisplayMode(.inline)
        .alert("重命名", isPresented: Binding(
            get: { editing != nil },
            set: { if !$0 { editing = nil } }
        )) {
            TextField("如 游戏 / 健身 / 杂项", text: $draftName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
            Button("保存") {
                if let cat = editing {
                    let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
                    var overrides = store.categoryNameOverrides
                    if trimmed.isEmpty || trimmed == cat.defaultTitle {
                        overrides[cat.rawValue] = nil
                    } else {
                        overrides[cat.rawValue] = trimmed
                    }
                    store.categoryNameOverrides = overrides
                }
                editing = nil
            }
            Button("取消", role: .cancel) { editing = nil }
        } message: {
            if let cat = editing {
                Text("默认: \(cat.defaultTitle)")
            }
        }
    }
}

#Preview {
    NavigationStack { CategorySettingsView() }
        .environmentObject(SubscriptionStore())
}
