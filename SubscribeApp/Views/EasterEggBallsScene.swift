import SwiftUI
import SpriteKit
import CoreMotion
import UIKit

// 彩蛋页背景的"订阅图标球"。每个活跃订阅 = 一个球,从顶部掉进来,
// 然后用设备重力感应在底部滚来滚去,撞墙 / 撞球时给一段轻震动。
// SpriteKit + CoreMotion 比手撸 SwiftUI 物理稳得多,iOS 自己的渲染线程
// 帮我们 60fps,List 在前面套 Liquid Glass 也不会因为同帧重布局卡顿。

/// 单例 scene。SwiftUI Wrapper 在 onAppear 时把所有图标的纹理塞进来,
/// scene 出现后一次性 spawn 完球,之后只跑物理 + 重力感应 + 撞击反馈。
final class EasterEggBallsScene: SKScene, SKPhysicsContactDelegate {
    private let motion = CMMotionManager()
    private var hasSpawned = false
    private var pendingTextures: [SKTexture] = []

    /// 节流用 —— 同一帧多球同时撞墙会把所有 contact 全报上来,
    /// 全部触发 haptic 体感就很糊。每 0.06s 最多放一次。
    private var lastImpactTime: TimeInterval = 0
    private let softHaptic = UIImpactFeedbackGenerator(style: .light)
    private let firmHaptic = UIImpactFeedbackGenerator(style: .medium)

    /// 注入要画的球纹理。Wrapper 用 ImageRenderer 把 CategoryGlyph 烤成 UIImage
    /// 再包成 SKTexture,scene 这边只负责拿过来 spawn。
    func configure(textures: [SKTexture]) {
        pendingTextures = textures
    }

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        scaleMode = .resizeFill
        physicsWorld.gravity = CGVector(dx: 0, dy: -12)
        physicsWorld.contactDelegate = self

