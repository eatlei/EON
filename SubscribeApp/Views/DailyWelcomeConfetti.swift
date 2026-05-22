import SwiftUI

/// 每天首次打开 App 时,在 Dashboard 上洒一阵迷你订阅图标 —— 像 Apple Watch
/// 关圈圈的那种轻量奖励。低调、1.5 秒内自然结束、不打扰操作。
///
/// 数据驱动:粒子用 store 里月费最高的前 6 个订阅做素材;不够 6 个就用现有
/// 的。一天最多触发一次,通过 UserDefaults 的 `lastDailyConfettiDate` 记录。

/// 单个掉落粒子。重力把它从屏幕上方拉到下方,带轻微旋转 + 淡出。
private struct ConfettiParticle: Identifiable {
    let id = UUID()
    let subscription: Subscription
    /// 起始 x(占画布宽度的比例,0..1)。
    let startXRatio: CGFloat
    /// 终点 x 的偏移(pt),让粒子稍微飘到一侧而不是直线下落。
    let drift: CGFloat
    /// 起飞延迟,让 6 个粒子错开下落,不像齐发。
    let delay: TimeInterval
    /// 总自转量。
    let spin: Double
    /// 整体缩放(让大小有一点变化)。
    let scale: CGFloat
}

/// 玻璃球质感的订阅图标:圆形裁切 + 高光 + 折射阴影,仿 Liquid Glass 效果。
private struct GlassBallView: View {
    let subscription: Subscription
    let size: CGFloat

    var body: some View {
        ZStack {
            // 图标本体:圆形裁切,比球体略小留出玻璃边距。
            CategoryGlyph(subscription: subscription, size: size * 0.86)
                .clipShape(Circle())

            // 顶部高光:模拟球面折射的主镜面反射区域(左上方亮斑)。
            RadialGradient(
                colors: [
                    .white.opacity(0.78),
                    .white.opacity(0.30),
                    .clear
                ],
                center: UnitPoint(x: 0.3, y: 0.22),
                startRadius: 0,
                endRadius: size * 0.36
            )
            .clipShape(Circle())

            // 底部折射暗角:给球体加深度感。
            RadialGradient(
                colors: [.clear, .black.opacity(0.22)],
                center: UnitPoint(x: 0.68, y: 0.78),
                startRadius: size * 0.18,
                endRadius: size * 0.52
            )
            .clipShape(Circle())

            // 玻璃边缘:顶亮底暗的渐变描边模拟球面边缘折射。
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.85),
                            .white.opacity(0.25),
                            .white.opacity(0.05)
                        ],
                        startPoint: UnitPoint(x: 0.2, y: 0.0),
                        endPoint: UnitPoint(x: 0.9, y: 1.0)
                    ),
                    lineWidth: 1.2
                )
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.28), radius: 10, x: 0, y: 6)
    }
}

private struct ConfettiParticleView: View {
    let particle: ConfettiParticle
    let containerSize: CGSize
    @State private var progress: CGFloat = 0

    private let duration: TimeInterval = 2.0
    private let ballSize: CGFloat = 42

    var body: some View {
        let startX = particle.startXRatio * containerSize.width
        let endX = startX + particle.drift
        let startY: CGFloat = -60
        let endY = containerSize.height * 0.55  // 落到屏幕中部就开始淡出,不要砸到底部 TabBar
        let x = startX + (endX - startX) * progress
        // 用 easeIn 模拟"重力加速下落"
        let yFactor = progress * progress
        let y = startY + (endY - startY) * yFactor

        let opacity: Double = {
            if progress < 0.05 { return 0 }
            if progress > 0.75 { return max(0, Double(1 - (progress - 0.75) / 0.25)) }
            return 1
        }()

        return GlassBallView(subscription: particle.subscription, size: ballSize)
            .scaleEffect(particle.scale)
            // 玻璃球滚动感:旋转量比原先小一些,不要转得太快
            .rotationEffect(.degrees(particle.spin * 0.4 * Double(progress)))
            .opacity(opacity)
            .position(x: x, y: y)
            .onAppear {
                Task { @MainActor in
                    if particle.delay > 0 {
                        try? await Task.sleep(nanoseconds: UInt64(particle.delay * 1_000_000_000))
                    }
                    withAnimation(.easeIn(duration: duration)) {
                        progress = 1
                    }
                }
            }
    }
}

/// 全屏粒子层。挂在 DashboardView 的 .overlay 里,不拦截手势。
/// 通过外层传入的 `active: Bool` 决定要不要显示;隔一天才会再次激活。
struct DailyWelcomeConfetti: View {
    let subscriptions: [Subscription]

    /// 算出来的本次掉落粒子列表;一旦 view 出现就锁死,后续不会再随机。
    @State private var particles: [ConfettiParticle] = []

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { p in
                    ConfettiParticleView(particle: p, containerSize: geo.size)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .allowsHitTesting(false)
            .onAppear {
                if particles.isEmpty { particles = makeParticles() }
            }
        }
    }

    /// 6 个粒子,起始 x 均匀分布 + 抖动,延迟从 0 起递增,终止 x 飘到两侧。
    private func makeParticles() -> [ConfettiParticle] {
        let count = min(6, subscriptions.count)
        guard count > 0 else { return [] }
        let used = Array(subscriptions.prefix(count))
        return used.enumerated().map { i, sub in
            let ratio = (CGFloat(i) + 0.5) / CGFloat(count)
            let ratioJitter = ratio + CGFloat.random(in: -0.05...0.05)
            return ConfettiParticle(
                subscription: sub,
                startXRatio: max(0.05, min(0.95, ratioJitter)),
                drift: CGFloat.random(in: -50...50),
                delay: Double(i) * 0.12 + Double.random(in: 0...0.08),
                spin: Double.random(in: -360...360),
                scale: CGFloat.random(in: 0.85...1.15)
            )
        }
    }
}

// MARK: - "今天有没有放过" 持久化

enum DailyWelcomeTracker {
    private static let key = "eon.daily-welcome-date"

    /// 今天是不是已经放过彩带了。是 = 不再放。
    static func hasShownToday() -> Bool {
        guard let last = UserDefaults.standard.object(forKey: key) as? Date else { return false }
        return Calendar.current.isDateInToday(last)
    }

    /// 记一次"今天放过了",下次回到这页就不会再触发。
    static func markShownToday() {
        UserDefaults.standard.set(Date(), forKey: key)
    }
}
