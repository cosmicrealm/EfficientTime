import Foundation

public enum DayPlanStatus: String, Codable, CaseIterable, Sendable {
    case draft
    case ready
    case running
    case finished
    case archived
}

public struct DayPlan: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var date: LocalDate
    public var availableWindows: [TimeWindow]
    public var blocks: [TimeBlock]
    public var status: DayPlanStatus

    public init(
        id: UUID = UUID(),
        date: LocalDate,
        availableWindows: [TimeWindow],
        blocks: [TimeBlock] = [],
        status: DayPlanStatus = .draft
    ) {
        self.id = id
        self.date = date
        self.availableWindows = availableWindows.sorted { $0.start < $1.start }
        self.blocks = blocks
            .enumerated()
            .sorted { lhs, rhs in
                if lhs.element.start != rhs.element.start {
                    return lhs.element.start < rhs.element.start
                }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
        self.status = status
    }
}

public enum ExecutionEventType: String, Codable, CaseIterable, Sendable {
    case started
    case completed
    case skipped
    case delayed
    case extended
    case interrupted
    case replanned
    case notified
}

public struct ExecutionLog: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var blockId: UUID
    public var eventType: ExecutionEventType
    public var timestamp: Date
    public var payload: [String: String]

    public init(
        id: UUID = UUID(),
        blockId: UUID,
        eventType: ExecutionEventType,
        timestamp: Date = Date(),
        payload: [String: String] = [:]
    ) {
        self.id = id
        self.blockId = blockId
        self.eventType = eventType
        self.timestamp = timestamp
        self.payload = payload
    }
}
