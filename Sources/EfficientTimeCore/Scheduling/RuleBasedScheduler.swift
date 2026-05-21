import Foundation

public struct ScheduleRequest: Sendable {
    public var date: LocalDate
    public var availableWindows: [TimeWindow]
    public var tasks: [Task]
    public var bufferMinutes: Int

    public init(
        date: LocalDate,
        availableWindows: [TimeWindow],
        tasks: [Task],
        bufferMinutes: Int = 5
    ) {
        self.date = date
        self.availableWindows = availableWindows.sorted { $0.start < $1.start }
        self.tasks = tasks
        self.bufferMinutes = max(0, bufferMinutes)
    }
}

public struct ScheduleResult: Sendable {
    public var plan: DayPlan
    public var unscheduledTasks: [Task]
    public var issues: [ScheduleIssue]

    public init(plan: DayPlan, unscheduledTasks: [Task], issues: [ScheduleIssue]) {
        self.plan = plan
        self.unscheduledTasks = unscheduledTasks
        self.issues = issues
    }
}

public enum ScheduleIssueKind: String, Codable, Sendable {
    case invalidDuration
    case outsideAvailability
    case overlap
    case noAvailableSlot
}

public struct ScheduleIssue: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var kind: ScheduleIssueKind
    public var message: String
    public var taskId: UUID?
    public var blockId: UUID?

    public init(
        id: UUID = UUID(),
        kind: ScheduleIssueKind,
        message: String,
        taskId: UUID? = nil,
        blockId: UUID? = nil
    ) {
        self.id = id
        self.kind = kind
        self.message = message
        self.taskId = taskId
        self.blockId = blockId
    }
}

public struct RuleBasedScheduler: Sendable {
    public init() {}

    public func makePlan(request: ScheduleRequest) -> ScheduleResult {
        var blocks: [TimeBlock] = []
        var unscheduledTasks: [Task] = []
        var issues: [ScheduleIssue] = []
        let tasks = TaskMerger.mergeSameTitleTasks(request.tasks)

        let fixedTasks = tasks
            .enumerated()
            .filter { $0.element.isFixedTime }
            .sorted { lhs, rhs in
                let leftStart = lhs.element.fixedStart ?? .startOfDay
                let rightStart = rhs.element.fixedStart ?? .startOfDay
                if leftStart != rightStart {
                    return leftStart < rightStart
                }
                return lhs.offset < rhs.offset
            }
            .map(\.element)

        for task in fixedTasks {
            guard task.estimatedDurationMinutes > 0 else {
                issues.append(.invalidDuration(task: task))
                unscheduledTasks.append(task)
                continue
            }
            guard let start = task.fixedStart,
                  let end = start.adding(minutes: task.estimatedDurationMinutes)
            else {
                issues.append(.outsideAvailability(task: task))
                unscheduledTasks.append(task)
                continue
            }

            let block = TimeBlock(taskId: task.id, title: task.title, start: start, end: end)
            guard request.availableWindows.contains(where: { $0.contains(block) }) else {
                issues.append(.outsideAvailability(task: task))
                unscheduledTasks.append(task)
                continue
            }
            blocks.append(block)
        }

        let flexibleTasks = tasks
            .filter { !$0.isFixedTime }
            .sorted(by: flexibleTaskSort)

        for task in flexibleTasks {
            guard task.estimatedDurationMinutes > 0 else {
                issues.append(.invalidDuration(task: task))
                unscheduledTasks.append(task)
                continue
            }
            guard let slot = findSlot(
                for: task,
                windows: request.availableWindows,
                occupiedBlocks: blocks,
                bufferMinutes: request.bufferMinutes
            ) else {
                issues.append(.noAvailableSlot(task: task))
                unscheduledTasks.append(task)
                continue
            }

            blocks.append(
                TimeBlock(
                    taskId: task.id,
                    title: task.title,
                    start: slot.start,
                    end: slot.end
                )
            )
            blocks = stableSortedBlocks(blocks)
        }

        let plan = DayPlan(
            date: request.date,
            availableWindows: request.availableWindows,
            blocks: stableSortedBlocks(blocks),
            status: .ready
        )
        issues.append(contentsOf: ScheduleValidator.validate(plan: plan))

        return ScheduleResult(
            plan: plan,
            unscheduledTasks: unscheduledTasks,
            issues: issues
        )
    }

    private func flexibleTaskSort(lhs: Task, rhs: Task) -> Bool {
        if lhs.priority != rhs.priority {
            return lhs.priority > rhs.priority
        }
        switch (lhs.deadline, rhs.deadline) {
        case let (left?, right?) where left != right:
            return left < right
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        default:
            return lhs.estimatedDurationMinutes > rhs.estimatedDurationMinutes
        }
    }

    private func findSlot(
        for task: Task,
        windows: [TimeWindow],
        occupiedBlocks: [TimeBlock],
        bufferMinutes: Int
    ) -> TimeWindow? {
        let earliest = task.earliestStart ?? .startOfDay
        let latest = task.latestEnd ?? .endOfDay

        for window in windows {
            let searchStart = max(window.start, earliest)
            let searchEnd = min(window.end, latest)
            guard searchStart < searchEnd else { continue }

            var cursor = searchStart
            let busyBlocks = occupiedBlocks
                .compactMap { expandedWindow(for: $0, bufferMinutes: bufferMinutes) }
                .filter { $0.intersects(TimeWindow(start: searchStart, end: searchEnd)) }
                .sorted { $0.start < $1.start }

            for busy in busyBlocks {
                let gapEnd = min(busy.start, searchEnd)
                if let end = cursor.adding(minutes: task.estimatedDurationMinutes),
                   end <= gapEnd {
                    return TimeWindow(start: cursor, end: end)
                }
                cursor = max(cursor, busy.end)
                if cursor >= searchEnd { break }
            }

            if let end = cursor.adding(minutes: task.estimatedDurationMinutes),
               end <= searchEnd {
                return TimeWindow(start: cursor, end: end)
            }
        }

        return nil
    }

    private func expandedWindow(for block: TimeBlock, bufferMinutes: Int) -> TimeWindow? {
        let start = block.start.adding(minutes: -bufferMinutes) ?? .startOfDay
        let end = block.end.adding(minutes: bufferMinutes) ?? .endOfDay
        guard start < end else { return nil }
        return TimeWindow(start: start, end: end)
    }

    private func stableSortedBlocks(_ blocks: [TimeBlock]) -> [TimeBlock] {
        blocks
            .enumerated()
            .sorted { lhs, rhs in
                if lhs.element.start != rhs.element.start {
                    return lhs.element.start < rhs.element.start
                }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }
}

private extension ScheduleIssue {
    static func invalidDuration(task: Task) -> ScheduleIssue {
        ScheduleIssue(
            kind: .invalidDuration,
            message: "`\(task.title)` 的预计耗时必须大于 0 分钟。",
            taskId: task.id
        )
    }

    static func outsideAvailability(task: Task) -> ScheduleIssue {
        ScheduleIssue(
            kind: .outsideAvailability,
            message: "`\(task.title)` 不在当天可用时间段内。",
            taskId: task.id
        )
    }

    static func noAvailableSlot(task: Task) -> ScheduleIssue {
        ScheduleIssue(
            kind: .noAvailableSlot,
            message: "`\(task.title)` 没有可安排的连续时间段。",
            taskId: task.id
        )
    }
}
