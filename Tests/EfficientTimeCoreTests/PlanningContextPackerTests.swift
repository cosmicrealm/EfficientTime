import XCTest
@testable import EfficientTimeCore

final class PlanningContextPackerTests: XCTestCase {
    func testPackerDropsPrivateTasksAndAnonymizesSensitiveTasks() {
        let privateTask = Task(
            title: "午饭地点和私人安排",
            estimatedDurationMinutes: 60,
            category: .life,
            privacyLevel: .private
        )
        let anonymizedTask = Task(
            title: "查看招商证券账户资产变化",
            estimatedDurationMinutes: 20,
            category: .finance,
            privacyLevel: .anonymized
        )
        let visibleTask = Task(
            title: "阅读 EfficientTime 相关资料",
            estimatedDurationMinutes: 45,
            category: .study,
            privacyLevel: .aiVisible
        )

        let context = PlanningContext(
            date: LocalDate(year: 2026, month: 5, day: 18),
            availableWindows: [
                TimeWindow(start: ClockTime(hour: 8, minute: 0), end: ClockTime(hour: 12, minute: 0))
            ],
            tasks: [privateTask, anonymizedTask, visibleTask],
            rawUserInput: "今天安排一下任务"
        )

        let packed = PlanningContextPacker().pack(context)

        XCTAssertEqual(packed.tasks.count, 2)
        XCTAssertEqual(packed.defaultSchedule, AIPlanningDefaults.standard)
        XCTAssertFalse(packed.tasks.contains { $0.title.contains("午饭地点") })
        XCTAssertFalse(packed.tasks.contains { $0.title.contains("招商证券") })
        XCTAssertTrue(packed.tasks.contains { $0.title == "财务检查" })
        XCTAssertTrue(packed.tasks.contains { $0.title == "阅读 EfficientTime 相关资料" })
    }
}
