import SwiftUI
import UIKit

/// 「订阅人格」全屏蒙层弹窗:在变暗的 App 之上浮起一整张包装海报式卡片。
/// 中央是放大的人格形象,两侧像"装备"一样陈列用户订阅的 App 图标,配上标题 /
/// 标语 / 常驻分类 / 数据。进入时先放"正在生成卡片"的 loading,再把卡片连同两侧
/// 图标错峰弹出来;卡片支持拖拽 3D 倾斜、形象浮动、高光扫过。
struct PersonalityView: View {
    @EnvironmentObject private var store: SubscriptionStore
    @Environment(\.dismiss) private var dismiss

    private var type: PersonalityType { store.personality }

    /// loading 阶段(生成卡片);结束后切到卡片。
    @State private var isGenerating = true
    /// 卡片入场总开关:true 时卡片 + 两侧图标错峰弹入。
    @State private var play = false
    @State private var revealTick = 0
    @State private var cardImage: UIImage?

    /// 卡上要陈列的订阅图标:取活跃订阅前 6 个(两侧各最多 3 个)。
    private var iconSubs: [Subscription] { Array(store.activeSubscriptions.prefix(6)) }

    /// 分享卡片要展示的"隐私安全"数据:订阅数 + 分类数 + 订阅最多的分类(只放
    /// 聚合数字与分类名,不含金额、不含具体服务名)。
    private var shareStats: PersonaShareStats {
        let subs = store.activeSubscriptions
        let cats = Set(subs.map { $0.displayCategoryID })
        // 订阅条数最多的分类(不是按金额,而是按数量)。
        let groups = Dictionary(grouping: subs, by: { $0.displayCategoryID })
        let top = groups.max { $0.value.count < $1.value.count }
        return PersonaShareStats(
            count: subs.count,
            categoryCount: cats.count,
            topCategoryTitle: top?.value.first?.displayCategoryTitle,
            topCategoryCount: top?.value.count ?? 0
        )
    }

    var body: some View {
        ZStack {
            // 暗色蒙层 —— 点击空白处关闭。
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            // 卡片整体居中:topBar + 卡片一起作为 VStack,在屏高内垂直居中。
            // 这样分享 / 关闭按钮紧贴卡片顶部,而不是悬浮在屏幕最顶端。
            GeometryReader { geo in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppTheme.Space.s) {
                        topBar
                        PersonaPosterCard(type: type, subs: iconSubs, stats: shareStats, play: play)
                            .padding(.horizontal, AppTheme.Space.l)
                            .readableWidth(540)
                            .frame(maxWidth: .infinity)
                    }
                    .frame(minHeight: geo.size.height, alignment: .center)
                }
            }
            .opacity(play ? 1 : 0)
            .scaleEffect(play ? 1 : 0.94)

            // Loading 阶段的关闭按钮:卡片还没显示时保留一个 X 供用户随时退出。
            // 卡片出现(play = true)后淡出,由 topBar 里的 X 接管。
            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: { circleButton(system: "xmark") }
                }
                .padding(.horizontal, AppTheme.Space.l)
                .padding(.top, AppTheme.Space.s)
                Spacer()
            }
            .opacity(play ? 0 : 1)
            .animation(.easeOut(duration: 0.3), value: play)

            if isGenerating {
                GeneratingOverlay(tint: type.tint)
                    .transition(.opacity)
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: revealTick)
        .task { await generateAndReveal() }
    }

    // 顶部一行:分享 + 关闭(圆形玻璃按钮,紧贴卡片上方)。
    // 该 view 随卡片一起在 play=true 时出现,所以不需要自己的 opacity 控制。
    private var topBar: some View {
        HStack {
            if let img = cardImage {
                ShareLink(
                    item: Image(uiImage: img),
                    preview: SharePreview(Text(verbatim: "EON · \(type.name)"),
                                          image: Image(uiImage: img))
                ) {
                    circleButton(system: "square.and.arrow.up")
                }
            } else {
                // 占位,保持布局稳定(cardImage 在 play=true 前已经渲染好,极少为 nil)
                circleButton(system: "square.and.arrow.up").hidden()
            }
            Spacer()
            Button { dismiss() } label: { circleButton(system: "xmark") }
        }
        .padding(.horizontal, AppTheme.Space.l)
    }

    private func circleButton(system: String) -> some View {
        Image(systemName: system)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 38, height: 38)
            .background(Color.white.opacity(0.18), in: Circle())
            .overlay(Circle().stroke(.white.opacity(0.22), lineWidth: 0.5))
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
                    .stroke(.white.opacity(0.18), lineWidth: 6)
                    .frame(width: 84, height: 84)
                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(tint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 84, height: 84)
                    .rotationEffect(.degrees(spin ? 360 : 0))
                Image(systemName: "sparkles")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .scaleEffect(pulse ? 1.12 : 0.88)
            }
            Text("正在生成你的人格卡片…")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
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
    /// 订阅条数最多的分类名(可能没有)。
    let topCategoryTitle: String?
    /// 该分类下的订阅条数。
    let topCategoryCount: Int
}

