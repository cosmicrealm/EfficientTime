import Foundation

public struct MockPlanningService: AIPlanningService {
    private let scheduler: RuleBasedScheduler

    public init(scheduler: RuleBasedScheduler = RuleBasedScheduler()) {
        self.scheduler = scheduler
    }

    public func extractTasks(from input: String, context: PlanningContext) async throws -> [TaskDraft] {
        let lines = input
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return lines.map {
            TaskDraft(
                title: String($0),
                estimatedDurationMinutes: 30,
                assumptions: ["Mock 默认每条输入估算为 30 分钟。"]
            )
        }
    }

    public func askClarifyingQuestions(context: PlanningContext) async throws -> [String] {
        if context.availableWindows.isEmpty {
            return ["今天有哪些可用时间段？"]
        }
        if context.tasks.contains(where: { $0.estimatedDurationMinutes <= 0 }) {
            return ["有些任务缺少预计耗时，是否需要我先按默认 30 分钟估算？"]
        }
        return []
    }

    public func proposeSchedule(context: PlanningContext) async throws -> PlanDraft {
        let result = scheduler.makePlan(
            request: ScheduleRequest(
                date: context.date,
                availableWindows: context.availableWindows,
                tasks: context.tasks
            )
        )
        return PlanDraft(
            date: context.date,
            blocks: result.plan.blocks,
            unscheduledTaskTitles: result.unscheduledTasks.map(\.title),
            assumptions: ["Mock 使用本地规则排程器生成草稿。"]
        )
    }

    public func summarizeDay(plan: DayPlan, logs: [ExecutionLog], outputLanguage: String = "Simplified Chinese") async throws -> String {
        let doneCount = plan.blocks.filter { $0.status == .done }.count
        return "今天完成 \(doneCount)/\(plan.blocks.count) 个时间块，记录事件 \(logs.count) 条。"
    }
}
