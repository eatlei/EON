import SwiftUI
import StoreKit
import UIKit

/// 打赏 sheet —— 跟"功能解锁"完全脱钩,纯爱心的"请开发者喝杯咖啡"。
/// 设计偏游戏化:咖啡 emoji 卡 + 玩笑文案,把"花一笔小钱支持独立开发者"
/// 做得轻松。文案全套走 String(localized:),所有语言都跟上。
struct TipSheet: View {
    @ObservedObject var tips: TipStore
    @Environment(\.dismiss) private var dismiss
    /// hero 大爱心的心跳动画 trigger。
    @State private var heartBeat = false
    /// 打赏成功后的庆祝层(emoji 雨 + 感谢卡)。
    @State private var celebrate = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Space.xl) {
                    hero
                    if !tips.loaded {
                        ProgressView()
                            .padding(.vertical, AppTheme.Space.xl)
                    } else if tips.products.isEmpty {
                        emptyState
                    } else {
                        tipCards
                    }
                    footnote
                }
                .padding(.horizontal, AppTheme.Space.xl)
                .padding(.top, AppTheme.Space.l)
                .padding(.bottom, AppTheme.Space.xxl)
                // iPad / Mac 上别把卡片拉得太宽,限制一个舒服的阅读宽度并居中。
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
            }
            .background(AppTheme.canvas.ignoresSafeArea())
            .navigationTitle("请我喝杯咖啡 ☕")
            .navigationBarTitleDisplayMode(.inline)
            .tint(AppTheme.accent)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .task { await tips.load() }
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    heartBeat.toggle()
                }
            }
            // 购买成功 → 起庆祝层。把 store 的 thanksShown 转成本地 celebrate,
            // 顺手清掉 store 标志,避免重复触发。
            .onChange(of: tips.thanksShown) { _, shown in
                if shown {
                    Haptics.success()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { celebrate = true }
                    tips.thanksShown = false
                }
            }
            // 庆祝层:emoji 雨从天而降 + 感谢卡。盖满全屏。
            .overlay {
                if celebrate {
                    TipCelebration(onDone: {
                        withAnimation(.easeOut(duration: 0.25)) { celebrate = false }
                        dismiss()
                    })
                }
            }
        }
    }

    // MARK: - Hero

    @ViewBuilder
    private var hero: some View {
        VStack(spacing: AppTheme.Space.m) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [AppTheme.accent.opacity(0.35), AppTheme.accent.opacity(0)],
                            center: .center, startRadius: 0, endRadius: 90
                        )
                    )
                    .frame(width: 180, height: 180)
                Text("💖")
                    .font(.system(size: 80))
                    .scaleEffect(heartBeat ? 1.08 : 0.95)
            }
            Text("你养的不是订阅,是开发者")
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.ink)
                .multilineTextAlignment(.center)
            Text("EON 帮你看住了钱包。要是它真帮上了忙,请开发者喝杯咖啡续个命?")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.Space.l)
        }
    }

    // MARK: - Tip cards

    @ViewBuilder
    private var tipCards: some View {
        VStack(spacing: AppTheme.Space.m) {
            ForEach(Array(tips.products.enumerated()), id: \.element.id) { idx, product in
                TipCard(
                    assetName: TipMeta.asset(idx),
                    emoji: TipMeta.emoji(idx),
                    title: TipMeta.title(idx),
                    flavor: TipMeta.flavor(idx),
                    price: product.displayPrice,
                    isPurchasing: tips.purchasingID == product.id,
                    isLocked: tips.purchasingID != nil && tips.purchasingID != product.id,
                    onTap: {
                        Haptics.tap()
                        Task { await tips.purchase(product) }
                    }
                )
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("😅")
                .font(.system(size: 44))
            Text("打赏货架暂时没加载出来,可能是网络的锅。稍后再试?")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.Space.l)
        }
        .padding(.vertical, AppTheme.Space.l)
    }

    @ViewBuilder
    private var footnote: some View {
        VStack(spacing: 6) {
            Text("完全自愿 · 不解锁任何功能 · 一次性,不是订阅")
                .font(.caption)
                .foregroundStyle(AppTheme.tertiary)
                .multilineTextAlignment(.center)
            // 一句俏皮话:你都用订阅管理 App 了,可别再给自己添一笔订阅。
            Text("你都在用订阅管理 App 了,就别再给自己加一个叫 EON 的订阅啦 😉 打赏就一下,绝不续费。")
                .font(.caption2)
                .foregroundStyle(AppTheme.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, AppTheme.Space.s)
    }
}

// MARK: - Tip card

