import SwiftUI

/// 支付方式管理。整页就一个 List:
/// - 上面 Section 列已有方式,左滑 / EditButton 删除。
/// - 下面 Section 是一个"添加新方式"的内联表单(输入框 + 添加按钮),
///   不再走顶部 toolbar 弹 alert,跟列表本体在同一上下文,操作链路更短。
struct PaymentMethodsView: View {
    @EnvironmentObject private var store: SubscriptionStore
    @State private var newName = ""
    @FocusState private var newFieldFocused: Bool

    private var canAdd: Bool {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && !store.paymentMethods.contains(trimmed)
    }

    var body: some View {
        List {
            // MARK: 已有支付方式
            Section {
                ForEach(store.paymentMethods, id: \.self) { method in
                    HStack(spacing: 12) {
                        Image(systemName: "creditcard")
                            .font(.subheadline.weight(.regular))
                            .foregroundStyle(.secondary)
                            .frame(width: 22, alignment: .center)
                        Text(method)
                    }
                }
                .onDelete { store.removePaymentMethods(at: $0) }
                .onMove { from, to in
                    store.paymentMethods.move(fromOffsets: from, toOffset: to)
                }
            } header: {
                Text("已添加")
            } footer: {
                Text("添加订阅时可以从这里挑支付方式;左滑或点上方编辑可以删除/排序。删除不会影响已经填好的订阅。")
            }

            // MARK: 内联添加
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(canAdd ? AppTheme.accent : AppTheme.tertiary)
                        .font(.title3)
                    TextField(String(localized: "名称,如 花呗 / 招行信用卡"), text: $newName)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .focused($newFieldFocused)
                        .submitLabel(.done)
                        .onSubmit { commitAdd() }
                    if !newName.isEmpty {
                        Button {
                            commitAdd()
                        } label: {
                            Text("添加")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(canAdd ? .white : .white.opacity(0.5))
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(
                                    (canAdd ? AppTheme.accent : AppTheme.tertiary),
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(!canAdd)
                    }
                }
            } header: {
                Text("添加新方式")
            } footer: {
                if !newName.isEmpty && !canAdd {
                    Text("已经有同名的支付方式啦。")
                        .foregroundStyle(.orange)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("支付方式")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .tint(AppTheme.accent)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { EditButton() }
        }
    }

    private func commitAdd() {
        guard canAdd else { return }
        store.addPaymentMethod(newName)
        newName = ""
        // 添加后输入框失焦,免得键盘黏住
        newFieldFocused = false
    }
}

#Preview {
    NavigationStack { PaymentMethodsView().environmentObject(SubscriptionStore()) }
}
