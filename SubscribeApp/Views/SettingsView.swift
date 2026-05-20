import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: SubscriptionStore

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink { AppearanceSettingsView() } label: {
                        Label("外观", systemImage: "paintpalette")
                    }
                    NavigationLink { CurrencySettingsView() } label: {
                        HStack {
                            Label("货币", systemImage: "dollarsign.circle")
                            Spacer()
                            Text(store.baseCurrency.rawValue).foregroundStyle(.secondary)
                        }
                    }
                    NavigationLink { NotificationSettingsView() } label: {
                        Label("通知", systemImage: "bell")
                    }
                }

                Section {
                    NavigationLink { PaymentMethodsView() } label: {
                        Label("支付方式", systemImage: "creditcard")
                    }
                    NavigationLink { ArchivedSubscriptionsView() } label: {
                        Label("归档订阅", systemImage: "archivebox")
                    }
                    Toggle(isOn: $store.iCloudSyncEnabled) {
                        Label("通过 iCloud 同步订阅", systemImage: "icloud")
                    }
                } footer: {
                    Text("开启后自动同步：本机更改即时上传，其他设备的更改自动合并。真机需 Apple ID 与应用 iCloud 权限。")
                }

                Section {
                    NavigationLink { AboutView() } label: {
                        Label("关于", systemImage: "info.circle")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.visible)
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .labelStyle(.settings)
        }
    }
}

#Preview {
    SettingsView().environmentObject(SubscriptionStore())
}
