# Subscribe — 冷调深色 + Liquid Glass 视觉迭代 Implementation Plan

> 这是首版重塑（`docs/superpowers/specs/2026-05-18-subscribe-ui-redesign-design.md`）之后的视觉迭代轮，spec §8 已预期"数轮视觉微调"。**硬约束：结构完全不动**——视图层级 / 导航 / dock 布局 / 页面组成 / store API 一律不改，只换设计 token 的值与材质。

**Goal:** 把全 App 从暖白 Things-3 风翻成冷调深色 + 原生 Liquid Glass（iOS 26），更现代：更大圆角、玻璃卡片、微渐变/高光点缀。

**Architecture:** 视觉已集中在 `AppTheme.swift`（token + AppScreen/Panel/SectionLabel/Hairline/CategoryGlyph/RevealModifier/reveal/Font.amount*）。保持所有**公开符号名不变**，只改值/材质；视图文件因此基本零改动，仅做深色对比度收尾微调（不改结构）。底部 dock 在 ContentView 内就地换 Liquid Glass 材质（同一 ZStack/HStack 结构）。

**Tech Stack:** SwiftUI + iOS 26 Liquid Glass (`glassEffect`/`GlassEffectContainer`/`.buttonStyle(.glass)`), Charts, XcodeGen, Xcode 26.5。iOS 26.5 SDK + iOS 26 模拟器已确认可用。无测试 target（验证=xcodebuild 编译 + 模拟器肉眼）。

**分支:** `redesign/glass`（从 main @ 8118dea 切出）。每任务末编译验证 + commit。

---

## 设计增量（token 语义不变，值/材质变）

- **底色 canvas**：冷调深色，参考 `#0E1014`（近黑蓝灰），无暖味。
- **surface（卡片/面板）**：Liquid Glass 玻璃材质（`.glassEffect(.regular, in:)`），不再是纯白实色。深色玻璃，半透明。
- **ink（主文字）**：近白 `#F2F4F8`。**secondary** 中灰偏冷 `#9BA0AB`。**tertiary** 更暗 `#5E636E`。
- **accent（单一高饱和强调）**：冷调亮色，参考电蓝/青 `#3D9CFF`（深色玻璃下最跳、最现代）。
- **hairline**：极淡冷白描边 `Color.white.opacity(0.08)`（深色下做玻璃边界/分隔）。
- **radius**：放大，`radius 16`、`radiusSmall 12`（更现代的大圆角）。
- **微渐变/高光**：Hero 数字区与强调处加极轻的顶部高光/线性渐变（克制，服务质感不喧宾夺主）。
- **Liquid Glass**：dock、Panel、关键卡片用原生 `glassEffect`；dock 多元素用 `GlassEffectContainer` 融合。深色模式锁定（本迭代不做浅色）。
- **Space / spring / Font.amount\* / 所有结构**：不变。

> 关键不变量：`AppTheme.canvas/surface/ink/secondary/tertiary/hairline/accent/radius/radiusSmall/Space/spring`、`AppScreen/Panel/SectionLabel/Hairline/CategoryGlyph/reveal/Font.amountHero()/amount()/amountSmall()` 这些**名字与签名一字不改**，调用方（5 个视图）因此无需结构改动。

---

## Task G0: 分支就绪 + 部署目标提到 iOS 26

**Files:** `project.yml`

- [ ] **Step 1**：把 `project.yml` 的 `deploymentTarget: iOS: "17.0"` 改为 `iOS: "26.0"`。
- [ ] **Step 2**：`cd /Users/bytedance/Desktop/Subscribe && xcodegen generate && xcodebuild -project Subscribe.xcodeproj -scheme SubscribeApp -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -3` → 预期 `** BUILD SUCCEEDED **`（改 token 前先确认 iOS 26 目标下现状仍可编译）。
- [ ] **Step 3**：`git add -A && git commit -q -m "build: raise deployment target to iOS 26 for Liquid Glass" && echo done`

## Task G1: AppTheme 翻冷调深色 + Liquid Glass（核心）

**Files:** `SubscribeApp/Views/AppTheme.swift`（按"设计增量"重写值/材质，**公开符号名与签名不变**）

