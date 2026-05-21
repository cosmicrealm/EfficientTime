public enum ScheduleValidator {
    public static func validate(plan: DayPlan) -> [ScheduleIssue] {
        var issues: [ScheduleIssue] = []
        let blocks = plan.blocks.sorted { $0.start < $1.start }

        for block in blocks {
            if !plan.availableWindows.contains(where: { $0.contains(block) }) {
                issues.append(
                    ScheduleIssue(
                        kind: .outsideAvailability,
                        message: "`\(block.title)` 不在当天可用时间段内。",
                        blockId: block.id
                    )
                )
            }
        }

        return issues
    }
}
