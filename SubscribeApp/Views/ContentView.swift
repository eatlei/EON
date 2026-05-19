import SwiftUI

private enum AppTab: Hashable {
    case dashboard, subscriptions, settings, add
}

struct ContentView: View {
    @EnvironmentObject private var store: SubscriptionStore
    @State private var tab: AppTab = .dashboard
    @State private var lastContentTab: AppTab = .dashboard
    @State private var showEditor = false

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
    }
}

#Preview {
    ContentView().environmentObject(SubscriptionStore())
}
