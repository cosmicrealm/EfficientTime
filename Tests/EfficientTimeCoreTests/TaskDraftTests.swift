import XCTest
@testable import EfficientTimeCore

final class TaskDraftTests: XCTestCase {
    func testTaskDraftConvertsToTaskWithConstraints() {
        let draft = TaskDraft(
            title: "写代码",
            estimatedDurationMinutes: 90,
            priority: .critical,
            category: .work,
            fixedStart: ClockTime(hour: 9, minute: 0),
            canSplit: true,
            assumptions: ["适合安排在上午。"]
        )

        let task = draft.makeTask(privacyLevel: .aiVisible)

        XCTAssertEqual(task.title, "写代码")
        XCTAssertEqual(task.estimatedDurationMinutes, 90)
        XCTAssertEqual(task.priority, .critical)
        XCTAssertEqual(task.category, .work)
        XCTAssertEqual(task.fixedStart, ClockTime(hour: 9, minute: 0))
        XCTAssertTrue(task.canSplit)
        XCTAssertEqual(task.privacyLevel, .aiVisible)
        XCTAssertTrue(task.notes.contains("适合安排在上午"))
    }
}

