import SwiftUI

struct SubscriptionsView: View {
    @EnvironmentObject private var store: SubscriptionStore
    @State private var editing: Subscription?
    @State private var search = ""
    @State private var sort: SortOption = .renewalDate
    /// 视图换算口径:把所有订阅的金额换算到这个周期下展示(月/季/年)。
    /// 例:年付订阅 ¥120 在"按月"下显示 ¥10/月,在"按季"下显示 ¥30/季。
    @State private var viewPeriod: ViewPeriod = .monthly
    /// 拖拽归档刚发生 → 顶部弹一个 "归档了 · 撤销" toast。
    /// 4 秒内点撤销可以恢复;过了就消失。
    @State private var recentlyArchived: Subscription?
    @State private var archiveHapticTick: Int = 0

    /// 阶段触觉的两个中间分位,基于 progress (0..1) 划分。
    private let stage1: CGFloat = 0.45
    private let stage2: CGFloat = 0.85

    private var rows: [Subscription] {
        let f = store.subscriptions.filter { sub in
            guard !sub.isArchived else { return false }
            return search.isEmpty
                || sub.name.localizedCaseInsensitiveContains(search)
                || sub.plan.localizedCaseInsensitiveContains(search)
                || sub.displayCategoryTitle.localizedCaseInsensitiveContains(search)
                || sub.category.rawValue.localizedCaseInsensitiveContains(search)
        }
        switch sort {
        case .renewalDate: return f.sorted { $0.nextBillingDate < $1.nextBillingDate }
        case .duration: return f.sorted {
            $0.billingCycle.days(customDays: $0.customCycleDays) > $1.billingCycle.days(customDays: $1.customCycleDays) }
        case .cost: return f.sorted {
            $0.monthlyCost(in: store.baseCurrency, converter: store.converter)
            > $1.monthlyCost(in: store.baseCurrency, converter: store.converter) }
        case .name: return f.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Space.l) {
                    // 搜索框跟随页面滚动,不再吸顶 —— 仅在用户主动滚回顶部
                    // 才看得到,避免占住固定可视区。
                    searchBar.reveal(0)

                    if rows.isEmpty {
                        VStack(spacing: AppTheme.Space.m) {
                            Image(systemName: "rectangle.stack").font(.system(size: 40, weight: .light))
                                .foregroundStyle(AppTheme.tertiary)
                            Text(search.isEmpty ? "还没有订阅" : "没有匹配的订阅")
                                .font(.headline).foregroundStyle(AppTheme.ink)
                        }.frame(maxWidth: .infinity).padding(.top, 100).reveal(1)
                    } else {
                        LazyVStack(spacing: AppTheme.Space.m) {
                            ForEach(Array(rows.enumerated()), id: \.element.id) { i, sub in
                                // 不再外包一层 Button —— Row 自己用 .onTapGesture
                                // 处理点击,因为它内部已经把 DragGesture 接管掉了
                                // (按钮 + 拖拽手势会互相打架,左拉的时候会被按钮
                                // 误触发"点击")。
                                Row(
                                    subscription: sub,
                                    viewPeriod: viewPeriod,
                                    onTap: { editing = sub },
                                    onArchive: { archiveByDrag(sub) },
                                    onDelete: { store.delete(ids: [sub.id]) }
                                )
                                .reveal(i + 1)
                            }
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Space.xl)
                .padding(.top, AppTheme.Space.m)
                .padding(.bottom, AppTheme.dockClearance)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppTheme.canvas.ignoresSafeArea())
            .safeAreaInset(edge: .top, spacing: 0) {
                // 吸顶只保留 月/季/年 + 排序按钮,不带底板,跟 Overview 一致。
                stickyHeader
                    .padding(.horizontal, AppTheme.Space.xl)
                    .padding(.top, AppTheme.Space.s)
                    .padding(.bottom, AppTheme.Space.s)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $editing) { SubscriptionEditorView(subscription: $0) }
            // 拖拽归档后的 toast,4 秒内可撤销。挂在底部 safeAreaInset 上,不挡
            // 列表头部的吸顶按钮。
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if let archived = recentlyArchived {
                    archiveToast(for: archived)
                        .padding(.horizontal, AppTheme.Space.xl)
                        .padding(.bottom, AppTheme.Space.s)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: recentlyArchived?.id)
            .sensoryFeedback(.impact(weight: .heavy), trigger: archiveHapticTick)
        }
    }

