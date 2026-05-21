import SwiftUI
import UIKit

/// 二级页面:把用户的"订阅人格"呈现为**一整张包装海报式卡片**(灵感来自潮玩
/// 收藏卡):中间是人格形象,两侧像"装备"一样陈列用户订阅的 App 图标,配上标题 /
/// 标语 / 条码等文案。进入时先放一个"正在生成卡片"的 loading 动效,再把卡片
/// 连同两侧图标错峰弹出来。整卡支持拖拽轻微 3D 倾斜 + 形象浮动 + 高光扫过。
struct PersonalityView: View {
    @EnvironmentObject private var store: SubscriptionStore

    private var type: PersonalityType { store.personality }

    /// loading 阶段(生成卡片);结束后切到卡片。
    @State private var isGenerating = true
    /// 卡片入场总开关:true 时卡片 + 两侧图标错峰弹入。
    @State private var play = false
    @State private var revealTick = 0
    @State private var cardImage: UIImage?

    /// 卡上要陈列的订阅图标:取活跃订阅前 6 个(两侧各最多 3 个)。
    private var iconSubs: [Subscription] { Array(store.activeSubscriptions.prefix(6)) }

    /// 分享卡片要展示的"隐私安全"数据:订阅数 + 分类数 + top 分类名(不含金额、
    /// 不含具体服务名)。
    private var shareStats: PersonaShareStats {
        let subs = store.activeSubscriptions
        let cats = Set(subs.map { $0.displayCategoryID })
        let top = store.categorySpend.prefix(3).map { $0.title }
        return PersonaShareStats(count: subs.count, categoryCount: cats.count, topCategories: Array(top))
    }

    var body: some View {
        ZStack {
            posterBackground

            ScrollView {
                PersonaPosterCard(type: type, subs: iconSubs, stats: shareStats, play: play)
                    .padding(AppTheme.Space.l)
                    .readableWidth(520)
            }
            .opacity(play ? 1 : 0)
            .scaleEffect(play ? 1 : 0.96)

            if isGenerating {
                GeneratingOverlay(tint: type.tint)
                    .transition(.opacity)
            }
        }
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
        .task { await generateAndReveal() }
    }

    /// 整页背景:canvas 上叠一层从顶部洒下的主题色光晕,让页面跟人格同色调。
    private var posterBackground: some View {
        ZStack {
            AppTheme.canvas
            RadialGradient(
                colors: [type.tint.opacity(0.20), type.tint.opacity(0.05), .clear],
                center: .top, startRadius: 0, endRadius: 460
            )
        }
        .ignoresSafeArea()
    }

    /// 先把分享图烤好,放一会 loading 动效(营造"生成卡片"的仪式感),
    /// 再淡出 loading、弹入卡片。
    private func generateAndReveal() async {
        renderShareCard()
        try? await Task.sleep(nanoseconds: 1_150_000_000)
        withAnimation(.easeOut(duration: 0.35)) { isGenerating = false }
        withAnimation(.spring(response: 0.62, dampingFraction: 0.8)) { play = true }
        revealTick &+= 1
    }

    /// 用 ImageRenderer 把海报卡片烤成图(3x),分享 / 存相册。
    @MainActor
    private func renderShareCard() {
        let card = PersonaPosterCard(type: type, subs: iconSubs, stats: shareStats,
                                     play: true, forSharing: true)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        cardImage = renderer.uiImage
    }
}

// MARK: - 生成中 loading

/// "正在生成你的人格卡片"——一圈旋转的进度弧 + 中心脉动 sparkles。
private struct GeneratingOverlay: View {
    let tint: Color
    @State private var spin = false
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(tint.opacity(0.15), lineWidth: 6)
                    .frame(width: 84, height: 84)
                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(tint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 84, height: 84)
                    .rotationEffect(.degrees(spin ? 360 : 0))
                Image(systemName: "sparkles")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(tint)
                    .scaleEffect(pulse ? 1.12 : 0.88)
            }
            Text("正在生成你的人格卡片…")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.secondary)
        }
        .onAppear {
            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) { spin = true }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}

// MARK: - 海报卡片

/// 卡片要展示的隐私安全数据。只放聚合数字 + 分类名,绝不含金额或具体服务名。
struct PersonaShareStats {
    let count: Int
    let categoryCount: Int
    let topCategories: [String]
}

/// 一整张"包装海报"式人格卡:头部品牌行 + 大标题 + 中央形象(两侧陈列订阅图标)
/// + 底部条码与数据。屏幕上可拖拽轻微 3D 倾斜、形象上下浮动、高光循环扫过;
/// 用 ImageRenderer 出图分享时传 `forSharing` 关掉交互、用固定宽度。
private struct PersonaPosterCard: View {
    let type: PersonalityType
    let subs: [Subscription]
    let stats: PersonaShareStats
    var play: Bool
    var forSharing: Bool = false

