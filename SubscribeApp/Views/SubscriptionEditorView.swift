import SwiftUI

struct SubscriptionEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: SubscriptionStore
    @State private var draft: Subscription
    @State private var showIconPicker = false

    init(subscription: Subscription?) {
        _draft = State(initialValue: subscription ?? Subscription(
            name: "",
            plan: "",
            category: .productivity,
            price: 0,
            currency: .cny,
            billingCycle: .monthly,
            customCycleDays: 30,
            nextBillingDate: Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now,
            reminderDaysBefore: 3,
            status: .active,
            paymentMethod: ""
        ))
    }

    private var canSave: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && draft.price >= 0
    }

    private var paymentOptions: [String] {
        var opts = store.paymentMethods
        let cur = draft.paymentMethod.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cur.isEmpty && !opts.contains(cur) { opts.insert(cur, at: 0) }
        return opts
    }

    var body: some View {
        NavigationStack {
            AppScreen(bottomPadding: AppTheme.Space.l) {
                VStack(spacing: AppTheme.Space.l) {
                    Panel(title: "基础") {
                        Button { showIconPicker = true } label: {
                            HStack(spacing: AppTheme.Space.m) {
                                Text("图标")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(AppTheme.secondary)
                                Spacer()
                                CategoryGlyph(subscription: draft, size: 34)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(AppTheme.tertiary)
                            }
                            .padding(.vertical, AppTheme.Space.s)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Hairline()
                        FieldRow("名称") { TextField("如 ChatGPT", text: $draft.name).multilineTextAlignment(.trailing) }
                        Hairline()
                        FieldRow("套餐") { TextField("如 Plus", text: $draft.plan).multilineTextAlignment(.trailing) }
                        Hairline()
                        FieldRow("分类") {
                            Picker("", selection: $draft.category) {
                                ForEach(SubscriptionCategory.allCases) { Text($0.title).tag($0) }
                            }.labelsHidden().tint(AppTheme.ink)
                        }
                        Hairline()
                        FieldRow("状态") {
                            Picker("", selection: $draft.status) {
                                ForEach(RenewalStatus.allCases) { Text($0.title).tag($0) }
                            }.labelsHidden().tint(AppTheme.ink)
                        }
                    }

                    Panel(title: "价格与周期") {
                        FieldRow("金额") {
                            TextField("0", value: $draft.price, format: .number.precision(.fractionLength(2)))
                                .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                        }
                        Hairline()
                        FieldRow("币种") {
                            Picker("", selection: $draft.currency) {
                                ForEach(CurrencyCode.allCases) { Text($0.rawValue).tag($0) }
                            }.labelsHidden().tint(AppTheme.ink)
                        }
                        Hairline()
                        FieldRow("扣费周期") {
                            Picker("", selection: $draft.billingCycle) {
                                ForEach(BillingCycle.allCases) { Text($0.title).tag($0) }
                            }.labelsHidden().tint(AppTheme.ink)
                        }
                        if draft.billingCycle == .custom {
                            Hairline()
                            FieldRow("自定义天数") {
                                Stepper(String(localized: "\(draft.customCycleDays) 天"), value: $draft.customCycleDays, in: 1...730)
                                    .fixedSize()
                            }
                        }
                        Hairline()
                        FieldRow("开始时间") {
                            DatePicker("", selection: $draft.nextBillingDate, displayedComponents: .date)
                                .labelsHidden()
                                .tint(AppTheme.ink)
                        }
                        Hairline()
                        FieldRow("提前提醒") {
                            Stepper(String(localized: "\(draft.reminderDaysBefore) 天"), value: $draft.reminderDaysBefore, in: 0...30)
                                .fixedSize()
                        }
                    }

                    Panel(title: "支付") {
                        FieldRow("支付方式") {
                            Picker("", selection: $draft.paymentMethod) {
                                Text("无").tag("")
                                ForEach(paymentOptions, id: \.self) { Text($0).tag($0) }
                            }
                            .labelsHidden()
                            .tint(AppTheme.ink)
                        }
                    }
                }
            }
            .navigationTitle(draft.name.isEmpty ? String(localized: "新增订阅") : draft.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }.tint(AppTheme.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { store.upsert(draft); dismiss() }
                        .tint(AppTheme.accent).disabled(!canSave)
                }
            }
            .sheet(isPresented: $showIconPicker) {
                IconPickerView(icon: $draft.icon, appName: $draft.name)
            }
        }
    }
}

private struct FieldRow<Trailing: View>: View {
    let label: LocalizedStringKey
    @ViewBuilder var trailing: Trailing
    init(_ label: LocalizedStringKey, @ViewBuilder trailing: () -> Trailing) {
        self.label = label
        self.trailing = trailing()
    }
    var body: some View {
        HStack(spacing: AppTheme.Space.m) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.secondary)
            Spacer(minLength: AppTheme.Space.m)
            trailing
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
        }
        .padding(.vertical, AppTheme.Space.s)
    }
}

#Preview {
    SubscriptionEditorView(subscription: nil)
        .environmentObject(SubscriptionStore())
}