    // MARK: - Drag-to-archive plumbing

    /// 拖拽到位置后执行归档,记一次 toast 状态,4 秒后自动清除。
    private func archiveByDrag(_ sub: Subscription) {
        store.archive(ids: [sub.id])
        archiveHapticTick &+= 1
        recentlyArchived = sub
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            // 只清自己,不要把后续可能弹出的新 toast 顺手抹掉
            if recentlyArchived?.id == sub.id {
                recentlyArchived = nil
            }
        }
    }

    /// 撤销 toast 卡片 —— 浮在底部 TabBar 上方,左侧 archive 图标 + 文字,右侧
    /// "撤销" 按钮。
    @ViewBuilder
    private func archiveToast(for sub: Subscription) -> some View {
        HStack(spacing: AppTheme.Space.m) {
            Image(systemName: "archivebox.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text(String(localized: "已归档「\(sub.name)」"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                Text("4 秒内可撤销")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.tertiary)
            }
            Spacer()
            Button {
                store.restore(ids: [sub.id])
                recentlyArchived = nil
            } label: {
                Text("撤销")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.accent)
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(AppTheme.accent.opacity(0.14), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppTheme.Space.m)
        .padding(.vertical, 10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.radius))
        .overlay(RoundedRectangle(cornerRadius: AppTheme.radius).stroke(AppTheme.hairline, lineWidth: 0.5))
    }

    /// 吸顶部分:仅 月/季/年 胶囊 + 排序圆按钮,没有底板。
    @ViewBuilder
    private var stickyHeader: some View {
        HStack(spacing: AppTheme.Space.m) {
            SegmentedPill(
                selection: $viewPeriod,
                items: ViewPeriod.allCases.map { ($0, $0.title) }
            )
            .frame(maxWidth: 200)   // 跟 Overview 同款最小宽度

            Spacer()

            Menu {
                Picker("", selection: $sort) {
                    ForEach(SortOption.allCases) {
                        Label($0.title, systemImage: $0.icon).tag($0)
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.ink)
                    .frame(width: 40, height: 40)
                    .glassEffect(.regular, in: Capsule())
            }
        }
    }

    /// 搜索框 —— 跟着内容滚动,顶部初始可见,滚下去就消失。
    @ViewBuilder
    private var searchBar: some View {
        HStack(spacing: AppTheme.Space.s) {
            Image(systemName: "magnifyingglass").foregroundStyle(AppTheme.tertiary)
            TextField("搜索名称、套餐或分类", text: $search)
                .textInputAutocapitalization(.never)
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(AppTheme.tertiary)
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, AppTheme.Space.m)
        .padding(.vertical, 10)
        .background(AppTheme.surface, in: Capsule())
        .overlay(Capsule().stroke(AppTheme.hairline, lineWidth: 0.5))
    }
}

private enum SortOption: String, CaseIterable, Identifiable {
    case renewalDate, duration, cost, name
    var id: String { rawValue }
    var title: String {
        switch self {
        case .renewalDate: String(localized: "按时间"); case .duration: String(localized: "按周期长度")
        case .cost: String(localized: "按费用"); case .name: String(localized: "按名称")
        }
    }
    var icon: String {
        switch self {
        case .renewalDate: "calendar"; case .duration: "timer"
        case .cost: "banknote"; case .name: "textformat"
        }
    }
}

