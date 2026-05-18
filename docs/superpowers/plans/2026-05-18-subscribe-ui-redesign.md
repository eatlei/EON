# Subscribe UI 重塑 + 功能精简 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 Subscribe 的全部界面重塑到 Things 3 级原生质感，并砍掉非核心字段与死代码，不动已验证的数据/计算层。

**Architecture:** 原地重塑视觉层。新建统一设计 token 文件 `AppTheme`，所有视图引用它；先做数据层精简与 bug 修复（确定性、可编译验证），再逐页重做 UI（编译 + 模拟器在环迭代）。

**Tech Stack:** SwiftUI / Charts / UserNotifications，XcodeGen 生成工程，Xcode 26.5，iOS 17，无测试 target（按设计文档为非目标）。

**Spec:** `docs/superpowers/specs/2026-05-18-subscribe-ui-redesign-design.md`

---

## 关于本计划的执行方式（必读）

- **无测试 target**（设计文档明确为非目标）。每个任务的"验证"= `xcodegen generate` 后 `xcodebuild ... build` 编译通过；UI 任务额外在模拟器肉眼验收。不写单元测试。
- **当前目录非 git 仓库**。Task 0 会 `git init` 建立回退兜底（设计文档 §8 风险）。之后每个任务末尾用 `git commit` 作为检查点；若用户拒绝 git，则以"编译通过"为检查点，跳过 commit 步骤。
- **数据层任务（Task 1–3）代码完整给出**，必须精确照做。
- **视觉任务（Task 4–8）给出完整可编译的首版 SwiftUI**。首版编译通过后，视觉微调（间距/字号/色值常量）在模拟器中迭代——那是调常量，不是重新设计。

### 文件结构与职责

| 文件 | 职责 | 本次动作 |
|---|---|---|
| `SubscribeApp/Views/AppTheme.swift` | 全局设计 token + 复用组件 | 新建（替代旧 `AppDesign.swift`） |
| `SubscribeApp/Views/AppDesign.swift` | 旧设计 token | 删除 |
| `SubscribeApp/Models/Subscription.swift` | 订阅模型 | 删 4 字段 |
| `SubscribeApp/Models/Analytics.swift` | 总览数据结构 | 删 4 个未用结构体 |
| `SubscribeApp/Store/SubscriptionStore.swift` | 状态 + 计算 | 删死代码 + 修 B1/B2 |
| `SubscribeApp/Services/NotificationScheduler.swift` | 本地通知 | 加 `cancelAll()` |
| `SubscribeApp/Views/ContentView.swift` | 底部 dock + 路由 | 重塑视觉 |
| `SubscribeApp/Views/DashboardView.swift` | 总览页 | 重做 |
| `SubscribeApp/Views/SubscriptionsView.swift` | 列表页 | 重做 |
| `SubscribeApp/Views/SubscriptionEditorView.swift` | 新增/编辑 | 重做 + 删字段 |
| `SubscribeApp/Views/SettingsView.swift` | 设置页 | 重塑视觉 |

---

## Task 0: 基线与 git 兜底

**Files:** 无代码改动

- [ ] **Step 1: 建立编译基线**

Run:
```bash
cd /Users/bytedance/Desktop/Subscribe && xcodegen generate && xcodebuild -project Subscribe.xcodeproj -scheme SubscribeApp -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -5
```
Expected: 末尾出现 `** BUILD SUCCEEDED **`。若失败，先停下报告——基线就坏，不能继续。

- [ ] **Step 2: git 兜底（用户已同意 git init）**

Run:
```bash
cd /Users/bytedance/Desktop/Subscribe && git init -q && printf '.superpowers/\n*.xcodeproj/xcuserdata/\nDerivedData/\n.DS_Store\n' > .gitignore && git add -A && git commit -q -m "chore: baseline before UI redesign" && echo committed
```
Expected: `committed`。若用户拒绝 git，跳过本步，后续所有 commit 步骤改为仅"编译通过即检查点"。

---

## Task 1: 数据模型精简（删 4 字段 + samples）

**Files:**
- Modify: `SubscribeApp/Models/Subscription.swift`
- Modify: `SubscribeApp/Store/SubscriptionStore.swift`（仅 `samples`）

- [ ] **Step 1: 删除 `Subscription` 的 4 个字段**

在 `SubscribeApp/Models/Subscription.swift` 的 `struct Subscription` 中，删除这 4 行：
```swift
    var seats: Int
    var usageScore: Int
    var importanceScore: Int
    var notes: String
```
删除后 `struct Subscription` 的存储属性为：
```swift
    var id = UUID()
    var name: String
    var plan: String
    var category: SubscriptionCategory
    var price: Double
    var currency: CurrencyCode
    var billingCycle: BillingCycle
    var customCycleDays: Int
    var nextBillingDate: Date
    var reminderDaysBefore: Int
    var status: RenewalStatus
    var paymentMethod: String
```
`isActive`、`monthlyCost`、`annualCost` 不变。

> 迁移说明：`Subscription` 是 `Codable`，移除属性后 `JSONDecoder` 默认忽略旧数据里多余的 `seats/usageScore/...` 键，旧数据仍能解码出保留字段，无需自定义 init。Task 9 会用旧数据实测。

- [ ] **Step 2: 更新 samples**

