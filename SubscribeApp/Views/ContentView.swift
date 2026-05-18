import SwiftUI

private enum AppTab: String, CaseIterable, Identifiable {
    case dashboard, subscriptions, settings
    var id: String { rawValue }
    var title: String {
        switch self {
        case .dashboard: "总览"; case .subscriptions: "订阅"; case .settings: "设置"
        }
    }
    var icon: String {
        switch self {
        case .dashboard: "chart.pie.fill"
        case .subscriptions: "rectangle.stack.fill"
        case .settings: "gearshape.fill"
        }
    }
}

struct ContentView: View {
    @State private var tab: AppTab = .dashboard
    @State private var showEditor = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $tab) {
                Tab(AppTab.dashboard.title, systemImage: AppTab.dashboard.icon, value: AppTab.dashboard) {
                    DashboardView()
                }
                Tab(AppTab.subscriptions.title, systemImage: AppTab.subscriptions.icon, value: AppTab.subscriptions) {
                    SubscriptionsView()
                }
                Tab(AppTab.settings.title, systemImage: AppTab.settings.icon, value: AppTab.settings) {
                    SettingsView()
                }
            }
            .tint(AppTheme.accent)

            Button {
                showEditor = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 58, height: 58)
                    .glassEffect(.regular.interactive(), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, AppTheme.Space.l)
            .padding(.bottom, 20)
            .accessibilityLabel("新增订阅")
        }
        .sheet(isPresented: $showEditor) { SubscriptionEditorView(subscription: nil) }
    }
}

#Preview {
    ContentView().environmentObject(SubscriptionStore())
}
