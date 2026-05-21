import Foundation

public enum TaskMerger {
    public static func mergeSameTitleTasks(_ tasks: [Task]) -> [Task] {
        var mergedTasks: [Task] = []
        var indexByTitle: [String: Int] = [:]

        for task in tasks {
            let key = normalizedTitle(task.title)
            guard !key.isEmpty else {
                mergedTasks.append(task)
                continue
            }

            if let existingIndex = indexByTitle[key] {
                mergedTasks[existingIndex] = merge(mergedTasks[existingIndex], with: task)
            } else {
                indexByTitle[key] = mergedTasks.count
                mergedTasks.append(task)
            }
        }

        return mergedTasks
    }

    private static func normalizedTitle(_ title: String) -> String {
        title
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .lowercased()
    }

    private static func merge(_ existing: Task, with duplicate: Task) -> Task {
        let existingWindow = fixedWindow(for: existing)
        let duplicateWindow = fixedWindow(for: duplicate)
        let fixedStart = [existingWindow?.start, duplicateWindow?.start].compactMap { $0 }.min()
        let fixedEnd = [existingWindow?.end, duplicateWindow?.end].compactMap { $0 }.max()

        var duration = max(existing.estimatedDurationMinutes, duplicate.estimatedDurationMinutes)
        if let fixedStart, let fixedEnd {
            duration = max(duration, fixedEnd.minutesSinceMidnight - fixedStart.minutesSinceMidnight)
        }

        return Task(
            id: existing.id,
            title: existing.title,
            notes: mergedNotes(existing.notes, duplicate.notes),
            estimatedDurationMinutes: max(1, duration),
            priority: max(existing.priority, duplicate.priority),
            category: mergedCategory(existing.category, duplicate.category),
            deadline: earliest(existing.deadline, duplicate.deadline),
            earliestStart: fixedStart == nil ? earliest(existing.earliestStart, duplicate.earliestStart) : nil,
            latestEnd: fixedStart == nil ? latest(existing.latestEnd, duplicate.latestEnd) : nil,
            fixedStart: fixedStart,
            canSplit: existing.canSplit || duplicate.canSplit,
            status: mergedStatus(existing.status, duplicate.status),
            privacyLevel: mergedPrivacyLevel(existing.privacyLevel, duplicate.privacyLevel)
        )
    }

    private static func fixedWindow(for task: Task) -> TimeWindow? {
        guard let start = task.fixedStart,
              let end = start.adding(minutes: task.estimatedDurationMinutes),
              start < end
        else { return nil }
        return TimeWindow(start: start, end: end)
    }

    private static func mergedNotes(_ lhs: String, _ rhs: String) -> String {
        let parts = [lhs, rhs]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.reduce(into: [String]()) { uniqueParts, note in
            if !uniqueParts.contains(note) {
                uniqueParts.append(note)
            }
        }
        .joined(separator: "\n")
    }

    private static func mergedCategory(_ lhs: TaskCategory, _ rhs: TaskCategory) -> TaskCategory {
        lhs == .other ? rhs : lhs
    }

    private static func mergedStatus(_ lhs: TaskStatus, _ rhs: TaskStatus) -> TaskStatus {
        if lhs == .done || rhs == .done { return .done }
        if lhs == .active || rhs == .active { return .active }
        if lhs == .skipped || rhs == .skipped { return .skipped }
        if lhs == .delayed || rhs == .delayed { return .delayed }
        if lhs == .interrupted || rhs == .interrupted { return .interrupted }
        return .planned
    }

    private static func mergedPrivacyLevel(_ lhs: TaskPrivacyLevel, _ rhs: TaskPrivacyLevel) -> TaskPrivacyLevel {
        if lhs == .private || rhs == .private { return .private }
        if lhs == .anonymized || rhs == .anonymized { return .anonymized }
        return .aiVisible
    }

    private static func earliest(_ lhs: ClockTime?, _ rhs: ClockTime?) -> ClockTime? {
        switch (lhs, rhs) {
        case let (lhs?, rhs?): return min(lhs, rhs)
        case let (lhs?, nil): return lhs
        case let (nil, rhs?): return rhs
        case (nil, nil): return nil
        }
    }

    private static func latest(_ lhs: ClockTime?, _ rhs: ClockTime?) -> ClockTime? {
        switch (lhs, rhs) {
        case let (lhs?, rhs?): return max(lhs, rhs)
        case let (lhs?, nil): return lhs
        case let (nil, rhs?): return rhs
        case (nil, nil): return nil
        }
    }
}
