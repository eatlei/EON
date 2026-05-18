import SwiftUI

enum AppDesign {
    static let background = Color(red: 0.965, green: 0.968, blue: 0.958)
    static let surface = Color(red: 0.996, green: 0.996, blue: 0.988)
    static let ink = Color(red: 0.095, green: 0.105, blue: 0.115)
    static let muted = Color(red: 0.44, green: 0.47, blue: 0.49)
    static let line = Color(red: 0.84, green: 0.85, blue: 0.82)
    static let teal = Color(red: 0.10, green: 0.48, blue: 0.46)
    static let amber = Color(red: 0.76, green: 0.45, blue: 0.18)
    static let rose = Color(red: 0.72, green: 0.26, blue: 0.32)

    static let spring = Animation.spring(response: 0.58, dampingFraction: 0.82)
}

struct AppScreen<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            content
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 118)
        }
        .background(
            LinearGradient(
                colors: [
                    AppDesign.background,
                    Color(red: 0.93, green: 0.95, blue: 0.93),
                    Color(red: 0.97, green: 0.955, blue: 0.925)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
    }
}

struct InsightPanel<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder var content: Content

    init(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppDesign.ink)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AppDesign.muted)
                }
            }

            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(AppDesign.surface.opacity(0.92))
                .stroke(AppDesign.line.opacity(0.72), lineWidth: 1)
        )
        .shadow(color: AppDesign.ink.opacity(0.05), radius: 22, y: 12)
    }
}

struct RevealModifier: ViewModifier {
    let index: Int
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
            .scaleEffect(appeared ? 1 : 0.985)
            .animation(AppDesign.spring.delay(Double(index) * 0.055), value: appeared)
            .onAppear {
                appeared = true
            }
    }
}

extension View {
    func reveal(_ index: Int) -> some View {
        modifier(RevealModifier(index: index))
    }
}

struct CapsuleProgress: View {
    let value: Double
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppDesign.line.opacity(0.5))

                Capsule()
                    .fill(tint)
                    .frame(width: max(8, proxy.size.width * min(max(value, 0), 1)))
            }
        }
        .frame(height: 8)
    }
}