/// 一整张"包装海报"式人格卡:头部品牌行 + 大标题 + 中央放大的形象(两侧散落陈列
/// 订阅图标)+ 底部一行数据 + 居中署名。屏幕上可拖拽轻微 3D 倾斜、形象上下浮动;
/// 用 ImageRenderer 出图分享时传 `forSharing` 关掉交互、用固定宽度。
private struct PersonaPosterCard: View {
    let type: PersonalityType
    let subs: [Subscription]
    let stats: PersonaShareStats
    var play: Bool
    var forSharing: Bool = false

    @State private var float = false
    @GestureState private var drag: CGSize = .zero

    private let corner: CGFloat = 30

    // 两侧图标的"随机"摆放(用固定序列,保证稳定 & 出图一致),让陈列不那么死板。
    private let jitterX: [CGFloat] = [-7, 11, -4, 9, -9, 5]
    private let jitterY: [CGFloat] = [5, -7, 9, -4, 7, -6]
    private let jitterRot: [Double] = [-9, 7, -5, 10, -7, 6]

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
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .stroke(AppTheme.ink.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: .black.opacity(forSharing ? 0 : 0.35), radius: 30, x: 0, y: 18)
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
                .font(.system(size: 33, weight: .heavy, design: .rounded))
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

    // 中央舞台:左列散落图标 + 放大的形象 + 右列散落图标
    private var stage: some View {
        HStack(alignment: .center, spacing: 2) {
            if !leftSubs.isEmpty {
                iconColumn(leftSubs, sideOffset: 0)
            }
            figure
            if !rightSubs.isEmpty {
                iconColumn(rightSubs, sideOffset: leftSubs.count)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 300)
    }

    // 两侧图标:无外框、带轻投影,按固定"随机"序列做旋转 / 偏移,显得不那么整齐。
    private func iconColumn(_ items: [Subscription], sideOffset: Int) -> some View {
        VStack(spacing: AppTheme.Space.m) {
            ForEach(Array(items.enumerated()), id: \.element.id) { i, sub in
                let g = (sideOffset + i) % jitterX.count
                PersonaIcon(subscription: sub)
                    .rotationEffect(.degrees(jitterRot[g]))
                    .offset(x: jitterX[g], y: jitterY[g])
                    .scaleEffect(play ? 1 : 0.4)
                    .opacity(play ? 1 : 0)
                    .animation(.spring(response: 0.55, dampingFraction: 0.65)
                        .delay(0.25 + Double(sideOffset + i) * 0.09), value: play)
            }
        }
        .frame(width: 58)
    }

    // 中央形象:放大的主题色光晕 + 透明抠图浮动。
    // 注意:用 `maxWidth: .infinity` + 固定高度的「填充式」光晕,**不要**用固定
    // 宽度的大 Circle —— 固定宽会把整张卡的最小宽度撑过屏幕,导致溢出。
    private var figure: some View {
        ZStack {
            RadialGradient(
                colors: [type.tint.opacity(0.42), type.tint.opacity(0.12), .clear],
                center: .center, startRadius: 0, endRadius: 170)
                .frame(height: 300)
                .blur(radius: 6)
            artwork
                .frame(maxWidth: .infinity, maxHeight: 288)
                .offset(y: float ? -9 : 9)
                .shadow(color: .black.opacity(0.22), radius: 16, x: 0, y: 12)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 300)
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
                .font(.system(size: 120, weight: .bold))
                .foregroundStyle(type.tint)
        }
    }

