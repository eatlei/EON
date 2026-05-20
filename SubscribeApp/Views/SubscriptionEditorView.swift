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
        // 新建订阅:默认字母 tile,颜色每次随机从 8 个 monogram 预设里挑一个。
        // 这样空名字也有视觉存在感,且每次打开都不一样。
        // 默认"开始时间"= 今天的 00:00(用 startOfDay 抹掉时分秒,DatePicker 不会
        // 出现"今天 03:47"这种凌乱显示)。 之前默认成 "今天 + 7" 是早期
        // "下次扣费"语义留下的脏值,这里跟着字段重命名一起回归本意。
        let initial = subscription ?? Subscription(
            name: "",
            plan: "",
            category: .productivity,
            price: 0,
            currency: .cny,
            billingCycle: .monthly,
            customCycleDays: 30,
            nextBillingDate: Calendar.current.startOfDay(for: .now),
            reminderDaysBefore: 3,
            status: .active,
            paymentMethod: "",
            icon: .tile(glyph: .letter, colorHex: AppTheme.monogramColors.randomElement())
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
            ZStack {
                ImmersiveBackground(subscription: draft)

                ScrollView {
                    VStack(spacing: AppTheme.Space.l) {
                        HeroIcon(subscription: draft) { showIconPicker = true }
                            .padding(.top, AppTheme.Space.s)

                        MaterialPanel(title: "基础") {
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
                                MenuPickerLabel(text: draft.displayCategoryTitle) {
                                    // 内置分类:点中 → 解绑 customCategoryID
                                    Section {
                                        ForEach(SubscriptionCategory.allCases) { c in
                                            Button {
                                                draft.category = c
                                                draft.customCategoryID = nil
                                            } label: {
                                                if draft.category == c && draft.customCategoryID == nil {
                                                    Label(c.title, systemImage: "checkmark")
                                                } else { Text(c.title) }
                                            }
                                        }
                                    }
                                    // 自定义分类:点中 → 绑定 ID,category 保留作为 fallback
                                    if !store.customCategories.isEmpty {
                                        Section(String(localized: "自定义分类")) {
                                            ForEach(store.customCategories) { cc in
                                                Button { draft.customCategoryID = cc.id } label: {
                                                    if draft.customCategoryID == cc.id {
                                                        Label(cc.name, systemImage: "checkmark")
                                                    } else { Text(cc.name) }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            Hairline()
                            FieldRow("状态") {
                                MenuPickerLabel(text: draft.status.title) {
                                    ForEach(RenewalStatus.allCases) { s in
                                        Button { draft.status = s } label: {
                                            if draft.status == s {
                                                Label(s.title, systemImage: "checkmark")
                                            } else { Text(s.title) }
                                        }
                                    }
                                }
                            }
                        }

                        MaterialPanel(title: "价格与周期") {
                            FieldRow("金额") {
                                TextField("0", text: $priceText)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .focused($focused, equals: .price)
                                    .onChange(of: priceText) { _, newValue in
                                        let sanitized = Self.sanitizePriceInput(newValue)
                                        if sanitized != newValue {
                                            priceText = sanitized
                                            return
                                        }
                                        draft.price = Double(sanitized) ?? 0
                                    }
                            }
                            Hairline()
                            FieldRow("币种") {
                                MenuPickerLabel(text: draft.currency.rawValue) {
                                    ForEach(CurrencyCode.allCases.sorted { $0.rawValue < $1.rawValue }) { c in
                                        Button { draft.currency = c } label: {
                                            if draft.currency == c {
                                                Label("\(c.rawValue) · \(c.title)", systemImage: "checkmark")
                                            } else { Text("\(c.rawValue) · \(c.title)") }
                                        }
                                    }
                                }
                            }
                            Hairline()
                            FieldRow("扣费周期") {
                                MenuPickerLabel(text: draft.billingCycle.title) {
                                    ForEach(BillingCycle.allCases) { b in
                                        Button { draft.billingCycle = b } label: {
                                            if draft.billingCycle == b {
                                                Label(b.title, systemImage: "checkmark")
                                            } else { Text(b.title) }
                                        }
                                    }
                                }
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
                                    .tint(.primary)
                            }
                            Hairline()
                            FieldRow("提前提醒") {
                                Stepper(String(localized: "\(draft.reminderDaysBefore) 天"), value: $draft.reminderDaysBefore, in: 0...30)
                                    .fixedSize()
                            }
                        }

                        MaterialPanel(title: "支付") {
                            FieldRow("支付方式") {
                                MenuPickerLabel(text: draft.paymentMethod.isEmpty ? String(localized: "无") : draft.paymentMethod) {
                                    Button { draft.paymentMethod = "" } label: {
                                        if draft.paymentMethod.isEmpty {
                                            Label(String(localized: "无"), systemImage: "checkmark")
                                        } else { Text("无") }
                                    }
                                    ForEach(paymentOptions, id: \.self) { p in
                                        Button { draft.paymentMethod = p } label: {
                                            if draft.paymentMethod == p {
                                                Label(p, systemImage: "checkmark")
                                            } else { Text(p) }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, AppTheme.Space.xl)
                    .padding(.bottom, AppTheme.Space.xxl)
                    .contentShape(Rectangle())
                    .onTapGesture { focused = nil }
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(isNew ? String(localized: "新增订阅") : String(localized: "编辑订阅"))
            .navigationBarTitleDisplayMode(.inline)
            // 之前是隐藏 toolbar 背景 + 强行白字,在浅色 tile(比如 Netflix 红、苹果黄)
            // 顶部就会出现"取消 / 保存"字几乎透明读不清的情况。改成 ultraThinMaterial
            // 给 navigation bar 加一层薄玻璃,toolbarColorScheme 留给系统按背景自动适配:
            // 任何 tile 色下,按钮都能稳定看清。
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .onAppear {
                if isNew && !didApplyDefaults {
                    draft.reminderDaysBefore = store.defaultReminderDays
                    didApplyDefaults = true
                }
            }
            // 默认显示 "0",聚焦时清空让用户直接输入;失焦后若为空则补回 "0"。
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
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        focused = nil
                        draft.price = Double(priceText) ?? 0
                        // 新订阅首次保存时把 startDate 固定下来 = 当时的 nextBillingDate。
                        // 之后即便用户改 nextBillingDate(把下次扣费日往后挪),
                        // startDate 也不动,这样"已扣 N 次"才有可追溯的基准日。
                        if isNew && draft.startDate == nil {
                            draft.startDate = draft.nextBillingDate
                        }
                        store.upsert(draft)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
                // 键盘工具栏:任何键盘都能一键收起(decimal pad 没有 return)。
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

    private static func sanitizePriceInput(_ raw: String) -> String {
        let filtered = raw.filter { $0.isNumber || $0 == "." }
        guard let firstDot = filtered.firstIndex(of: ".") else { return filtered }
        let head = filtered[..<firstDot]
        let tail = filtered[filtered.index(after: firstDot)...].filter { $0 != "." }
        return String(head) + "." + tail
    }

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

// MARK: - Hero icon (sits on top of the immersive background)

private struct HeroIcon: View {
    let subscription: Subscription
    let onTapIcon: () -> Void

    var body: some View {
        VStack(spacing: AppTheme.Space.m) {
            Button(action: onTapIcon) {
                CategoryGlyph(subscription: subscription, size: 112)
                    .shadow(color: .black.opacity(0.4), radius: 24, y: 12)
                    .overlay(alignment: .bottomTrailing) {
                        // Edit affordance — hints the icon is tappable.
                        Image(systemName: "pencil.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .black.opacity(0.55))
                            .offset(x: 6, y: 6)
                    }
            }
            .buttonStyle(.plain)

            if !subscription.name.isEmpty {
                Text(subscription.name)
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.55), radius: 6, y: 2)
                    .lineLimit(1)
                    .padding(.horizontal, AppTheme.Space.l)
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.Space.m)
        .animation(.smooth(duration: 0.3), value: subscription.name.isEmpty)
        .animation(.smooth(duration: 0.4), value: subscription.icon)
    }
}

// MARK: - Immersive background (full-screen, derived from the icon)

private struct ImmersiveBackground: View {
    let subscription: Subscription

    var body: some View {
        ZStack {
            baseLayer

            // Localized darkening: top (so toolbar glyphs read) + bottom (so the
            // glass form panels keep contrast). Middle stays at full intensity so
            // the hero icon "owns" the visual.
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.22), location: 0.00),
                    .init(color: .black.opacity(0.00), location: 0.16),
                    .init(color: .black.opacity(0.00), location: 0.45),
                    .init(color: .black.opacity(0.18), location: 1.00),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .animation(.smooth(duration: 0.4), value: subscription.icon)
    }

    @ViewBuilder
    private var baseLayer: some View {
        switch subscription.icon {
        case .image(let id):
            if let ui = IconStore.loadUIImage(id) {
                // CRITICAL: use a GeometryReader to give the image an EXPLICIT
                // width/height. Without it, .resizable().aspectRatio(.fill)
                // produces an unbounded layout that — combined with .blur —
                // occluded sibling views in the parent ZStack on iOS 26,
                // making the entire form panels' content invisible. Plain
                // `.blur(radius:)` on an unframed `.aspectRatio(.fill)` image
                // is the root cause, not the blur itself.
                GeometryReader { geo in
                    Image(uiImage: ui)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .blur(radius: 60)
                        .saturation(1.35)
                        .clipped()
                }
            } else {
                tileLayer(subscription.displayCategoryColor)
            }
        case .tile(_, let hex):
            tileLayer(hex.map { Color(hexString: $0) } ?? subscription.displayCategoryColor)
        }
    }

    private func tileLayer(_ color: Color) -> some View {
        ZStack {
            color
            RadialGradient(
                colors: [.white.opacity(0.30), .clear],
                center: UnitPoint(x: 0.30, y: 0.15),
                startRadius: 0, endRadius: 420
            )
        }
    }
}

// MARK: - Menu picker label
// Replaces `Picker(.menu)` which forces the displayed value to render in the
// accent colour (terrible contrast on a tinted Material panel). This uses a
// plain Menu, and the visible label uses `.primary` so it adapts to the
// underlying material brightness automatically.
private struct MenuPickerLabel<Items: View>: View {
    let text: String
    @ViewBuilder var items: Items
    var body: some View {
        Menu {
            items
        } label: {
            HStack(spacing: 4) {
                Text(text).foregroundStyle(.white)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .contentShape(Rectangle())
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
                .foregroundStyle(.white.opacity(0.7))
            Spacer(minLength: AppTheme.Space.m)
            trailing
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .tint(.white)
        }
        .padding(.vertical, AppTheme.Space.s)
    }
}

#Preview {
    SubscriptionEditorView(subscription: nil)
        .environmentObject(SubscriptionStore())
}
