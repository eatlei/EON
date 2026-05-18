import SwiftUI

struct SubscriptionEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: SubscriptionStore

    @State private var draft: Subscription

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
            paymentMethod: "",
            seats: 1,
            usageScore: 3,
            importanceScore: 3,
            notes: ""
        ))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基础") {
                    TextField("名称", text: $draft.name)
                    TextField("套餐", text: $draft.plan)

                    Picker("分类", selection: $draft.category) {
                        ForEach(SubscriptionCategory.allCases) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }

                    Picker("状态", selection: $draft.status) {
                        Text(RenewalStatus.active.rawValue).tag(RenewalStatus.active)
                        Text(RenewalStatus.manual.rawValue).tag(RenewalStatus.manual)
                        Text(RenewalStatus.trial.rawValue).tag(RenewalStatus.trial)
                        Text(RenewalStatus.paused.rawValue).tag(RenewalStatus.paused)
                    }
                }

                Section("价格与周期") {
                    TextField("金额", value: $draft.price, format: .number.precision(.fractionLength(2)))
                        .keyboardType(.decimalPad)

                    Picker("币种", selection: $draft.currency) {
                        ForEach(CurrencyCode.allCases) { currency in
                            Text("\(currency.rawValue) · \(currency.title)").tag(currency)
                        }
                    }

                    Picker("扣费周期", selection: $draft.billingCycle) {
                        ForEach(BillingCycle.allCases) { cycle in
                            Text(cycle.rawValue).tag(cycle)
                        }
                    }

                    if draft.billingCycle == .custom {
                        Stepper("每 \(draft.customCycleDays) 天扣费", value: $draft.customCycleDays, in: 1...730)
                    }

                    DatePicker("下次扣费", selection: $draft.nextBillingDate, displayedComponents: .date)
                    Stepper("提前 \(draft.reminderDaysBefore) 天提醒", value: $draft.reminderDaysBefore, in: 0...30)
                }

                Section("使用画像") {
                    Stepper("席位 \(draft.seats)", value: $draft.seats, in: 1...99)
                    LabeledSlider(title: "使用频率", value: $draft.usageScore)
                    LabeledSlider(title: "重要程度", value: $draft.importanceScore)
                    TextField("支付方式", text: $draft.paymentMethod)
                    TextField("备注", text: $draft.notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(draft.name.isEmpty ? "新增订阅" : draft.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        store.upsert(draft)
                        dismiss()
                    }
                    .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draft.price < 0)
                }
            }
        }
    }
}

private struct LabeledSlider: View {
    let title: String
    @Binding var value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text("\(value)/5")
                    .foregroundStyle(.secondary)
            }

            Slider(
                value: Binding(
                    get: { Double(value) },
                    set: { value = Int($0.rounded()) }
                ),
                in: 1...5,
                step: 1
            )
        }
    }
}
