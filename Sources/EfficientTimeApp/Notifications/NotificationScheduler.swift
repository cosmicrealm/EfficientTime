import EfficientTimeCore
import Foundation
@preconcurrency import UserNotifications

final class NotificationScheduler: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestAuthorization(completion: (@Sendable (Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            completion?(granted)
        }
    }

    func getAuthorizationStatus(
        completion: @escaping @Sendable (UNAuthorizationStatus) -> Void
    ) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            completion(settings.authorizationStatus)
        }
    }

    func deliverNow(
        identifier: String,
        title: String,
        body: String,
        completion: (@Sendable (Error?) -> Void)? = nil
    ) {
        UNUserNotificationCenter.current().delegate = self
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            completion?(error)
        }
    }

    func scheduleNotifications(for plan: DayPlan, settings: AppSettings) {
        scheduleNotifications(for: [plan], settings: settings)
    }

    func scheduleNotifications(for plans: [DayPlan], settings: AppSettings) {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.getPendingNotificationRequests { [weak self] requests in
            guard let self else { return }
            let staleIDs = requests
                .map(\.identifier)
                .filter(Self.isEfficientTimeIdentifier)
            center.removePendingNotificationRequests(withIdentifiers: staleIDs)

            for plan in plans {
                self.scheduleBlockNotifications(for: plan, settings: settings)
            }

            if settings.tomorrowPlanningReminderEnabled {
                self.scheduleDailyNotification(
                    identifier: "efficienttime-tomorrow-planning-reminder",
                    title: AppLocalization.text("该规划明天了", language: settings.language),
                    body: AppLocalization.text("打开 EfficientTime 安排明天的时间表", language: settings.language),
                    time: settings.tomorrowPlanningReminderTime
                )
            }
        }
    }

    private func scheduleBlockNotifications(for plan: DayPlan, settings: AppSettings) {
        guard plan.status != .finished,
              plan.status != .archived
        else { return }

        for block in plan.blocks {
            guard block.status != .done,
                  block.status != .skipped,
                  block.status != .delayed
            else { continue }

            if settings.advanceReminderMinutes > 0,
               let advanceTime = block.start.adding(minutes: -settings.advanceReminderMinutes),
               advanceTime < block.start {
                scheduleNotification(
                    identifier: "efficienttime-block-advance-\(block.id.uuidString)",
                    title: AppLocalization.format("即将开始：%@", language: settings.language, block.title),
                    body: AppLocalization.format("还有 %d 分钟开始", language: settings.language, settings.advanceReminderMinutes),
                    date: plan.date,
                    time: advanceTime
                )
            }

            if settings.startNotificationsEnabled {
                scheduleNotification(
                    identifier: "efficienttime-block-start-\(block.id.uuidString)",
                    title: AppLocalization.format("开始：%@", language: settings.language, block.title),
                    body: AppLocalization.format("当前任务开始了，%@-%@", language: settings.language, block.start.displayString, block.end.displayString),
                    date: plan.date,
                    time: block.start
                )
            }

            if settings.endNotificationsEnabled {
                scheduleNotification(
                    identifier: "efficienttime-block-end-\(block.id.uuidString)",
                    title: AppLocalization.format("结束：%@", language: settings.language, block.title),
                    body: AppLocalization.text("当前任务到结束时间了，请标记完成或跳过", language: settings.language),
                    date: plan.date,
                    time: block.end
                )
            }
        }
    }

    private func scheduleNotification(
        identifier: String,
        title: String,
        body: String,
        date: LocalDate,
        time: ClockTime
    ) {
        var components = DateComponents()
        components.year = date.year
        components.month = date.month
        components.day = date.day
        components.hour = time.hour
        components.minute = time.minute
        components.second = 0

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        guard let triggerDate = Calendar.current.date(from: components) else { return }
        let elapsed = Date().timeIntervalSince(triggerDate)
        if elapsed >= 0 {
            if elapsed <= 180 {
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
                UNUserNotificationCenter.current().add(request)
            }
            return
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private func scheduleDailyNotification(
        identifier: String,
        title: String,
        body: String,
        time: ClockTime
    ) {
        var components = DateComponents()
        components.hour = time.hour
        components.minute = time.minute

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private static func isEfficientTimeIdentifier(_ identifier: String) -> Bool {
        identifier.hasPrefix("efficienttime-") ||
            identifier.hasPrefix("block-advance-") ||
            identifier.hasPrefix("block-start-") ||
            identifier.hasPrefix("block-end-") ||
            identifier == "tomorrow-planning-reminder"
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }
}
