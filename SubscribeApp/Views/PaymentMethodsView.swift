import SwiftUI

struct PaymentMethodsView: View {
    @EnvironmentObject private var store: SubscriptionStore
    @State private var showAdd = false
    @State private var newName = ""

    var body: some View {
        List {
            Section {
                ForEach(store.paymentMethods, id: \.self) { Text($0) }
                    .onDelete { store.removePaymentMethods(at: $0) }
            } footer: {
                Text("添加订阅时可以从这个列表里选支付方式。删除不会影响已经填好的订阅。")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("支付方式")
        .navigationBarTitleDisplayMode(.inline)
        .tint(AppTheme.accent)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { EditButton() }
            ToolbarItem(placement: .topBarTrailing) {
                Button { newName = ""; showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .alert("添加支付方式", isPresented: $showAdd) {
            TextField("名称，如 花呗", text: $newName)
            Button("取消", role: .cancel) { }
            Button("添加") { store.addPaymentMethod(newName) }
        } message: {
            Text("添加后可在新增/编辑订阅时选择。")
        }
    }
}

#Preview {
    NavigationStack { PaymentMethodsView().environmentObject(SubscriptionStore()) }
}