        rebuildBoundary()
        softHaptic.prepare()
        firmHaptic.prepare()
        startMotion()
        spawnBallsIfNeeded()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard oldSize != size else { return }
        rebuildBoundary()
        // 第一次 didMove 时 size 可能还是 0,等 SwiftUI 给到真实尺寸后补 spawn。
        spawnBallsIfNeeded()
    }

    /// 边界 = 左墙 + 地板 + 右墙(不封顶)。这样球可以从屏幕外掉进来,
    /// 用户也可以反手把手机倒过来"摇出去再摇回来",顶部留口体验更好玩。
    private func rebuildBoundary() {
        guard size.width > 0, size.height > 0 else { return }
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: size.height + 200))
        path.addLine(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: size.width, y: 0))
        path.addLine(to: CGPoint(x: size.width, y: size.height + 200))
        let body = SKPhysicsBody(edgeChainFrom: path)
        body.friction = 0.3
        body.restitution = 0.35
        physicsBody = body
    }

    private func spawnBallsIfNeeded() {
        guard !hasSpawned, !pendingTextures.isEmpty,
              size.width > 1, size.height > 1 else { return }
        hasSpawned = true

        // 球直径从 44 升到 64,在 iPhone 屏幕上更"有分量",图标也能看清是什么。
        // 上限 24 个 × 64pt 直径,堆在底部不至于互相叠死。
        let radius: CGFloat = 32
        for (i, tex) in pendingTextures.enumerated() {
            let ball = SKSpriteNode(texture: tex)
            ball.size = CGSize(width: radius * 2, height: radius * 2)

            // x 在屏幕宽度内均匀分布 + 一点抖动,避免一柱齐落。
            let lane = (CGFloat(i) + 0.5) / CGFloat(pendingTextures.count)
            let jitter = CGFloat.random(in: -0.05...0.05)
            let x = max(radius + 10, min(size.width - radius - 10, (lane + jitter) * size.width))
            // y 错位,让球依次落,前面落地了后面才刚冒头。
            let y = size.height + radius + CGFloat(i) * 38 + CGFloat.random(in: 0...18)
            ball.position = CGPoint(x: x, y: y)
            ball.zRotation = CGFloat.random(in: -0.6...0.6)

            let body = SKPhysicsBody(circleOfRadius: radius)
            body.restitution = 0.45        // 弹一下,但别像皮球一样不停跳
            body.friction = 0.5            // 滚的时候有阻尼,不像冰球
            body.linearDamping = 0.18
            body.angularDamping = 0.2
            body.mass = 0.3
            body.angularVelocity = CGFloat.random(in: -2.5...2.5)
            // 让球之间也能产生 contact 回调,撞球也响震动
            body.contactTestBitMask = body.collisionBitMask
            ball.physicsBody = body
            addChild(ball)
        }
    }

    /// 把设备 attitude 当成 SpriteKit 的重力源。CoreMotion 给的是物理坐标
    /// (面朝上时 z=-1),portrait 下 x/y 跟 SpriteKit 的 x/y 直接对得上。
    private func startMotion() {
        guard motion.isDeviceMotionAvailable else { return }
        motion.deviceMotionUpdateInterval = 1.0 / 60.0
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self, let g = data?.gravity else { return }
            // 12 量级跟 spawn 初始的 -12 对齐,转动手机时不会突然变沉或变飘。
            let scale: CGFloat = 12
            self.physicsWorld.gravity = CGVector(dx: g.x * scale, dy: g.y * scale)
        }
    }

    // MARK: SKPhysicsContactDelegate
    // SKScene 在 Swift 6 是 @MainActor 隔离的,而 SKPhysicsContactDelegate 的
    // 回调是 nonisolated 的;直接实现会编译报"crosses into main actor"。
    // 这里把 didBegin 标 nonisolated,只读 impulse(值类型,安全),然后把
    // haptic + 节流的状态写都跳回主线程做。
    nonisolated func didBegin(_ contact: SKPhysicsContact) {
        let impulse = contact.collisionImpulse
        // 太轻的接触(球缓慢滚着碰墙)不响,只有真砸下来 / 撞球才反馈。
        guard impulse > 0.08 else { return }
        Task { @MainActor in
            self.fireHapticIfAllowed(impulse: impulse)
        }
    }

    @MainActor
    private func fireHapticIfAllowed(impulse: CGFloat) {
        guard Haptics.enabled else { return }
        let now = CACurrentMediaTime()
        guard now - lastImpactTime > 0.06 else { return }
        lastImpactTime = now
        if impulse > 0.9 {
            firmHaptic.impactOccurred(intensity: min(1, impulse / 1.6))
        } else {
            softHaptic.impactOccurred(intensity: min(1, impulse))
        }
    }

    func stopMotion() {
        motion.stopDeviceMotionUpdates()
    }
    // 注:不写 deinit 主动停 motion —— Swift 6 下 SKScene 是 @MainActor,
    // deinit 又是 nonisolated,访问 CMMotionManager 会报数据竞争。
    // SwiftUI 包装层的 .onDisappear 已经调 stopMotion(),够用。
}

// MARK: - SwiftUI wrapper

/// SwiftUI 端:订阅列表 → 每个订阅 icon 烤成圆形 UIImage → SKTexture → 球。
/// 把 SpriteView 当 ZStack 背景挂在彩蛋页里,List 走 Liquid Glass 行背景透出来。
struct EasterEggBallsView: View {
    let subscriptions: [Subscription]
    /// 纯色表情模式:开了之后球不画图标,改成"订阅主色纯色球 + 随机表情"。
    var solidEmoji: Bool = false
    /// 安全上限。订阅数大于这个值时,只取前 N 个做球;再多 SpriteKit 也不卡,
    /// 但球互相挤会黏成一团没意思。
    static let ballCap = 24

    /// 纯色模式用的表情池。按订阅 id 稳定取一个,不会每次重绘乱跳。
    private static let emojiPool: [String] = [
        "😀", "😎", "🤑", "🥳", "😴", "🤖", "👾", "🎉", "💎", "🔥",
        "🌈", "🍩", "🐱", "🦊", "🐼", "🚀", "⭐️", "🍀", "🎈", "🍕",
        "👻", "🤡", "🦄", "🍔"
    ]