在 `SubscribeApp/Store/SubscriptionStore.swift` 的 `static let samples` 里，每个 `Subscription(...)` 删除 `seats:`、`usageScore:`、`importanceScore:`、`notes:` 四个实参。例如第一个改为：
```swift
        Subscription(
            name: "ChatGPT",
            plan: "Plus",
            category: .ai,
            price: 20,
            currency: .usd,
            billingCycle: .monthly,
            customCycleDays: 30,
            nextBillingDate: Calendar.current.date(byAdding: .day, value: 8, to: .now) ?? .now,
            reminderDaysBefore: 3,
            status: .active,
            paymentMethod: "Visa 0821"
        ),
```
其余 3 个（Netflix / iCloud+ / Notion）同样只保留上述 11 个实参，值沿用原值（plan/category/price/currency/cycle/nextBillingDate offset 13/19/61 天/reminderDaysBefore/status/paymentMethod 不变）。

- [ ] **Step 3: 编译（此步会因视图仍引用旧字段而失败——预期）**

Run:
```bash
cd /Users/bytedance/Desktop/Subscribe && xcodebuild -project Subscribe.xcodeproj -scheme SubscribeApp -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "error:" | head
```
Expected: 报错集中在 `SubscriptionEditorView.swift`、`SubscriptionsView.swift`、`SubscriptionStore.swift`（引用已删字段）。这些在 Task 2/3/7 修。记录报错文件清单，确认无 `Subscription.swift` 自身语法错误。

---

## Task 2: Store 死代码清理 + B1/B2 修复

**Files:**
- Modify: `SubscribeApp/Store/SubscriptionStore.swift`
- Modify: `SubscribeApp/Services/NotificationScheduler.swift`
- Modify: `SubscribeApp/Models/Analytics.swift`

- [ ] **Step 1: 删除 `Analytics.swift` 中 4 个未用结构体**

在 `SubscribeApp/Models/Analytics.swift` 删除 `struct CurrencyExposure`、`struct CycleSpend`、`struct RenewalWindow`、`struct StatusCount` 四个定义。**保留** `SpendPeriod`、`RenewalCharge`、`CategorySpend`、`ForecastMonth`（`ForecastMonth` 仍被年柱状图用）。

- [ ] **Step 2: 删除 `SubscriptionStore` 未用计算属性与私有方法**

在 `SubscribeApp/Store/SubscriptionStore.swift` 删除这些成员（含整段实现）：`averageMonthlyCost`、`averageUsageScore`、`averageImportanceScore`、`currencyExposure`、`cycleSpend`、`topSubscriptions`、`statusCounts`、`forecast`、`renewalWindows`、私有 `renewalWindow(id:title:days:tint:)`、私有 `projectedCharge(for:from:to:)`（仅被已删的 `forecast` 使用）。
**保留：** `activeSubscriptions`、`monthlyTotal`、`annualTotal`、`upcoming`、`total(for:)`、`categorySpend`、`interval(for:)`、`charges(in:)`、`dueAmount(in:)`、`dueCount(in:)`、`nextCharge(in:)`、`monthTotalsForCurrentYear()`、`upsert(_:)`、`delete(ids:)`、`resetSamples()`、`syncToICloud()`、`syncFromICloud()`、私有 `projectedCharges(for:from:to:)`、`save()`、`saveSettings()`。

- [ ] **Step 3: B2 — 删除 `delete(at offsets:)`**

删除 `SubscriptionStore` 中整个：
```swift
    func delete(at offsets: IndexSet) {
        let sorted = subscriptions.sorted { $0.nextBillingDate < $1.nextBillingDate }
        let ids = offsets.map { sorted[$0].id }
        delete(ids: ids)
    }
```
（视图统一用 `delete(ids:)`，无调用方。）

- [ ] **Step 4: B1 — 让 `remindersEnabled` 真正 gate 通知**

在 `NotificationScheduler` 增加（放在 `rescheduleAll` 后）：
```swift
    static func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
```

在 `SubscriptionStore` 增加私有方法：
```swift
    private func syncReminders() {
        if remindersEnabled {
            NotificationScheduler.rescheduleAll(subscriptions)
        } else {
            NotificationScheduler.cancelAll()
        }
    }
```

把 `subscriptions` 的 `didSet` 改为：
```swift
    @Published var subscriptions: [Subscription] {
        didSet {
            save()
            syncReminders()
        }
    }
```

把 `remindersEnabled` 的 `didSet` 改为：
```swift
    @Published var remindersEnabled: Bool {
        didSet {
            saveSettings()
            syncReminders()
        }
    }
```
（`init` 内对 `remindersEnabled` 的首次赋值在 `didSet` 触发前 store 尚未完全初始化，沿用现状不在 init 里手动调 `syncReminders`；首次调度由 `subscriptions` 在 init 末的赋值/后续变更触发，行为与现状一致但现在受开关 gate。）

- [ ] **Step 5: 编译**

Run:
```bash
cd /Users/bytedance/Desktop/Subscribe && xcodebuild -project Subscribe.xcodeproj -scheme SubscribeApp -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "error:" | head
```
Expected: 仅剩 `SubscriptionEditorView.swift` / `SubscriptionsView.swift` 引用已删字段的报错（Task 3/7 修），`SubscriptionStore.swift` / `Analytics.swift` / `NotificationScheduler.swift` 无报错。

- [ ] **Step 6: Commit**

```bash
cd /Users/bytedance/Desktop/Subscribe && git add -A && git commit -q -m "refactor: trim model fields + dead store code, fix reminders gate (B1) and remove delete(at:) (B2)" && echo done
```

---

## Task 3: 设计系统 AppTheme（新建，删旧 AppDesign）

**Files:**
- Create: `SubscribeApp/Views/AppTheme.swift`
- Delete: `SubscribeApp/Views/AppDesign.swift`（Task 4 起所有视图改引用 AppTheme；本任务先建好，旧文件在 Task 8 末确认无引用后删，过渡期两者共存不冲突——命名不同）

- [ ] **Step 1: 新建 `AppTheme.swift`（完整内容）**

