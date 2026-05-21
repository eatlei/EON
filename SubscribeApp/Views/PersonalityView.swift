import SwiftUI
import UIKit

/// 二级页面:展示用户的"订阅人格"。布局是 1 张大图 + 名字 + 口号 + 描述 +
/// 一句"会随订阅变化"的提示 + 免责声明。入场带丰富的动画(渐显 / 缩放 /
/// 错开节奏),配合震动反馈,做出"翻牌揭晓"的惊喜感。
struct PersonalityView: View {
    @EnvironmentObject private var store: SubscriptionStore

    private var type: PersonalityType { store.personality }

    // MARK: - 进场动画相关 state
    //
    // 每个 state 控制 view 链里一组元素的"是否进场",时间错开 0.05~0.15 秒就能
    // 形成"图先到 → 名字到 → 标语到 → 详情到 → 提示到"的瀑布感。
    @State private var heroAppeared = false      // 大图缩放 + 旋转入场
    @State private var nameAppeared = false      // 人格名字
    @State private var taglineAppeared = false   // 一句标语
    @State private var detailAppeared = false    // 详细描述
    @State private var hintAppeared = false      // 会变化的提示
    @State private var disclaimerAppeared = false // 免责声明

    /// 进场时的轻触反馈:大图弹到位时一下 medium impact,跟视觉的"啪"对上。
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
        // 主内容 = 大图 + 名字 + 标语 + 详情;放在可滚动区。
        // 辅助说明(随订阅变化 / 仅供娱乐)从滚动内容里拆出来,固定在弹窗底部,
        // 这样用户看主内容时眼睛不会被这两行 caption 拽下去。
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: AppTheme.Space.xl) {
                    heroImage
                    content
                }
                .padding(.horizontal, AppTheme.Space.xl)
                .padding(.top, AppTheme.Space.l)
                .padding(.bottom, AppTheme.Space.l)
                .readableWidth(560)
            }

            VStack(spacing: AppTheme.Space.xs) {
                evolutionHint
                disclaimer
            }
            .padding(.horizontal, AppTheme.Space.xl)
            .padding(.top, AppTheme.Space.s)
            .padding(.bottom, AppTheme.Space.m)
            .frame(maxWidth: .infinity)
        }
        .background(AppTheme.canvas.ignoresSafeArea())
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

    /// 用 ImageRenderer 把分享卡片烤成图。3x 保证清晰,出图后工具栏分享按钮才出现。
    @MainActor
    private func renderShareCard() {
        let card = PersonalityShareCard(type: type, stats: shareStats)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        cardImage = renderer.uiImage
    }

    /// 入场动画编排 —— 各元素错开节奏,跟一次 medium haptic 同步。
    private func playEntryAnimation() async {
        // 大图先弹到位
        withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) {
            heroAppeared = true
        }
        revealTick &+= 1
        try? await Task.sleep(nanoseconds: 220_000_000)
        withAnimation(.easeOut(duration: 0.35)) { nameAppeared = true }
        try? await Task.sleep(nanoseconds: 110_000_000)
        withAnimation(.easeOut(duration: 0.35)) { taglineAppeared = true }
        try? await Task.sleep(nanoseconds: 110_000_000)
        withAnimation(.easeOut(duration: 0.4)) { detailAppeared = true }
        try? await Task.sleep(nanoseconds: 130_000_000)
        withAnimation(.easeOut(duration: 0.4)) { hintAppeared = true }
        try? await Task.sleep(nanoseconds: 110_000_000)
        withAnimation(.easeOut(duration: 0.4)) { disclaimerAppeared = true }
    }

    // MARK: - 大图

    /// 真图(Assets 里)优先,没有就用渐变 + SF Symbol 兜底。入场做 spring 缩放
    /// + 轻微旋转,显得"啪一下揭出来"。
    @ViewBuilder
    private var heroImage: some View {
        let assetName = type.imageAssetName
        let hasAsset = (UIImage(named: assetName) != nil)

        ZStack {
            if hasAsset {
                Image(assetName)
                    .resizable()
                    .scaledToFill()
            } else {
                RadialGradient(
                    stops: [
                        .init(color: type.tint.opacity(0.85), location: 0.0),
                        .init(color: type.tint.opacity(0.35), location: 0.55),
                        .init(color: type.tint.opacity(0.10), location: 1.0),
                    ],
                    center: .center, startRadius: 0, endRadius: 220
                )
                Image(systemName: type.fallbackSymbol)
                    .font(.system(size: 110, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 0.5)
        )
        .shadow(color: type.tint.opacity(0.25), radius: 22, x: 0, y: 12)
        // 入场缩放 + 极轻旋转:0.85 → 1.0, -2° → 0°,弹簧节奏
        .scaleEffect(heroAppeared ? 1.0 : 0.85)
        .rotationEffect(.degrees(heroAppeared ? 0 : -2))
        .opacity(heroAppeared ? 1 : 0)
    }

    // MARK: - 文字部分

    @ViewBuilder
    private var content: some View {
        VStack(spacing: AppTheme.Space.s) {
            // 名字 —— 从下方淡入
            Text(type.name)
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundStyle(AppTheme.ink)
                .multilineTextAlignment(.center)
                .opacity(nameAppeared ? 1 : 0)
                .offset(y: nameAppeared ? 0 : 12)

            // 标语 —— 跟在名字后面 0.1s 进入
            Text(type.tagline)
                .font(.headline.weight(.semibold))
                .foregroundStyle(type.tint)
                .multilineTextAlignment(.center)
                .padding(.bottom, 4)
                .opacity(taglineAppeared ? 1 : 0)
                .offset(y: taglineAppeared ? 0 : 10)

            // 详情 —— 多行段落,渐显
            Text(type.detail)
                .font(.body)
                .foregroundStyle(AppTheme.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(detailAppeared ? 1 : 0)
                .offset(y: detailAppeared ? 0 : 8)
        }
        .padding(.horizontal, AppTheme.Space.s)
    }

    // MARK: - "会随订阅变化"提示
    //
    // 一行小字,纯灰,不抢戏。之前用大色卡 + 加粗标题太重,现在调成"脚注"质感:
    // 一个小图标 + 一句轻描淡写的解释,信息传达到了即可。

    @ViewBuilder
    private var evolutionHint: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.caption2)
            Text("人格会随你的订阅而变化")  // 短一句脚注;译文表里已配 8 国语种
                .font(.caption)
        }
        .foregroundStyle(AppTheme.tertiary)
        .padding(.top, AppTheme.Space.s)
        .opacity(hintAppeared ? 1 : 0)
    }

    // MARK: - 免责声明

    @ViewBuilder
    private var disclaimer: some View {
        VStack(spacing: 4) {
            Image(systemName: "sparkles")
                .font(.caption)
                .foregroundStyle(AppTheme.tertiary)
            Text("仅供娱乐 · 不代表 EON 的任何评价或建议")
                .font(.caption)
                .foregroundStyle(AppTheme.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, AppTheme.Space.m)
        .opacity(disclaimerAppeared ? 1 : 0)
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
