import UIKit
import CoreImage

/// 订阅自定义图片图标的本地文件存储（Application Support，非备份目录）。
enum IconStore {
    /// 缓存每张图标的"平均色",用于彩色卡片背景。计算一次,内存里复用。
    /// `nonisolated(unsafe)` 因为 NSCache 本身线程安全,但 Swift 6 严格并发检查
    /// 看不出它是 Sendable;实际使用全部在 main thread。
    nonisolated(unsafe) private static let avgColorCache = NSCache<NSString, UIColor>()
    nonisolated(unsafe) private static let ciContext = CIContext(options: [.workingColorSpace: kCFNull as Any])

    /// 返回该 icon 文件的代表色(用作彩色卡片底色)。失败 / 信息不足时返回 nil。
    ///
    /// 两段式策略:
    ///   1) **整图平均**:大部分 App 图标整图平均落在品牌色上(Netflix 红色 N
    ///      + 黑色背景的整图平均 ≈ 暗红色)。
    ///   2) 整图平均饱和度太低 (例如脸图、纯黑白 logo) 时,转而采**四角**——
    ///      iOS 风格图标通常用一种纯色铺满方形背景,角落就是品牌背景色,
    ///      这样豆包脸图能取到它外框的浅蓝。
    ///   3) 两个都饱和度不达标(纯灰图标) 就返回 nil,卡片走分类色回退。
    /// 对取到的色再统一做亮度夹紧 [0.30, 0.58],避免和白色文字撞色或一片死黑。
    static func averageColor(_ id: String) -> UIColor? {
        if let cached = avgColorCache.object(forKey: id as NSString) { return cached }
        guard let img = loadUIImage(id), let ci = CIImage(image: img) else { return nil }
        let extent = ci.extent
        guard extent.width > 0, extent.height > 0 else { return nil }

        // Pass 1: whole-image average.
        if let rgb = computeAverage(ci), let final = clampToReadable(rgb: rgb) {
            avgColorCache.setObject(final, forKey: id as NSString)
            return final
        }

        // Pass 2: corner sampling.
        let w = extent.width, h = extent.height
        let cs: CGFloat = 0.18
        let corners: [CGRect] = [
            CGRect(x: extent.minX,            y: extent.minY,            width: w * cs, height: h * cs),
            CGRect(x: extent.maxX - w * cs,   y: extent.minY,            width: w * cs, height: h * cs),
            CGRect(x: extent.minX,            y: extent.maxY - h * cs,   width: w * cs, height: h * cs),
            CGRect(x: extent.maxX - w * cs,   y: extent.maxY - h * cs,   width: w * cs, height: h * cs),
        ]
        var sumR = 0.0, sumG = 0.0, sumB = 0.0, n = 0
        for rect in corners {
            if let avg = computeAverage(ci.cropped(to: rect)) {
                sumR += avg.0; sumG += avg.1; sumB += avg.2; n += 1
            }
        }
        guard n > 0,
              let final = clampToReadable(rgb: (sumR / Double(n), sumG / Double(n), sumB / Double(n))) else {
            return nil
        }
        avgColorCache.setObject(final, forKey: id as NSString)
        return final
    }

    private static func computeAverage(_ ci: CIImage) -> (Double, Double, Double)? {
        guard ci.extent.width > 0, ci.extent.height > 0 else { return nil }
        let filter = CIFilter(name: "CIAreaAverage")
        filter?.setValue(ci, forKey: kCIInputImageKey)
        filter?.setValue(CIVector(cgRect: ci.extent), forKey: "inputExtent")
        guard let out = filter?.outputImage else { return nil }
        var bitmap = [UInt8](repeating: 0, count: 4)
        ciContext.render(out, toBitmap: &bitmap, rowBytes: 4,
                         bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                         format: .RGBA8, colorSpace: nil)
        return (Double(bitmap[0]) / 255, Double(bitmap[1]) / 255, Double(bitmap[2]) / 255)
    }

    private static func clampToReadable(rgb: (Double, Double, Double)) -> UIColor? {
        let raw = UIColor(red: CGFloat(rgb.0), green: CGFloat(rgb.1), blue: CGFloat(rgb.2), alpha: 1)
        var hue: CGFloat = 0, sat: CGFloat = 0, br: CGFloat = 0, a: CGFloat = 0
        raw.getHue(&hue, saturation: &sat, brightness: &br, alpha: &a)
        if sat < 0.18 { return nil }
        let clampedBr = max(0.30, min(0.58, br))
        let boostedSat = min(1.0, sat * 1.10)
        return UIColor(hue: hue, saturation: boostedSat, brightness: clampedBr, alpha: 1)
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