```swift
import SwiftUI

enum AppTheme {
    // Surfaces — 纸感暖白，无渐变
    static let canvas = Color(red: 0.984, green: 0.980, blue: 0.973)   // #FBFAF8
    static let surface = Color.white
    static let hairline = Color(red: 0.90, green: 0.89, blue: 0.87)

    // Text
    static let ink = Color(red: 0.102, green: 0.102, blue: 0.110)      // #1A1A1C
    static let secondary = Color(red: 0.52, green: 0.52, blue: 0.55)
    static let tertiary = Color(red: 0.70, green: 0.70, blue: 0.72)

    // 单一克制强调色
    static let accent = Color(red: 0.18, green: 0.45, blue: 0.42)

    // 圆角
    static let radius: CGFloat = 12
    static let radiusSmall: CGFloat = 8

    // 间距阶
    enum Space {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 28
    }

    static let spring = Animation.spring(response: 0.42, dampingFraction: 0.86)
}

extension Font {
    static func amountHero() -> Font { .system(size: 52, weight: .heavy, design: .rounded) }
    static func amount() -> Font { .system(size: 17, weight: .bold, design: .rounded) }
    static func amountSmall() -> Font { .system(size: 14, weight: .bold, design: .rounded) }
}

/// 全屏滚动容器：纯色画布，无渐变
struct AppScreen<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView {
            content
                .padding(.horizontal, AppTheme.Space.xl)
                .padding(.top, AppTheme.Space.m)
                .padding(.bottom, 112)
        }
        .background(AppTheme.canvas.ignoresSafeArea())
    }
}

/// 极淡边界的面板：白底 + 统一圆角 + 0.5pt 发丝线，无重阴影
struct Panel<Content: View>: View {
    var title: String? = nil
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.m) {
            if let title {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Space.l)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.radius))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radius)
                .stroke(AppTheme.hairline, lineWidth: 0.5)
        )
    }
}

struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.bold))
            .tracking(0.8)
            .foregroundStyle(AppTheme.tertiary)
    }
}

struct Hairline: View {
    var body: some View {
        Rectangle().fill(AppTheme.hairline).frame(height: 0.5)
    }
}

/// 分类字母头像（颜色只在这种小圆点上出现）
struct CategoryGlyph: View {
    let subscription: Subscription
    var size: CGFloat = 38
    var body: some View {
        Text(String(subscription.name.prefix(1)).uppercased())
            .font(.system(size: size * 0.42, weight: .heavy, design: .rounded))
            .foregroundStyle(subscription.category.color)
            .frame(width: size, height: size)
            .background(subscription.category.color.opacity(0.14),
                        in: RoundedRectangle(cornerRadius: AppTheme.radiusSmall))
    }
}

struct RevealModifier: ViewModifier {
    let index: Int
    @State private var shown = false
    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 10)
            .animation(AppTheme.spring.delay(Double(index) * 0.04), value: shown)
            .onAppear { shown = true }
    }
}

extension View {
    func reveal(_ index: Int) -> some View { modifier(RevealModifier(index: index)) }
}
```

- [ ] **Step 2: 编译（AppTheme 自身无误）**

Run:
```bash
cd /Users/bytedance/Desktop/Subscribe && xcodegen generate && xcodebuild -project Subscribe.xcodeproj -scheme SubscribeApp -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "AppTheme.swift.*error:" | head
```
Expected: 无 `AppTheme.swift` 报错（其它视图仍报旧字段错，正常，后续任务修）。

- [ ] **Step 3: Commit**

```bash
cd /Users/bytedance/Desktop/Subscribe && git add -A && git commit -q -m "feat: add AppTheme design system" && echo done
```

---

## Task 4: 编辑/新增页重做（当前最丑，删字段）

**Files:**
- Modify: `SubscribeApp/Views/SubscriptionEditorView.swift`（整文件替换）

- [ ] **Step 1: 整文件替换为以下内容**

```swift
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
            paymentMethod: ""
        ))
    }

    private var canSave: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && draft.price >= 0
    }

    var body: some View {
        NavigationStack {
            AppScreen {
                VStack(spacing: AppTheme.Space.l) {
                    Panel(title: "基础") {
                        FieldRow("名称") { TextField("如 ChatGPT", text: $draft.name).multilineTextAlignment(.trailing) }
                        Hairline()
                        FieldRow("套餐") { TextField("如 Plus", text: $draft.plan).multilineTextAlignment(.trailing) }
                        Hairline()
                        FieldRow("分类") {
                            Picker("", selection: $draft.category) {
                                ForEach(SubscriptionCategory.allCases) { Text($0.rawValue).tag($0) }
                            }.labelsHidden().tint(AppTheme.ink)
                        }
                        Hairline()
                        FieldRow("状态") {
                            Picker("", selection: $draft.status) {
                                ForEach(RenewalStatus.allCases) { Text($0.rawValue).tag($0) }
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
                                ForEach(CurrencyCode.allCases) { Text("\($0.rawValue) · \($0.title)").tag($0) }
                            }.labelsHidden().tint(AppTheme.ink)
                        }
                        Hairline()
                        FieldRow("扣费周期") {
                            Picker("", selection: $draft.billingCycle) {
                                ForEach(BillingCycle.allCases) { Text($0.rawValue).tag($0) }
                            }.labelsHidden().tint(AppTheme.ink)
                        }
                        if draft.billingCycle == .custom {
                            Hairline()
                            FieldRow("自定义天数") {
                                Stepper("\(draft.customCycleDays) 天", value: $draft.customCycleDays, in: 1...730)
                                    .fixedSize()
                            }
                        }
                        Hairline()
                        FieldRow("下次扣费") {
                            DatePicker("", selection: $draft.nextBillingDate, displayedComponents: .date)
                                .labelsHidden()
                        }
                        Hairline()
                        FieldRow("提前提醒") {
                            Stepper("\(draft.reminderDaysBefore) 天", value: $draft.reminderDaysBefore, in: 0...30)
                                .fixedSize()
                        }
                    }

                    Panel(title: "支付") {
                        FieldRow("支付方式") {
                            TextField("如 Visa 0821", text: $draft.paymentMethod).multilineTextAlignment(.trailing)
                        }
                    }
                }
            }
            .navigationTitle(draft.name.isEmpty ? "新增订阅" : draft.name)
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
        }
    }
}

private struct FieldRow<Trailing: View>: View {
    let label: String
    @ViewBuilder var trailing: Trailing
    init(_ label: String, @ViewBuilder trailing: () -> Trailing) {
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
```

