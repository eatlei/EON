import SwiftUI
import UIKit

/// 二级页面:展示用户的"订阅人格"。布局是 1 张大图 + 名字 + 口号 + 描述,
/// 底部一句免责声明"仅供娱乐"。
struct PersonalityView: View {
    @EnvironmentObject private var store: SubscriptionStore

    private var type: PersonalityType { store.personality }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Space.xl) {
                heroImage
                content
                disclaimer
            }
            .padding(.horizontal, AppTheme.Space.xl)
            .padding(.top, AppTheme.Space.l)
            .padding(.bottom, AppTheme.Space.xxl)
            .frame(maxWidth: .infinity)
        }
        .background(AppTheme.canvas.ignoresSafeArea())
        .navigationTitle("订阅人格")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 大图

    /// 优先用 Asset 里的真实插画,没有就用渐变 + SF Symbol 兜底 —— 装饰但不寒酸。
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
                // 占位:径向色块 + 大号 SF Symbol。色调跟着 type.tint。
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
        .shadow(color: type.tint.opacity(0.20), radius: 20, x: 0, y: 10)
    }

    // MARK: - 文字部分

    @ViewBuilder
    private var content: some View {
        VStack(spacing: AppTheme.Space.s) {
            Text(type.name)
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(AppTheme.ink)
                .multilineTextAlignment(.center)

            Text(type.tagline)
                .font(.headline.weight(.semibold))
                .foregroundStyle(type.tint)
                .multilineTextAlignment(.center)
                .padding(.bottom, 4)

            Text(type.detail)
                .font(.body)
                .foregroundStyle(AppTheme.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, AppTheme.Space.s)
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
    }
}

#Preview {
    NavigationStack { PersonalityView() }
        .environmentObject(SubscriptionStore())
}
