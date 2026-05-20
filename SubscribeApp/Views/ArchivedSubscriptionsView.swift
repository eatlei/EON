import SwiftUI

struct ArchivedSubscriptionsView: View {
    @EnvironmentObject private var store: SubscriptionStore
    @State private var restoring: Subscription?

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
                            restoring = sub
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
                    Text("点一下任意订阅可以查看并恢复。恢复后会重新出现在订阅列表里。")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("归档订阅")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarVisibility(.hidden, for: .tabBar)
        .tint(AppTheme.accent)
        .sheet(item: $restoring) { sub in
            RestoreConfirmView(subscription: sub) {
                store.restore(ids: [sub.id])
            }
            .environmentObject(store)
        }
    }
}

private struct RestoreConfirmView: View {
    @EnvironmentObject private var store: SubscriptionStore
    @Environment(\.dismiss) private var dismiss
    let subscription: Subscription
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    row("名称", subscription.name)
                    row("套餐", subscription.plan.isEmpty ? String(localized: "无") : subscription.plan)
                    row("分类", subscription.displayCategoryTitle)
                    row("价格", store.converter.format(subscription.price, currency: subscription.currency))
                    row("扣费周期", subscription.billingCycle.title)
                    row("开始时间", subscription.nextBillingDate.formatted(.dateTime.year().month().day()))
                    row("状态", subscription.status.title)
                    row("支付方式", subscription.paymentMethod.isEmpty ? String(localized: "无") : subscription.paymentMethod)
                } header: {
                    Text("订阅信息")
                } footer: {
                    Text("确认后该订阅将恢复到订阅列表并重新计入统计。")
                }

                Section {
                    Button {
                        onConfirm()
                        dismiss()
                    } label: {
                        Text("确认恢复")
                            .frame(maxWidth: .infinity)
                            .fontWeight(.semibold)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("恢复订阅")
            .navigationBarTitleDisplayMode(.inline)
            .tint(AppTheme.accent)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private func row(_ label: LocalizedStringKey, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).foregroundStyle(.primary).multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }
}

#Preview {
    NavigationStack { ArchivedSubscriptionsView().environmentObject(SubscriptionStore()) }
}
