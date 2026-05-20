import SwiftUI

/// 加载中持续旋转的 SettingsIcon。点击后:
/// - **开始**:从 0° 起 .linear + .repeatForever 持续顺时针旋转
/// - **结束**:不要回弹 360→0(原来的实现会有这个回退) —— 而是
///   * 先无动画地把 rotation 设为当前显示角度,断开 repeatForever 的循环
///   * 再 easeOut 平滑转完这一圈到 360
///   * 落定之后无动画地复位到 0,准备下次起转
/// 整个 stop 过程视觉上"丝滑收尾",不会回退,不会瞬移。
struct SpinningIcon: View {
    let name: String
    let isSpinning: Bool
    /// 每圈耗时。短一点会更明显是"加载中"。
    var secondsPerTurn: Double = 0.9

    @State private var rotation: Double = 0
    @State private var spinStartedAt: Date?

    var body: some View {
        SettingsIcon(name: name)
            .rotationEffect(.degrees(rotation))
            .onChange(of: isSpinning) { _, newValue in
                if newValue { start() } else { stop() }
            }
            .onAppear {
                // 父层在 onAppear 那一帧 isSpinning 就 = true 的情况下也能起来
                if isSpinning && spinStartedAt == nil { start() }
            }
    }

    private func start() {
        // 复位 + 起转
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) { rotation = 0 }

        spinStartedAt = .now
        withAnimation(.linear(duration: secondsPerTurn).repeatForever(autoreverses: false)) {
            rotation = 360
        }
    }

    private func stop() {
        guard let start = spinStartedAt else {
            // 没真启动过,直接归零
            var t = Transaction(); t.disablesAnimations = true
            withTransaction(t) { rotation = 0 }
            return
        }
        let elapsed = Date().timeIntervalSince(start)
        let turns = elapsed / secondsPerTurn
        // 当前可见角度(0..360)
        let displayed = (turns - floor(turns)) * 360
        // 把 rotation 切回当前可见角度,无动画 —— 这一步关键:断开 repeatForever
        var t = Transaction(); t.disablesAnimations = true
        withTransaction(t) { rotation = displayed }

        // 计算到下一个整圈还差多少时间,用同样的线性速度去补完那点弧度
        let remainingFraction = 1.0 - (turns - floor(turns))
        let finishDuration = max(0.15, min(0.55, remainingFraction * secondsPerTurn))
        withAnimation(.linear(duration: finishDuration)) {
            rotation = 360
        }
        // 落地后悄悄归零(无动画),等下次再起转
        let resetAt = DispatchTime.now() + finishDuration + 0.05
        DispatchQueue.main.asyncAfter(deadline: resetAt) {
            var t = Transaction(); t.disablesAnimations = true
            withTransaction(t) { rotation = 0 }
        }
        spinStartedAt = nil
    }
}
