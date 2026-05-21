public struct AIPlanningDefaultBreak: Codable, Hashable, Sendable {
    public var title: String
    public var start: ClockTime
    public var end: ClockTime

    public init(title: String, start: ClockTime, end: ClockTime) {
        self.title = title
        self.start = start
        self.end = end
    }

    public var durationMinutes: Int {
        end.minutesSinceMidnight - start.minutesSinceMidnight
    }

    public var window: TimeWindow {
        TimeWindow(start: start, end: end)
    }

    public var description: String {
        "\(start.displayString)-\(end.displayString) \(title)"
    }
}

public struct AIPlanningDefaultSchedule: Codable, Hashable, Sendable {
    public var start: ClockTime
    public var end: ClockTime
    public var breaks: [AIPlanningDefaultBreak]

    public init(
        start: ClockTime,
        end: ClockTime,
        breaks: [AIPlanningDefaultBreak]
    ) {
        self.start = start
        self.end = end
        self.breaks = breaks.sorted { $0.start < $1.start }
    }

    public var isValid: Bool {
        let sortedBreaks = breaks.sorted { $0.start < $1.start }
        let breaksDoNotOverlap = zip(sortedBreaks, sortedBreaks.dropFirst()).allSatisfy { current, next in
            current.end <= next.start
        }
        return start < end && breaksDoNotOverlap && breaks.allSatisfy {
            start <= $0.start && $0.start < $0.end && $0.end <= end
        }
    }

    public var window: TimeWindow {
        TimeWindow(start: start, end: end)
    }

    public var windows: [TimeWindow] {
        [window]
    }

    public var windowDescription: String {
        "\(start.displayString)-\(end.displayString)"
    }

    public var breakDescription: String {
        breaks.map(\.description).joined(separator: "；")
    }

    public var workSegments: [TimeWindow] {
        guard start < end else { return [] }

        var segments: [TimeWindow] = []
        var cursor = start
        let validBreaks = breaks.filter {
            start <= $0.start && $0.start < $0.end && $0.end <= end
        }

        for breakWindow in validBreaks.map(\.window).sorted(by: { $0.start < $1.start }) {
            if cursor < breakWindow.start {
                segments.append(TimeWindow(start: cursor, end: breakWindow.start))
            }
            cursor = max(cursor, breakWindow.end)
        }

        if cursor < end {
            segments.append(TimeWindow(start: cursor, end: end))
        }

        return segments
    }
}

public enum AIPlanningDefaults {
    public static let standard = AIPlanningDefaultSchedule(
        start: ClockTime(hour: 9, minute: 30),
        end: ClockTime(hour: 21, minute: 30),
        breaks: [
            AIPlanningDefaultBreak(
                title: "午饭",
                start: ClockTime(hour: 12, minute: 0),
                end: ClockTime(hour: 14, minute: 0)
            ),
            AIPlanningDefaultBreak(
                title: "晚饭",
                start: ClockTime(hour: 18, minute: 0),
                end: ClockTime(hour: 19, minute: 0)
            )
        ]
    )

    public static var defaultStart: ClockTime {
        standard.start
    }

    public static var defaultEnd: ClockTime {
        standard.end
    }

    public static var defaultBreaks: [AIPlanningDefaultBreak] {
        standard.breaks
    }

    public static var defaultWindow: TimeWindow {
        standard.window
    }

    public static var defaultWindows: [TimeWindow] {
        standard.windows
    }

    public static var defaultWindowDescription: String {
        standard.windowDescription
    }

    public static var defaultBreakDescription: String {
        standard.breakDescription
    }
}
