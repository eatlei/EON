# Subscribe — UI 重塑 + 功能精简 设计文档

日期：2026-05-18
状态：已与用户确认，进入实现规划

## 1. 背景与目标

Subscribe 是一个 SwiftUI iOS 订阅管理 App。数据层与业务计算（`Subscription` 模型、`SubscriptionStore` 的金额换算与周期投影）正确且干净；问题集中在视觉层粗糙、功能冗余。

本次目标，仅两件事：

1. **变好看**：将全部界面重塑到 Things 3 级别的原生质感与克制美学。
2. **精简**：砍掉非核心字段与未使用的死代码，回归"录入订阅 + 多货币展示 + 安静但丰富的全局概览"这一核心。

非目标（本次明确不做）：实时汇率 API、预算功能、CSV 导入、订阅详情独立页、单元测试 target、真实 AppIcon。

## 2. 实现策略

原地重塑视觉层，不重写架构。保留 `Subscription` 模型与 `SubscriptionStore` 计算逻辑，重做整个 `Views/`，删除被砍字段与死代码。风险低，不破坏已验证逻辑。

## 3. 功能范围（已确认）

### 保留
- 续费提醒（本地通知）
- iCloud Key-Value Store 同步
- 状态标记（自动续费 / 手动续费 / 试用期 / 已暂停）
- 支付方式字段

### 砍掉
- 字段：`usageScore`（使用频率）、`importanceScore`（重要程度）、`seats`（席位）、`notes`（备注）
- `SubscriptionStore` 中无任何视图使用的计算属性：`currencyExposure`、`cycleSpend`、`topSubscriptions`、`forecast`、`renewalWindows`、`statusCounts`、`averageMonthlyCost`、`averageUsageScore`、`averageImportanceScore`
- `Analytics.swift` 中对应未使用结构体：`CurrencyExposure`、`CycleSpend`、`RenewalWindow`、`StatusCount`
- 说明：`ForecastMonth` 结构体**保留**（年柱状图 `monthTotalsForCurrentYear` 仍在用）；但 `SubscriptionStore.forecast` 这个 6 个月预测计算属性无任何视图使用，**删除**

### 顺带修复的真实 bug
- **B1**：`remindersEnabled` 开关失效。`SubscriptionStore.subscriptions.didSet` 无条件调用 `NotificationScheduler.rescheduleAll`，且 `NotificationScheduler` 从不检查 `remindersEnabled`。修复后开关真正 gate 通知调度：关闭时清除所有 pending 通知，开启时按规则重排。
- **B2**：`SubscriptionStore.delete(at offsets:)` 按 `nextBillingDate` 排序映射 offset，与视图实际使用的 filter/sort 列表不一致，存在删错条目隐患。视图已统一走 `delete(ids:)`，本次直接移除 `delete(at:)`。

### 数据迁移容错
旧 UserDefaults / iCloud KVS 中的 `Subscription` JSON 含被删字段。解码必须容错：被删字段在 `Codable` 中忽略即可（移除属性后 `JSONDecoder` 默认忽略多余键，无需自定义），但需验证移除属性后旧数据仍能解码成功，不丢失保留字段。samples 同步更新。

## 4. 视觉系统（Things 3 级，目标定义）

约束以可验证的规则表达，避免主观词：

- **底色**：纸感暖白，单色，无渐变。参考 `#FBFAF8`。深色模式本次不专门设计（沿用浅色，后续可扩展）。
- **层级**：靠字重 + 留白分组，不靠卡片描边/阴影。移除现有视图中普遍存在的 `RoundedRectangle().stroke(...) + .shadow(...)` 组合。面板边界最多一条 ≤1px 的极淡发丝线，或纯靠间距。
- **色彩**：
  - 文本墨黑 `#1A1A1C`，次要文字中灰。
  - 一个低饱和强调色用于选中态与关键数字。
  - 分类颜色只出现在小圆点 / 字母头像背景上，不做大色块。
- **字体**：纯系统 SF。金额为视觉主角：大号、`.bold`/`.heavy`、`.rounded` design、`monospacedDigit`、紧字距。
- **圆角**：全 App 统一一个值（10pt 基准），所有 `RoundedRectangle`/clip 一致。
- **间距**：定义一套间距阶（如 4/8/12/16/20/28），所有布局取自该阶，不再散落魔法数。
- **动效**：保留轻量入场（reveal）但降低位移与延迟；金额变化用 `.contentTransition(.numericText())`；页面/周期切换用统一 spring。移除"收据齿轮 / 虚线分隔"等不服务状态的装饰。

这些以 `AppDesign.swift` 中的设计 token + 复用组件落地，全 App 引用同一套，禁止视图内写散落样式常量。

## 5. 页面设计

