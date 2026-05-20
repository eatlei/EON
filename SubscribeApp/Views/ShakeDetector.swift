import SwiftUI
import UIKit

/// SwiftUI 没有原生的"摇一摇"手势。这里用一个隐形 UIViewController 拿到 first
/// responder,然后从 UIResponder 的 `motionEnded(_:with:)` 里听 .motionShake 事件。
/// 用法:任何 SwiftUI view 上调 `.onShake { ... }`。
struct ShakeDetector: UIViewControllerRepresentable {
    let onShake: () -> Void

    func makeUIViewController(context: Context) -> ShakeViewController {
        let vc = ShakeViewController()
        vc.onShake = onShake
        return vc
    }

    func updateUIViewController(_ uiViewController: ShakeViewController, context: Context) {
        uiViewController.onShake = onShake
    }

    final class ShakeViewController: UIViewController {
        var onShake: (() -> Void)?

        // 必须是 first responder 才能收到 motionEnded
        override var canBecomeFirstResponder: Bool { true }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            becomeFirstResponder()
        }

        override func viewDidDisappear(_ animated: Bool) {
            super.viewDidDisappear(animated)
            resignFirstResponder()
        }

        override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
            super.motionEnded(motion, with: event)
            if motion == .motionShake {
                onShake?()
            }
        }
    }
}

extension View {
    /// 任意 view 上挂这个,App 收到摇一摇时会触发 action。背景透明、不拦截点击。
    func onShake(perform action: @escaping () -> Void) -> some View {
        background(
            ShakeDetector(onShake: action)
                .allowsHitTesting(false)
                .frame(width: 0, height: 0)
        )
    }
}
