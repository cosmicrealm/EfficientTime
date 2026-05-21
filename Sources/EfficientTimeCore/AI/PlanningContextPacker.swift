public struct PackedPlanningContext: Codable, Hashable, Sendable {
    public var date: LocalDate
    public var availableWindows: [TimeWindow]
    public var defaultSchedule: AIPlanningDefaultSchedule
    public var tasks: [PackedTaskContext]
    public var rawUserInput: String
    public var effort: PlanningEffort
}

public struct PackedTaskContext: Identifiable, Codable, Hashable, Sendable {
    public var id: Task.ID
    public var title: String
    public var estimatedDurationMinutes: Int
    public var priority: TaskPriority
    public var category: TaskCategory
    public var deadline: ClockTime?
    public var earliestStart: ClockTime?
    public var latestEnd: ClockTime?
    public var fixedStart: ClockTime?
    public var canSplit: Bool
}

public struct PlanningContextPacker: Sendable {
    public init() {}

    public func pack(_ context: PlanningContext) -> PackedPlanningContext {
        PackedPlanningContext(
            date: context.date,
            availableWindows: context.availableWindows,
            defaultSchedule: context.defaultSchedule,
            tasks: context.tasks.compactMap(packTask),
            rawUserInput: context.rawUserInput,
            effort: context.effort
        )
    }

    private func packTask(_ task: Task) -> PackedTaskContext? {
        switch task.privacyLevel {
        case .private:
            return nil
        case .anonymized:
            return PackedTaskContext(
                id: task.id,
                title: task.category.anonymizedTitle,
                estimatedDurationMinutes: task.estimatedDurationMinutes,
                priority: task.priority,
                category: task.category,
                deadline: task.deadline,
                earliestStart: task.earliestStart,
                latestEnd: task.latestEnd,
                fixedStart: task.fixedStart,
                canSplit: task.canSplit
            )
        case .aiVisible:
            return PackedTaskContext(
                id: task.id,
                title: task.title,
                estimatedDurationMinutes: task.estimatedDurationMinutes,
                priority: task.priority,
                category: task.category,
                deadline: task.deadline,
                earliestStart: task.earliestStart,
                latestEnd: task.latestEnd,
                fixedStart: task.fixedStart,
                canSplit: task.canSplit
            )
        }
    }
}
