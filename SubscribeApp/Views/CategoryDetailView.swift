import SwiftUI

/// 从首页"支出分类"点进来的二级页。一行一张卡,卡片中心展示分类名 + 总金额,
/// 底部把这个分类里的订阅图标排开来。卡片背景用分类色做径向光晕,跟 Apple
/// Passwords 的 category 视图同款"色调引导"感觉。
struct CategoryDetailView: View {
    @EnvironmentObject private var store: SubscriptionStore

    /// 把 store.categorySpend(已聚合金额 + 分类元信息)跟每个分类下的实际订阅
    /// 配对起来,卡片渲染时直接消费。只取计入统计的订阅 —— 跟分类金额口径一致。
    private struct CategoryGroup: Identifiable {
        let id: String
        let title: String
        let color: Color
        let amount: Double
        let subs: [Subscription]
    }

    private var groups: [CategoryGroup] {
        store.categorySpend.map { spend in
            let subs = store.statisticsCountableSubscriptions
                .filter { $0.displayCategoryID == spend.id }
            return CategoryGroup(
                id: spend.id,
                title: spend.title,
                color: spend.color,
                amount: spend.amount,
                subs: subs
            )
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Space.m) {
                if groups.isEmpty {
                    VStack(spacing: AppTheme.Space.s) {
                        Image(systemName: "chart.pie")
                            .font(.system(size: 44, weight: .light))
                            .foregroundStyle(AppTheme.tertiary)
                        Text("暂无分类支出")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 120)
                } else {
                    ForEach(Array(groups.enumerated()), id: \.element.id) { i, g in
                        card(for: g).reveal(i)
                    }
                }
            }
            .padding(.horizontal, AppTheme.Space.xl)
            .padding(.top, AppTheme.Space.m)
            .padding(.bottom, AppTheme.dockClearance)
        }
        .background(AppTheme.canvas.ignoresSafeArea())
        .navigationTitle("支出分类")
        .navigationBarTitleDisplayMode(.inline)
        // 二级页隐掉底部 TabBar,避免遮住内容 + 让用户更专注。
    }

    @ViewBuilder
    private func card(for g: CategoryGroup) -> some View {
        ZStack {
            // 卡片底:surface + 一层径向分类色光晕。颜色感跟首页订阅卡片同源。
            AppTheme.surface
            RadialGradient(
                stops: [
                    .init(color: g.color.opacity(0.42), location: 0.00),
                    .init(color: g.color.opacity(0.20), location: 0.45),
                    .init(color: g.color.opacity(0.04), location: 0.85),
                    .init(color: .clear,                location: 1.00),
                ],
                center: UnitPoint(x: 0.50, y: 0.50),
                startRadius: 0,
                endRadius: 260
            )

            VStack(spacing: 10) {
                Text(g.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.ink)
                Text(store.converter.format(g.amount, currency: store.baseCurrency))
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(String(localized: "%lld 个订阅 · 月均").replacingOccurrences(of: "%lld", with: "\(g.subs.count)"))
                    .font(.caption2)
                    .foregroundStyle(AppTheme.secondary)
                if !g.subs.isEmpty {
                    iconRow(subs: g.subs)
                        .padding(.top, 6)
                }
            }
            .padding(.vertical, AppTheme.Space.l)
            .padding(.horizontal, AppTheme.Space.l)
            .frame(maxWidth: .infinity)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius))
        .glassBorder()
    }

    /// 底部那一排订阅图标。最多展示 8 个,超过用 "+N" 简略指示还有几个没显示。
    /// 故意不排得整整齐齐 —— 每个图标按 id 派生一组稳定的"乱序"参数(上下偏移 +
    /// 轻微旋转 + 微缩放),做出"随手撒在桌上"的松散感,比一字排开更有生活气。
    /// 用 id 哈希派生保证同一进程内滚动时不抖动。
    @ViewBuilder
    private func iconRow(subs: [Subscription]) -> some View {
        let visible = Array(subs.prefix(8))
        let overflow = max(0, subs.count - 8)
        HStack(spacing: 2) {
            ForEach(visible) { sub in
                let j = Self.jitter(for: sub)
                CategoryGlyph(subscription: sub, size: 36)
                    .shadow(color: .black.opacity(0.14), radius: 3, x: 0, y: 2)
                    .scaleEffect(j.scale)
                    .rotationEffect(.degrees(j.angle))
                    .offset(y: j.dy)
                    .zIndex(j.z)
            }
            if overflow > 0 {
                Text("+\(overflow)")
                    .font(.caption.weight(.heavy).monospacedDigit())
                    .foregroundStyle(AppTheme.secondary)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 10))
                    .glassBorder(cornerRadius: 10)
            }
        }
        // 给整排留一点上下余量,免得旋转 + 偏移后的图标被卡片裁掉边角。
        .padding(.vertical, 8)
    }

    /// 由订阅 id 派生的稳定"乱序"参数。同一 id 在一次运行内永远得到同一组值,
    /// 所以图标不会在滚动 / 重绘时乱跳。
    private static func jitter(for sub: Subscription) -> (dy: CGFloat, angle: Double, scale: CGFloat, z: Double) {
        let h = abs(sub.id.uuidString.hashValue)
        let dy = CGFloat(h % 11) - 5            // -5...5 pt 上下错位
        let angle = Double((h / 11) % 19) - 9   // -9...9 度倾斜
        let scale = 0.9 + CGFloat((h / 211) % 5) * 0.05  // 0.90...1.10 微缩放
        let z = Double((h / 23) % 7)            // 随机叠放层级,重叠时谁压谁不固定
        return (dy, angle, scale, z)
    }
}

#Preview {
    NavigationStack { CategoryDetailView() }
        .environmentObject(SubscriptionStore())
}
