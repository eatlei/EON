# Subscribe App Handoff

这份文档用于让后续接手的 Claude/Codex 快速理解当前 iOS App 的产品方向、功能现状、代码结构和可继续优化的任务。

## 产品定位

Subscribe 是一个 SwiftUI iOS 订阅管理 App。核心目标不是做复杂决策系统，而是让用户用很低成本看清：

- 本月/今年订阅要花多少钱。
- 哪些订阅即将扣费。
- 钱花在哪些分类上。
- 每个订阅的价格、周期、币种、提醒、使用情况。

当前设计参考过 Subo 和 Sublist，但目标是更清晰、更适合手机端阅读：减少大标题和解释文案，突出金额、日期、明细、分类占比。

## 当前功能

- 订阅管理：新增、编辑、删除订阅。
- 订阅字段：名称、套餐、分类、价格、币种、扣费周期、自定义周期、下次扣费日、提醒天数、状态、支付方式、席位、使用频率、重要程度、备注。
- 总览页：
  - 月/年一级切换。
  - 当前周期总额。
  - 当前周期扣费笔数。
  - 活跃订阅数量。
  - 下一笔扣费。
  - 本月扣费日历。
  - 全年扣费柱状图。
  - 支出分类饼图。
  - 收据风格的本月/近期明细。
- 订阅页：
  - 搜索订阅。
  - 按续费时间、周期时长、费用、名称排序。
  - 卡片式订阅列表。
- 底部导航：
  - 自定义 dock：总览、订阅、设置。
  - 加号按钮与 tab 同层级，但独立放置在右侧。
- 设置页：
  - 统一展示币种。
  - 内置汇率展示。
  - 本地通知授权与提醒同步。
  - iCloud Key-Value Store 同步开关、拉取、上传。
  - 恢复样例数据。

## 技术栈

- SwiftUI
- Charts
- UserNotifications
- UserDefaults 本地持久化
- NSUbiquitousKeyValueStore iCloud Key-Value Store
- XcodeGen 生成 Xcode 工程

运行命令：

