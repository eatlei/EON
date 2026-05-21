import SwiftUI

/// 订阅详情弹窗。从「总览」/「订阅」列表点一条订阅时,先弹这个(约半屏高度),
/// 把所有信息一次性铺出来给用户看;右上角「编辑」再进现有的编辑器修改。
///
/// 这里按 id 从 store 实时读取订阅,而不是持有快照 —— 这样在弹窗里点编辑、改完
/// 保存,回到这个弹窗能立刻看到最新数据,不会显示旧值。
struct SubscriptionDetailSheet: View {
    @EnvironmentObject private var store: SubscriptionStore
    @Environment(\.dismiss) private var dismiss
    let subscriptionID: UUID
    @State private var editing: Subscription?

    private var sub: Subscription? {
        store.subscriptions.first { $0.id == subscriptionID }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let sub {
                    detail(for: sub)
                } else {
                    // 极少数情况:订阅在别处(比如另一台设备同步)被删了。
                    VStack(spacing: AppTheme.Space.m) {
                        Image(systemName: "questionmark.folder")
                            .font(.system(size: 40, weight: .light))
                            .foregroundStyle(AppTheme.tertiary)
                        Text("订阅已不存在").foregroundStyle(AppTheme.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(AppTheme.canvas.ignoresSafeArea())
            .navigationTitle("订阅详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        if let sub { editing = sub }
                    } label: {
                        Label("编辑", systemImage: "square.and.pencil")
                    }
                    .disabled(sub == nil)
                }
            }
        }
        // 编辑器盖在详情弹窗之上;保存后回落到详情,详情按 id 重新读取 → 自动刷新。
        .sheet(item: $editing) { s in
            SubscriptionEditorView(subscription: s)
                .environmentObject(store)
        }
    }

    // MARK: - 详情主体

    @ViewBuilder
    private func detail(for sub: Subscription) -> some View {
        ScrollView {
            VStack(spacing: AppTheme.Space.l) {
                header(sub)
                amountCard(sub)
                scheduleCard(sub)
                recordCard(sub)
                otherCard(sub)
            }
            .padding(.horizontal, AppTheme.Space.xl)
            .padding(.top, AppTheme.Space.m)
            .padding(.bottom, AppTheme.Space.xxl)
        }
    }

    @ViewBuilder
    private func header(_ sub: Subscription) -> some View {
        VStack(spacing: AppTheme.Space.s) {
            CategoryGlyph(subscription: sub, size: 72)
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
            Text(sub.name)
                .font(.title3.weight(.heavy))
                .foregroundStyle(AppTheme.ink)
                .multilineTextAlignment(.center)
            HStack(spacing: 6) {
                Text(sub.displayCategoryTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(sub.displayCategoryColor)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(sub.displayCategoryColor.opacity(0.14), in: Capsule())
                statusBadge(sub.status)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, AppTheme.Space.s)
    }

    @ViewBuilder
    private func statusBadge(_ status: RenewalStatus) -> some View {
        let tint: Color = {
            switch status {
            case .active:  return AppTheme.accent
            case .manual:  return AppTheme.accent
            case .trial:   return .orange
            case .paused:  return AppTheme.secondary
            }
        }()
        Text(status.title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(tint.opacity(0.14), in: Capsule())
    }

    // MARK: - 卡片们

    private func amountCard(_ sub: Subscription) -> some View {
        let monthly = sub.monthlyCost(in: store.baseCurrency, converter: store.converter)
        return infoCard(title: "金额") {
            DetailRow(label: "价格", value: store.converter.format(sub.price, currency: sub.currency))
            Hairline()
            DetailRow(label: "折合月均", value: "≈ " + store.converter.format(monthly, currency: store.baseCurrency))
            Hairline()
            DetailRow(label: "扣费周期", value: cycleText(sub))
        }
    }

    private func scheduleCard(_ sub: Subscription) -> some View {
        let upcoming = sub.upcomingBillingDate()
        return infoCard(title: "时间") {
            DetailRow(label: "下次扣费",
                      value: dateText(upcoming),
                      hint: daysText(upcoming))
            Hairline()
            DetailRow(label: "开始时间", value: dateText(sub.effectiveStartDate))
            if let end = sub.endDate {
                Hairline()
                DetailRow(label: "结束日期", value: dateText(end),
                          hint: String(localized: "到期自动归档"))
            }
            Hairline()
            DetailRow(label: "提前提醒",
                      value: sub.reminderDaysBefore == 0
                        ? String(localized: "不提醒")
                        : String(localized: "提前 \(sub.reminderDaysBefore) 天"))
        }
    }

    private func recordCard(_ sub: Subscription) -> some View {
        let billed = sub.billingCountElapsed()
        let lifetime = sub.lifetimeSpend(in: store.baseCurrency, converter: store.converter)
        return infoCard(title: "记录") {
            DetailRow(label: "已扣费次数", value: String(localized: "\(billed) 次"))
            Hairline()
            DetailRow(label: "累计支付", value: store.converter.format(lifetime, currency: store.baseCurrency))
        }
    }

    private func otherCard(_ sub: Subscription) -> some View {
        infoCard(title: "其他") {
            DetailRow(label: "套餐", value: sub.plan.isEmpty ? String(localized: "无") : sub.plan)
            Hairline()
            DetailRow(label: "支付方式", value: sub.paymentMethod.isEmpty ? String(localized: "无") : sub.paymentMethod)
            Hairline()
            DetailRow(label: "计入统计",
                      value: sub.includeInStatistics ? String(localized: "是") : String(localized: "否"),
                      hint: sub.includeInStatistics ? nil : String(localized: "不算进支出总额"))
        }
    }

    // MARK: - 取值辅助

    private func cycleText(_ sub: Subscription) -> String {
        if sub.billingCycle == .custom {
            return String(localized: "每 \(sub.customCycleDays) 天")
        }
        return sub.billingCycle.title
    }

    private func dateText(_ date: Date) -> String {
        date.formatted(.dateTime.year().month().day())
    }

    private func daysText(_ date: Date) -> String {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let target = cal.startOfDay(for: date)
        let days = cal.dateComponents([.day], from: today, to: target).day ?? 0
        if days <= 0 { return String(localized: "今天") }
        if days == 1 { return String(localized: "明天") }
        return String(localized: "还有 \(days) 天")
    }

    // MARK: - 卡片容器

    @ViewBuilder
    private func infoCard<Content: View>(title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.s) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.secondary)
                .padding(.leading, 2)
            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, AppTheme.Space.l)
            .padding(.vertical, AppTheme.Space.xs)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.radius))
            .glassBorder()
        }
    }
}

/// 详情里的一行:左标签 + 右值(可带一行小提示)。
private struct DetailRow: View {
    let label: LocalizedStringKey
    let value: String
    var hint: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondary)
            Spacer(minLength: AppTheme.Space.m)
            VStack(alignment: .trailing, spacing: 2) {
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                    .multilineTextAlignment(.trailing)
                if let hint {
                    Text(hint)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.tertiary)
                }
            }
        }
        .padding(.vertical, AppTheme.Space.m)
    }
}

#Preview {
    SubscriptionDetailSheet(subscriptionID: UUID())
        .environmentObject(SubscriptionStore())
}
