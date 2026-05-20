import SwiftUI

struct AppearanceSettingsView: View {
    @EnvironmentObject private var store: SubscriptionStore

    var body: some View {
        List {
            Section {
                Picker(selection: $store.appearance) {
                    ForEach(AppAppearance.allCases) { Text($0.title).tag($0) }
                } label: {
                    Label("外观", systemImage: "circle.lefthalf.filled")
                }
                .pickerStyle(.menu)

                DisclosureGroup {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: AppTheme.Space.m)], spacing: AppTheme.Space.m) {
                        ForEach(AccentTheme.allCases) { theme in
                            Button {
                                store.accentTheme = theme
                            } label: {
                                Circle()
                                    .fill(theme.color)
                                    .frame(width: 34, height: 34)
                                    .overlay(
                                        Image(systemName: "checkmark")
                                            .font(.caption.weight(.black))
                                            .foregroundStyle(.white)
                                            .opacity(store.accentTheme == theme ? 1 : 0)
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary.opacity(store.accentTheme == theme ? 0.85 : 0), lineWidth: 2)
                                            .padding(-3)
                                    )
                                    .accessibilityLabel(Text(theme.title))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, AppTheme.Space.s)
                } label: {
                    HStack {
                        Label("主题色", systemImage: "paintpalette")
                            .foregroundStyle(.primary)
                        Spacer()
                        Circle()
                            .fill(store.accentTheme.color)
                            .frame(width: 18, height: 18)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.visible)
        .navigationTitle("外观")
        .navigationBarTitleDisplayMode(.inline)
        .labelStyle(.settings)
    }
}

#Preview {
    NavigationStack { AppearanceSettingsView() }
        .environmentObject(SubscriptionStore())
}