```bash
xcodegen generate
xcodebuild -project Subscribe.xcodeproj -scheme SubscribeApp -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

## 代码地图

- `project.yml`
  - XcodeGen 配置。
  - 声明 iOS target、bundle id、entitlements。

- `SubscribeApp/SubscribeApp.swift`
  - App 入口。
  - 创建并注入 `SubscriptionStore`。

- `SubscribeApp/Models/Subscription.swift`
  - 核心订阅模型。
  - 枚举：`CurrencyCode`、`SubscriptionCategory`、`BillingCycle`、`RenewalStatus`。
  - `Subscription` 包含订阅字段和月/年成本计算。

- `SubscribeApp/Models/Analytics.swift`
  - 面向总览页的数据结构。
  - 包含 `SpendPeriod`、`RenewalCharge`、`CategorySpend`、`ForecastMonth` 等。

- `SubscribeApp/Services/CurrencyConverter.swift`
  - 内置汇率换算。
  - 当前是静态汇率，以 CNY 为中间基准。

- `SubscribeApp/Services/NotificationScheduler.swift`
  - 本地通知授权。
  - 按订阅的提前提醒天数创建续费提醒。

- `SubscribeApp/Store/SubscriptionStore.swift`
  - 全局状态和业务计算中心。
  - 管理订阅数组、基础币种、提醒开关、iCloud 同步开关。
  - 负责 UserDefaults 持久化。
  - 负责 iCloud KVS 同步。
  - 负责总览页所需的周期扣费、分类统计、月度投影等计算。
  - 内置样例数据。

- `SubscribeApp/Views/AppDesign.swift`
  - 全局视觉 token。
  - 包含颜色、通用背景、面板组件、入场动效、进度条。

- `SubscribeApp/Views/ContentView.swift`
  - 自定义底部 dock。
  - 控制总览/订阅/设置页面切换。
  - 右侧独立加号按钮弹出新增订阅表单。

- `SubscribeApp/Views/DashboardView.swift`
  - 总览页。
  - 月/年切换、主摘要卡、本月日历、全年柱状图、分类饼图、收据明细。

- `SubscribeApp/Views/SubscriptionsView.swift`
  - 订阅列表页。
  - 搜索和排序。
  - 点击卡片进入编辑。

- `SubscribeApp/Views/SubscriptionEditorView.swift`
  - 新增/编辑表单。
  - 使用 SwiftUI `Form`。

- `SubscribeApp/Views/SettingsView.swift`
  - 设置页。
  - 币种、通知、iCloud、数据重置。

- `SubscribeApp/SubscribeApp.entitlements`
  - iCloud Key-Value Store entitlement。

## 数据流

1. App 启动时 `SubscribeApp` 创建 `SubscriptionStore`。
2. `SubscriptionStore` 从 UserDefaults 读取订阅和设置。
3. 如果开启 iCloud 同步，会尝试从 `NSUbiquitousKeyValueStore` 拉取订阅。
4. 页面通过 `@EnvironmentObject` 读取 store。
5. 新增/编辑订阅时调用 `store.upsert(_:)`。
6. 删除订阅时调用 `store.delete(ids:)`。
7. `subscriptions` 变化后自动：
   - 保存到 UserDefaults。
   - 重新同步本地通知。
   - 如果 iCloud 开启，同步到 iCloud KVS。

## 重要设计原则

- 不要恢复“决策/替代方案”功能，用户已经明确要求移除。
- 不要在页面头部放大标题，如“总览”“订阅”。
- 不要添加无意义动效，所有动效都应该服务于状态变化或层级关系。
- 总览页应该优先展示金额、日期、扣费明细、分类占比。
- 新增入口保持在底部 dock 右侧，和 tab 同层级但视觉分离。
- 数据图表要可解释，避免抽象指标堆砌。
- UI 风格保持干净、圆角 8、浅色面板、低饱和色、数字信息突出。

## 当前限制

- 汇率是静态内置数据，没有实时汇率 API。
- iCloud 使用 KVS，只适合小量数据；未来大量附件或历史记录应迁移到 CloudKit。
- App 没有独立测试 target。
- AppIcon 只有占位 asset，没有真实图标。
- `SubscriptionEditorView` 仍是系统 Form 风格，和总览/订阅页的定制 UI 不完全一致。
- 通知只按当前 `nextBillingDate` 创建一次性提醒，没有自动在续费后滚动到下一周期。
- 没有历史支付记录，当前的年/月投影是基于下次扣费日和周期推算。

## 建议下一步

优先级较高：

1. 重做新增/编辑页 UI，让它和主界面视觉一致。
2. 增加真实 AppIcon 和订阅服务图标/字母头像优化。
3. 给 iCloud 同步增加状态反馈：同步中、成功、失败、上次同步时间。
4. 给通知增加“每次续费后自动排下一次提醒”的逻辑。
5. 增加空状态体验：没有订阅时总览页展示引导和添加按钮。

优先级中等：

1. 添加实时汇率服务，并允许用户手动覆盖汇率。
2. 增加预算目标：月预算、分类预算、超预算提醒。
3. 增加导入能力：从 CSV 或 App Store 订阅截图手动导入。
4. 增加归档/暂停订阅视图。
5. 增加订阅详情页，而不是直接从列表进入编辑。

质量保障：

1. 为 `CurrencyConverter` 和 `SubscriptionStore` 的扣费投影逻辑补单元测试。
2. 为月/年扣费统计补边界测试：年付、季度、自定义周期、跨年、过去日期。
3. 在模拟器和真机分别验证 iCloud 与通知权限。

## 注意事项

- 这个目录当前不是 git repository。
- 修改工程结构后需要重新运行 `xcodegen generate`。
- 真机 iCloud 同步需要有效 Apple Developer 配置、iCloud capability 和签名环境；无签名 generic build 只能验证编译。