/// 列表换算口径(把任意周期的订阅都摊到指定时间单位下展示)。
enum ViewPeriod: String, CaseIterable, Identifiable, Hashable {
    case monthly, quarterly, yearly
    var id: String { rawValue }
    /// 用 "周期·X" 短 key,跟 Overview 的 SpendPeriod 共享缩写翻译,胶囊宽度一致。
    var title: String {
        switch self {
        case .monthly:   String(localized: "周期·月")
        case .quarterly: String(localized: "周期·季")
        case .yearly:    String(localized: "周期·年")
        }
    }
    /// 月费乘上这个系数 = 该周期对应金额。
    var monthlyMultiplier: Double {
        switch self {
        case .monthly: 1
        case .quarterly: 3
        case .yearly: 12
        }
    }
    /// 金额后的紧凑后缀。
    var suffix: String {
        switch self {
        case .monthly:   String(localized: "/月")
        case .quarterly: String(localized: "/季")
        case .yearly:    String(localized: "/年")
        }
    }
}

private struct Row: View {
    @EnvironmentObject private var store: SubscriptionStore
    @Environment(\.colorScheme) private var colorScheme
    let subscription: Subscription
    let viewPeriod: ViewPeriod
    let onTap: () -> Void
    let onArchive: () -> Void
    let onDelete: () -> Void

    private var colored: Bool { store.coloredSubscriptionCards }
    private var isDark: Bool { colorScheme == .dark }

    // MARK: - Drag-to-archive state
    //
    // 用户左拉卡片,过了 60% 宽度松手就归档。dragX 跟手指实时同步:< 0 = 拖向
    // 左边;红色 archive 背景的透明度按这个值线性变浓,松手时若过阈值则:
    //  1) onArchive 通知父层
    //  2) 卡片飞出屏幕(动画到 -screenWidth)
    // 否则弹回原位。

    /// 当前 X 位移。负值 = 往左拉。
    @State private var dragX: CGFloat = 0
    /// 是否已经触发了归档(避免动画/手势竞态导致重复触发)。
    @State private var isArchivedLocally = false
    /// 拖拽过半时给一次轻微的 tick,提示"已经过阈值,松手就执行"。
    @State private var thresholdTick: Int = 0
    /// 直接用绝对像素阈值代替 "卡片宽度 × 比例"。这样 Row 不再需要 GeometryReader
    /// 来测自身宽,在 LazyVStack 里几十张卡片同时存在时,滚动 / 拖拽性能显著好得多
    /// —— 之前每行都会跑一次 layout 测量,拖一下就触发几十次重排。
    private let archiveThresholdPoints: CGFloat = 130

    /// 卡片底色:.tile 取色号,.image 取图像平均色,均回退分类色(自定义优先)。
    private var cardColor: Color {
        switch subscription.icon {
        case .tile(_, let hex):
            return hex.map { Color(hexString: $0) } ?? subscription.displayCategoryColor
        case .image(let id):
            if let ui = IconStore.averageColor(id) { return Color(uiColor: ui) }
            return subscription.displayCategoryColor
        }
    }

    /// 在当前 viewPeriod 口径下,该订阅折算到的金额(已换算到 baseCurrency)。
    private var displayedAmount: Double {
        let monthly = subscription.monthlyCost(in: store.baseCurrency, converter: store.converter)
        return monthly * viewPeriod.monthlyMultiplier
    }

    /// 副标题:精简显示。优先「套餐 · 分类」;套餐为空时只展示分类。
    /// 周期不再展示在这里,因为整页已经统一了换算口径(/月 /季 /年)。
    private var subtitle: String {
        let plan = subscription.plan.trimmingCharacters(in: .whitespaces)
        if plan.isEmpty { return subscription.displayCategoryTitle }
        return "\(plan) · \(subscription.displayCategoryTitle)"
    }

