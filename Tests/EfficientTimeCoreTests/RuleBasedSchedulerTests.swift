import XCTest
@testable import EfficientTimeCore

final class RuleBasedSchedulerTests: XCTestCase {
    func testSchedulesFlexibleTaskAfterFixedTaskWithBuffer() {
        let fixed = Task(
            title: "查看股票账户",
            estimatedDurationMinutes: 20,
            priority: .high,
            category: .finance,
            fixedStart: ClockTime(hour: 8, minute: 0)
        )
        let flexible = Task(
            title: "阅读文章综述",
            estimatedDurationMinutes: 60,
            priority: .high,
            category: .study,
            earliestStart: ClockTime(hour: 8, minute: 0)
        )
        let scheduler = RuleBasedScheduler()
        let result = scheduler.makePlan(
            request: ScheduleRequest(
                date: LocalDate(year: 2026, month: 5, day: 18),
                availableWindows: [
                    TimeWindow(start: ClockTime(hour: 8, minute: 0), end: ClockTime(hour: 12, minute: 0))
                ],
                tasks: [fixed, flexible],
                bufferMinutes: 10
            )
        )

        XCTAssertTrue(result.unscheduledTasks.isEmpty)
        XCTAssertEqual(result.plan.blocks.count, 2)
        XCTAssertEqual(result.plan.blocks[0].title, "查看股票账户")
        XCTAssertEqual(result.plan.blocks[0].start, ClockTime(hour: 8, minute: 0))
        XCTAssertEqual(result.plan.blocks[0].end, ClockTime(hour: 8, minute: 20))
        XCTAssertEqual(result.plan.blocks[1].title, "阅读文章综述")
        XCTAssertEqual(result.plan.blocks[1].start, ClockTime(hour: 8, minute: 30))
        XCTAssertEqual(result.plan.blocks[1].end, ClockTime(hour: 9, minute: 30))
    }

    func testAllowsOverlappingFixedTasksWithDifferentTitles() {
        let first = Task(
            title: "固定任务 A",
            estimatedDurationMinutes: 60,
            fixedStart: ClockTime(hour: 8, minute: 0)
        )
        let second = Task(
            title: "固定任务 B",
            estimatedDurationMinutes: 30,
            fixedStart: ClockTime(hour: 8, minute: 30)
        )
        let scheduler = RuleBasedScheduler()
        let result = scheduler.makePlan(
            request: ScheduleRequest(
                date: LocalDate(year: 2026, month: 5, day: 18),
                availableWindows: [
                    TimeWindow(start: ClockTime(hour: 8, minute: 0), end: ClockTime(hour: 12, minute: 0))
                ],
                tasks: [first, second]
            )
        )

        XCTAssertEqual(result.plan.blocks.count, 2)
        XCTAssertTrue(result.unscheduledTasks.isEmpty)
        XCTAssertTrue(result.issues.isEmpty)
        XCTAssertEqual(result.plan.blocks.map(\.title), ["固定任务 A", "固定任务 B"])
    }

    func testMergesDuplicateFixedTasksByTitle() {
        let first = Task(
            title: "整理资料",
            notes: "文档",
            estimatedDurationMinutes: 30,
            fixedStart: ClockTime(hour: 8, minute: 0)
        )
        let second = Task(
            title: " 整理资料 ",
            notes: "图片",
            estimatedDurationMinutes: 20,
            fixedStart: ClockTime(hour: 8, minute: 20)
        )
        let scheduler = RuleBasedScheduler()
        let result = scheduler.makePlan(
            request: ScheduleRequest(
                date: LocalDate(year: 2026, month: 5, day: 18),
                availableWindows: [
                    TimeWindow(start: ClockTime(hour: 8, minute: 0), end: ClockTime(hour: 12, minute: 0))
                ],
                tasks: [first, second]
            )
        )

        XCTAssertEqual(result.plan.blocks.count, 1)
        XCTAssertTrue(result.unscheduledTasks.isEmpty)
        XCTAssertEqual(result.plan.blocks[0].title, "整理资料")
        XCTAssertEqual(result.plan.blocks[0].start, ClockTime(hour: 8, minute: 0))
        XCTAssertEqual(result.plan.blocks[0].end, ClockTime(hour: 8, minute: 40))
    }

    func testLeavesTaskUnscheduledWhenNoContinuousSlotExists() {
        let longTask = Task(
            title: "深度工作",
            estimatedDurationMinutes: 180,
            priority: .critical
        )
        let scheduler = RuleBasedScheduler()
        let result = scheduler.makePlan(
            request: ScheduleRequest(
                date: LocalDate(year: 2026, month: 5, day: 18),
                availableWindows: [
                    TimeWindow(start: ClockTime(hour: 8, minute: 0), end: ClockTime(hour: 9, minute: 0)),
                    TimeWindow(start: ClockTime(hour: 10, minute: 0), end: ClockTime(hour: 11, minute: 0))
                ],
                tasks: [longTask]
            )
        )

        XCTAssertTrue(result.plan.blocks.isEmpty)
        XCTAssertEqual(result.unscheduledTasks.map(\.title), ["深度工作"])
        XCTAssertTrue(result.issues.contains { $0.kind == .noAvailableSlot })
    }
}
