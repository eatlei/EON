import UIKit
import SwiftUI
import UserNotifications

/// 把订阅图标烤成一张 PNG,做成通知的 UNNotificationAttachment —— iOS 会把它
/// 显示在通知右侧的缩略图位置。两种图标都支持:
///   - .image:直接用用户上传 / 下载的方形图
///   - .tile :画一个圆角色块 + 首字母 / SF Symbol(跟 App 里 CategoryGlyph 一致)
enum NotificationIconRenderer {
    /// 把订阅图标渲染成 PNG 数据(给 widget 写到 App Group 容器用)。
    @MainActor
    static func pngData(for sub: Subscription) -> Data? {
        renderIcon(for: sub)?.pngData()
    }

    /// 为某个订阅生成通知缩略图附件。失败(画不出 / 写盘失败)返回 nil,
    /// 调用方据此决定通知带不带图,都不影响通知本身能发出去。
    @MainActor
    static func attachment(for sub: Subscription) -> UNNotificationAttachment? {
        guard let url = iconFileURL(for: sub) else { return nil }
        return try? UNNotificationAttachment(
            identifier: "icon-\(sub.id.uuidString)",
            url: url,
            options: nil
        )
    }

    /// 把缩略图烤成 PNG 写到 tmp,返回文件 URL。URL 是 Sendable,可以安全地从
    /// MainActor 传回 async 上下文再去构造 UNNotificationAttachment(后者非 Sendable,
    /// 不能跨 actor 传递)。
    @MainActor
    static func iconFileURL(for sub: Subscription) -> URL? {
        guard let image = renderIcon(for: sub),
              let data = image.pngData() else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("notif-icon-\(sub.id.uuidString).png")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    @MainActor
    private static func renderIcon(for sub: Subscription) -> UIImage? {
        let size = CGSize(width: 120, height: 120)
        let radius = size.width * 0.28
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            UIBezierPath(roundedRect: rect, cornerRadius: radius).addClip()

            switch sub.icon {
            case .image(let id):
                if let ui = IconStore.loadUIImage(id) {
                    ui.draw(in: rect)
                } else {
                    drawTile(in: rect, color: UIColor(sub.displayCategoryColor),
                             glyph: .letter, name: sub.name, size: size)
                }
            case .tile(let glyph, let hex):
                let color = hex.map { UIColor(Color(hexString: $0)) } ?? UIColor(sub.displayCategoryColor)
                drawTile(in: rect, color: color, glyph: glyph, name: sub.name, size: size)
            }
        }
    }

    @MainActor
    private static func drawTile(in rect: CGRect, color: UIColor, glyph: TileGlyph,
                                 name: String, size: CGSize) {
        color.setFill()
        UIRectFill(rect)
        switch glyph {
        case .letter:
            let letter = String(name.prefix(1)).uppercased()
            let para = NSMutableParagraphStyle(); para.alignment = .center
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: size.height * 0.46, weight: .heavy),
                .foregroundColor: UIColor.white,
                .paragraphStyle: para
            ]
            let s = NSAttributedString(string: letter, attributes: attrs)
            let textSize = s.size()
            s.draw(at: CGPoint(x: (size.width - textSize.width) / 2,
                               y: (size.height - textSize.height) / 2))
        case .symbol(let symbolName):
            let cfg = UIImage.SymbolConfiguration(pointSize: size.height * 0.46, weight: .semibold)
            if let sym = UIImage(systemName: symbolName, withConfiguration: cfg)?
                .withTintColor(.white, renderingMode: .alwaysOriginal) {
                let r = CGRect(x: (size.width - sym.size.width) / 2,
                               y: (size.height - sym.size.height) / 2,
                               width: sym.size.width, height: sym.size.height)
                sym.draw(in: r)
            }
        }
    }
}