    var body: some View {
        let threshold = archiveThresholdPoints
        let passedThreshold = -dragX >= threshold

        ZStack(alignment: .trailing) {
            // accent 色"归档"背景层 —— 卡片往左滑时跟着露出来,过阈值后变成实心
            archiveBackground(passedThreshold: passedThreshold,
                              progress: min(1, -dragX / threshold))

            // 真正的卡片 —— 沿 X 平移;触发归档后会被父层从列表里删掉,我们也
            // 让它一次性飞出屏幕左侧。彩蛋关掉的时候完全不挂 DragGesture,
            // 卡片只剩点击 → 编辑的原行为。
            if store.easterEggs.dragToArchive {
                cardContent
                    .offset(x: dragX)
                    .gesture(
                        DragGesture(minimumDistance: 12)
                            .onChanged { value in
                                guard !isArchivedLocally else { return }
                                // 只响应向左的拖拽;向右拖一律忽略,免得跟系统 swipe-back 冲突
                                if value.translation.width > 0 {
                                    if dragX != 0 { dragX = 0 }
                                    return
                                }
                                let prev = dragX
                                dragX = value.translation.width
                                // 跨阈值瞬间一次中度震感,给"已上膛"的反馈
                                if -prev < threshold && -dragX >= threshold {
                                    thresholdTick &+= 1
                                }
                            }
                            .onEnded { value in
                                guard !isArchivedLocally else { return }
                                if -value.translation.width >= threshold {
                                    // 飞出屏幕 + 通知父层。-600 足够覆盖任何 iPhone 宽度。
                                    isArchivedLocally = true
                                    withAnimation(.easeIn(duration: 0.22)) {
                                        dragX = -600
                                    }
                                    Task { @MainActor in
                                        try? await Task.sleep(nanoseconds: 180_000_000)
                                        onArchive()
                                    }
                                } else {
                                    // 弹回原位
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                        dragX = 0
                                    }
                                }
                            }
                    )
                    .onTapGesture(perform: onTap)
            } else {
                cardContent.onTapGesture(perform: onTap)
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: thresholdTick)
    }