private struct TipCard: View {
    /// 该档对应的咖啡图标资源名(抠好背景的 PNG)。资源缺失时回退到 emoji。
    let assetName: String
    let emoji: String
    let title: LocalizedStringKey
    let flavor: LocalizedStringKey
    let price: String
    let isPurchasing: Bool
    let isLocked: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppTheme.Space.l) {
                Group {
                    if !assetName.isEmpty, UIImage(named: assetName) != nil {
                        Image(assetName)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Text(emoji).font(.system(size: 44))
                    }
                }
                // 抠好背景的图标直接浮在卡片上,不再套深色色块(深色模式下那块会发黑)。
                .frame(width: 64, height: 64)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(flavor)
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if isPurchasing {
                    ProgressView()
                } else {
                    Text(price)
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(AppTheme.accent, in: Capsule())
                }
            }
            .padding(AppTheme.Space.m)
            .frame(maxWidth: .infinity)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.radius))
            .glassBorder()
            .opacity(isLocked ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isLocked || isPurchasing)
    }
}

// MARK: - 打赏成功庆祝层(emoji 雨 + 感谢卡)

private struct TipCelebration: View {
    let onDone: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
                .onTapGesture { onDone() }

            EmojiRain()
                .allowsHitTesting(false)

            VStack(spacing: AppTheme.Space.m) {
                Text("☕")
                    .font(.system(size: 64))
                Text("咕噜咕噜,下肚了")
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(AppTheme.ink)
                Text("这杯咖啡一下去,今晚八成又睡不着了 —— 那正好,爬起来给 EON 写点新东西。真心谢谢你 🙏")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondary)
                    .multilineTextAlignment(.center)
                Button {
                    onDone()
                } label: {
                    Text("不客气啦")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: AppTheme.radius))
                }
                .buttonStyle(.plain)
                .padding(.top, AppTheme.Space.s)
            }
            .padding(AppTheme.Space.xl)
            .frame(maxWidth: 340)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 24))
            .glassBorder(cornerRadius: 24)
            .padding(.horizontal, AppTheme.Space.xl)
            .transition(.scale(scale: 0.8).combined(with: .opacity))
        }
    }
}

/// 从屏幕上方落下一阵可爱 emoji,约 2 秒自然飘完。纯装饰,不拦手势。
private struct EmojiRain: View {
    private static let pool = ["☕", "🎉", "💕", "✨", "🥰", "🙏", "💖", "🧋", "👍", "🫶"]

    private struct Drop: Identifiable {
        let id = UUID()
        let emoji: String
        let xRatio: CGFloat
        let delay: Double
        let duration: Double
        let size: CGFloat
        let spin: Double
    }

    @State private var drops: [Drop] = []

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(drops) { d in
                    EmojiDropView(drop: d, containerHeight: geo.size.height)
                        .position(x: d.xRatio * geo.size.width, y: 0)
                }
            }
            .onAppear { if drops.isEmpty { drops = makeDrops() } }
        }
    }

    private func makeDrops() -> [Drop] {
        (0..<26).map { _ in
            Drop(
                emoji: Self.pool.randomElement() ?? "☕",
                xRatio: CGFloat.random(in: 0.05...0.95),
                delay: Double.random(in: 0...0.8),
                duration: Double.random(in: 1.6...2.6),
                size: CGFloat.random(in: 22...40),
                spin: Double.random(in: -180...180)
            )
        }
    }

    private struct EmojiDropView: View {
        let drop: Drop
        let containerHeight: CGFloat
        @State private var progress: CGFloat = 0

        var body: some View {
            Text(drop.emoji)
                .font(.system(size: drop.size))
                .rotationEffect(.degrees(drop.spin * Double(progress)))
                .opacity(progress > 0.85 ? Double((1 - progress) / 0.15) : 1)
                .offset(y: progress * (containerHeight + 80))
                .onAppear {
                    Task { @MainActor in
                        if drop.delay > 0 {
                            try? await Task.sleep(nanoseconds: UInt64(drop.delay * 1_000_000_000))
                        }
                        withAnimation(.easeIn(duration: drop.duration)) { progress = 1 }
                    }
                }
        }
    }
}

// MARK: - Per-tier metadata
//
// 四档全部围绕"咖啡"做梯度,价格从低到高(load() 里按 price 排序):
// 速溶 < 冰美式 < 冷萃 < 顶级瑰夏手冲。

private enum TipMeta {
    /// 各档对应的咖啡图标资源名(抠好背景):速溶 / 冰美式 / 冷萃 / 瑰夏手冲。
    static func asset(_ idx: Int) -> String {
        ["TipInstant", "TipIced", "TipColdBrew", "TipGeisha"][safe: idx] ?? ""
    }
    static func emoji(_ idx: Int) -> String {
        ["☕", "🥤", "🧊", "🏆"][safe: idx] ?? "💝"
    }
    static func title(_ idx: Int) -> LocalizedStringKey {
        ["速溶咖啡", "冰美式", "冷萃咖啡", "顶级瑰夏手冲咖啡 👍"][safe: idx] ?? "随心意"
    }
    static func flavor(_ idx: Int) -> LocalizedStringKey {
        [
            "一包速溶冲下去,提神继续敲代码",
            "冰美式续命,Bug 一个个退散",
            "冷萃慢慢滴,功能慢慢磨",
            "瑰夏手冲级别的款待,开发者能记一整年"
        ][safe: idx] ?? "感谢任何形式的支持"
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
