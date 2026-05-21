import SwiftUI
import UIKit

/// 二级页面:展示用户的"订阅人格"。
///
/// 设计为一张"可分享卡片"风格的主视觉(不是浮层弹窗):主题色渐变卡片 +
/// 透明抠图形象浮在卡上,配合「上下浮动 / 背后光晕脉动 / 斜向高光扫过 /
/// 拖拽倾斜」的动效,做出一张活的卡片。卡片下方是描述卡 + 两行轻量脚注。
struct PersonalityView: View {
    @EnvironmentObject private var store: SubscriptionStore

    private var type: PersonalityType { store.personality }

    // MARK: - 进场动画 state
    @State private var heroAppeared = false       // 主卡片缩放 + 渐显
    @State private var detailAppeared = false     // 描述卡上浮
    @State private var hintAppeared = false        // 会变化的提示
    @State private var disclaimerAppeared = false  // 免责声明

    /// 主卡片弹到位时来一下 medium impact,跟视觉的"啪"对上。
    @State private var revealTick = 0

    /// 渲染好的分享卡片图(ImageRenderer 出图后填上,工具栏才出现分享按钮)。
    @State private var cardImage: UIImage?

    /// 分享卡片要展示的"隐私安全"数据:订阅数 + 分类数 + top 分类名(不含金额、
    /// 不含具体服务名),足够有趣又不泄露敏感信息。
    private var shareStats: PersonaShareStats {
        let subs = store.activeSubscriptions
        let cats = Set(subs.map { $0.displayCategoryID })
        let top = store.categorySpend.prefix(3).map { $0.title }
        return PersonaShareStats(count: subs.count, categoryCount: cats.count, topCategories: Array(top))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Space.xl) {
                // 主视觉:活的分享卡
                PersonaHeroCard(type: type, stats: shareStats)
                    .scaleEffect(heroAppeared ? 1 : 0.9)
                    .opacity(heroAppeared ? 1 : 0)

                // 描述卡
                detailCard
                    .opacity(detailAppeared ? 1 : 0)
                    .offset(y: detailAppeared ? 0 : 18)

                // 脚注
                VStack(spacing: AppTheme.Space.s) {
                    evolutionHint
                    disclaimer
                }
            }
            .padding(.horizontal, AppTheme.Space.xl)
            .padding(.top, AppTheme.Space.l)
            .padding(.bottom, AppTheme.Space.xxl)
            .readableWidth(560)
        }
        .background(themedBackground)
        .navigationTitle("订阅人格")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.impact(weight: .medium), trigger: revealTick)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let img = cardImage {
                    ShareLink(
                        item: Image(uiImage: img),
                        preview: SharePreview(Text(verbatim: "EON · \(type.name)"),
                                              image: Image(uiImage: img))
                    ) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .task {
            renderShareCard()
            await playEntryAnimation()
        }
    }

    // MARK: - 主题化背景

    /// 整页背景:canvas 上叠一层从顶部洒下的主题色光晕,让页面跟人格同色调。
    private var themedBackground: some View {
        ZStack {
            AppTheme.canvas
            RadialGradient(
                colors: [type.tint.opacity(0.22), type.tint.opacity(0.06), .clear],
                center: .top, startRadius: 0, endRadius: 460
            )
        }
        .ignoresSafeArea()
    }

    // MARK: - 描述卡

    private var detailCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.s) {
            Text(type.detail)
                .font(.body)
                .foregroundStyle(AppTheme.secondary)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
            // top 分类:有就用小胶囊点一下"是哪些"(不含金额,隐私安全)
            if !shareStats.topCategories.isEmpty {
                HStack(spacing: 6) {
                    ForEach(shareStats.topCategories, id: \.self) { name in
                        Text(name)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(type.tint)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(type.tint.opacity(0.12), in: Capsule())
                    }
                }
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Space.l)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.radius))
        .glassBorder()
    }

    // MARK: - 脚注

    @ViewBuilder
    private var evolutionHint: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.caption2)
            Text("人格会随你的订阅而变化")
                .font(.caption)
        }
        .foregroundStyle(AppTheme.tertiary)
        .padding(.top, AppTheme.Space.s)
        .opacity(hintAppeared ? 1 : 0)
    }

    @ViewBuilder
    private var disclaimer: some View {
        VStack(spacing: 4) {
            Image(systemName: "sparkles")
                .font(.caption)
            Text("仅供娱乐 · 不代表 EON 的任何评价或建议")
                .font(.caption)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(AppTheme.tertiary)
        .padding(.top, AppTheme.Space.xs)
        .opacity(disclaimerAppeared ? 1 : 0)
    }

    // MARK: - 出图 & 动画编排

    /// 用 ImageRenderer 把分享卡片烤成图。3x 保证清晰,出图后工具栏分享按钮才出现。
    @MainActor
    private func renderShareCard() {
        let card = PersonalityShareCard(type: type, stats: shareStats)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        cardImage = renderer.uiImage
    }

    /// 进场:主卡片弹到位(配 haptic)→ 描述卡上浮 → 脚注渐显。
    private func playEntryAnimation() async {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.72)) {
            heroAppeared = true
        }
        revealTick &+= 1
        try? await Task.sleep(nanoseconds: 240_000_000)
        withAnimation(.easeOut(duration: 0.4)) { detailAppeared = true }
        try? await Task.sleep(nanoseconds: 120_000_000)
        withAnimation(.easeOut(duration: 0.4)) { hintAppeared = true }
        try? await Task.sleep(nanoseconds: 100_000_000)
        withAnimation(.easeOut(duration: 0.4)) { disclaimerAppeared = true }
    }
}

