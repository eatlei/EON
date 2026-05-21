import SwiftUI

/// 一行收据明细。amount 已是格式化好的字符串(含币种符号)。
struct ReceiptLine: Identifiable {
    let id = UUID()
    let name: String
    let detail: String   // 例:"¥20.00 x 3"
    let amount: String   // 例:"¥60.00"
}

/// 超市热敏小票风格的"累计消费小票"。等宽字体 + 虚线分隔 + 假条形码,
/// 顶部露 EON 图标 + 名称。文案走 String(localized:),日期 / 金额按当前地区格式。
/// 用 ImageRenderer 烤成图来分享 / 存相册。
struct ReceiptView: View {
    let lines: [ReceiptLine]
    let totalText: String
    let chargeCount: Int
    let dateText: String
    let receiptNo: String

    private let width: CGFloat = 300
    private let paper = Color(red: 0.98, green: 0.96, blue: 0.92)
    private let ink = Color(red: 0.16, green: 0.16, blue: 0.16)
    private var mono: Font { .system(size: 12, weight: .regular, design: .monospaced) }

    var body: some View {
        VStack(spacing: 6) {
            // 顶部品牌
            brandIcon
                .padding(.top, 4)
            Text(verbatim: "E O N")
                .font(.system(size: 18, weight: .heavy, design: .monospaced))
                .tracking(2)
                .foregroundStyle(ink)
            Text("订阅消费小票")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(ink.opacity(0.8))

            dashed
            // 抬头:日期 + 单号
            row(left: dateText, right: "")
            row(left: String(localized: "小票号"), right: receiptNo)
            dashed
            // 列头
            HStack {
                Text("项目").font(mono).foregroundStyle(ink.opacity(0.7))
                Spacer()
                Text("金额").font(mono).foregroundStyle(ink.opacity(0.7))
            }
            dashed

            // 明细:每个订阅两行 —— 名称;缩进的"单价 x 次数"+ 右侧小计。
            ForEach(lines) { line in
                VStack(spacing: 1) {
                    HStack {
                        Text(line.name).font(mono).foregroundStyle(ink)
                            .lineLimit(1)
                        Spacer()
                    }
                    HStack {
                        Text("  " + line.detail)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(ink.opacity(0.7))
                        Spacer()
                        Text(line.amount).font(mono).foregroundStyle(ink)
                    }
                }
            }

            dashed
            // 合计
            HStack {
                Text("合计").font(.system(size: 14, weight: .heavy, design: .monospaced)).foregroundStyle(ink)
                Spacer()
                Text(totalText).font(.system(size: 14, weight: .heavy, design: .monospaced)).foregroundStyle(ink)
            }
            HStack {
                Text(String(localized: "共 \(chargeCount) 笔扣费"))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(ink.opacity(0.7))
                Spacer()
            }
            dashed

            // 假条形码
            barcode
            Text(receiptNo)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(ink.opacity(0.8))

            Text("谢谢惠顾 · 仅供娱乐")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(ink.opacity(0.8))
                .padding(.top, 2)
            Text("由 EON 生成")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(ink.opacity(0.55))
                .padding(.bottom, 6)
        }
        .padding(.horizontal, 18)
        .frame(width: width)
        .background(paper)
    }

    @ViewBuilder
    private var brandIcon: some View {
        if let ui = UIImage(named: "EONBrandIcon") {
            Image(uiImage: ui).resizable().scaledToFill()
                .frame(width: 38, height: 38)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 9).fill(ink.opacity(0.1)).frame(width: 38, height: 38)
                .overlay(Text(verbatim: "E").font(.system(size: 20, weight: .heavy, design: .monospaced)).foregroundStyle(ink))
        }
    }

    private var dashed: some View {
        Text(String(repeating: "-", count: 34))
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(ink.opacity(0.45))
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .center)
            .clipped()
    }

    private func row(left: String, right: String) -> some View {
        HStack {
            Text(left).font(mono).foregroundStyle(ink.opacity(0.8))
            Spacer()
            Text(right).font(mono).foregroundStyle(ink.opacity(0.8))
        }
    }

    /// 假条形码 —— 一排宽度随机的竖条。纯装饰。
    private var barcode: some View {
        HStack(spacing: 1.5) {
            ForEach(0..<40, id: \.self) { i in
                Rectangle()
                    .fill(ink)
                    .frame(width: [1, 1, 2, 3][i % 4], height: 34)
            }
        }
        .frame(maxWidth: .infinity)
        .clipped()
    }
}

// MARK: - 打印预览 sheet(带"出票"动画)

/// 展示烤好的小票图。进场时高度从 0 涨到完整,模拟热敏打印机一点点把小票吐出来。
/// 顶部有分享按钮(分享 / 存相册都走系统分享面板)。
struct ReceiptPreviewSheet: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    @State private var revealed: CGFloat = 0

    private var displayWidth: CGFloat { 300 }
    private var displayHeight: CGFloat {
        guard image.size.width > 0 else { return 0 }
        return image.size.height / image.size.width * displayWidth
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: displayWidth, height: displayHeight)
                        // "出票"遮罩:从顶部露出 revealed 高度,动画里从 0 → 满。
                        .mask(alignment: .top) {
                            Rectangle().frame(height: revealed)
                        }
                        .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
                        .padding(.vertical, AppTheme.Space.xl)
                }
                .frame(maxWidth: .infinity)
            }
            .background(AppTheme.canvas.ignoresSafeArea())
            .navigationTitle("小票")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(
                        item: Image(uiImage: image),
                        preview: SharePreview(Text("EON"), image: Image(uiImage: image))
                    ) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .onAppear {
                revealed = 0
                withAnimation(.easeOut(duration: 1.1)) { revealed = displayHeight }
                Haptics.tap()
            }
        }
    }
}
