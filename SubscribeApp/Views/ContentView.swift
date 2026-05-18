import SwiftUI

private enum AppTab: String, CaseIterable, Identifiable {
    case dashboard
    case subscriptions
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: "总览"
        case .subscriptions: "订阅"
        case .settings: "设置"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: "chart.pie.fill"
        case .subscriptions: "rectangle.stack.fill"
        case .settings: "gearshape.fill"
        }
    }
}

struct ContentView: View {
    @State private var selectedTab: AppTab = .dashboard
    @State private var showingEditor = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .dashboard:
                    DashboardView()
                case .subscriptions:
                    SubscriptionsView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    ForEach(AppTab.allCases) { tab in
                        Button {
                            withAnimation(AppDesign.spring) {
                                selectedTab = tab
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: tab.systemImage)
                                    .font(.system(size: 18, weight: .bold))
                                Text(tab.title)
                                    .font(.caption2.weight(.bold))
                            }
                            .foregroundStyle(selectedTab == tab ? .white : AppDesign.muted)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(selectedTab == tab ? AppDesign.ink : .clear, in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(5)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppDesign.line.opacity(0.72), lineWidth: 1)
                )
                .shadow(color: AppDesign.ink.opacity(0.1), radius: 18, y: 8)

                Button {
                    showingEditor = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title3.weight(.black))
                        .foregroundStyle(.white)
                        .frame(width: 62, height: 62)
                        .background(AppDesign.ink, in: RoundedRectangle(cornerRadius: 8))
                        .shadow(color: AppDesign.ink.opacity(0.24), radius: 18, y: 10)
                }
                .accessibilityLabel("新增订阅")
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .sheet(isPresented: $showingEditor) {
            SubscriptionEditorView(subscription: nil)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(SubscriptionStore())
}
