import SwiftUI

// MARK: - Scroll offset preference
//
// 一个 0 高度的 sensor view 放在 ScrollView 内容最顶上,通过 GeometryReader
// 把"我现在被推到容器坐标系下的什么位置"作为 PullOffsetKey 写出去。用户下
// 拉到顶之上时,这个 minY 会变成正值 —— 就是我们要的"拉了多少 pt"。

struct PullOffsetKey: PreferenceKey {
    // Swift 6 strict concurrency:用 `let` 存储 Sendable 类型,或用计算属性。
    // 这里走 `static let` 最直白,也不必 nonisolated(unsafe)。
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

extension View {
    /// 把当前 view 的顶部 Y 坐标(在指定 coordinate space)写到 PullOffsetKey。
    /// 放在 ScrollView 内容的最顶上,就能读到"用户下拉了多少 pt"。
    func reportPullOffset(in coordinateSpace: String) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: PullOffsetKey.self,
                    value: proxy.frame(in: .named(coordinateSpace)).minY
                )
            }
        )
    }
}

// MARK: - Launch particle

/// 一个"被喷射出去"的订阅图标。所有参数都在 fire 时随机生成,带一点点抖动
/// 让每次喷射看起来都不一样。
struct LaunchParticle: Identifiable {
    let id = UUID()
    let subscription: Subscription
    /// 出射角度(度)。-90 = 正上;实际取 -145..-35 范围,所有粒子都朝上方扇形散开。
    let angleDeg: Double
    /// 初速度(pt/秒,代入二维抛物线公式当 v0)。
    let velocity: CGFloat
    /// 整段飞行的总自转量(度)。
    let spinDeg: Double
    /// 启动延迟。一组粒子用 0..0.3s 错开,看起来更像"喷射"而不是"齐发"。
    let startDelay: TimeInterval
    /// 粒子稍微变大或变小,组里看起来不那么死板。
    let scale: CGFloat
}

struct LaunchParticleView: View {
    let particle: LaunchParticle
    let origin: CGPoint
    @State private var phase: CGFloat = 0

    /// 单粒子飞行总时长(秒)。
    private let duration: TimeInterval = 1.4
    /// 伪重力(pt/s²,正值 = 向下加速)。
    private let gravity: CGFloat = 1100

    var body: some View {
        let rad = particle.angleDeg * .pi / 180
        let t = CGFloat(phase) * CGFloat(duration)
        // 平面抛物线运动:
        //   x(t) = v · cos(θ) · t
        //   y(t) = v · sin(θ) · t + ½ · g · t²
        // 屏幕 Y 向下为正,所以 sin(-90°) = -1 让粒子向上,gravity 项再把它拉回来。
        let dx = cos(rad) * particle.velocity * t
        let dy = sin(rad) * particle.velocity * t + 0.5 * gravity * t * t

        // 头 4% 还没起步保持透明(等延迟入场),最后 20% 渐隐。
        let opacity: Double = {
            if phase < 0.04 { return 0 }
            if phase > 0.8 { return max(0, Double(1 - (phase - 0.8) / 0.2)) }
            return 1
        }()

        // 入场前 1/6 的时间里 scale 从 0.6 → 1.0,模拟"被推出"的弹出感。
        let scaleIn = min(1, phase * 6)

        return CategoryGlyph(subscription: particle.subscription, size: 52)
            .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
            .scaleEffect(particle.scale * (0.6 + 0.4 * scaleIn))
            .rotationEffect(.degrees(particle.spinDeg * Double(phase)))
            .opacity(opacity)
            .position(x: origin.x + dx, y: origin.y + dy)
            .onAppear {
                Task { @MainActor in
                    if particle.startDelay > 0 {
                        try? await Task.sleep(nanoseconds: UInt64(particle.startDelay * 1_000_000_000))
                    }
                    withAnimation(.easeOut(duration: duration)) {
                        phase = 1
                    }
                }
            }
    }
}

// MARK: - Pull banner

/// 用户下拉时浮在页面顶部的小胶囊。文案 + 表情随进度切换,armed 状态下变主题色。
struct PullBanner: View {
    /// 0 = 刚开始拉;1 = 到达发射阈值;> 1 = 越过阈值。
    let progress: CGFloat
    let armed: Bool

    private var text: LocalizedStringKey {
        if armed { return "松手发射 🚀" }
        if progress < 0.5 { return "继续往下拉…" }
        return "再来一点!"
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.down.circle.fill")
                .rotationEffect(.degrees(armed ? 180 : 0))
                .foregroundStyle(armed ? AppTheme.accent : AppTheme.secondary)
                .animation(AppTheme.spring, value: armed)
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(armed ? AppTheme.accent : AppTheme.ink)
                .contentTransition(.opacity)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(.thinMaterial, in: Capsule())
        .overlay(Capsule().stroke(AppTheme.hairline, lineWidth: 0.5))
        .scaleEffect(0.85 + 0.2 * min(1.2, progress))
        .opacity(min(1, progress * 2))
        .animation(AppTheme.spring, value: armed)
    }
}
