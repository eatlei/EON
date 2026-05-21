import WidgetKit
import SwiftUI
import UIKit

// EON 的桌面 / 锁屏小组件。三个:下次扣费、本月总额、本月清单。
// 数据来自 App Group 的 EONWidgetSnapshot;真实图标按 iconID 从共享容器读 PNG。

// MARK: - Timeline

struct EONEntry: TimelineEntry {
    let date: Date
    let snapshot: EONWidgetSnapshot
}

struct EONProvider: TimelineProvider {
    func placeholder(in context: Context) -> EONEntry {
        EONEntry(date: Date(), snapshot: .placeholder)
    }
    func getSnapshot(in context: Context, completion: @escaping (EONEntry) -> Void) {
        completion(EONEntry(date: Date(), snapshot: EONWidgetStore.load() ?? .placeholder))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<EONEntry>) -> Void) {
        let snap = EONWidgetStore.load() ?? .placeholder
        // 跨过午夜刷新一次(倒计时天数会变)。
        let next = Calendar.current.nextDate(after: Date(), matching: DateComponents(hour: 0, minute: 5),
                                             matchingPolicy: .nextTime) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [EONEntry(date: Date(), snapshot: snap)], policy: .after(next)))
    }
}

// MARK: - 复用零件

/// 真实订阅图标。有 PNG 文件就用真图,否则退回"色块 + 首字母"。
private struct WIcon: View {
    let item: EONWidgetSnapshot.Item
    var size: CGFloat = 30
    var body: some View {
        Group {
            if let url = EONWidgetStore.iconURL(item.iconID),
               let ui = UIImage(contentsOfFile: url.path) {
                Image(uiImage: ui).resizable().scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .fill(Color(eonHex: item.colorHex))
                    .overlay(
                        Text(item.letter)
                            .font(.system(size: size * 0.5, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
    }
}

/// 大金额:整数部分大,小数部分小一号、淡一档(像 Apple Wallet)。
private struct BigAmount: View {
    let major: String
    let minor: String
    var size: CGFloat = 30
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            Text(major)
                .font(.system(size: size, weight: .heavy, design: .rounded))
            if !minor.isEmpty {
                Text("." + minor)
                    .font(.system(size: size * 0.6, weight: .heavy, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .minimumScaleFactor(0.6)
        .lineLimit(1)
    }
}

private struct EonMark: View {
    var body: some View {
        Text("EON").font(.caption2.weight(.heavy)).foregroundStyle(.secondary).tracking(0.5)
    }
}

private func daysText(_ d: Int) -> String {
    if d <= 0 { return String(localized: "今天") }
    if d == 1 { return String(localized: "明天") }
    return String(localized: "还有 \(d) 天")
}

private func calLabel(_ s: String) -> some View {
    HStack(spacing: 4) {
        Image(systemName: "calendar").font(.caption2.weight(.bold))
        Text(s).font(.caption.weight(.semibold))
    }
    .foregroundStyle(.secondary)
}

// MARK: - 本月总额

struct MonthTotalWidgetView: View {
    var entry: EONEntry
    @Environment(\.widgetFamily) private var family
    private var snap: EONWidgetSnapshot { entry.snapshot }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                calLabel(snap.monthLabel)
                Spacer()
                EonMark()
            }
            Spacer(minLength: 2)
            BigAmount(major: snap.monthMajor, minor: snap.monthMinor, size: family == .systemSmall ? 30 : 34)
            Text(String(localized: "\(snap.dueCount) 笔待扣费"))
                .font(.caption).foregroundStyle(.secondary)
            if let first = snap.upcoming.first {
                Spacer(minLength: 2)
                Divider()
                HStack(spacing: 6) {
                    WIcon(item: first, size: 22)
                    Text(first.name).font(.caption2.weight(.semibold)).lineLimit(1)
                    Spacer()
                    Text(first.dateText).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct MonthTotalWidget: Widget {
    let kind = "EONMonthTotal"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: EONProvider()) { entry in
            MonthTotalWidgetView(entry: entry)
                .padding(2)
                .containerBackground(for: .widget) { Color(.systemBackground) }
        }
        .configurationDisplayName(Text("本月总额"))
        .description(Text("当前周期的订阅支出总额。"))
        .supportedFamilies([.systemSmall, .accessoryRectangular])
    }
}

// MARK: - 下次扣费

struct NextChargeWidgetView: View {
    var entry: EONEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let item = entry.snapshot.upcoming.first {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    WIcon(item: item, size: family == .systemSmall ? 30 : 36)
                    Spacer()
                    Text("续费").font(.caption2.weight(.heavy))
                        .foregroundStyle(.tint)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(.tint.opacity(0.15), in: Capsule())
                }
                Spacer(minLength: 0)
                Text(item.name).font(.headline).lineLimit(1)
                Text(daysText(item.daysLeft))
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(.tint)
                HStack(alignment: .firstTextBaseline) {
                    Text(item.amountText).font(.subheadline.weight(.bold))
                    Spacer()
                    Text(item.dateText).font(.caption).foregroundStyle(.secondary)
                }
            }
        } else {
            VStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill").font(.title).foregroundStyle(.green)
                Text("近期无扣费").font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct NextChargeWidget: Widget {
    let kind = "EONNextCharge"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: EONProvider()) { entry in
            NextChargeWidgetView(entry: entry)
                .padding(2)
                .containerBackground(for: .widget) { Color(.systemBackground) }
        }
        .configurationDisplayName(Text("下次扣费"))
        .description(Text("离你下一笔订阅续费还有几天。"))
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

// MARK: - 本月清单

struct UpcomingListWidgetView: View {
    var entry: EONEntry
    @Environment(\.widgetFamily) private var family
    private var snap: EONWidgetSnapshot { entry.snapshot }
    private var maxRows: Int { family == .systemLarge ? 7 : 3 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                calLabel(snap.monthLabel)
                Spacer()
                BigAmount(major: snap.monthMajor, minor: snap.monthMinor, size: 22)
            }
            if snap.periodCharges.isEmpty {
                Spacer()
                HStack { Spacer()
                    Text("本月无扣费").font(.caption).foregroundStyle(.secondary)
                    Spacer() }
                Spacer()
            } else {
                ForEach(snap.periodCharges.prefix(maxRows)) { item in
                    HStack(spacing: 8) {
                        WIcon(item: item, size: 26)
                        Text(item.name).font(.caption.weight(.semibold)).lineLimit(1)
                        Text(item.dateText).font(.caption2).foregroundStyle(.tertiary)
                        Spacer()
                        Text(item.amountText)
                            .font(.caption.weight(.bold).monospacedDigit())
                        if item.paid {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2).foregroundStyle(.green)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}

struct UpcomingListWidget: Widget {
    let kind = "EONUpcomingList"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: EONProvider()) { entry in
            UpcomingListWidgetView(entry: entry)
                .padding(2)
                .containerBackground(for: .widget) { Color(.systemBackground) }
        }
        .configurationDisplayName(Text("本月清单"))
        .description(Text("本月的订阅扣费清单。"))
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

// MARK: - Bundle

@main
struct EONWidgetBundle: WidgetBundle {
    var body: some Widget {
        NextChargeWidget()
        MonthTotalWidget()
        UpcomingListWidget()
    }
}
