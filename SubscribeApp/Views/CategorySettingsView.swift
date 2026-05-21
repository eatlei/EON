import SwiftUI

/// 分类管理:
/// - 第 1 段:8 个内置分类。可以重命名(改的是 nameOverrides),颜色不能改;
///   不能删除(它们是默认选项,任何老订阅都可能引用)。
/// - 第 2 段:用户的自定义分类。可加可删(swipe-to-delete),改名/换色都可以,
///   引用它的订阅会跟着实时更新(因为走的是 customLookup);删除时引用它的
///   订阅会被解绑回各自的内置 fallback。
///
/// 自定义分类总数上限 = CustomCategory.maxCount(默认 12 个)。
struct CategorySettingsView: View {
    @EnvironmentObject private var store: SubscriptionStore

    // 重命名内置分类的弹窗状态
    @State private var renamingBuiltIn: SubscriptionCategory?
    @State private var draftBuiltInName: String = ""

    // 自定义分类的"新建 / 编辑"弹窗
    @State private var editingCustom: CustomCategory?
    @State private var showingNewCustom = false

    var body: some View {
        List {
            // MARK: 内置分类
            Section {
                ForEach(SubscriptionCategory.allCases) { cat in
                    Button {
                        renamingBuiltIn = cat
                        draftBuiltInName = store.categoryNameOverrides[cat.rawValue] ?? ""
                    } label: {
                        HStack(spacing: 12) {
                            Circle().fill(cat.color).frame(width: 14, height: 14)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(cat.title).foregroundStyle(.primary)
                                if cat.title != cat.defaultTitle {
                                    Text(cat.defaultTitle)
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if cat.title != cat.defaultTitle {
                                Button {
                                    store.categoryNameOverrides[cat.rawValue] = nil
                                } label: {
                                    Image(systemName: "arrow.uturn.backward.circle")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("内置分类")
            } footer: {
                Text("点一下可以改名。颜色固定,不能删除。")
            }

            // MARK: 自定义分类
            Section {
                if store.customCategories.isEmpty {
                    Text("还没有自定义分类")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                } else {
                    ForEach(store.customCategories) { cc in
                        Button { editingCustom = cc } label: {
                            HStack(spacing: 12) {
                                Circle().fill(cc.color).frame(width: 14, height: 14)
                                Text(cc.name).foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        let ids = offsets.map { store.customCategories[$0].id }
                        for id in ids { store.deleteCustomCategory(id: id) }
                    }
                }

                Button {
                    showingNewCustom = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(store.customCategorySlotsLeft > 0 ? AppTheme.accent : AppTheme.tertiary)
                        Text("添加分类")
                            .foregroundStyle(store.customCategorySlotsLeft > 0 ? AppTheme.ink : AppTheme.tertiary)
                        Spacer()
                        Text("\(store.customCategories.count) / \(CustomCategory.maxCount)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(store.customCategorySlotsLeft == 0)
            } header: {
                Text("自定义分类")
            } footer: {
                Text("自定义分类最多 \(CustomCategory.maxCount) 个。删除一个分类后,引用它的订阅会回到原始内置分类显示。左滑可删除。")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.visible)
        .navigationTitle("分类")
        .navigationBarTitleDisplayMode(.inline)

        // 重命名内置分类
        .alert("重命名", isPresented: Binding(
            get: { renamingBuiltIn != nil },
            set: { if !$0 { renamingBuiltIn = nil } }
        )) {
            TextField("如 游戏 / 健身 / 杂项", text: $draftBuiltInName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
            Button("保存") {
                if let cat = renamingBuiltIn {
                    let trimmed = draftBuiltInName.trimmingCharacters(in: .whitespacesAndNewlines)
                    var overrides = store.categoryNameOverrides
                    if trimmed.isEmpty || trimmed == cat.defaultTitle {
                        overrides[cat.rawValue] = nil
                    } else {
                        overrides[cat.rawValue] = trimmed
                    }
                    store.categoryNameOverrides = overrides
                }
                renamingBuiltIn = nil
            }
            Button("取消", role: .cancel) { renamingBuiltIn = nil }
        } message: {
            if let cat = renamingBuiltIn {
                Text("默认: \(cat.defaultTitle)")
            }
        }

        // 新建自定义分类 —— 把"内置 8 色 + 其他 custom 用掉的"都传进去禁用,
        // 避免新建出来的分类跟任何已存在的颜色撞,影响饼图 / 卡片可辨识度。
        .sheet(isPresented: $showingNewCustom) {
            CustomCategoryEditorSheet(
                category: nil,
                usedColors: CustomCategory.builtInOccupiedHexes
                    .union(store.customCategories.map { $0.colorHex.lowercased() })
            ) { name, hex in
                store.addCustomCategory(name: name, colorHex: hex)
            }
        }

        // 编辑已有自定义分类 —— 用掉的色号包括"内置 8 色 + 其他 custom 用掉的",
        // 自己原来的色不在 used 集里所以仍可选。
        .sheet(item: $editingCustom) { existing in
            CustomCategoryEditorSheet(
                category: existing,
                usedColors: CustomCategory.builtInOccupiedHexes
                    .union(
                        store.customCategories
                            .filter { $0.id != existing.id }
                            .map { $0.colorHex.lowercased() }
                    )
            ) { name, hex in
                store.updateCustomCategory(
                    CustomCategory(id: existing.id, name: name, colorHex: hex)
                )
            }
        }
    }
}

// MARK: - 新建 / 编辑 自定义分类的弹窗

private struct CustomCategoryEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let category: CustomCategory?
    /// 已经被"其他 custom 分类"占用的颜色 hex(小写)。这些色号在选色盘上会
    /// 灰掉并禁用点击,避免两个 custom 分类撞色让饼图 / 卡片视觉混淆。
    let usedColors: Set<String>
    let onSave: (String, String) -> Void

    @State private var name: String
    @State private var colorHex: String

    init(category: CustomCategory?,
         usedColors: Set<String>,
         onSave: @escaping (String, String) -> Void) {
        self.category = category
        self.usedColors = usedColors
        self.onSave = onSave
        _name = State(initialValue: category?.name ?? "")
        // 默认选第一个"还没被用掉"的色,避免新建的时候默认就选到一个禁用项。
        let firstFree = CustomCategory.palette.first {
            !usedColors.contains($0.lowercased())
        } ?? CustomCategory.palette.first!
        _colorHex = State(initialValue: category?.colorHex ?? firstFree)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 6)

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "分类名称"), text: $name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                } header: {
                    Text("名称")
                }

                Section {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(CustomCategory.palette, id: \.self) { hex in
                            colorSwatch(hex)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("颜色")
                }

                // 预览
                Section {
                    HStack(spacing: 12) {
                        Circle().fill(Color(hexString: colorHex)).frame(width: 18, height: 18)
                        Text(name.isEmpty ? String(localized: "分类名称") : name)
                            .foregroundStyle(name.isEmpty ? .secondary : .primary)
                    }
                } header: {
                    Text("预览")
                }
            }
            .navigationTitle(category == nil ? "新建分类" : "编辑分类")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        onSave(name.trimmingCharacters(in: .whitespacesAndNewlines), colorHex)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    @ViewBuilder
    private func colorSwatch(_ hex: String) -> some View {
        let isSelected = hex == colorHex
        let isUsed = usedColors.contains(hex.lowercased())
        Button {
            guard !isUsed else { return }
            colorHex = hex
        } label: {
            ZStack {
                Circle().fill(Color(hexString: hex))
                    .frame(width: 36, height: 36)
                    .opacity(isUsed ? 0.28 : 1)
                if isSelected && !isUsed {
                    Circle()
                        .stroke(AppTheme.ink, lineWidth: 2.5)
                        .frame(width: 42, height: 42)
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(.white)
                }
                // 已占用的色号画一条斜杠,一眼就能看出来"这个不能选"。
                if isUsed {
                    Image(systemName: "slash.circle")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppTheme.secondary)
                }
            }
            .frame(height: 44)
        }
        .buttonStyle(.plain)
        .disabled(isUsed)
        .accessibilityLabel(Text(isUsed ? String(localized: "颜色已被使用") : ""))
    }
}

#Preview {
    NavigationStack { CategorySettingsView() }
        .environmentObject(SubscriptionStore())
}