- [ ] **Step 2: 编译**

Run:
```bash
cd /Users/bytedance/Desktop/Subscribe && xcodebuild -project Subscribe.xcodeproj -scheme SubscribeApp -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "SubscriptionEditorView.swift.*error:" | head
```
Expected: 无 `SubscriptionEditorView.swift` 报错。

- [ ] **Step 3: Commit**

```bash
cd /Users/bytedance/Desktop/Subscribe && git add -A && git commit -q -m "feat: redesign subscription editor, drop trimmed fields" && echo done
```

---

## Task 5: 总览页重做（核心）

**Files:**
- Modify: `SubscribeApp/Views/DashboardView.swift`（整文件替换）

- [ ] **Step 1: 整文件替换为以下内容**

```swift
import Charts
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: SubscriptionStore
    @State private var period: SpendPeriod = .month

    var body: some View {
        NavigationStack {
            AppScreen {
                if store.activeSubscriptions.isEmpty {
                    EmptyDashboard()
                } else {
                    VStack(spacing: AppTheme.Space.xl) {
                        DashboardHeader(period: $period).reveal(0)
                        HeroTotal(period: period).reveal(1)
                        UpcomingPanel(period: period).reveal(2)
                        CategoryPanel().reveal(3)
                        if period == .month {
                            CalendarPanel().reveal(4)
                        } else {
                            YearPanel().reveal(4)
                        }
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct DashboardHeader: View {
    @EnvironmentObject private var store: SubscriptionStore
    @Binding var period: SpendPeriod
    var body: some View {
        HStack(spacing: AppTheme.Space.m) {
            HStack(spacing: 2) {
                ForEach(SpendPeriod.allCases) { p in
                    Button {
                        withAnimation(AppTheme.spring) { period = p }
                    } label: {
                        Text(p.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(period == p ? AppTheme.surface : AppTheme.secondary)
                            .frame(maxWidth: .infinity).padding(.vertical, 8)
                            .background(period == p ? AppTheme.ink : .clear,
                                        in: RoundedRectangle(cornerRadius: AppTheme.radiusSmall))
                    }.buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.radius))
            .overlay(RoundedRectangle(cornerRadius: AppTheme.radius).stroke(AppTheme.hairline, lineWidth: 0.5))
            .frame(width: 132)

            Spacer()

            Menu {
                Picker("", selection: $store.baseCurrency) {
                    ForEach(CurrencyCode.allCases) { Text("\($0.rawValue) · \($0.title)").tag($0) }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "globe").font(.caption.weight(.bold))
                    Text(store.baseCurrency.rawValue).font(.subheadline.weight(.bold))
                }
                .foregroundStyle(AppTheme.ink)
                .padding(.horizontal, AppTheme.Space.m).padding(.vertical, AppTheme.Space.s)
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.radiusSmall))
                .overlay(RoundedRectangle(cornerRadius: AppTheme.radiusSmall).stroke(AppTheme.hairline, lineWidth: 0.5))
            }
        }
    }
}

private struct HeroTotal: View {
    @EnvironmentObject private var store: SubscriptionStore
    let period: SpendPeriod
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.s) {
            SectionLabel(text: period == .month ? "本月待扣费" : "今年待扣费")
            Text(store.converter.format(store.dueAmount(in: period), currency: store.baseCurrency))
                .font(.amountHero())
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1).minimumScaleFactor(0.5)
                .contentTransition(.numericText())
            Text(subtitle)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, AppTheme.Space.s)
        .animation(AppTheme.spring, value: period)
    }
    private var subtitle: String {
        let n = store.dueCount(in: period)
        if let next = store.nextCharge(in: period) {
            return "\(n) 笔 · 下一笔 \(next.subscription.name) \(next.date.formatted(.dateTime.month().day()))"
        }
        return "\(store.activeSubscriptions.count) 个订阅 · 本期无待扣费"
    }
}

private struct UpcomingPanel: View {
    @EnvironmentObject private var store: SubscriptionStore
    let period: SpendPeriod
    private var charges: [RenewalCharge] { Array(store.charges(in: period).prefix(6)) }
    var body: some View {
        Panel(title: "即将扣费") {
            if charges.isEmpty {
                Text("本期没有待扣费订阅")
                    .font(.subheadline).foregroundStyle(AppTheme.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, AppTheme.Space.s)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(charges.enumerated()), id: \.element.id) { i, c in
                        if i > 0 { Hairline() }
                        HStack(spacing: AppTheme.Space.m) {
                            CategoryGlyph(subscription: c.subscription)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(c.subscription.name).font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.ink)
                                Text("\(c.date.formatted(.dateTime.month().day())) · \(c.subscription.plan)")
                                    .font(.caption).foregroundStyle(AppTheme.secondary)
                            }
                            Spacer()
                            Text(store.converter.format(c.amount, currency: store.baseCurrency))
                                .font(.amount()).foregroundStyle(AppTheme.ink)
                        }
                        .padding(.vertical, AppTheme.Space.m)
                    }
                }
            }
        }
    }
}

private struct CategoryPanel: View {
    @EnvironmentObject private var store: SubscriptionStore
    var body: some View {
        Panel(title: "支出分类") {
            HStack(spacing: AppTheme.Space.xl) {
                Chart(store.categorySpend) { item in
                    SectorMark(angle: .value("金额", item.amount),
                               innerRadius: .ratio(0.68), angularInset: 1.5)
                        .foregroundStyle(item.category.color)
                }
                .frame(width: 116, height: 116)

                VStack(spacing: AppTheme.Space.s) {
                    ForEach(store.categorySpend.prefix(5)) { item in
                        HStack(spacing: AppTheme.Space.s) {
                            Circle().fill(item.category.color).frame(width: 7, height: 7)
                            Text(item.category.rawValue)
                                .font(.caption.weight(.semibold)).foregroundStyle(AppTheme.ink)
                            Spacer()
                            Text("\(Int((item.share * 100).rounded()))%")
                                .font(.caption.weight(.bold).monospacedDigit())
                                .foregroundStyle(AppTheme.secondary)
                        }
                    }
                }
            }
        }
    }
}

private struct CalendarPanel: View {
    @EnvironmentObject private var store: SubscriptionStore
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    private let symbols = Calendar.current.veryShortStandaloneWeekdaySymbols
    var body: some View {
        Panel(title: "本月扣费日") {
            VStack(spacing: AppTheme.Space.m) {
                HStack {
                    ForEach(symbols, id: \.self) { s in
                        Text(s).font(.caption2.weight(.semibold))
                            .foregroundStyle(AppTheme.tertiary).frame(maxWidth: .infinity)
                    }
                }
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(Array(cells.enumerated()), id: \.offset) { _, day in
                        if let day {
                            let cs = charges(on: day)
                            VStack(spacing: 3) {
                                Text("\(day)")
                                    .font(.caption.monospacedDigit().weight(cs.isEmpty ? .regular : .bold))
                                    .foregroundStyle(cs.isEmpty ? AppTheme.tertiary : AppTheme.ink)
                                HStack(spacing: 2) {
                                    ForEach(cs.prefix(3)) { c in
                                        Circle().fill(c.subscription.category.color).frame(width: 4, height: 4)
                                    }
                                }.frame(height: 4)
                            }
                            .frame(height: 34).frame(maxWidth: .infinity)
                            .background(cs.isEmpty ? Color.clear : AppTheme.accent.opacity(0.10),
                                        in: RoundedRectangle(cornerRadius: AppTheme.radiusSmall))
                        } else {
                            Color.clear.frame(height: 34)
                        }
                    }
                }
            }
        }
    }
    private var cells: [Int?] {
        let cal = Calendar.current
        guard let interval = cal.dateInterval(of: .month, for: .now),
              let range = cal.range(of: .day, in: .month, for: .now) else { return [] }
        let firstWeekday = cal.component(.weekday, from: interval.start)
        let lead = firstWeekday - cal.firstWeekday
        let offset = lead >= 0 ? lead : lead + 7
        return Array(repeating: nil, count: offset) + range.map { Optional($0) }
    }
    private func charges(on day: Int) -> [RenewalCharge] {
        store.charges(in: .month).filter { Calendar.current.component(.day, from: $0.date) == day }
    }
}

private struct YearPanel: View {
    @EnvironmentObject private var store: SubscriptionStore
    var body: some View {
        Panel(title: "全年扣费分布") {
            Chart(store.monthTotalsForCurrentYear()) { p in
                BarMark(x: .value("月", p.month, unit: .month),
                        y: .value("金额", p.amount))
                    .foregroundStyle(p.month < Date.now ? AppTheme.hairline : AppTheme.accent)
                    .cornerRadius(4)
            }
            .chartXAxis { AxisMarks(values: .stride(by: .month)) { _ in
                AxisValueLabel(format: .dateTime.month(.narrow)) } }
            .chartYAxis(.hidden)
            .frame(height: 128)
        }
    }
}

private struct EmptyDashboard: View {
    var body: some View {
        VStack(spacing: AppTheme.Space.m) {
            Image(systemName: "tray").font(.system(size: 44, weight: .light))
                .foregroundStyle(AppTheme.tertiary)
            Text("还没有订阅").font(.title3.weight(.bold)).foregroundStyle(AppTheme.ink)
            Text("点右下角的 + 添加第一个订阅，\n这里会显示你的支出概览。")
                .font(.subheadline).foregroundStyle(AppTheme.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.top, 120)
    }
}

#Preview {
    DashboardView().environmentObject(SubscriptionStore())
}
```

