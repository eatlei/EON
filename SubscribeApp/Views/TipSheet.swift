import SwiftUI
import StoreKit

/// 打赏 sheet —— 跟"功能解锁"完全脱钩,纯爱心的"请开发者喝一杯"。
/// 设计上偏游戏化:大块的 emoji 卡 + 玩笑文案,把"花一笔小钱支持一个独立
/// 开发者"的体验做得轻松。文案全套走 String(localized:),所有语言都跟上。
struct TipSheet: View {
    @ObservedObject var tips: TipStore
    @Environment(\.dismiss) private var dismiss
    /// 给"感谢"页面用的小动画 trigger —— 弹出来的时候让爱心心跳一下。
    @State private var heartBeat = false

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
            }
            .background(AppTheme.canvas.ignoresSafeArea())
            .navigationTitle("请我喝一杯 ☕")
            .navigationBarTitleDisplayMode(.inline)
            .tint(AppTheme.accent)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .alert(String(localized: "你真的太好了 🥰"), isPresented: $tips.thanksShown) {
                Button("不客气啦") {
                    dismiss()
                }
            } message: {
                Text("收到啦!这一杯/一顿我会真心实意地用来加班。")
            }
            .task { await tips.load() }
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    heartBeat.toggle()
                }
            }
        }
    }

    // MARK: - Hero

    /// 顶部的大爱心 + 一行问候。让用户一打开就感觉到"轻松、不被推销"。
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
            Text("如果 EON 帮你省下了一杯奶茶钱,要不要把那杯奶茶请给开发者?")
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
                    emoji: TipMeta.emoji(idx),
                    title: TipMeta.title(idx),
                    flavor: TipMeta.flavor(idx),
                    price: product.displayPrice,
                    isPurchasing: tips.purchasingID == product.id,
                    isLocked: tips.purchasingID != nil && tips.purchasingID != product.id,
                    onTap: { Task { await tips.purchase(product) } }
                )
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("😅")
                .font(.system(size: 44))
            Text("打赏暂时找不到货架,可能是网络的锅。稍后再试?")
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
            Text("完全自愿 · 不解锁任何功能 · 100% 暖到开发者")
                .font(.caption)
                .foregroundStyle(AppTheme.tertiary)
                .multilineTextAlignment(.center)
            Text("(不打赏也可以继续白嫖,我们做朋友 🤝)")
                .font(.caption2)
                .foregroundStyle(AppTheme.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, AppTheme.Space.s)
    }
}

// MARK: - Tip card

private struct TipCard: View {
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
                Text(emoji)
                    .font(.system(size: 44))
                    .frame(width: 64, height: 64)
                    .background(AppTheme.canvas, in: RoundedRectangle(cornerRadius: 18))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.ink)
                    Text(flavor)
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondary)
                        .lineLimit(2)
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

// MARK: - Per-tier metadata

private enum TipMeta {
    static func emoji(_ idx: Int) -> String {
        ["☕", "🍱", "🍣"][safe: idx] ?? "💝"
    }
    static func title(_ idx: Int) -> LocalizedStringKey {
        ["请杯咖啡", "请顿便餐", "请顿大餐"][safe: idx] ?? "随心意"
    }
    static func flavor(_ idx: Int) -> LocalizedStringKey {
        [
            "一杯咖啡,开发者会笑出声",
            "一顿外卖,Bug 被踩死三只",
            "一顿好的,深夜加班更带劲"
        ][safe: idx] ?? "感谢任何形式的支持"
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
