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
                    EditorHero(subscription: draft) { showIconPicker = true }
                        // Break out of AppScreen's horizontal padding so the hero is edge-to-edge.
                        .padding(.horizontal, -AppTheme.Space.xl)
                        // Pull up under the navbar a touch so the hero hugs the top.
                        .padding(.top, -AppTheme.Space.m)

                    Panel(title: "基础") {
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
            // "0" 在金额框中是默认值,用户聚焦时清空,失焦后若为空则补回 "0"。
            // 这样无需按删除就能直接输入数字替换。
            .onChange(of: focused) { _, newFocus in
                if newFocus == .price && priceText == "0" {
                    priceText = ""
                } else if newFocus != .price && priceText.isEmpty {
                    priceText = "0"
                    draft.price = 0
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

    /// Strip everything except digits and one decimal point.
    private static func sanitizePriceInput(_ raw: String) -> String {
        let filtered = raw.filter { $0.isNumber || $0 == "." }
        guard let firstDot = filtered.firstIndex(of: ".") else { return filtered }
        let head = filtered[..<firstDot]
        let tail = filtered[filtered.index(after: firstDot)...].filter { $0 != "." }
        return String(head) + "." + tail
    }

    /// Display the existing price as natural input text. 0 → "0" (visible
    /// default; cleared on focus so typing replaces it).
    private static func formatPriceForInput(_ value: Double) -> String {
        guard value != 0 else { return "0" }
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 4
        f.usesGroupingSeparator = false
        return f.string(from: NSNumber(value: value)) ?? String(value)
    }
}

// MARK: - Hero header (Apple Music-style immersive icon backdrop)

private struct EditorHero: View {
    let subscription: Subscription
    let onTapIcon: () -> Void

    var body: some View {
        ZStack {
            background
            // Bottom shade so the title stays legible over light gradients.
            LinearGradient(
                colors: [.clear, .black.opacity(0.28)],
                startPoint: .center, endPoint: .bottom
            )

            VStack(spacing: AppTheme.Space.m) {
                Button(action: onTapIcon) {
                    CategoryGlyph(subscription: subscription, size: 96)
                        .shadow(color: .black.opacity(0.35), radius: 22, y: 10)
                        .overlay(alignment: .bottomTrailing) {
                            // Edit affordance — hints the icon is tappable.
                            Image(systemName: "pencil.circle.fill")
                                .font(.title3)
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, .black.opacity(0.5))
                                .offset(x: 4, y: 4)
                        }
                }
                .buttonStyle(.plain)

                if !subscription.name.isEmpty {
                    Text(subscription.name)
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.55), radius: 6, y: 2)
                        .lineLimit(1)
                        .padding(.horizontal, AppTheme.Space.l)
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                }
            }
            .padding(.vertical, AppTheme.Space.xl)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 240)
        .clipped()
        .animation(.smooth(duration: 0.4), value: subscription.icon)
        .animation(.smooth(duration: 0.25), value: subscription.name.isEmpty)
    }

    /// Apple Music trick: when the icon is an image, scale it up and blur it
    /// heavily — same artwork = same color palette. For tile glyphs, use the
    /// tile's color (or category color) with a soft radial highlight.
    @ViewBuilder
    private var background: some View {
        switch subscription.icon {
        case .image(let id):
            if let ui = IconStore.loadUIImage(id) {
                Color.clear.overlay(
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .blur(radius: 50)
                        .saturation(1.35)
                )
                .clipped()
            } else {
                tileBackground(subscription.category.color)
            }
        case .tile(_, let hex):
            tileBackground(hex.map { Color(hexString: $0) } ?? subscription.category.color)
        }
    }

    private func tileBackground(_ color: Color) -> some View {
        ZStack {
            color
            LinearGradient(
                colors: [color.opacity(0.0), color.opacity(0.35)],
                startPoint: .top, endPoint: .bottom
            )
            RadialGradient(
                colors: [.white.opacity(0.30), .clear],
                center: UnitPoint(x: 0.28, y: 0.22),
                startRadius: 0, endRadius: 220
            )
        }
    }
}

// MARK: - Field row

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