- [ ] **Step 2: 编译**

Run:
```bash
cd /Users/bytedance/Desktop/Subscribe && xcodebuild -project Subscribe.xcodeproj -scheme SubscribeApp -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "DashboardView.swift.*error:" | head
```
Expected: 无 `DashboardView.swift` 报错。

- [ ] **Step 3: Commit**

```bash
cd /Users/bytedance/Desktop/Subscribe && git add -A && git commit -q -m "feat: redesign dashboard (hero / upcoming / category / calendar / year)" && echo done
```

---

## Task 6: 订阅列表页重做

**Files:**
- Modify: `SubscribeApp/Views/SubscriptionsView.swift`（整文件替换）

- [ ] **Step 1: 整文件替换为以下内容**

```swift
import SwiftUI

struct SubscriptionsView: View {
    @EnvironmentObject private var store: SubscriptionStore
    @State private var editing: Subscription?
    @State private var search = ""
    @State private var sort: SortOption = .renewalDate

    private var rows: [Subscription] {
        let f = store.subscriptions.filter {
            search.isEmpty
            || $0.name.localizedCaseInsensitiveContains(search)
            || $0.plan.localizedCaseInsensitiveContains(search)
            || $0.category.rawValue.localizedCaseInsensitiveContains(search)
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
            AppScreen {
                VStack(spacing: AppTheme.Space.l) {
                    HStack(spacing: AppTheme.Space.s) {
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
                        .padding(AppTheme.Space.m)
                        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.radius))
                        .overlay(RoundedRectangle(cornerRadius: AppTheme.radius).stroke(AppTheme.hairline, lineWidth: 0.5))

                        Menu {
                            Picker("", selection: $sort) {
                                ForEach(SortOption.allCases) { Label($0.title, systemImage: $0.icon).tag($0) }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.subheadline.weight(.bold)).foregroundStyle(AppTheme.ink)
                                .frame(width: 44, height: 44)
                                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.radius))
                                .overlay(RoundedRectangle(cornerRadius: AppTheme.radius).stroke(AppTheme.hairline, lineWidth: 0.5))
                        }
                    }
                    .reveal(0)

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
                                Button { editing = sub } label: {
                                    Row(subscription: sub) { store.delete(ids: [sub.id]) }
                                }
                                .buttonStyle(.plain).reveal(i + 1)
                            }
                        }
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $editing) { SubscriptionEditorView(subscription: $0) }
        }
    }
}

private enum SortOption: String, CaseIterable, Identifiable {
    case renewalDate, duration, cost, name
    var id: String { rawValue }
    var title: String {
        switch self {
        case .renewalDate: "按时间"; case .duration: "按周期长度"
        case .cost: "按费用"; case .name: "按名称"
        }
    }
    var icon: String {
        switch self {
        case .renewalDate: "calendar"; case .duration: "timer"
        case .cost: "banknote"; case .name: "textformat"
        }
    }
}

private struct Row: View {
    @EnvironmentObject private var store: SubscriptionStore
    let subscription: Subscription
    let onDelete: () -> Void
    var body: some View {
        HStack(spacing: AppTheme.Space.m) {
            CategoryGlyph(subscription: subscription, size: 44)
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
                }
                Text("\(subscription.plan) · \(subscription.category.rawValue) · \(subscription.billingCycle.rawValue)")
                    .font(.caption).foregroundStyle(AppTheme.secondary).lineLimit(1)
            }
            Spacer(minLength: AppTheme.Space.s)
            VStack(alignment: .trailing, spacing: 3) {
                Text(store.converter.format(
                    subscription.monthlyCost(in: store.baseCurrency, converter: store.converter),
                    currency: store.baseCurrency))
                    .font(.amountSmall()).foregroundStyle(AppTheme.ink)
                Text(subscription.nextBillingDate.formatted(.dateTime.month().day()))
                    .font(.caption2).foregroundStyle(AppTheme.tertiary)
            }
            Menu {
                Button(role: .destructive, action: onDelete) { Label("删除", systemImage: "trash") }
            } label: {
                Image(systemName: "ellipsis").font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.tertiary).frame(width: 28, height: 36)
            }
        }
        .padding(AppTheme.Space.l)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.radius))
        .overlay(RoundedRectangle(cornerRadius: AppTheme.radius).stroke(AppTheme.hairline, lineWidth: 0.5))
        .opacity(subscription.isActive ? 1 : 0.5)
    }
}

#Preview {
    SubscriptionsView().environmentObject(SubscriptionStore())
}
```

