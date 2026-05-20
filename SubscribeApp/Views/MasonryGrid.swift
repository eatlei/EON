import SwiftUI

/// 真·瀑布流 2 列布局。SwiftUI 自带的 LazyVGrid 不是瀑布流(每行都对齐到最高
/// 的一项,空白被浪费)。这里实现 SwiftUI 的 Layout 协议:每次把下一个 child
/// 放到当前更短的那列里,这样不同高度的卡片能自然交错填满,真的"流"起来。
///
/// 用法:
///   MasonryGrid(columns: 2, spacing: 12) {
///       ForEach(items) { item in CardView(item: item) }
///   }
struct MasonryGrid: Layout {
    /// 列数。默认 2,主调用方一般也只想要 2。
    var columns: Int = 2
    /// 列间距 + 行内每张卡之间的垂直 spacing,共用一个值就够。
    var spacing: CGFloat = 12

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard !subviews.isEmpty, let containerWidth = proposal.width else {
            return .zero
        }
        let columnWidth = (containerWidth - spacing * CGFloat(columns - 1)) / CGFloat(columns)
        // 跟踪每列当前累计高度,选最矮那列塞下一个 child
        var columnHeights = Array(repeating: CGFloat(0), count: columns)
        for sub in subviews {
            let size = sub.sizeThatFits(.init(width: columnWidth, height: nil))
            let shortest = columnHeights.indices.min { columnHeights[$0] < columnHeights[$1] } ?? 0
            // 第一项不需要加 spacing,之后每项都要预留卡片间距
            columnHeights[shortest] += (columnHeights[shortest] > 0 ? spacing : 0) + size.height
        }
        let totalHeight = columnHeights.max() ?? 0
        return CGSize(width: containerWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard !subviews.isEmpty else { return }
        let containerWidth = bounds.width
        let columnWidth = (containerWidth - spacing * CGFloat(columns - 1)) / CGFloat(columns)
        // 同样跟踪每列累计高度;每次选最短列把 child 放进去
        var columnY = Array(repeating: bounds.minY, count: columns)
        for sub in subviews {
            let size = sub.sizeThatFits(.init(width: columnWidth, height: nil))
            let col = columnY.indices.min { columnY[$0] < columnY[$1] } ?? 0
            let x = bounds.minX + CGFloat(col) * (columnWidth + spacing)
            // 第一项 columnY 还等于 bounds.minY,直接放;之后每项要先加 spacing
            let yOffset = (columnY[col] == bounds.minY) ? 0 : spacing
            let y = columnY[col] + yOffset
            sub.place(
                at: CGPoint(x: x, y: y),
                anchor: .topLeading,
                proposal: .init(width: columnWidth, height: size.height)
            )
            columnY[col] = y + size.height
        }
    }
}
