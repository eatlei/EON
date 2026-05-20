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
        .toolbar(.hidden, for: .tabBar)
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
    @ViewBuilder
    private func iconRow(subs: [Subscription]) -> some View {
        let visible = Array(subs.prefix(8))
        let overflow = max(0, subs.count - 8)
        HStack(spacing: 6) {
            ForEach(visible) { sub in
                CategoryGlyph(subscription: sub, size: 36)
                    .shadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 2)
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
    }
}

#Preview {
    NavigationStack { CategoryDetailView() }
        .environmentObject(SubscriptionStore())
}
