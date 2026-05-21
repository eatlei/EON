import WidgetKit
import SwiftUI

// EON 的桌面 / 锁屏小组件。三个:下次扣费倒计时、本月总额、即将扣费清单。
// 数据全部来自 App Group 里的 EONWidgetSnapshot(App 端算好写入)。

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

// MARK: - 共用小组件

private struct IconTile: View {
    let letter: String
    let colorHex: String
    var size: CGFloat = 34
    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(Color(eonHex: colorHex))
            .frame(width: size, height: size)
            .overlay(
                Text(letter)
                    .font(.system(size: size * 0.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            )
    }
}

private func daysText(_ d: Int) -> String {
    if d <= 0 { return String(localized: "今天") }
    if d == 1 { return String(localized: "明天") }
    return String(localized: "还有 \(d) 天")
}

// MARK: - 下次扣费倒计时

struct NextChargeWidgetView: View {
    var entry: EONEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let item = entry.snapshot.upcoming.first {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    IconTile(letter: item.letter, colorHex: item.colorHex, size: family == .systemSmall ? 30 : 34)
                    Spacer()
                    Text("EON").font(.caption2.weight(.heavy)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Text(item.name).font(.headline).lineLimit(1)
                Text(daysText(item.daysLeft))
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(.tint)
                HStack {
                    Text(item.amountText).font(.subheadline.weight(.bold))
                    Spacer()
                    Text(item.dateText).font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(4)
        } else {
            placeholderEmpty
        }
    }

    private var placeholderEmpty: some View {
        VStack(spacing: 6) {
            Image(systemName: "checkmark.circle").font(.title)
            Text("近期无扣费").font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct NextChargeWidget: Widget {
    let kind = "EONNextCharge"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: EONProvider()) { entry in
            NextChargeWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(Text("下次扣费"))
        .description(Text("离你下一笔订阅续费还有几天。"))
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

// MARK: - 本月总额

struct MonthTotalWidgetView: View {
    var entry: EONEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "chart.pie.fill").foregroundStyle(.tint)
                Spacer()
                Text("EON").font(.caption2.weight(.heavy)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Text("本月总额").font(.caption).foregroundStyle(.secondary)
            Text(entry.snapshot.monthTotalText)
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .minimumScaleFactor(0.5).lineLimit(1)
            Text(String(localized: "\(entry.snapshot.subscriptionCount) 个活跃订阅"))
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(4)
    }
}

struct MonthTotalWidget: Widget {
    let kind = "EONMonthTotal"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: EONProvider()) { entry in
            MonthTotalWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(Text("本月总额"))
        .description(Text("当前周期的订阅支出总额。"))
        .supportedFamilies([.systemSmall, .accessoryRectangular])
    }
}

// MARK: - 即将扣费清单

struct UpcomingListWidgetView: View {
    var entry: EONEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("即将扣费").font(.subheadline.weight(.bold))
                Spacer()
                Text("EON").font(.caption2.weight(.heavy)).foregroundStyle(.secondary)
            }
            if entry.snapshot.upcoming.isEmpty {
                Spacer()
                Text("近期无扣费").font(.caption).foregroundStyle(.secondary)
                Spacer()
            } else {
                ForEach(entry.snapshot.upcoming.prefix(4)) { item in
                    HStack(spacing: 8) {
                        IconTile(letter: item.letter, colorHex: item.colorHex, size: 26)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.name).font(.caption.weight(.semibold)).lineLimit(1)
                            Text(daysText(item.daysLeft)).font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(item.amountText).font(.caption.weight(.bold).monospacedDigit())
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(4)
    }
}

struct UpcomingListWidget: Widget {
    let kind = "EONUpcomingList"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: EONProvider()) { entry in
            UpcomingListWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(Text("即将扣费清单"))
        .description(Text("接下来几笔订阅扣费。"))
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
