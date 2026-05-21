import SwiftUI

struct ArchivedSubscriptionsView: View {
    @EnvironmentObject private var store: SubscriptionStore
    /// 点中的归档订阅。set 之后立刻 sheet 出 SubscriptionEditorView,让用户
    /// 在熟悉的编辑界面里改完保存就重启;editor 检测到原 sub.isArchived==true
    /// 时会把保存按钮接成"重启",在 upsert 之前把 isArchived 翻回 false。
    @State private var editing: Subscription?

    var body: some View {
        List {
            if store.archivedSubscriptions.isEmpty {
                Section {
                    Text("暂无归档订阅")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    ForEach(store.archivedSubscriptions) { sub in
                        Button {
                            editing = sub
                        } label: {
                            HStack(spacing: AppTheme.Space.m) {
                                CategoryGlyph(subscription: sub, size: 38)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(sub.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.ink)
                                    Text("\(sub.plan) · \(sub.displayCategoryTitle) · \(sub.billingCycle.title)")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "arrow.uturn.backward.circle")
                                    .foregroundStyle(AppTheme.accent)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } footer: {
                    Text("点一下会打开订阅卡片,改完保存就把它重新激活到订阅列表里;原数据(图标、套餐、价格、统计开关等)都保留,可顺便调整。")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("归档订阅")
        .navigationBarTitleDisplayMode(.inline)
        .tint(AppTheme.accent)
        .sheet(item: $editing) { sub in
            SubscriptionEditorView(subscription: sub)
                .environmentObject(store)
        }
    }
}

#Preview {
    NavigationStack { ArchivedSubscriptionsView().environmentObject(SubscriptionStore()) }
}
