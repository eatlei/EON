import SwiftUI
import UIKit

/// 二级页面:展示用户的"订阅人格"。布局是 1 张大图 + 名字 + 口号 + 描述 +
/// 一句"会随订阅变化"的提示 + 免责声明。入场带丰富的动画(渐显 / 缩放 /
/// 错开节奏),配合震动反馈,做出"翻牌揭晓"的惊喜感。
struct PersonalityView: View {
    @EnvironmentObject private var store: SubscriptionStore

    private var type: PersonalityType { store.personality }

    // MARK: - 进场动画相关 state
    //
    // 每个 state 控制 view 链里一组元素的"是否进场",时间错开 0.05~0.15 秒就能
    // 形成"图先到 → 名字到 → 标语到 → 详情到 → 提示到"的瀑布感。
    @State private var heroAppeared = false      // 大图缩放 + 旋转入场
    @State private var nameAppeared = false      // 人格名字
    @State private var taglineAppeared = false   // 一句标语
    @State private var detailAppeared = false    // 详细描述
    @State private var hintAppeared = false      // 会变化的提示
    @State private var disclaimerAppeared = false // 免责声明

    /// 进场时的轻触反馈:大图弹到位时一下 medium impact,跟视觉的"啪"对上。
    @State private var revealTick = 0

    var body: some View {
        // 主内容 = 大图 + 名字 + 标语 + 详情;放在可滚动区。
        // 辅助说明(随订阅变化 / 仅供娱乐)从滚动内容里拆出来,固定在弹窗底部,
        // 这样用户看主内容时眼睛不会被这两行 caption 拽下去。
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: AppTheme.Space.xl) {
                    heroImage
                    content
                }
                .padding(.horizontal, AppTheme.Space.xl)
                .padding(.top, AppTheme.Space.l)
                .padding(.bottom, AppTheme.Space.l)
                .frame(maxWidth: .infinity)
            }

            VStack(spacing: AppTheme.Space.xs) {
                evolutionHint
                disclaimer
            }
            .padding(.horizontal, AppTheme.Space.xl)
            .padding(.top, AppTheme.Space.s)
            .padding(.bottom, AppTheme.Space.m)
            .frame(maxWidth: .infinity)
        }
        .background(AppTheme.canvas.ignoresSafeArea())
        .navigationTitle("订阅人格")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.impact(weight: .medium), trigger: revealTick)
        .task {
            await playEntryAnimation()
        }
    }

    /// 入场动画编排 —— 各元素错开节奏,跟一次 medium haptic 同步。
    private func playEntryAnimation() async {
        // 大图先弹到位
        withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) {
            heroAppeared = true
        }
        revealTick &+= 1
        try? await Task.sleep(nanoseconds: 220_000_000)
        withAnimation(.easeOut(duration: 0.35)) { nameAppeared = true }
        try? await Task.sleep(nanoseconds: 110_000_000)
        withAnimation(.easeOut(duration: 0.35)) { taglineAppeared = true }
        try? await Task.sleep(nanoseconds: 110_000_000)
        withAnimation(.easeOut(duration: 0.4)) { detailAppeared = true }
        try? await Task.sleep(nanoseconds: 130_000_000)
        withAnimation(.easeOut(duration: 0.4)) { hintAppeared = true }
        try? await Task.sleep(nanoseconds: 110_000_000)
        withAnimation(.easeOut(duration: 0.4)) { disclaimerAppeared = true }
    }

    // MARK: - 大图

    /// 真图(Assets 里)优先,没有就用渐变 + SF Symbol 兜底。入场做 spring 缩放
    /// + 轻微旋转,显得"啪一下揭出来"。
    @ViewBuilder
    private var heroImage: some View {
        let assetName = type.imageAssetName
        let hasAsset = (UIImage(named: assetName) != nil)

        ZStack {
            if hasAsset {
                Image(assetName)
                    .resizable()
                    .scaledToFill()
            } else {
                RadialGradient(
                    stops: [
                        .init(color: type.tint.opacity(0.85), location: 0.0),
                        .init(color: type.tint.opacity(0.35), location: 0.55),
                        .init(color: type.tint.opacity(0.10), location: 1.0),
                    ],
                    center: .center, startRadius: 0, endRadius: 220
                )
                Image(systemName: type.fallbackSymbol)
                    .font(.system(size: 110, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 0.5)
        )
        .shadow(color: type.tint.opacity(0.25), radius: 22, x: 0, y: 12)
        // 入场缩放 + 极轻旋转:0.85 → 1.0, -2° → 0°,弹簧节奏
        .scaleEffect(heroAppeared ? 1.0 : 0.85)
        .rotationEffect(.degrees(heroAppeared ? 0 : -2))
        .opacity(heroAppeared ? 1 : 0)
    }

    // MARK: - 文字部分

    @ViewBuilder
    private var content: some View {
        VStack(spacing: AppTheme.Space.s) {
            // 名字 —— 从下方淡入
            Text(type.name)
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundStyle(AppTheme.ink)
                .multilineTextAlignment(.center)
                .opacity(nameAppeared ? 1 : 0)
                .offset(y: nameAppeared ? 0 : 12)

            // 标语 —— 跟在名字后面 0.1s 进入
            Text(type.tagline)
                .font(.headline.weight(.semibold))
                .foregroundStyle(type.tint)
                .multilineTextAlignment(.center)
                .padding(.bottom, 4)
                .opacity(taglineAppeared ? 1 : 0)
                .offset(y: taglineAppeared ? 0 : 10)

            // 详情 —— 多行段落,渐显
            Text(type.detail)
                .font(.body)
                .foregroundStyle(AppTheme.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(detailAppeared ? 1 : 0)
                .offset(y: detailAppeared ? 0 : 8)
        }
        .padding(.horizontal, AppTheme.Space.s)
    }

    // MARK: - "会随订阅变化"提示
    //
    // 一行小字,纯灰,不抢戏。之前用大色卡 + 加粗标题太重,现在调成"脚注"质感:
    // 一个小图标 + 一句轻描淡写的解释,信息传达到了即可。

    @ViewBuilder
    private var evolutionHint: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.caption2)
            Text("人格会随你的订阅而变化")  // 短一句脚注;译文表里已配 8 国语种
                .font(.caption)
        }
        .foregroundStyle(AppTheme.tertiary)
        .padding(.top, AppTheme.Space.s)
        .opacity(hintAppeared ? 1 : 0)
    }

    // MARK: - 免责声明

    @ViewBuilder
    private var disclaimer: some View {
        VStack(spacing: 4) {
            Image(systemName: "sparkles")
                .font(.caption)
                .foregroundStyle(AppTheme.tertiary)
            Text("仅供娱乐 · 不代表 EON 的任何评价或建议")
                .font(.caption)
                .foregroundStyle(AppTheme.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, AppTheme.Space.m)
        .opacity(disclaimerAppeared ? 1 : 0)
    }
}

#Preview {
    NavigationStack { PersonalityView() }
        .environmentObject(SubscriptionStore())
}
