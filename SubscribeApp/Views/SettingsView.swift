import SwiftUI
import UIKit

/// 设置页里每个二级入口对应的路由。用值驱动的 NavigationStack(path:),好处是
/// 能从 path.isEmpty 精确知道"现在是不是在某个二级页",从而在 stack 根上一次性
/// 控制底部 tab 的显隐 —— 而不是在每个子页各自 .toolbar(.hidden, for: .tabBar)。
/// 后者在返回时会让 tab bar 闪一下(系统在 pop 动画里重新算可见性,慢半拍),
/// 根级绑定则跟 pop 同步,不再闪。
private enum SettingsRoute: Hashable {
    case appearance, easterEgg, currency, category, payment, notification, archived, dataSync, about
}

/// 整 App 的设置入口。条目按"用途接近"原则分了 4 段:
/// - 偏好:外观(含语言/主题/卡片)
/// - 订阅:跟订阅本体最相关的设置
/// - 数据:iCloud 同步与导出
/// - 关于:App 信息 / 评分 / 反馈
struct SettingsView: View {
    @EnvironmentObject private var store: SubscriptionStore
    @State private var path: [SettingsRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                // MARK: 偏好(外观 / 语言 / 主题色 / 卡片样式都收到这一层)
                Section {
                    NavigationLink(value: SettingsRoute.appearance) {
                        HStack(spacing: 12) {
                            SettingsIcon(name: "paintpalette")
                            Text("外观与语言")
                        }
                    }
                    NavigationLink(value: SettingsRoute.easterEgg) {
                        HStack(spacing: 12) {
                            SettingsIcon(name: "sparkles")
                            Text("彩蛋")
                        }
                    }
                } header: {
                    Text("偏好")
                }

                // MARK: 订阅相关(高频改动放在显眼位置)
                Section {
                    NavigationLink(value: SettingsRoute.currency) {
                        HStack(spacing: 12) {
                            SettingsIcon(name: "dollarsign.circle")
                            Text("货币")
                            Spacer()
                            Text(store.baseCurrency.rawValue)
                                .fontWeight(.semibold)
                                .foregroundStyle(AppTheme.accent)
                        }
                    }
                    NavigationLink(value: SettingsRoute.category) {
                        HStack(spacing: 12) {
                            SettingsIcon(name: "tag")
                            Text("分类")
                        }
                    }
                    NavigationLink(value: SettingsRoute.payment) {
                        HStack(spacing: 12) {
                            SettingsIcon(name: "creditcard")
                            Text("支付方式")
                        }
                    }
                    NavigationLink(value: SettingsRoute.notification) {
                        HStack(spacing: 12) {
                            SettingsIcon(name: "bell")
                            Text("通知")
                        }
                    }
                    NavigationLink(value: SettingsRoute.archived) {
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
                    NavigationLink(value: SettingsRoute.dataSync) {
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
                    NavigationLink(value: SettingsRoute.about) {
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
            .navigationDestination(for: SettingsRoute.self) { route in
                switch route {
                case .appearance:   AppearanceSettingsView()
                case .easterEgg:    EasterEggSettingsView()
                case .currency:     CurrencySettingsView()
                case .category:     CategorySettingsView()
                case .payment:      PaymentMethodsView()
                case .notification: NotificationSettingsView()
                case .archived:     ArchivedSubscriptionsView()
                case .dataSync:     DataSyncSettingsView()
                case .about:        AboutView()
                }
            }
            // 根级一次性控制 tab bar:在任何二级页(path 非空)都隐藏,回到根就显示。
            // 跟 pop 动画同步,消除返回时 tab bar 闪一下的问题。
            .toolbar(path.isEmpty ? .visible : .hidden, for: .tabBar)
        }
    }
}

#Preview {
    SettingsView().environmentObject(SubscriptionStore())
}
