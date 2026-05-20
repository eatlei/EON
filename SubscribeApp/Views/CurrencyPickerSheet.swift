import SwiftUI

/// 浮在 Overview 顶部货币按钮上的选择面板。之前用的是 inline Menu + Picker,
/// 弹出后默认从列表第一项开始(USD/AUD…),用户得手动滚到自己当前用的币种 ——
/// 体验很糟。改成 .sheet + ScrollViewReader,出现的瞬间就把当前选中的币种锚
/// 到列表中部,一眼就能确认 + 改。
struct CurrencyPickerSheet: View {
    @EnvironmentObject private var store: SubscriptionStore
    @Environment(\.dismiss) private var dismiss

    private var currencies: [CurrencyCode] {
        CurrencyCode.allCases.sorted { $0.rawValue < $1.rawValue }
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                    Section {
                        ForEach(currencies) { c in
                            Button {
                                store.baseCurrency = c
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    // 符号列宽 56pt(原来 30pt 太窄,Rp / kr / NT$ / R$
                                    // 这种 2–3 字符的货币符号会被 wrap 成两行)。leading
                                    // 对齐看起来比 center 整齐,各行符号左侧对齐。
                                    Text(c.symbol)
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundStyle(AppTheme.secondary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                        .frame(width: 56, alignment: .leading)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(c.rawValue)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(AppTheme.ink)
                                        Text(c.title)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if store.baseCurrency == c {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(AppTheme.accent)
                                            .font(.subheadline.weight(.bold))
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .id(c)
                        }
                    } header: {
                        Text("当前币种")
                    } footer: {
                        Text("切换后,所有订阅金额会按最新汇率换算到这个币种展示。")
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.visible)
                .navigationTitle("货币")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("关闭") { dismiss() }
                    }
                }
                // 出现的瞬间把当前选中行滚到列表的中部 —— 必须 onAppear 里加一帧
                // 延迟,等 List 先把 layout 跑完再 scrollTo,直接同步调用有时不
                // 生效(SwiftUI List 渲染时机问题)。
                .onAppear {
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 50_000_000)
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(store.baseCurrency, anchor: .center)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    CurrencyPickerSheet().environmentObject(SubscriptionStore())
}
