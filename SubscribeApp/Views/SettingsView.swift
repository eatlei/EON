import SwiftUI
import UIKit

/// 整 App 的设置入口。条目按"用途接近"原则分了 4 段:
/// - 偏好:外观(含语言/主题/卡片)
/// - 订阅:跟订阅本体最相关的设置
/// - 数据:iCloud 同步与导出
/// - 关于:App 信息 / 评分 / 反馈
struct SettingsView: View {
    @EnvironmentObject private var store: SubscriptionStore

    var body: some View {
        NavigationStack {
            List {
                // MARK: 偏好(外观 / 语言 / 主题色 / 卡片样式都收到这一层)
                Section {
                    NavigationLink { AppearanceSettingsView() } label: {
                        HStack(spacing: 12) {
                            SettingsIcon(name: "paintpalette")
                            Text("外观与语言")
                        }
                    }
                } header: {
                    Text("偏好")
                }

                // MARK: 订阅相关(高频改动放在显眼位置)
                Section {
                    NavigationLink { CurrencySettingsView() } label: {
                        HStack(spacing: 12) {
                            SettingsIcon(name: "dollarsign.circle")
                            Text("货币")
                            Spacer()
                            Text(store.baseCurrency.rawValue).foregroundStyle(.secondary)
                        }
                    }
                    NavigationLink { CategorySettingsView() } label: {
                        HStack(spacing: 12) {
                            SettingsIcon(name: "tag")
                            Text("分类")
                        }
                    }
                    NavigationLink { PaymentMethodsView() } label: {
                        HStack(spacing: 12) {
                            SettingsIcon(name: "creditcard")
                            Text("支付方式")
                        }
                    }
                    NavigationLink { NotificationSettingsView() } label: {
                        HStack(spacing: 12) {
                            SettingsIcon(name: "bell")
                            Text("通知")
                        }
                    }
                    NavigationLink { ArchivedSubscriptionsView() } label: {
                        HStack(spacing: 12) {
                            SettingsIcon(name: "archivebox")
                            Text("归档订阅")
                        }
                    }
                } header: {
                    Text("订阅")
                }

                // MARK: 数据与同步
                Section {
                    NavigationLink { DataSyncSettingsView() } label: {
                        HStack(spacing: 12) {
                            SettingsIcon(name: "externaldrive")
                            Text("iCloud 与数据")
                        }
                    }
                } header: {
                    Text("数据")
                }

                // MARK: 关于
                Section {
                    NavigationLink { AboutView() } label: {
                        HStack(spacing: 12) {
                            SettingsIcon(name: "info.circle")
                            Text("关于")
                        }
                    }
                } header: {
                    Text("关于")
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
