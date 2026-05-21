import SwiftUI

/// 版本历史 / 更新记录。从「关于」进来。改动条目集中维护在 Self.releases 里,
/// 每发一个版本往最前面加一条即可。文案走 String(localized:),跟随系统语言。
struct VersionHistoryView: View {
    private struct Release: Identifiable {
        let id = UUID()
        let version: String
        let date: String
        let notes: [String]
    }

    /// 由近及远。最新版本放最前面。
    private static let releases: [Release] = [
        Release(
            version: "1.0",
            date: "2026-05",
            notes: [
                String(localized: "首个版本:订阅管理、总览统计、分类与累计支付。"),
                String(localized: "支持多币种,每日自动更新汇率。"),
                String(localized: "本地通知提醒,可按每个订阅单独设置提前天数。"),
                String(localized: "可设置订阅结束日期,到期自动归档。"),
                String(localized: "iCloud 同步;支持导出为 Markdown / JSON。"),
                String(localized: "彩蛋:摇一摇聚焦、每日彩带、订阅小球。"),
            ]
        ),
    ]

    var body: some View {
        List {
            ForEach(Self.releases) { release in
                Section {
                    ForEach(release.notes, id: \.self) { note in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 5))
                                .foregroundStyle(AppTheme.accent)
                                .padding(.top, 6)
                            Text(note)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                } header: {
                    HStack {
                        Text(verbatim: "v\(release.version)")
                            .font(.headline)
                            .foregroundStyle(AppTheme.ink)
                        Spacer()
                        Text(release.date)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.visible)
        .navigationTitle("版本历史")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { VersionHistoryView() }
}