- [ ] **Step 2: 编译**

Run:
```bash
cd /Users/bytedance/Desktop/Subscribe && xcodebuild -project Subscribe.xcodeproj -scheme SubscribeApp -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "SubscriptionsView.swift.*error:" | head
```
Expected: 无 `SubscriptionsView.swift` 报错。

- [ ] **Step 3: Commit**

```bash
cd /Users/bytedance/Desktop/Subscribe && git add -A && git commit -q -m "feat: redesign subscriptions list" && echo done
```

---

## Task 7: 设置页 + 底部导航重塑

**Files:**
- Modify: `SubscribeApp/Views/SettingsView.swift`（整文件替换）
- Modify: `SubscribeApp/Views/ContentView.swift`（整文件替换）

- [ ] **Step 1: 整文件替换 `SettingsView.swift`**

```swift
import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var store: SubscriptionStore
    @State private var authStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        NavigationStack {
            AppScreen {
                VStack(spacing: AppTheme.Space.l) {
                    Panel(title: "统计") {
                        HStack {
                            Text("统一查看币种").font(.subheadline.weight(.medium))
                                .foregroundStyle(AppTheme.secondary)
                            Spacer()
                            Picker("", selection: $store.baseCurrency) {
                                ForEach(CurrencyCode.allCases) { Text("\($0.rawValue) · \($0.title)").tag($0) }
                            }.labelsHidden().tint(AppTheme.ink)
                        }
                        Hairline()
                        SectionLabel(text: "内置汇率（以 CNY 为基准）")
                        ForEach(CurrencyCode.allCases) { c in
                            HStack {
                                Text(c.rawValue).font(.caption.weight(.semibold)).foregroundStyle(AppTheme.ink)
                                Spacer()
                                Text("1 \(c.rawValue) = \(store.converter.cnyRates[c, default: 1], specifier: "%.3f") CNY")
                                    .font(.caption.monospacedDigit()).foregroundStyle(AppTheme.secondary)
                            }
                        }
                    }

                    Panel(title: "续费提醒") {
                        Toggle("开启提醒", isOn: $store.remindersEnabled)
                            .tint(AppTheme.accent).font(.subheadline.weight(.medium))
                        Hairline()
                        Button {
                            Task {
                                if await NotificationScheduler.requestAuthorization() {
                                    NotificationScheduler.rescheduleAll(store.subscriptions)
                                }
                                await loadStatus()
                            }
                        } label: {
                            Label("授权并同步提醒", systemImage: "bell.badge")
                                .font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.accent)
                        }
                        Text(statusText).font(.caption).foregroundStyle(AppTheme.secondary)
                    }

                    Panel(title: "iCloud 同步") {
                        Toggle("通过 iCloud 同步订阅", isOn: $store.iCloudSyncEnabled)
                            .tint(AppTheme.accent).font(.subheadline.weight(.medium))
                        Hairline()
                        HStack {
                            Button { store.syncFromICloud() } label: {
                                Label("拉取", systemImage: "icloud.and.arrow.down")
                                    .font(.subheadline.weight(.semibold))
                            }.disabled(!store.iCloudSyncEnabled).tint(AppTheme.accent)
                            Spacer()
                            Button { store.syncToICloud() } label: {
                                Label("上传", systemImage: "icloud.and.arrow.up")
                                    .font(.subheadline.weight(.semibold))
                            }.disabled(!store.iCloudSyncEnabled).tint(AppTheme.accent)
                        }
                        Text("使用 iCloud Key-Value Store 同步当前订阅。真机需 Apple ID 与应用 iCloud 权限可用。")
                            .font(.caption).foregroundStyle(AppTheme.secondary)
                    }

                    Panel(title: "数据") {
                        Button(role: .destructive) { store.resetSamples() } label: {
                            Label("恢复样例数据", systemImage: "arrow.counterclockwise")
                                .font(.subheadline.weight(.semibold))
                        }.tint(.red)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .task { await loadStatus() }
        }
    }

    private var statusText: String {
        switch authStatus {
        case .authorized, .provisional, .ephemeral: "系统通知已授权，按每个订阅的提前天数提醒。"
        case .denied: "系统通知未授权，需在 iOS 设置中允许通知。"
        case .notDetermined: "尚未请求系统通知权限。"
        @unknown default: "通知权限状态未知。"
        }
    }
    private func loadStatus() async {
        authStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }
}

#Preview {
    SettingsView().environmentObject(SubscriptionStore())
}
```

