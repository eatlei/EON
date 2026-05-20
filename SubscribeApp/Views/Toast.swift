import SwiftUI

/// 全 App 共用的小 toast —— 一句话操作反馈,1.6 秒后自动收掉。
/// 用 `.toast($flag, text: "...")` 这一行就能挂上。比按钮上偷偷换个图标
/// 直观得多,放心点完操作能看到"已复制 ✓"这种明确确认。
struct ToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let text: LocalizedStringKey
    let icon: String
    let tint: Color

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if isPresented {
                    HStack(spacing: 8) {
                        Image(systemName: icon)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                        Text(text)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(tint, in: Capsule())
                    .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 4)
                    .padding(.top, 8)
                    .transition(
                        .move(edge: .top)
                            .combined(with: .opacity)
                    )
                    .task {
                        // 1.6 秒后自动收回。用 Task.sleep + withAnimation 让退出
                        // 走跟入场一样的 spring 节奏,比定时器 + 修改 state 更稳。
                        try? await Task.sleep(nanoseconds: 1_600_000_000)
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            isPresented = false
                        }
                    }
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isPresented)
    }
}

extension View {
    /// 成功类 toast(主题色) —— 适合"已复制"、"已同步"、"已更新"这种正向反馈。
    func toast(_ isPresented: Binding<Bool>,
               text: LocalizedStringKey,
               icon: String = "checkmark.circle.fill") -> some View {
        modifier(ToastModifier(isPresented: isPresented, text: text, icon: icon, tint: AppTheme.accent))
    }

    /// 警告类 toast(橙色) —— 适合"网络失败"、"权限被拒"这种轻度异常。
    func warningToast(_ isPresented: Binding<Bool>,
                      text: LocalizedStringKey,
                      icon: String = "exclamationmark.circle.fill") -> some View {
        modifier(ToastModifier(isPresented: isPresented, text: text, icon: icon, tint: .orange))
    }
}
