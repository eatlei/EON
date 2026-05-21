import EventKit
import UIKit

/// 把订阅的"续费 / 试用到期"提醒写进系统「提醒事项」。相比 App 内本地通知,
/// 提醒事项支持多重提醒(到期前几天 + 当天 + 基于位置等),用户更不容易错过。
/// 全程在设备本地完成,需要用户一次性授权(NSRemindersFullAccessUsageDescription)。
enum RemindersService {
    enum Result {
        case added            // 成功写入
        case denied           // 用户拒绝授权
        case failed           // 其他失败
    }

    /// 为订阅创建一条提醒,带"提前 N 天"和"当天"两个 alarm —— 这就是用户口中
    /// "苹果提醒事项的多重提醒机制"。due 用真·下次扣费日(滚动到今天之后)。
    @MainActor
    static func addRenewalReminder(for sub: Subscription) async -> Result {
        let store = EKEventStore()
        let granted: Bool
        do {
            granted = try await store.requestFullAccessToReminders()
        } catch {
            return .failed
        }
        guard granted else { return .denied }

        let reminder = EKReminder(eventStore: store)
        reminder.calendar = store.defaultCalendarForNewReminders()
        guard reminder.calendar != nil else { return .failed }

        let cal = Calendar.current
        let due = sub.upcomingBillingDate()
        let isTrial = sub.status == .trial
        reminder.title = isTrial
            ? String(localized: "EON · \(sub.name) 试用即将到期")
            : String(localized: "EON · \(sub.name) 即将续费")
        reminder.notes = String(localized: "由 EON 添加。到期请决定是否继续订阅。")

        // 截止日 = 当天 9:00。
        var dueComp = cal.dateComponents([.year, .month, .day], from: due)
        dueComp.hour = 9
        reminder.dueDateComponents = dueComp

        // 多重提醒:提前 N 天(取订阅自己的提醒天数,至少 1 天)+ 当天早上。
        let lead = max(sub.reminderDaysBefore, 1)
        if let dueDate = cal.date(from: dueComp) {
            if let early = cal.date(byAdding: .day, value: -lead, to: dueDate) {
                reminder.addAlarm(EKAlarm(absoluteDate: early))
            }
            reminder.addAlarm(EKAlarm(absoluteDate: dueDate))
        }

        do {
            try store.save(reminder, commit: true)
            return .added
        } catch {
            return .failed
        }
    }

    /// 打开系统「提醒事项」App。装不上 / 打不开时回退到 App Store 对应页面。
    @MainActor
    static func openRemindersApp() {
        let appURL = URL(string: "x-apple-reminderkit://")!
        let storeURL = URL(string: "https://apps.apple.com/app/id1108187841")! // Apple Reminders
        if UIApplication.shared.canOpenURL(appURL) {
            UIApplication.shared.open(appURL)
        } else {
            UIApplication.shared.open(storeURL)
        }
    }
}
