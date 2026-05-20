import SwiftUI

struct TipSheet: View {
    @ObservedObject var tips: TipStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if !tips.loaded {
                        HStack { Text("加载中…"); Spacer(); ProgressView() }
                    } else if tips.products.isEmpty {
                        Text("打赏暂不可用").foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(tips.products.enumerated()), id: \.element.id) { idx, product in
                            Button {
                                Task { await tips.purchase(product) }
                            } label: {
                                HStack {
                                    Label(product.displayName, systemImage: tipIcon(idx))
                                    Spacer()
                                    if tips.purchasingID == product.id {
                                        ProgressView()
                                    } else {
                                        Text(product.displayPrice)
                                            .foregroundStyle(.secondary)
                                            .monospacedDigit()
                                    }
                                }
                            }
                            .disabled(tips.purchasingID != nil)
                        }
                    }
                } header: {
                    Text("选择金额")
                } footer: {
                    Text("打赏完全自愿，用于支持后续开发，不解锁任何功能。")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("支持开发者")
            .navigationBarTitleDisplayMode(.inline)
            .tint(AppTheme.accent)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .alert("感谢支持！", isPresented: $tips.thanksShown) {
                Button("好的", role: .cancel) { dismiss() }
            } message: {
                Text("你的支持是持续更新的动力。")
            }
            .task { await tips.load() }
        }
    }

    private func tipIcon(_ index: Int) -> String {
        ["cup.and.saucer", "fork.knife", "gift"][safe: index] ?? "heart"
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
