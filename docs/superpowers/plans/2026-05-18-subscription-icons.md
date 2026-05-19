# 订阅图标功能 Implementation Plan

> 用户授权：直接提交到 `main`（无分支）。范围：地基 + 三种来源（SF Symbol 图标库 / App Store 搜索抓取含地区切换 / 相册上传）。设计已与用户确认；法律安全取舍：图标库用 SF Symbols，不打包品牌 logo。两个硬限制用户已接受：自定义图片不跨设备同步（KVS 太小，需 CloudKit 才行，本期不做）；iTunes Search API 用于取图标属条款边缘但行业通行。

**Tech:** SwiftUI / iOS 26 / PhotosUI / URLSession（全 App 首段网络）。无测试 target，验证=xcodebuild + 模拟器。提交直接落 main，每任务后编译验证 + commit。

## 共同地基

`SubscriptionIcon`（Swift 自动合成枚举 Codable）：`.category`（默认/现状）、`.symbol(String)`（SF Symbol 名）、`.image(String)`（本地图片文件 id）。`Subscription` 加 `var icon: SubscriptionIcon = .category`。

**迁移要点（必须做对）**：`Subscription` 现为合成 Codable，加字段会让旧 JSON 解码失败。解法：在**扩展里**写自定义 `init(from:)`（扩展里写不会抑制 memberwise init，samples/editor 的 `Subscription(name:…)` 仍可用），其余字段正常 decode，`icon` 用 `decodeIfPresent ?? .category`。需显式 `CodingKeys` 含 icon。

`IconStore`：把图片裁中心方形、缩放到 512、PNG 写入 `Application Support/SubscriptionIcons/<uuid>.png`，返回 uuid；提供 load/delete；`store.delete(ids:)` 删订阅时清理其 `.image` 文件。

`CategoryGlyph(subscription:size:)`（AppTheme.swift，签名不变，调用方零改动）按 `subscription.icon` 分发渲染：`.category`→现状色块首字母；`.symbol`→白色 SF Symbol 居中于分类色圆角块；`.image`→读文件填充裁圆角，读不到回退 `.category`。

## Tasks

- **K1 地基**：`SubscriptionIcon` + `Subscription.icon` + 扩展内容错 `init(from:)` + `CodingKeys` + `IconStore` + `CategoryGlyph` 泛化 + `store.delete` 清文件。samples 保持 `.category`。全 App 编译绿、现有视觉不变。
- **K2 App Store 服务**：`AppStoreRegion`（cn/us/jp/gb/hk/de + 中文名 + country code）；`AppStoreIconService.search(term:region:) async throws -> [AppStoreApp]`（`https://itunes.apple.com/search?entity=software&limit=24&country=<cc>&term=<urlencoded>`，解析 `results[].trackName` + `artworkUrl100`→替换 `100x100`/`60x60` 为 `512x512`）；`fetchArtwork(_:) async throws -> Data`。纯服务，编译绿。
- **K3 选择器 UI**：`IconPickerView`（sheet，三段：① 精选 SF Symbol 网格 ~24 个、可搜过滤 → `.symbol`；② App Store：搜索框 + 地区 `Picker` + 结果列表，点选下载 artwork→`IconStore`→`.image`；③ `PhotosPicker` 选图→缩放→`IconStore`→`.image`；含"恢复默认"→`.category`）。`SubscriptionEditorView` 加"图标"行：左侧 `CategoryGlyph` 预览，点开 `IconPickerView` 绑定 `$draft.icon`。编译绿 + 模拟器截图。
- **K4 评审+验证**：聚焦评审（迁移容错：旧数据仍解码且 icon 默认 .category、memberwise init 保留；网络错误/空结果处理；图片文件生命周期/删除清理；无范围回归）；模拟器截图（选择器三段 + 应用某图标，浅/深）；确认 main 全量编译绿。

## 验收

- 旧持久化数据（无 icon 键）启动不崩、订阅完好、图标回退 `.category`（K4 用旧数据实测）。
- 三种来源都能设置成功并在总览/列表正确显示；删订阅清理图片文件；App Store 可搜索、可切地区。
- 全 App `** BUILD SUCCEEDED **`；现有 Hero/分类/日历等不受影响。

## 注意

- PhotosPicker(PHPicker) 与 itunes.apple.com HTTPS 均无需改 Info.plist / ATS。
- 网络层做超时与错误态（空结果、断网）UI 反馈；不阻塞主线程（async）。
- `.image` 文件存 Application Support（非 Documents，避免备份膨胀）。
