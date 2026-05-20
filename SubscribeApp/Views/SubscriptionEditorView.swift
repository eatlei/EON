import SwiftUI

struct SubscriptionEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: SubscriptionStore
    @State private var draft: Subscription
    @State private var priceText: String
    @State private var showIconPicker = false
    private let isNew: Bool
    @State private var didApplyDefaults = false

    private enum Field: Hashable { case name, plan, price }
    @FocusState private var focused: Field?

    init(subscription: Subscription?) {
        self.isNew = subscription == nil
        let initial = subscription ?? Subscription(
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
        )
        _draft = State(initialValue: initial)
        _priceText = State(initialValue: Self.formatPriceForInput(initial.price))
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
                        FieldRow("名称") {
                            TextField("如 ChatGPT", text: $draft.name)
                                .multilineTextAlignment(.trailing)
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()
                                .submitLabel(.next)
                                .focused($focused, equals: .name)
                                .onSubmit { focused = .plan }
                        }
                        Hairline()
                        FieldRow("套餐") {
                            TextField("如 Plus", text: $draft.plan)
                                .multilineTextAlignment(.trailing)
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()
                                .submitLabel(.next)
                                .focused($focused, equals: .plan)
                                .onSubmit { focused = .price }
                        }
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
                            TextField("0", text: $priceText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .focused($focused, equals: .price)
                                .onChange(of: priceText) { _, newValue in
                                    let sanitized = Self.sanitizePriceInput(newValue)
                                    if sanitized != newValue {
                                        priceText = sanitized
                                        return // onChange will fire again with the sanitized value
                                    }
                                    draft.price = Double(sanitized) ?? 0
                                }
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
                // Tap outside any field dismisses the keyboard.
                .contentShape(Rectangle())
                .onTapGesture { focused = nil }
            }
            .navigationTitle(draft.name.isEmpty ? String(localized: "新增订阅") : draft.name)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if isNew && !didApplyDefaults {
                    draft.reminderDaysBefore = store.defaultReminderDays
                    didApplyDefaults = true
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }.tint(AppTheme.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        focused = nil
                        draft.price = Double(priceText) ?? 0
                        store.upsert(draft)
                        dismiss()
                    }
                    .tint(AppTheme.accent).disabled(!canSave)
                }
                // Keyboard toolbar — works for every keyboard type (including .decimalPad
                // which has no return key) so the user can always dismiss in one tap.
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(String(localized: "完成")) { focused = nil }
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showIconPicker) {
                IconPickerView(icon: $draft.icon, appName: $draft.name)
            }
        }
    }

    // MARK: - Price input helpers

    /// Strip everything except digits and one decimal point. Reject leading dots without a digit?
    /// We allow "5.", ".5" etc. while typing — both parse as valid Doubles.
    private static func sanitizePriceInput(_ raw: String) -> String {
        let filtered = raw.filter { $0.isNumber || $0 == "." }
        guard let firstDot = filtered.firstIndex(of: ".") else { return filtered }
        let head = filtered[..<firstDot]
        let tail = filtered[filtered.index(after: firstDot)...].filter { $0 != "." }
        return String(head) + "." + tail
    }

    /// Display the existing price as natural input text (no formatter padding / trailing zeros).
    /// 0 → "" so the placeholder "0" shows for new drafts.
    private static func formatPriceForInput(_ value: Double) -> String {
        guard value != 0 else { return "" }
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 4
        f.usesGroupingSeparator = false
        return f.string(from: NSNumber(value: value)) ?? String(value)
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
