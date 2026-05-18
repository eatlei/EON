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
        ZStack(alignment: .bottom) {
            ZStack {
                DashboardView()
                    .opacity(tab == .dashboard ? 1 : 0)
                    .allowsHitTesting(tab == .dashboard)
                SubscriptionsView()
                    .opacity(tab == .subscriptions ? 1 : 0)
                    .allowsHitTesting(tab == .subscriptions)
                SettingsView()
                    .opacity(tab == .settings ? 1 : 0)
                    .allowsHitTesting(tab == .settings)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 0) {
                ForEach(AppTab.allCases) { t in
                    Button { tab = t } label: {
                        VStack(spacing: 3) {
                            Image(systemName: t.icon).font(.system(size: 17, weight: .semibold))
                            Text(t.title).font(.caption2.weight(.semibold))
                        }
                        .foregroundStyle(tab == t ? AppTheme.accent : AppTheme.secondary)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                Rectangle()
                    .fill(AppTheme.hairline)
                    .frame(width: 1, height: 26)
                Button { showEditor = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppTheme.accent)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("新增订阅")
            }
            .frame(height: 58)
            .background(AppTheme.surface, in: Capsule())
            .overlay(Capsule().stroke(AppTheme.hairline, lineWidth: 1))
            .padding(.horizontal, AppTheme.Space.l)
            .padding(.bottom, AppTheme.Space.s)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .sheet(isPresented: $showEditor) { SubscriptionEditorView(subscription: nil) }
    }
}

#Preview {
    ContentView().environmentObject(SubscriptionStore())
}