// MARK: - 活的主卡片

/// 主视觉卡片:主题色渐变 + 透明抠图形象 + 名字 + 标语 + 数据胶囊。
/// 动效:形象上下浮动、背后光晕脉动、斜向高光循环扫过、拖拽时整卡 3D 倾斜。
private struct PersonaHeroCard: View {
    let type: PersonalityType
    let stats: PersonaShareStats

    @State private var float = false       // 形象上下浮动
    @State private var glowPulse = false   // 背后光晕脉动
    @State private var shine = false        // 斜向高光扫过
    @GestureState private var drag: CGSize = .zero

    private let corner: CGFloat = 32

    var body: some View {
        VStack(spacing: AppTheme.Space.l) {
            artZone
            VStack(spacing: 6) {
                Text(type.name)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(type.tagline)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: 10) {
                statChip(value: "\(stats.count)", label: "订阅")
                statChip(value: "\(stats.categoryCount)", label: "分类")
            }
        }
        .padding(.vertical, AppTheme.Space.xxl)
        .padding(.horizontal, AppTheme.Space.xl)
        .frame(maxWidth: .infinity)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .overlay(shineOverlay)
        .overlay(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .stroke(.white.opacity(0.28), lineWidth: 1)
        )
        .shadow(color: type.tint.opacity(0.45), radius: 28, x: 0, y: 18)
        // 拖拽倾斜:整卡跟着手指做轻微 3D 旋转,松手弹回。
        .rotation3DEffect(.degrees(Double(drag.width) / 16),
                          axis: (x: 0, y: 1, z: 0), perspective: 0.6)
        .rotation3DEffect(.degrees(Double(-drag.height) / 18),
                          axis: (x: 1, y: 0, z: 0), perspective: 0.6)
        .gesture(
            DragGesture(minimumDistance: 0)
                .updating($drag) { value, state, _ in state = value.translation }
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: drag)
        .onAppear { startAmbientAnimations() }
    }

