import Foundation

public enum TaskPriority: String, Codable, CaseIterable, Sendable {
    case low
    case medium
    case high
    case critical

    public var rank: Int {
        switch self {
        case .low: 0
        case .medium: 1
        case .high: 2
        case .critical: 3
        }
    }
}

extension TaskPriority: Comparable {
    public static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool {
        lhs.rank < rhs.rank
    }
}

public enum TaskCategory: String, Codable, CaseIterable, Sendable {
    case work
    case study
    case finance
    case life
    case rest
    case review
    case other

    public var anonymizedTitle: String {
        switch self {
        case .work: "工作任务"
        case .study: "学习任务"
        case .finance: "财务检查"
        case .life: "生活事项"
        case .rest: "休息"
        case .review: "复盘"
        case .other: "普通任务"
        }
    }
}

public enum TaskStatus: String, Codable, CaseIterable, Sendable {
    case planned
    case active
    case done
    case skipped
    case delayed
    case interrupted
}

public enum TaskPrivacyLevel: String, Codable, CaseIterable, Sendable {
    case `private`
    case anonymized
    case aiVisible
}

public struct Task: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var notes: String
    public var estimatedDurationMinutes: Int
    public var priority: TaskPriority
    public var category: TaskCategory
    public var deadline: ClockTime?
    public var earliestStart: ClockTime?
    public var latestEnd: ClockTime?
    public var fixedStart: ClockTime?
    public var canSplit: Bool
    public var status: TaskStatus
    public var privacyLevel: TaskPrivacyLevel

    public init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        estimatedDurationMinutes: Int,
        priority: TaskPriority = .medium,
        category: TaskCategory = .other,
        deadline: ClockTime? = nil,
        earliestStart: ClockTime? = nil,
        latestEnd: ClockTime? = nil,
        fixedStart: ClockTime? = nil,
        canSplit: Bool = false,
        status: TaskStatus = .planned,
        privacyLevel: TaskPrivacyLevel = .anonymized
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.estimatedDurationMinutes = estimatedDurationMinutes
        self.priority = priority
        self.category = category
        self.deadline = deadline
        self.earliestStart = earliestStart
        self.latestEnd = latestEnd
        self.fixedStart = fixedStart
        self.canSplit = canSplit
        self.status = status
        self.privacyLevel = privacyLevel
    }

    public var isFixedTime: Bool {
        fixedStart != nil
    }
}

