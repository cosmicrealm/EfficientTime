import Foundation

public struct LocalDate: Codable, Hashable, Comparable, Sendable {
    public var year: Int
    public var month: Int
    public var day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public static func today(calendar: Calendar = .current) -> LocalDate {
        let components = calendar.dateComponents([.year, .month, .day], from: Date())
        return LocalDate(
            year: components.year ?? 1970,
            month: components.month ?? 1,
            day: components.day ?? 1
        )
    }

    public func adding(days: Int, calendar: Calendar = .current) -> LocalDate {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        let date = calendar.date(from: components) ?? Date()
        let adjusted = calendar.date(byAdding: .day, value: days, to: date) ?? date
        let adjustedComponents = calendar.dateComponents([.year, .month, .day], from: adjusted)
        return LocalDate(
            year: adjustedComponents.year ?? year,
            month: adjustedComponents.month ?? month,
            day: adjustedComponents.day ?? day
        )
    }

    public func date(calendar: Calendar = .current) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return calendar.date(from: components) ?? Date()
    }

    public func startOfWeek(calendar: Calendar = .current) -> LocalDate {
        let date = self.date(calendar: calendar)
        let interval = calendar.dateInterval(of: .weekOfYear, for: date)
        let start = interval?.start ?? date
        let components = calendar.dateComponents([.year, .month, .day], from: start)
        return LocalDate(
            year: components.year ?? year,
            month: components.month ?? month,
            day: components.day ?? day
        )
    }

    public var weekdayTitle: String {
        let weekday = Calendar.current.component(.weekday, from: date())
        switch weekday {
        case 1: return "周日"
        case 2: return "周一"
        case 3: return "周二"
        case 4: return "周三"
        case 5: return "周四"
        case 6: return "周五"
        case 7: return "周六"
        default: return ""
        }
    }

    public var shortDisplayString: String {
        String(format: "%02d-%02d", month, day)
    }

    public var displayString: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    public static func < (lhs: LocalDate, rhs: LocalDate) -> Bool {
        if lhs.year != rhs.year { return lhs.year < rhs.year }
        if lhs.month != rhs.month { return lhs.month < rhs.month }
        return lhs.day < rhs.day
    }
}

public struct ClockTime: Codable, Hashable, Comparable, Sendable {
    public static let startOfDay = ClockTime(minutesSinceMidnight: 0)
    public static let endOfDay = ClockTime(minutesSinceMidnight: 24 * 60)

    public var minutesSinceMidnight: Int

    public init(hour: Int, minute: Int) {
        precondition((0...24).contains(hour), "Hour must be between 0 and 24")
        precondition((0...59).contains(minute), "Minute must be between 0 and 59")
        precondition(hour < 24 || minute == 0, "24:00 is the only valid 24-hour time")
        self.init(minutesSinceMidnight: hour * 60 + minute)
    }

    public init(minutesSinceMidnight: Int) {
        precondition((0...(24 * 60)).contains(minutesSinceMidnight), "Time must be within one day")
        self.minutesSinceMidnight = minutesSinceMidnight
    }

    public init(parsing value: String) throws {
        let parts = value.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0...24).contains(hour),
              (0...59).contains(minute),
              hour < 24 || minute == 0
        else {
            throw ClockTimeParseError.invalidFormat(value)
        }
        self.init(hour: hour, minute: minute)
    }

    public var hour: Int {
        minutesSinceMidnight / 60
    }

    public var minute: Int {
        minutesSinceMidnight % 60
    }

    public var displayString: String {
        String(format: "%02d:%02d", hour, minute)
    }

    public func adding(minutes: Int) -> ClockTime? {
        let value = minutesSinceMidnight + minutes
        guard (0...(24 * 60)).contains(value) else { return nil }
        return ClockTime(minutesSinceMidnight: value)
    }

    public static func < (lhs: ClockTime, rhs: ClockTime) -> Bool {
        lhs.minutesSinceMidnight < rhs.minutesSinceMidnight
    }
}

public enum ClockTimeParseError: Error, Equatable {
    case invalidFormat(String)
}

public struct TimeWindow: Codable, Hashable, Sendable {
    public var start: ClockTime
    public var end: ClockTime

    public init(start: ClockTime, end: ClockTime) {
        precondition(start < end, "TimeWindow start must be before end")
        self.start = start
        self.end = end
    }

    public var durationMinutes: Int {
        end.minutesSinceMidnight - start.minutesSinceMidnight
    }

    public func contains(_ time: ClockTime) -> Bool {
        start <= time && time <= end
    }

    public func contains(_ block: TimeBlock) -> Bool {
        start <= block.start && block.end <= end
    }

    public func intersects(_ other: TimeWindow) -> Bool {
        start < other.end && other.start < end
    }
}
