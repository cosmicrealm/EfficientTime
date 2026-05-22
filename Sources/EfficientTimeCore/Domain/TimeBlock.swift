import Foundation

public enum TimeBlockStatus: String, Codable, CaseIterable, Sendable {
    case planned
    case active
    case done
    case skipped
    case delayed
    case interrupted
    case deleted
}

public struct TimeBlock: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var taskId: UUID?
    public var title: String
    public var start: ClockTime
    public var end: ClockTime
    public var status: TimeBlockStatus
    public var actualStartAt: Date?
    public var actualEndAt: Date?

    public init(
        id: UUID = UUID(),
        taskId: UUID?,
        title: String,
        start: ClockTime,
        end: ClockTime,
        status: TimeBlockStatus = .planned,
        actualStartAt: Date? = nil,
        actualEndAt: Date? = nil
    ) {
        precondition(start < end, "TimeBlock start must be before end")
        self.id = id
        self.taskId = taskId
        self.title = title
        self.start = start
        self.end = end
        self.status = status
        self.actualStartAt = actualStartAt
        self.actualEndAt = actualEndAt
    }

    public var durationMinutes: Int {
        end.minutesSinceMidnight - start.minutesSinceMidnight
    }

    public func overlaps(_ other: TimeBlock) -> Bool {
        start < other.end && other.start < end
    }
}
