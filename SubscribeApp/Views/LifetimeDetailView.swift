import SwiftUI

/// 从首页"累计支付"卡片点进来的二级页。展示全部计入统计的活跃订阅,按累计
/// 支付金额降序;每行能看到该订阅自创建以来的累计金额、已扣费次数、单次价格。
/// 顶部是一个 Hero 卡:大字号总额 + 笔数。
struct LifetimeDetailView: View {
    @EnvironmentObject private var store: SubscriptionStore
    @State private var receiptImage: UIImage?
    @State private var showReceipt = false
    /// 小票出图比较慢(ImageRenderer 同步、3x、行数多),给个全屏 loading 态。
    @State private var isRendering = false

    /// 所有计入统计的活跃订阅,按累计支付金额从高到低。归档 / 不计入统计的不包含。
    private var subs: [Subscription] {
        store.statisticsCountableSubscriptions
            .filter { $0.billingCountElapsed() > 0 }  // 0 次扣费的也不展示,没东西可看
            .sorted {
                $0.lifetimeSpend(in: store.baseCurrency, converter: store.converter)
                > $1.lifetimeSpend(in: store.baseCurrency, converter: store.converter)
            }
    }

    private var total: Double { store.totalLifetimeSpend }
    private var totalCount: Int { store.totalLifetimeChargeCount }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Space.l) {
                heroCard
                if subs.isEmpty {
                    emptyState
                } else {
                    listCard
                }
            }
            .padding(.horizontal, AppTheme.Space.xl)
            .padding(.top, AppTheme.Space.m)
            .padding(.bottom, AppTheme.dockClearance)
        }
        .background(AppTheme.canvas.ignoresSafeArea())
        .navigationTitle("累计支付")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                // "Print" —— 把累计消费打成一张超市小票样式的图片。
                Button {
                    Task { await generateReceipt() }
                } label: {
                    Label("Print", systemImage: "printer")
                }
                .disabled(subs.isEmpty || isRendering)
            }
        }
        .sheet(isPresented: $showReceipt) {
            if let img = receiptImage {
                ReceiptPreviewSheet(image: img)
            }
        }
        // 出图 loading 态:盖满全屏,转圈 + 文案,告诉用户"在生成,稍等"。
        .overlay {
            if isRendering {
                ZStack {
                    Color.black.opacity(0.45).ignoresSafeArea()
                    VStack(spacing: 14) {
                        ProgressView().tint(.white).scaleEffect(1.3)
                        Text("正在生成小票…")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text("正在汇总你的消费记录…")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    .padding(.horizontal, 30).padding(.vertical, 24)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                }
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: isRendering)
    }

    /// 先把 loading 推上来并让它渲染一帧,再做(同步、稍慢的)出图,最后弹预览。
    @MainActor
    private func generateReceipt() async {
        isRendering = true
        // 让 loading UI 先画出来(否则同步出图会把这一帧也卡住)。
        try? await Task.sleep(nanoseconds: 80_000_000)
        renderReceipt()
        isRendering = false
        if receiptImage != nil { showReceipt = true }
    }

    /// 把累计消费按时间顺序烤成一张小票图。按 effectiveStartDate 升序(从最早订到
    /// 最新),最贴近"消费历史"的直觉。日期 / 金额走当前地区格式。
    @MainActor
    private func renderReceipt() {
        let chrono = subs.sorted { $0.effectiveStartDate < $1.effectiveStartDate }
        let lines: [ReceiptLine] = chrono.map { sub in
            let unit = store.converter.convert(sub.price, from: sub.currency, to: store.baseCurrency)
            let count = sub.billingCountElapsed()
            let lifetime = sub.lifetimeSpend(in: store.baseCurrency, converter: store.converter)
            return ReceiptLine(
                name: sub.name,
                detail: "\(store.converter.format(unit, currency: store.baseCurrency)) x \(count)",
                amount: store.converter.format(lifetime, currency: store.baseCurrency)
            )
        }
        let df = DateFormatter()
        df.locale = .current
        df.dateStyle = .medium
        df.timeStyle = .short
        // 单号:用日期 + 时间拼一个看起来像收银流水号的东西。
        let noFmt = DateFormatter()
        noFmt.dateFormat = "MMddHHmm"
        let receipt = ReceiptView(
            lines: lines,
            totalText: store.converter.format(total, currency: store.baseCurrency),
            chargeCount: totalCount,
            dateText: df.string(from: Date()),
            receiptNo: "EON-" + noFmt.string(from: Date())
        )
        let renderer = ImageRenderer(content: receipt)
        renderer.scale = 3
        receiptImage = renderer.uiImage
    }

    // MARK: - 顶部总额卡

    @ViewBuilder
    private var heroCard: some View {
        VStack(spacing: AppTheme.Space.s) {
            Text("总累计")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.secondary)
                .textCase(.uppercase)
                .tracking(0.8)

            Text(store.converter.format(total, currency: store.baseCurrency))
                .font(.system(size: 38, weight: .heavy, design: .rounded))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text(String(localized: "覆盖 \(subs.count) 个订阅 · 共 \(totalCount) 笔扣费"))
                .font(.caption)
                .foregroundStyle(AppTheme.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.Space.xl)
        .padding(.horizontal, AppTheme.Space.l)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.radius))
        .glassBorder()
    }

    // MARK: - 订阅明细

    @ViewBuilder
    private var listCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(subs.enumerated()), id: \.element.id) { i, sub in
                if i > 0 { Hairline() }
                row(rank: i + 1, sub: sub).reveal(i)
            }
        }
        .padding(AppTheme.Space.s)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.radius))
        .glassBorder()
    }

    @ViewBuilder
    private func row(rank: Int, sub: Subscription) -> some View {
        let lifetime = sub.lifetimeSpend(in: store.baseCurrency, converter: store.converter)
        let count = sub.billingCountElapsed()
        let perCharge = store.converter.convert(sub.price, from: sub.currency, to: store.baseCurrency)

        HStack(spacing: AppTheme.Space.m) {
            // 名次徽章 —— 前 3 名 accent 高亮,后面用 tertiary,做出"排行榜"的层级
            Text("\(rank)")
                .font(.caption.weight(.heavy).monospacedDigit())
                .foregroundStyle(rank <= 3 ? AppTheme.accent : AppTheme.tertiary)
                .frame(width: 20, alignment: .center)

            CategoryGlyph(subscription: sub, size: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text(sub.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                // 单次价格 × 已扣次数 = 累计 —— 一行给透三个数,用户秒懂账面怎么来的
                Text(String(localized: "\(store.converter.format(perCharge, currency: store.baseCurrency)) × \(count) 次"))
                    .font(.caption2)
                    .foregroundStyle(AppTheme.secondary)
                    .monospacedDigit()
            }

            Spacer(minLength: AppTheme.Space.s)

            VStack(alignment: .trailing, spacing: 2) {
                Text(store.converter.format(lifetime, currency: store.baseCurrency))
                    .font(.amount())
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(sub.displayCategoryTitle)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, AppTheme.Space.m)
        .padding(.vertical, AppTheme.Space.s)
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: AppTheme.Space.s) {
            Image(systemName: "creditcard")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(AppTheme.tertiary)
            Text("还没有产生过实际扣费")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }
}

#Preview {
    NavigationStack { LifetimeDetailView() }
        .environmentObject(SubscriptionStore())
}