    // 底部:三个等宽等高的弱化数据胶囊(订阅 / 分类 / 最多订阅),下面居中署名。
    // 三个格子用 maxWidth: .infinity 均分 HStack 宽度,高度由 minHeight 锁齐。
    private var footer: some View {
        VStack(spacing: AppTheme.Space.m) {
            HStack(spacing: AppTheme.Space.s) {
                infoChip(value: "\(stats.count)", label: "订阅")
                infoChip(value: "\(stats.categoryCount)", label: "分类")
                if let title = stats.topCategoryTitle, stats.topCategoryCount > 0 {
                    infoChip(value: title, label: "最多订阅")
                }
            }
            Text("由 EON 生成 · 仅供娱乐")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppTheme.tertiary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    /// 统一的数据胶囊:三个格子外形、颜色完全一致,视觉弱化不抢主体。
    /// maxWidth: .infinity 配合父层 HStack 让三格平分宽度;minHeight 锁齐高度。
    private func infoChip(value: String, label: LocalizedStringKey) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(AppTheme.ink.opacity(0.65))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(AppTheme.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 48)
        .background(AppTheme.ink.opacity(0.05),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.ink.opacity(0.08), lineWidth: 0.5)
        )
    }

    // 卡面:surface 底 + 柔和主题色光团(mesh 质感)+ 科技点阵纹理 + 顶部微染。
    // 光团会被外层 clipShape 裁进圆角卡片内,营造现代科技感的层次。
    private var cardBackground: some View {
        ZStack {
            AppTheme.surface
            Circle()
                .fill(type.tint.opacity(0.16))
                .frame(width: 260, height: 260)
                .blur(radius: 70)
                .offset(x: -110, y: -90)
            Circle()
                .fill(type.tint.opacity(0.12))
                .frame(width: 220, height: 220)
                .blur(radius: 70)
                .offset(x: 130, y: 150)
            TechTexture(color: AppTheme.ink.opacity(0.06))
            RadialGradient(
                colors: [type.tint.opacity(0.10), .clear],
                center: UnitPoint(x: 0.5, y: 0.0), startRadius: 0, endRadius: 300)
        }
    }

    // 四角裁切标记,呼应包装海报的"印刷裁切线"
    private var cornerTicks: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let len: CGFloat = 12, inset: CGFloat = 14
            Path { p in
                p.move(to: CGPoint(x: inset, y: inset + len)); p.addLine(to: CGPoint(x: inset, y: inset)); p.addLine(to: CGPoint(x: inset + len, y: inset))
                p.move(to: CGPoint(x: w - inset - len, y: inset)); p.addLine(to: CGPoint(x: w - inset, y: inset)); p.addLine(to: CGPoint(x: w - inset, y: inset + len))
                p.move(to: CGPoint(x: inset, y: h - inset - len)); p.addLine(to: CGPoint(x: inset, y: h - inset)); p.addLine(to: CGPoint(x: inset + len, y: h - inset))
                p.move(to: CGPoint(x: w - inset - len, y: h - inset)); p.addLine(to: CGPoint(x: w - inset, y: h - inset)); p.addLine(to: CGPoint(x: w - inset, y: h - inset - len))
            }
            .stroke(AppTheme.ink.opacity(0.18), lineWidth: 1.2)
        }
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

// MARK: - 订阅图标

/// 两侧陈列的订阅图标:无外框,直接是 App 图标本身,加一层轻投影做出"漂浮"感。
private struct PersonaIcon: View {
    let subscription: Subscription

    var body: some View {
        CategoryGlyph(subscription: subscription, size: 46)
            .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 4)
    }
}

// MARK: - 装饰元素

/// 科技感点阵纹理:细线网格 + 交点小圆点,像 HUD / 蓝图底纹。
private struct TechTexture: View {
    var spacing: CGFloat = 20
    var color: Color

    var body: some View {
        Canvas { ctx, size in
            // 细线网格
            var lines = Path()
            var x: CGFloat = 0
            while x <= size.width { lines.move(to: CGPoint(x: x, y: 0)); lines.addLine(to: CGPoint(x: x, y: size.height)); x += spacing }
            var y: CGFloat = 0
            while y <= size.height { lines.move(to: CGPoint(x: 0, y: y)); lines.addLine(to: CGPoint(x: size.width, y: y)); y += spacing }
            ctx.stroke(lines, with: .color(color.opacity(0.5)), lineWidth: 0.5)

            // 交点小圆点(更强的色),做出"点阵"科技感
            var dots = Path()
            var gy: CGFloat = 0
            while gy <= size.height {
                var gx: CGFloat = 0
                while gx <= size.width {
                    dots.addEllipse(in: CGRect(x: gx - 0.9, y: gy - 0.9, width: 1.8, height: 1.8))
                    gx += spacing
                }
                gy += spacing
            }
            ctx.fill(dots, with: .color(color))
        }
    }
}

#Preview {
    NavigationStack { PersonalityView() }
        .environmentObject(SubscriptionStore())
}