### 5.1 总览 DashboardView（核心，"丰富但安静"）
- 顶部：月/年极简分段控件 + 币种切换（弱化为小入口菜单）。
- Hero：当前周期待扣费**巨大数字** + 一行副信息（`N 笔 · 下一笔 X 日期`）。无卡片描边，靠留白与字重立住。
- 即将扣费：干净列表行（分类色字母头像圆点 + 名称 + 日期/套餐 + 金额），非收据样式。
- 支出分类：克制细环图（细描边 sector）+ 右侧 分类圆点/名称/百分比 列表。
- 周期视图：月 → 简化扣费日历网格；年 → 安静单色柱状图（去描边、去多余轴）。
- 空状态：无订阅时展示引导文案 + 提示从右下加号添加（替代现状的空白/默认 ContentUnavailableView 风格，视觉对齐）。

### 5.2 订阅列表 SubscriptionsView
- 搜索 + 排序保留（排序项：续费时间/周期时长/费用/名称）。
- 卡片去阴影、去彩色描边，改为 Things 式清爽行/轻卡，分类色仅在小圆点。
- 点击进入编辑（保持现状交互，不新增详情页）。
- 删除走 `delete(ids:)`。

### 5.3 编辑/新增 SubscriptionEditorView（当前最丑，重做）
- 用与主界面一致的自定义表单替换系统 `Form` 默认样式：分组留白、原生输入控件但统一视觉 token。
- 字段（精简后）：名称、套餐、分类、价格 + 币种、扣费周期（+ 周期为自定义时显示自定义天数）、下次扣费日、状态、提前提醒天数、支付方式。
- 保存校验沿用：名称非空、价格 ≥ 0。

### 5.4 设置 SettingsView
- 保留：统一币种、内置汇率展示、续费提醒（开关 + 授权 + 状态文案）、iCloud 同步（开关 + 拉取/上传 + 说明）、恢复样例数据。
- 提醒开关接入 B1 修复，行为真实生效。
- 视觉对齐主界面 token，脱离系统 Form 默认观感。

### 5.5 全局导航 ContentView
- 保留底部自定义 dock（总览/订阅/设置）+ 右侧独立加号弹出新增表单的结构。
- 视觉重塑：去重阴影/描边堆叠，统一圆角与材质，与新设计系统一致。

## 6. 受影响代码清单（实现规划据此展开）

- `Views/AppDesign.swift`：重写——色板 / 间距阶 / 统一圆角 / 字体规格 / 新的轻面板与行组件 / 精简动效。
- `Models/Subscription.swift`：移除 `usageScore`、`importanceScore`、`seats`、`notes`；更新 `monthlyCost`/`annualCost` 无关，不动。
- `Models/Analytics.swift`：移除未使用结构体（`CurrencyExposure`/`CycleSpend`/`RenewalWindow`/`StatusCount`），保留 `SpendPeriod`/`RenewalCharge`/`CategorySpend`/`ForecastMonth`（`ForecastMonth` 仍被 `monthTotalsForCurrentYear` 年柱状图使用，**保留**）。
- `Store/SubscriptionStore.swift`：移除未使用计算属性（见 §3）；保留 `monthTotalsForCurrentYear`、`charges`、`dueAmount/Count`、`nextCharge`、`categorySpend`、`upcoming`、`monthlyTotal/annualTotal`；移除 `delete(at:)`（B2）；提醒调度接入 `remindersEnabled`（B1）；samples 去掉被删字段。
- `Services/NotificationScheduler.swift`：`rescheduleAll` / 调度逻辑接入 `remindersEnabled` gate（B1，需要把开关状态传入或在 store 侧判断后再调）。
- `Views/DashboardView.swift`、`SubscriptionsView.swift`、`SubscriptionEditorView.swift`、`SettingsView.swift`、`ContentView.swift`：按 §5 重做，引用新 token。
- 文件增删后需重跑 `xcodegen generate`。

## 7. 验收标准

- `xcodegen generate` 后 `xcodebuild ... CODE_SIGNING_ALLOWED=NO build` 编译通过（改动前先建立基线）。
- 模拟器运行：四个页面视觉统一，无系统 Form 默认观感，无散落阴影/描边堆叠。
- 砍掉的字段在模型、编辑页、列表卡片、samples 中均无残留引用。
- 设置页关闭"开启提醒"后，新增/修改订阅不再产生 pending 通知；开启后恢复（B1 可在模拟器用通知中心或日志验证）。
- 用含旧字段的 UserDefaults 数据启动，不崩溃、保留字段不丢（B 迁移容错）。
- 视觉迭代在模拟器中进行，以真机原生质感为准，不依赖 HTML 草图。

## 8. 风险

- Things 级"好看"主观，已通过 §4 可验证规则降低分歧；最终以模拟器真机效果迭代确认，预期需要数轮视觉微调。
- 删字段的数据迁移：必须用旧数据实测，避免老用户数据解码失败。
- 当前目录非 git 仓库，无版本回退兜底；改动前建立编译基线，分阶段推进。
