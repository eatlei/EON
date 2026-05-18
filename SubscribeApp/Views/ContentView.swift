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
        case .dashboard: "chart.pie"; case .subscriptions: "rectangle.stack"; case .settings: "gearshape"
        }
    }
}

struct ContentView: View {
    @State private var tab: AppTab = .dashboard
    @State private var showEditor = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch tab {
                case .dashboard: DashboardView()
                case .subscriptions: SubscriptionsView()
                case .settings: SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: AppTheme.Space.m) {
                HStack(spacing: 2) {
                    ForEach(AppTab.allCases) { t in
                        Button {
                            withAnimation(AppTheme.spring) { tab = t }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: t.icon).font(.system(size: 17, weight: .semibold))
                                Text(t.title).font(.caption2.weight(.semibold))
                            }
                            .foregroundStyle(tab == t ? AppTheme.surface : AppTheme.secondary)
                            .frame(maxWidth: .infinity).frame(height: 52)
                            .background(tab == t ? AppTheme.ink : .clear,
                                        in: RoundedRectangle(cornerRadius: AppTheme.radiusSmall))
                        }.buttonStyle(.plain)
                    }
                }
                .padding(4)
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.radius))
                .overlay(RoundedRectangle(cornerRadius: AppTheme.radius).stroke(AppTheme.hairline, lineWidth: 0.5))

                Button { showEditor = true } label: {
                    Image(systemName: "plus").font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.surface)
                        .frame(width: 60, height: 60)
                        .background(AppTheme.ink, in: RoundedRectangle(cornerRadius: AppTheme.radius))
                }
                .accessibilityLabel("新增订阅")
            }
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