- [ ] **Step 2: 整文件替换 `ContentView.swift`**

```swift
import SwiftUI

private enum AppTab: String, CaseIterable, Identifiable {
    case dashboard, subscriptions, settings
    var id: String { rawValue }
    var title: String {
        switch self {
        case .dashboard: "总览"; case .subscriptions: "订阅"; case .settings: "设置"
        }
    }
    var icon: String {
        switch self {
        case .dashboard: "chart.pie"; case .subscriptions: "rectangle.stack"; case .settings: "gearshape"
        }
    }
}

struct ContentView: View {
    @State private var tab: AppTab = .dashboard
    @State private var showEditor = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch tab {
                case .dashboard: DashboardView()
                case .subscriptions: SubscriptionsView()
                case .settings: SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: AppTheme.Space.m) {
                HStack(spacing: 2) {
                    ForEach(AppTab.allCases) { t in
                        Button {
                            withAnimation(AppTheme.spring) { tab = t }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: t.icon).font(.system(size: 17, weight: .semibold))
                                Text(t.title).font(.caption2.weight(.semibold))
                            }
                            .foregroundStyle(tab == t ? AppTheme.surface : AppTheme.secondary)
                            .frame(maxWidth: .infinity).frame(height: 52)
                            .background(tab == t ? AppTheme.ink : .clear,
                                        in: RoundedRectangle(cornerRadius: AppTheme.radiusSmall))
                        }.buttonStyle(.plain)
                    }
                }
                .padding(4)
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.radius))
                .overlay(RoundedRectangle(cornerRadius: AppTheme.radius).stroke(AppTheme.hairline, lineWidth: 0.5))

                Button { showEditor = true } label: {
                    Image(systemName: "plus").font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.surface)
                        .frame(width: 60, height: 60)
                        .background(AppTheme.ink, in: RoundedRectangle(cornerRadius: AppTheme.radius))
                }
                .accessibilityLabel("新增订阅")
            }
            .padding(.horizontal, AppTheme.Space.l)
            .padding(.bottom, AppTheme.Space.s)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .sheet(isPresented: $showEditor) { SubscriptionEditorView(subscription: nil) }
    }
}

#Preview {
    ContentView().environmentObject(SubscriptionStore())
}
```

- [ ] **Step 3: 删除旧 `AppDesign.swift`**

Run:
```bash
cd /Users/bytedance/Desktop/Subscribe && grep -rl "AppDesign" SubscribeApp --include="*.swift"
```
Expected: 无输出（无文件再引用旧 token）。若有输出，先把这些引用改成 `AppTheme` 对应项再继续。然后：
```bash
cd /Users/bytedance/Desktop/Subscribe && rm SubscribeApp/Views/AppDesign.swift && xcodegen generate && echo removed
```

- [ ] **Step 4: 全量编译**

Run:
```bash
cd /Users/bytedance/Desktop/Subscribe && xcodebuild -project Subscribe.xcodeproj -scheme SubscribeApp -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -3
```
Expected: `** BUILD SUCCEEDED **`。

- [ ] **Step 5: Commit**

```bash
cd /Users/bytedance/Desktop/Subscribe && git add -A && git commit -q -m "feat: redesign settings + bottom dock, remove old AppDesign" && echo done
```

---

## Task 8: 模拟器验收 + 旧数据迁移实测

**Files:** 无代码改动（发现问题则回到对应任务修）