    @State private var scene: EasterEggBallsScene?
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        GeometryReader { geo in
            Group {
                if let scene {
                    SpriteView(
                        scene: scene,
                        options: [.allowsTransparency]
                    )
                } else {
                    Color.clear
                }
            }
            .onAppear { ensureScene(size: geo.size) }
            .onChange(of: geo.size) { _, new in
                // List 顶起 / 旋屏会改尺寸,scene 跟着同步,边界重建在 didChangeSize 里。
                scene?.size = new
            }
            .onDisappear { scene?.stopMotion() }
        }
    }

    @MainActor
    private func ensureScene(size: CGSize) {
        guard scene == nil, size.width > 1, size.height > 1 else { return }
        let textures = bakeTextures()
        guard !textures.isEmpty else { return }
        let s = EasterEggBallsScene(size: size)
        s.scaleMode = .resizeFill
        s.configure(textures: textures)
        scene = s
    }

    /// 用 ImageRenderer 把每个订阅的 CategoryGlyph 烤成圆形 UIImage。
    /// 128pt × displayScale 的分辨率配合场景里 64pt 的球,纹理 2× 余量滚动时
    /// 不糊;白边 + 顶部高光 + 阴影叠出"实体玻璃球"的体积感。
    @MainActor
    private func bakeTextures() -> [SKTexture] {
        let used = Array(subscriptions.prefix(Self.ballCap))
        let renderSize: CGFloat = 128
        var out: [SKTexture] = []
        for sub in used {
            let view = ZStack {
                // 球面本体:默认画订阅图标;纯色模式画"主色 + 表情"。
                if solidEmoji {
                    ZStack {
                        Circle().fill(ballColor(sub))
                        Text(emoji(for: sub))
                            .font(.system(size: renderSize * 0.5))
                    }
                    .frame(width: renderSize, height: renderSize)
                } else {
                    CategoryGlyph(subscription: sub, size: renderSize)
                        .frame(width: renderSize, height: renderSize)
                        .clipShape(Circle())
                }
                // 顶部偏左的高光 —— 一小撮 radial gradient,撑起"球面"的反光感,
                // 让平的 icon 看起来真的像个抛了光的玻璃 / 弹珠球。
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(0.55), Color.white.opacity(0.0)],
                            center: UnitPoint(x: 0.32, y: 0.22),
                            startRadius: 0,
                            endRadius: renderSize * 0.55
                        )
                    )
                    .blendMode(.screen)
                    .allowsHitTesting(false)
                // 边缘 ring —— 内描边,模拟球壳厚度。
                Circle()
                    .strokeBorder(Color.white.opacity(0.75), lineWidth: 3)
                Circle()
                    .strokeBorder(Color.black.opacity(0.18), lineWidth: 1)
                    .padding(3)
            }
            .frame(width: renderSize, height: renderSize)
            .shadow(color: .black.opacity(0.28), radius: 5, x: 0, y: 2)

            let renderer = ImageRenderer(content: view)
            renderer.scale = displayScale
            if let ui = renderer.uiImage {
                out.append(SKTexture(image: ui))
            }
        }
        return out
    }

    /// 订阅"主色":tile 取色号,image 取图像平均色,都回退分类色。跟订阅卡片同源。
    private func ballColor(_ sub: Subscription) -> Color {
        switch sub.icon {
        case .tile(_, let hex):
            return hex.map { Color(hexString: $0) } ?? sub.displayCategoryColor
        case .image(let id):
            if let ui = IconStore.averageColor(id) { return Color(uiColor: ui) }
            return sub.displayCategoryColor
        }
    }

    /// 由订阅 id 稳定取一个表情,保证同一订阅每次都是同一个脸。
    private func emoji(for sub: Subscription) -> String {
        let idx = abs(sub.id.uuidString.hashValue) % Self.emojiPool.count
        return Self.emojiPool[idx]
    }
}