    @State private var float = false
    @State private var shine = false
    @GestureState private var drag: CGSize = .zero

    private let corner: CGFloat = 28

    /// 两侧分配:左列拿前一半,右列拿后一半。
    private var leftSubs: [Subscription] { Array(subs.prefix((subs.count + 1) / 2)) }
    private var rightSubs: [Subscription] { Array(subs.suffix(subs.count - (subs.count + 1) / 2)) }

    /// 给海报一个稳定的"编号"——人格在枚举里的序号。
    private var personaNumber: String {
        let idx = (PersonalityType.allCases.firstIndex(of: type) ?? 0) + 1
        return String(format: "#%02d", idx)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.l) {
            header
            titleBlock
            stage
            footer
        }
        .padding(AppTheme.Space.l)
        .frame(maxWidth: forSharing ? 360 : .infinity)
        .background(cardBackground)
        .overlay(cornerTicks)
        .overlay(shineOverlay)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .stroke(AppTheme.ink.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: type.tint.opacity(forSharing ? 0 : 0.22), radius: 26, x: 0, y: 16)
        .rotation3DEffect(.degrees(forSharing ? 0 : Double(drag.width) / 18),
                          axis: (x: 0, y: 1, z: 0), perspective: 0.6)
        .rotation3DEffect(.degrees(forSharing ? 0 : Double(-drag.height) / 22),
                          axis: (x: 1, y: 0, z: 0), perspective: 0.6)
        .gesture(forSharing ? nil :
            DragGesture(minimumDistance: 0)
                .updating($drag) { value, state, _ in state = value.translation }
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: drag)
        .onAppear {
            guard !forSharing else { return }
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) { float = true }
            withAnimation(.linear(duration: 3.6).repeatForever(autoreverses: false).delay(0.8)) { shine = true }
        }
    }

    // 头部品牌行
    private var header: some View {
        HStack(spacing: 8) {
            brandIcon
            Text(verbatim: "EON")
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(AppTheme.ink)
            Spacer()
            Text(verbatim: personaNumber)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.secondary)
            Text("订阅人格")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(type.tint, in: Capsule())
        }
    }

    // 大标题块
    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: "SUBSCRIPTION PERSONA")
                .font(.system(size: 10, weight: .bold))
                .tracking(2)
                .foregroundStyle(AppTheme.tertiary)
            Text(type.name)
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(type.tagline)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(type.tint)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // 中央舞台:左列图标 + 形象 + 右列图标
    private var stage: some View {
        HStack(alignment: .center, spacing: AppTheme.Space.s) {
            if !leftSubs.isEmpty {
                iconColumn(leftSubs, sideOffset: 0)
            }
            figure
                .frame(maxWidth: .infinity)
            if !rightSubs.isEmpty {
                iconColumn(rightSubs, sideOffset: leftSubs.count)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 210)
    }

    private func iconColumn(_ items: [Subscription], sideOffset: Int) -> some View {
        VStack(spacing: AppTheme.Space.s) {
            ForEach(Array(items.enumerated()), id: \.element.id) { i, sub in
                IconBlister(subscription: sub, tint: type.tint)
                    .scaleEffect(play ? 1 : 0.5)
                    .opacity(play ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7)
                        .delay(0.25 + Double(sideOffset + i) * 0.08), value: play)
            }
        }
    }

    // 中央形象:主题色光晕 + 透明抠图浮动
    private var figure: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [type.tint.opacity(0.4), type.tint.opacity(0.12), .clear],
                    center: .center, startRadius: 0, endRadius: 120))
                .frame(width: 230, height: 230)
                .blur(radius: 4)
            artwork
                .frame(height: 188)
                .offset(y: float ? -8 : 8)
                .shadow(color: .black.opacity(0.2), radius: 14, x: 0, y: 10)
        }
        .scaleEffect(play ? 1 : 0.8)
        .opacity(play ? 1 : 0)
        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: play)
    }

    @ViewBuilder
    private var artwork: some View {
        if UIImage(named: type.imageAssetName) != nil {
            Image(type.imageAssetName).resizable().scaledToFit()
        } else {
            Image(systemName: type.fallbackSymbol)
                .font(.system(size: 92, weight: .bold))
                .foregroundStyle(type.tint)
        }
    }

    // 底部:条码 + 生成署名 + 数据胶囊
    private var footer: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                BarcodeStrip(tint: AppTheme.ink)
                    .frame(width: 110, height: 26)
                Text("由 EON 生成 · 仅供娱乐")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(AppTheme.tertiary)
            }
            Spacer()
            HStack(spacing: 6) {
                statChip(value: "\(stats.count)", label: "订阅")
                statChip(value: "\(stats.categoryCount)", label: "分类")
            }
        }
    }

    private func statChip(value: String, label: LocalizedStringKey) -> some View {
        VStack(spacing: 0) {
            Text(value)
                .font(.system(size: 18, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(AppTheme.ink)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(AppTheme.secondary)
        }
        .frame(minWidth: 52)
        .padding(.vertical, 7)
        .background(type.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(type.tint.opacity(0.25), lineWidth: 0.5))
    }

    // 卡面:surface 底 + 浅网格 + 顶部主题色微染
    private var cardBackground: some View {
        ZStack {
            AppTheme.surface
            GridPattern(spacing: 22, color: AppTheme.ink.opacity(0.045))
            RadialGradient(
                colors: [type.tint.opacity(0.12), .clear],
                center: UnitPoint(x: 0.5, y: 0.0), startRadius: 0, endRadius: 280)
        }
    }

    // 四角裁切标记,呼应包装海报的"印刷裁切线"
    private var cornerTicks: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let len: CGFloat = 12, inset: CGFloat = 14
            Path { p in
                // 左上
                p.move(to: CGPoint(x: inset, y: inset + len)); p.addLine(to: CGPoint(x: inset, y: inset)); p.addLine(to: CGPoint(x: inset + len, y: inset))
                // 右上
                p.move(to: CGPoint(x: w - inset - len, y: inset)); p.addLine(to: CGPoint(x: w - inset, y: inset)); p.addLine(to: CGPoint(x: w - inset, y: inset + len))
                // 左下
                p.move(to: CGPoint(x: inset, y: h - inset - len)); p.addLine(to: CGPoint(x: inset, y: h - inset)); p.addLine(to: CGPoint(x: inset + len, y: h - inset))
                // 右下
                p.move(to: CGPoint(x: w - inset - len, y: h - inset)); p.addLine(to: CGPoint(x: w - inset, y: h - inset)); p.addLine(to: CGPoint(x: w - inset, y: h - inset - len))
            }
            .stroke(AppTheme.ink.opacity(0.18), lineWidth: 1.2)
        }
        .allowsHitTesting(false)
    }

    private var shineOverlay: some View {
        GeometryReader { geo in
            let w = geo.size.width
            LinearGradient(colors: [.clear, .white.opacity(0.22), .clear],
                           startPoint: .top, endPoint: .bottom)
                .frame(width: w * 0.4)
                .rotationEffect(.degrees(22))
                .offset(x: shine ? w * 1.3 : -w * 1.3)
                .blendMode(.plusLighter)
        }
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var brandIcon: some View {
        if let ui = UIImage(named: "EONBrandIcon") {
            Image(uiImage: ui).resizable().scaledToFill()
                .frame(width: 24, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(type.tint)
                .frame(width: 24, height: 24)
                .overlay(Text(verbatim: "E").font(.system(size: 13, weight: .heavy, design: .rounded)).foregroundStyle(.white))
        }
    }
}

// MARK: - 订阅图标"装备格"

/// 单个订阅图标的"泡壳格":白底圆角 + 细描边 + App 图标,像潮玩包装里的配件。
private struct IconBlister: View {
    let subscription: Subscription
    let tint: Color

    var body: some View {
        CategoryGlyph(subscription: subscription, size: 38)
            .padding(9)
            .background(AppTheme.canvas, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.ink.opacity(0.12), lineWidth: 1))
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}

// MARK: - 装饰元素

/// 卡面浅网格(graph-paper 质感)。
private struct GridPattern: View {
    var spacing: CGFloat = 22
    var color: Color

    var body: some View {
        Canvas { ctx, size in
            var path = Path()
            var x: CGFloat = 0
            while x <= size.width { path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height)); x += spacing }
            var y: CGFloat = 0
            while y <= size.height { path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y)); y += spacing }
            ctx.stroke(path, with: .color(color), lineWidth: 0.5)
        }
    }
}

/// 纯装饰的"条码"——一排粗细随机但稳定的竖线,给海报增添包装感。
private struct BarcodeStrip: View {
    var tint: Color
    // 固定的一段条宽序列,保证每次渲染一致(也利于出图)。
    private let widths: [CGFloat] = [2, 1, 3, 1, 1, 2, 1, 3, 2, 1, 1, 2, 3, 1, 2, 1, 1, 3, 1, 2, 2, 1, 3, 1]

    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .center, spacing: 1.5) {
                ForEach(Array(widths.enumerated()), id: \.offset) { i, w in
                    Rectangle()
                        .fill(tint.opacity(i % 5 == 0 ? 0.35 : 0.8))
                        .frame(width: w)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .leading)
        }
    }
}

#Preview {
    NavigationStack { PersonalityView() }
        .environmentObject(SubscriptionStore())
}