- [ ] **Step 1: 启动模拟器并安装**

Run:
```bash
cd /Users/bytedance/Desktop/Subscribe && xcrun simctl boot "iPhone 17 Pro" 2>/dev/null; open -a Simulator; xcodebuild -project Subscribe.xcodeproj -scheme SubscribeApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO -derivedDataPath /tmp/SubBuild build 2>&1 | tail -3
```
Expected: `** BUILD SUCCEEDED **`。

- [ ] **Step 2: 安装并启动 App**

Run:
```bash
xcrun simctl install "iPhone 17 Pro" "$(find /tmp/SubBuild -name 'SubscribeApp.app' -type d | head -1)" && xcrun simctl launch "iPhone 17 Pro" com.codex.SubscribeApp && echo launched
```
Expected: `launched`，模拟器中 App 打开，进入总览页（样例数据）。

- [ ] **Step 3: 肉眼验收清单（逐项确认）**

- [ ] 总览：Hero 大数字、即将扣费列表、分类细环、月日历 / 年柱状图，视觉统一无系统 Form 味
- [ ] 月/年切换、币种切换正常，金额有数字过渡动效
- [ ] 订阅页：搜索、排序、卡片样式干净，点卡片进编辑
- [ ] 编辑页：自定义表单（非系统 Form 灰底），无"使用频率/重要程度/席位/备注"，有"支付方式"；保存生效
- [ ] 设置页：四个分组视觉对齐；切换"开启提醒"开关
- [ ] 全 App 统一暖白底、统一圆角、无散落重阴影/彩色描边
- [ ] 删除一个订阅，删的是所点的那条（B2）
- [ ] 清空到无订阅时总览显示空状态引导

发现视觉偏差（间距/字号/色值）→ 回对应 view 文件改常量后重跑 Step 1–2，不改结构。

- [ ] **Step 4: B1 提醒开关实测**

模拟器中：设置页关闭"开启提醒"→ 回订阅页编辑任意订阅保存。Run:
```bash
xcrun simctl spawn "iPhone 17 Pro" log show --last 2m --predicate 'subsystem contains "com.apple.UserNotifications"' 2>/dev/null | tail -5 || echo "（无法取系统日志则改为：终端不可验证，记录为已知项，由用户在通知中心人工确认开/关行为）"
```
Expected: 关闭开关后保存订阅不新增 pending 通知；重新开启后恢复。系统日志取不到时如实记录为"人工确认项"，不谎报通过。

- [ ] **Step 5: 旧数据迁移实测（关键）**

构造含已删字段的旧版订阅 JSON，写入模拟器 App 的 UserDefaults，验证不崩、保留字段不丢。Run:
```bash
cd /Users/bytedance/Desktop/Subscribe && DC=$(xcrun simctl get_app_container "iPhone 17 Pro" com.codex.SubscribeApp data 2>/dev/null) && PLIST="$DC/Library/Preferences/com.codex.SubscribeApp.plist" && OLD='[{"id":"00000000-0000-0000-0000-000000000001","name":"OldSub","plan":"Legacy","category":"AI","price":12.5,"currency":"USD","billingCycle":"每月","customCycleDays":30,"nextBillingDate":"2026-06-01T00:00:00Z","reminderDaysBefore":3,"status":"自动续费","paymentMethod":"Visa","seats":5,"usageScore":4,"importanceScore":5,"notes":"legacy note"}]' && xcrun simctl terminate "iPhone 17 Pro" com.codex.SubscribeApp 2>/dev/null; plutil -replace "subscriptions.v1" -data "$(printf '%s' "$OLD" | base64)" "$PLIST" && xcrun simctl launch "iPhone 17 Pro" com.codex.SubscribeApp && echo "relaunched with legacy data"
```
Expected: `relaunched with legacy data`，App 不崩溃；订阅页出现 "OldSub"（name/price/currency/paymentMethod 等保留字段完好，多余的 seats/usageScore/... 被忽略）。若崩溃 → Task 1 的迁移容错有问题，回 Task 1 处理（必要时为 `Subscription` 写自定义 `init(from:)` 容错解码）。

- [ ] **Step 6: 收尾 Commit**

```bash
cd /Users/bytedance/Desktop/Subscribe && git add -A && git commit -q -m "chore: simulator acceptance + legacy data migration verified" --allow-empty && echo done
```

---

## Self-Review（已执行）

- **Spec 覆盖**：§3 字段砍除→Task1；死代码→Task2；B1/B2→Task2；迁移容错→Task1+Task8.5；§4 视觉系统→Task3；§5 五个页面→Task4–7（含空状态 Task5/6）；§7 验收→Task8。无遗漏。
- **占位扫描**：无 TBD/TODO；所有改代码步骤含完整代码；视图首版代码完整可编译，视觉迭代明确为"调常量"。
- **类型一致性**：`AppTheme`/`AppScreen`/`Panel`/`SectionLabel`/`Hairline`/`CategoryGlyph`/`reveal(_:)`/`Font.amount*()` 在 Task3 定义，Task4–7 引用一致；`SortOption`/`FieldRow`/`Row` 为各 view 私有；store 仅引用 Task2 保留的 API（`activeSubscriptions`/`dueAmount`/`dueCount`/`nextCharge`/`charges`/`categorySpend`/`monthTotalsForCurrentYear`/`baseCurrency`/`converter`/`subscriptions`/`upsert`/`delete(ids:)`/`resetSamples`/`syncFromICloud`/`syncToICloud`/`remindersEnabled`/`iCloudSyncEnabled`），均未被删。`SubscriptionStore.samples` 为 internal `static`，Preview 用 `SubscriptionStore()`（init 内自带 samples），一致。
