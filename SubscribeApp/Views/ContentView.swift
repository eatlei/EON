import SwiftUI

private enum AppTab: String, CaseIterable, Identifiable {
    case dashboard, subscriptions, settings
    var id: String { rawValue }
}

struct ContentView: View {
    @State private var tab: AppTab = .dashboard
    @State private var showEditor = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
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
            }
            .tint(AppTheme.accent)

            Button {
                showEditor = true
            } label: {
                Image(systemName: "plus")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .glassEffect(.regular.tint(AppTheme.accent).interactive(), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, AppTheme.Space.l)
            .padding(.bottom, 22)
            .accessibilityLabel("新增订阅")
        }
        .sheet(isPresented: $showEditor) { SubscriptionEditorView(subscription: nil) }
    }
}

#Preview {
    ContentView().environmentObject(SubscriptionStore())
}
