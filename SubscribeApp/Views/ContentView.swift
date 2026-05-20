import SwiftUI

private enum AppTab: Hashable {
    case dashboard, subscriptions, settings, add
}

struct ContentView: View {
    @EnvironmentObject private var store: SubscriptionStore
    @State private var tab: AppTab = .dashboard
    @State private var lastContentTab: AppTab = .dashboard
    @State private var showEditor = false
    /// 摇一摇彩蛋:摇手机时随机抽一个活跃订阅 spotlight 出来。空列表 / 已开
    /// 的话不重复弹。挂在最顶层是为了任何 tab 都能触发。
    @State private var spotlightSubscription: Subscription?

    var body: some View {
        TabView(selection: $tab) {
            Tab("总览", systemImage: "chart.pie", value: AppTab.dashboard) {
                DashboardView()
            }
            Tab("订阅", systemImage: "rectangle.stack", value: AppTab.subscriptions) {
                SubscriptionsView()
            }
            Tab("设置", systemImage: "gearshape", value: AppTab.settings) {
                SettingsView()
            }
            Tab("新增", systemImage: "plus", value: AppTab.add, role: .search) {
                Color.clear
            }
        }
        .tint(store.accentTheme.color)
        .onChange(of: tab) { _, newValue in
            if newValue == .add {
                showEditor = true
                tab = lastContentTab
            } else {
                lastContentTab = newValue
            }
        }
        .sheet(isPresented: $showEditor) {
            SubscriptionEditorView(subscription: nil)
        }
        // 摇一摇 spotlight。已经在弹层里 / 没订阅 / 当前在编辑器里都不重复触发。
        .onShake {
            guard spotlightSubscription == nil, !showEditor else { return }
            if let picked = store.activeSubscriptions.randomElement() {
                spotlightSubscription = picked
            }
        }
        .sheet(item: $spotlightSubscription) { sub in
            RandomSpotlightSheet(initial: sub)
                .environmentObject(store)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}

#Preview {
    ContentView().environmentObject(SubscriptionStore())
}
