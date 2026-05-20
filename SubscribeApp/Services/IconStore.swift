import UIKit
import CoreImage

/// 订阅自定义图片图标的本地文件存储（Application Support，非备份目录）。
enum IconStore {
    /// 缓存每张图标的"平均色",用于彩色卡片背景。计算一次,内存里复用。
    /// `nonisolated(unsafe)` 因为 NSCache 本身线程安全,但 Swift 6 严格并发检查
    /// 看不出它是 Sendable;实际使用全部在 main thread。
    nonisolated(unsafe) private static let avgColorCache = NSCache<NSString, UIColor>()
    nonisolated(unsafe) private static let ciContext = CIContext(options: [.workingColorSpace: kCFNull as Any])

    /// 返回该 icon 文件的平均颜色（图像主色调）。失败返回 nil(由调用方回退到分类色)。
    static func averageColor(_ id: String) -> UIColor? {
        if let cached = avgColorCache.object(forKey: id as NSString) { return cached }
        guard let img = loadUIImage(id), let ci = CIImage(image: img) else { return nil }
        let filter = CIFilter(name: "CIAreaAverage")
        filter?.setValue(ci, forKey: kCIInputImageKey)
        filter?.setValue(CIVector(cgRect: ci.extent), forKey: "inputExtent")
        guard let out = filter?.outputImage else { return nil }
        var bitmap = [UInt8](repeating: 0, count: 4)
        ciContext.render(out,
                         toBitmap: &bitmap,
                         rowBytes: 4,
                         bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                         format: .RGBA8,
                         colorSpace: nil)
        var r = CGFloat(bitmap[0]) / 255
        var g = CGFloat(bitmap[1]) / 255
        var b = CGFloat(bitmap[2]) / 255
        // 亮度上限:避免接近白色的 logo 算出来一片浅灰,让卡片和白字撞色。
        let lum = 0.299 * r + 0.587 * g + 0.114 * b
        if lum > 0.55 {
            let scale = 0.45 / lum
            r *= scale; g *= scale; b *= scale
        }
        // 饱和度下限:近灰图(头像、纯黑白 logo)做出来的卡片没色彩感,
        // 返回 nil 让调用方回退到分类色,给出一个有"性格"的卡片底色。
        let maxC = max(r, g, b), minC = min(r, g, b)
        let saturation = maxC == 0 ? 0 : (maxC - minC) / maxC
        if saturation < 0.18 { return nil }
        let color = UIColor(red: r, green: g, blue: b, alpha: 1)
        avgColorCache.setObject(color, forKey: id as NSString)
        return color
    }

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