    // 形象区:背后脉动光晕 + 浮动的透明抠图。
    private var artZone: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [.white.opacity(0.5), .white.opacity(0.12), .clear],
                    center: .center, startRadius: 0, endRadius: 130))
                .frame(width: 240, height: 240)
                .scaleEffect(glowPulse ? 1.08 : 0.9)
                .opacity(glowPulse ? 0.95 : 0.55)
                .blur(radius: 6)

            artwork
                .frame(height: 184)
                .offset(y: float ? -9 : 9)
                .shadow(color: .black.opacity(0.22), radius: 16, x: 0, y: 12)
        }
        .frame(height: 212)
    }

    @ViewBuilder
    private var artwork: some View {
        if UIImage(named: type.imageAssetName) != nil {
            Image(type.imageAssetName)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: type.fallbackSymbol)
                .font(.system(size: 96, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private var cardBackground: some View {
        ZStack {
            LinearGradient(
                colors: [type.tint, type.tint.opacity(0.68)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [.white.opacity(0.3), .clear],
                center: UnitPoint(x: 0.22, y: 0.1), startRadius: 0, endRadius: 340
            )
        }
    }

    // 斜向高光:一条半透明白带循环从左下扫到右上。
    private var shineOverlay: some View {
        GeometryReader { geo in
            let w = geo.size.width
            LinearGradient(
                colors: [.clear, .white.opacity(0.35), .clear],
                startPoint: .top, endPoint: .bottom
            )
            .frame(width: w * 0.45)
            .rotationEffect(.degrees(22))
            .offset(x: shine ? w * 1.25 : -w * 1.25)
            .blendMode(.plusLighter)
        }
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .allowsHitTesting(false)
    }

    private func statChip(value: String, label: LocalizedStringKey) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
        }
        .frame(minWidth: 72)
        .padding(.vertical, 10)
        .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(.white.opacity(0.2), lineWidth: 0.5))
    }

    private func startAmbientAnimations() {
        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
            float = true
        }
        withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
            glowPulse = true
        }
        withAnimation(.linear(duration: 3.4).repeatForever(autoreverses: false).delay(0.8)) {
            shine = true
        }
    }
}

// MARK: - 分享卡片

/// 卡片要展示的隐私安全数据。只放聚合数字 + 分类名,绝不含金额或具体服务名。
struct PersonaShareStats {
    let count: Int
    let categoryCount: Int
    let topCategories: [String]
}

/// 可分享的"订阅人格"卡片。用 ImageRenderer 烤成图后分享 / 存相册。
/// 顶部露出 EON 图标 + 名称,中间是人格形象 + 名字 + 标语,下面是几枚数据胶囊。
private struct PersonalityShareCard: View {
    let type: PersonalityType
    let stats: PersonaShareStats

    private let width: CGFloat = 360

    var body: some View {
        VStack(spacing: AppTheme.Space.l) {
            // 顶部品牌行
            HStack(spacing: 8) {
                brandIcon
                Text(verbatim: "EON")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Text("订阅人格")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(.white.opacity(0.18), in: Capsule())
            }

            // 人格形象
            personaArt
                .frame(width: 150, height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(.white.opacity(0.5), lineWidth: 1))
                .shadow(color: .black.opacity(0.25), radius: 16, y: 8)

            VStack(spacing: 6) {
                Text(type.name)
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(type.tagline)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
            }

            // 数据胶囊(隐私安全:只有数量 + 分类名)
            HStack(spacing: 8) {
                statChip(value: "\(stats.count)", label: String(localized: "订阅"))
                statChip(value: "\(stats.categoryCount)", label: String(localized: "分类"))
            }
            if !stats.topCategories.isEmpty {
                Text(stats.topCategories.joined(separator: " · "))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(.white.opacity(0.15), in: Capsule())
            }

            Text("由 EON 生成 · 仅供娱乐")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
                .padding(.top, 2)
        }
        .padding(AppTheme.Space.xl)
        .frame(width: width)
        .background(
            ZStack {
                LinearGradient(
                    colors: [type.tint, type.tint.opacity(0.65)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                RadialGradient(
                    colors: [.white.opacity(0.25), .clear],
                    center: UnitPoint(x: 0.2, y: 0.1), startRadius: 0, endRadius: 260
                )
            }
        )
    }

    @ViewBuilder
    private var brandIcon: some View {
        if let ui = UIImage(named: "EONBrandIcon") {
            Image(uiImage: ui).resizable().scaledToFill()
                .frame(width: 30, height: 30)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(.white.opacity(0.25))
                .frame(width: 30, height: 30)
                .overlay(Text(verbatim: "E").font(.system(size: 16, weight: .heavy, design: .rounded)).foregroundStyle(.white))
        }
    }

    @ViewBuilder
    private var personaArt: some View {
        if UIImage(named: type.imageAssetName) != nil {
            Image(type.imageAssetName).resizable().scaledToFill()
        } else {
            ZStack {
                Color.white.opacity(0.16)
                Image(systemName: type.fallbackSymbol)
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }

    private func statChip(value: String, label: String) -> some View {
        VStack(spacing: 0) {
            Text(value)
                .font(.system(size: 22, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.8))
        }
        .frame(minWidth: 64)
        .padding(.vertical, 8)
        .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    NavigationStack { PersonalityView() }
        .environmentObject(SubscriptionStore())
}
