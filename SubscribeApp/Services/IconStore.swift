import UIKit

/// 订阅自定义图片图标的本地文件存储（Application Support，非备份目录）。
enum IconStore {
    private static var dir: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let d = base.appendingPathComponent("SubscriptionIcons", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }
    private static func url(_ id: String) -> URL { dir.appendingPathComponent(id + ".png") }

    /// 居中等比铺满裁成 512 方形 PNG 落盘，返回文件 id（失败 nil）。
    static func save(_ image: UIImage) -> String? {
        let side: CGFloat = 512
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        let out = renderer.image { _ in
            let scale = max(side / max(image.size.width, 1), side / max(image.size.height, 1))
            let w = image.size.width * scale
            let h = image.size.height * scale
            image.draw(in: CGRect(x: (side - w) / 2, y: (side - h) / 2, width: w, height: h))
        }
        guard let data = out.pngData() else { return nil }
        let id = UUID().uuidString
        do { try data.write(to: url(id)); return id } catch { return nil }
    }

    static func save(data: Data) -> String? {
        guard let img = UIImage(data: data) else { return nil }
        return save(img)
    }

    static func loadUIImage(_ id: String) -> UIImage? {
        UIImage(contentsOfFile: url(id).path)
    }

    static func delete(_ id: String) {
        try? FileManager.default.removeItem(at: url(id))
    }
}