- [ ] **Step 1**：改色板常量为上文冷调深色值（canvas/surface 语义保留；surface 现在配合 glass 使用）。radius=16、radiusSmall=12。`Space`/`spring`/`Font.amount*` 不动。
- [ ] **Step 2**：`Panel` 背景从纯 `surface` 实色改为 Liquid Glass：`.glassEffect(.regular, in: RoundedRectangle(cornerRadius: AppTheme.radius))`（保留可选 title、@ViewBuilder init、frame/padding 结构不变）。`AppScreen` 背景改深色 canvas（保留 bottomPadding 参数与 init 不变）。`Hairline` 用新 hairline 值。`CategoryGlyph`/`SectionLabel`/`RevealModifier`/`reveal` 逻辑不变，仅随新 token 取色。
- [ ] **Step 3**：Hero/强调处可加极轻渐变高光的复用修饰（可选，若加则新增不破坏现有 API 的辅助，不改 `Font.amount*` 签名）。
- [ ] **Step 4**：`cd /Users/bytedance/Desktop/Subscribe && xcodebuild -project Subscribe.xcodeproj -scheme SubscribeApp -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -3` → 预期 `** BUILD SUCCEEDED **`（符号名未变，5 个视图应无需改动即编译通过；若某视图报错说明动了不该动的符号——回退该处）。
- [ ] **Step 5**：`git add -A && git commit -q -m "feat: AppTheme to cool-dark + Liquid Glass" && echo done`

## Task G2: dock Liquid Glass + 深色对比度收尾（不改结构）

**Files:** `SubscribeApp/Views/ContentView.swift`（仅 dock 材质）、必要时各视图**仅 token 取值/不透明度**微调（禁止改布局/层级/控件）

- [ ] **Step 1**：ContentView 底部 dock —— 保持同一 `ZStack(alignment:.bottom)` + `HStack` + tab 按钮 + 独立加号的结构，仅把 pill bar 与加号按钮的 `.background(...surface/ink...)` 换成 Liquid Glass：用 `GlassEffectContainer` 包裹，pill bar `.glassEffect(.regular, in: Capsule()/RoundedRectangle)`，选中态用 `AppTheme.accent` tint（`.glassEffect(.regular.tint(...))` 或选中底色 accent），加号按钮 `.buttonStyle(.glass)` 或 `.glassEffect`。不新增/删除控件，不改 padding 结构层级。
- [ ] **Step 2**：深色对比度走查——逐个视图检查上一版用 token 的地方在深色玻璃下是否可读：选中 tab/分段的 fg/bg、`AppTheme.accent.opacity(0.10/0.14)` 高亮是否够亮、年柱状图 past=hairline 是否可见、Charts 分类色在深色下对比。**只允许调 token 取值或 opacity 常量，不允许改任何布局/结构/控件层级**。逐文件最小改动。
- [ ] **Step 3**：全量编译 `... | tail -3` → `** BUILD SUCCEEDED **`。
- [ ] **Step 4**：`git add -A && git commit -q -m "feat: Liquid Glass dock + dark-mode contrast pass" && echo done`

## Task G3: 模拟器肉眼验收（截图给用户签字）

**Files:** 无代码改动（发现问题回对应任务）

- [ ] **Step 1**：`cd /Users/bytedance/Desktop/Subscribe && xcrun simctl boot "iPhone 17 Pro" 2>/dev/null; xcodebuild -project Subscribe.xcodeproj -scheme SubscribeApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO -derivedDataPath /tmp/SubGlass build 2>&1 | tail -3` → `** BUILD SUCCEEDED **`
- [ ] **Step 2**：`xcrun simctl install "iPhone 17 Pro" "$(find /tmp/SubGlass -name 'SubscribeApp.app' -type d | head -1)" && xcrun simctl launch "iPhone 17 Pro" com.codex.SubscribeApp && echo launched`，等 3s（`python3 -c "import time;time.sleep(3)"`）。
- [ ] **Step 3**：截图 `/tmp/sub_glass/01-dashboard.png`（其余屏需交互无法纯脚本驱动——如实标注哪些是机器可截、哪些需人工在模拟器看）。
- [ ] **Step 4**：`git commit -q --allow-empty -m "chore: glass restyle simulator check" && echo done`

## Self-Review

- 范围：用户三决定（押 iOS 26 / 冷调深色 / 大圆角+玻璃卡片+微渐变）逐项落到 G0–G2；硬约束"结构不动"在每个任务显式禁止改布局/层级/控件，仅允许 token 值+材质+opacity。无遗漏。
- 占位：无 TBD；命令完整；设计增量给了具体色值/半径。
- 一致性：所有 `AppTheme.*` 公开符号名/签名显式声明不变，故 5 个视图调用方无需结构改动即可继续编译——这是"结构不动"可行的技术依据。Liquid Glass 为 iOS 26 新 API，以 xcodebuild 编译为硬验证，评审子代理额外核查 API 用法。
