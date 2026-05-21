import XCTest
@testable import EfficientTimeCore

final class AIPlanningDefaultsTests: XCTestCase {
    func testDefaultPlanningWindowRunsFromNineThirtyToTwentyOneThirty() {
        XCTAssertEqual(AIPlanningDefaults.defaultStart, ClockTime(hour: 9, minute: 30))
        XCTAssertEqual(AIPlanningDefaults.defaultEnd, ClockTime(hour: 21, minute: 30))
        XCTAssertEqual(AIPlanningDefaults.defaultWindow.start, ClockTime(hour: 9, minute: 30))
        XCTAssertEqual(AIPlanningDefaults.defaultWindow.end, ClockTime(hour: 21, minute: 30))
        XCTAssertEqual(AIPlanningDefaults.defaultWindowDescription, "09:30-21:30")
        XCTAssertEqual(AIPlanningDefaults.defaultBreaks.map(\.title), ["午饭", "晚饭"])
        XCTAssertEqual(AIPlanningDefaults.defaultBreaks.map(\.start), [
            ClockTime(hour: 12, minute: 0),
            ClockTime(hour: 18, minute: 0)
        ])
        XCTAssertEqual(AIPlanningDefaults.defaultBreaks.map(\.end), [
            ClockTime(hour: 14, minute: 0),
            ClockTime(hour: 19, minute: 0)
        ])
    }

    func testDefaultScheduleProducesWorkSegmentsAroundBreaks() {
        XCTAssertEqual(AIPlanningDefaults.standard.workSegments, [
            TimeWindow(start: ClockTime(hour: 9, minute: 30), end: ClockTime(hour: 12, minute: 0)),
            TimeWindow(start: ClockTime(hour: 14, minute: 0), end: ClockTime(hour: 18, minute: 0)),
            TimeWindow(start: ClockTime(hour: 19, minute: 0), end: ClockTime(hour: 21, minute: 30))
        ])
    }

    func testCustomScheduleValidationRejectsBreaksOutsideWindow() {
        let schedule = AIPlanningDefaultSchedule(
            start: ClockTime(hour: 10, minute: 0),
            end: ClockTime(hour: 20, minute: 0),
            breaks: [
                AIPlanningDefaultBreak(
                    title: "午饭",
                    start: ClockTime(hour: 9, minute: 0),
                    end: ClockTime(hour: 10, minute: 30)
                )
            ]
        )

        XCTAssertFalse(schedule.isValid)
    }

    func testCustomScheduleValidationRejectsOverlappingBreaks() {
        let schedule = AIPlanningDefaultSchedule(
            start: ClockTime(hour: 9, minute: 30),
            end: ClockTime(hour: 21, minute: 30),
            breaks: [
                AIPlanningDefaultBreak(
                    title: "午饭",
                    start: ClockTime(hour: 12, minute: 0),
                    end: ClockTime(hour: 14, minute: 0)
                ),
                AIPlanningDefaultBreak(
                    title: "晚饭",
                    start: ClockTime(hour: 13, minute: 30),
                    end: ClockTime(hour: 14, minute: 30)
                )
            ]
        )

        XCTAssertFalse(schedule.isValid)
    }
}
