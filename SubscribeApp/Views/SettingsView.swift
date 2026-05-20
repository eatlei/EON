import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var store: SubscriptionStore
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink { AppearanceSettingsView() } label: {
                        HStack(spacing: 12) {
                            SettingsIcon(name: "paintpalette")
                            Text("外观")
                        }
                    }
                    NavigationLink { CurrencySettingsView() } label: {
                        HStack(spacing: 12) {
                            SettingsIcon(name: "dollarsign.circle")
                            Text("货币")
                            Spacer()
                            Text(store.baseCurrency.rawValue).foregroundStyle(.secondary)
                        }
                    }
                    NavigationLink { NotificationSettingsView() } label: {
                        HStack(spacing: 12) {
                            SettingsIcon(name: "bell")
                            Text("通知")
                        }
                    }
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            SettingsIcon(name: "character.book.closed")
                            Text("语言")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                Section {
                    NavigationLink { PaymentMethodsView() } label: {
                        HStack(spacing: 12) {
                            SettingsIcon(name: "creditcard")
                            Text("支付方式")
                        }
                    }
                    NavigationLink { ArchivedSubscriptionsView() } label: {
                        HStack(spacing: 12) {
                            SettingsIcon(name: "archivebox")
                            Text("归档订阅")
                        }
                    }
                    NavigationLink { DataSyncSettingsView() } label: {
                        HStack(spacing: 12) {
                            SettingsIcon(name: "externaldrive")
                            Text("数据")
                        }
                    }
                }

                Section {
                    NavigationLink { AboutView() } label: {
                        HStack(spacing: 12) {
                            SettingsIcon(name: "info.circle")
                            Text("关于")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.visible)
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    SettingsView().environmentObject(SubscriptionStore())
}