    /// 右侧露出来的"归档"背景。底色跟随主题(AppTheme.accent),过阈值变实心。
    /// 之前用纯红色,跟主题切换割裂,看起来像系统警告;改成 accent 后语义是
    /// "你即将归档" 而不是"危险操作"。
    @ViewBuilder
    private func archiveBackground(passedThreshold: Bool, progress: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: AppTheme.radius)
            .fill(AppTheme.accent.opacity(passedThreshold ? 0.95 : 0.55))
            .overlay(alignment: .trailing) {
                HStack(spacing: 8) {
                    Image(systemName: "archivebox.fill")
                        .font(.subheadline.weight(.bold))
                    Text(passedThreshold ? "松手归档" : "归档")
                        .font(.subheadline.weight(.semibold))
                        .contentTransition(.opacity)
                }
                .foregroundStyle(.white)
                .padding(.trailing, AppTheme.Space.l)
                .opacity(min(1, progress * 1.5))
                .scaleEffect(passedThreshold ? 1.08 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: passedThreshold)
            }
    }

    /// 原本的卡片内容 —— 跟拖拽机制无关,逻辑全在这里面。
    @ViewBuilder
    private var cardContent: some View {
        HStack(spacing: AppTheme.Space.m) {
            CategoryGlyph(subscription: subscription, size: 44)
                .shadow(color: colored ? .black.opacity(isDark ? 0.25 : 0.10) : .clear,
                        radius: 6, x: 0, y: 3)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(subscription.name).font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                    if subscription.status == .trial {
                        Text("试用").font(.caption2.weight(.bold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(AppTheme.accent.opacity(0.14), in: Capsule())
                            .foregroundStyle(AppTheme.accent)
                    }
                    // 用户明确关闭了"计入统计" → 用一个低调灰色徽章告诉他,
                    // 免得回头看着 Hero 总额对不上发懵。
                    if !subscription.includeInStatistics {
                        Text("不计入")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(AppTheme.tertiary.opacity(0.18), in: Capsule())
                            .foregroundStyle(AppTheme.secondary)
                    }
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: AppTheme.Space.s)
            VStack(alignment: .trailing, spacing: 4) {
                // 不再展示 /月 /季 /年 后缀 —— 整页顶部的视图切换已经表明了口径,
                // 在每张卡片上再写一次是冗余。
                Text(store.converter.format(displayedAmount, currency: store.baseCurrency))
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                // "已扣 N 次"小徽章 —— 默默告诉用户这笔订阅累计已经付过几次费,
                // 跟下方的下次扣费日叠在一起,垂直空间也不太挤。
                let billed = subscription.billingCountElapsed()
                if billed > 0 {
                    Text(String(localized: "已扣 \(billed) 次"))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(AppTheme.secondary)
                }
                Text(subscription.nextBillingDate.formatted(.dateTime.month().day()))
                    .font(.caption2)
                    .foregroundStyle(AppTheme.tertiary)
            }
            Menu {
                Button { onArchive() } label: {
                    Label("归档", systemImage: "archivebox")
                }
                Divider()
                Button(role: .destructive, action: onDelete) {
                    Label("删除", systemImage: "trash")
                }
                .tint(.red)
            } label: {
                Image(systemName: "ellipsis").font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.tertiary)
                    .frame(width: 28, height: 36)
            }
        }
        .padding(AppTheme.Space.l)
        .background(coloredCardBackground)
        .glassBorder()
        .opacity(subscription.isActive ? 1 : 0.5)
    }

    /// 卡片底色 = AppTheme.surface(自动适配明暗模式)+ icon 主色径向光晕。
    /// 光晕透明度在浅色模式下显著降低,避免在白底页面里"突兀"。
    /// 深色模式还保留 Apple Library 那种"暗玻璃 + 浓色光晕"的味道。
    @ViewBuilder
    private var coloredCardBackground: some View {
        if colored {
            ZStack {
                AppTheme.surface

                // 深色模式才需要的顶部 sheen + 底部 shadow(浅色模式上加这层就脏了)
                if isDark {
                    LinearGradient(
                        colors: [.white.opacity(0.04), .clear, .black.opacity(0.18)],
                        startPoint: .top, endPoint: .bottom
                    )
                }

                // 左侧色彩光晕 —— 加密 stop 数量、扩大 endRadius,让右半边的衰减
                // 更平滑,不再有"突然消失"的硬边。
                RadialGradient(
                    stops: [
                        .init(color: cardColor.opacity(isDark ? 0.95 : 0.38), location: 0.00),
                        .init(color: cardColor.opacity(isDark ? 0.70 : 0.27), location: 0.20),
                        .init(color: cardColor.opacity(isDark ? 0.45 : 0.18), location: 0.40),
                        .init(color: cardColor.opacity(isDark ? 0.25 : 0.10), location: 0.60),
                        .init(color: cardColor.opacity(isDark ? 0.10 : 0.04), location: 0.80),
                        .init(color: cardColor.opacity(isDark ? 0.03 : 0.01), location: 0.92),
                        .init(color: .clear,                                  location: 1.00),
                    ],
                    center: UnitPoint(x: 0.13, y: 0.50),
                    startRadius: 0,
                    endRadius: 320  // 比卡片宽更大一点,让边缘自然消逝在卡片外
                )

                // 深色模式上的玻璃反光高光 —— 浅色下加白色高光等于没加,直接跳过。
                if isDark {
                    LinearGradient(
                        colors: [.white.opacity(0.06), .clear],
                        startPoint: .top, endPoint: .center
                    )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius))
        } else {
            AppTheme.surface.clipShape(RoundedRectangle(cornerRadius: AppTheme.radius))
        }
    }

}

#Preview {
    SubscriptionsView().environmentObject(SubscriptionStore())
}
