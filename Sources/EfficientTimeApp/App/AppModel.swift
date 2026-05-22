import EfficientTimeCore
import AppKit
import Foundation
import SwiftUI
@preconcurrency import UserNotifications

@MainActor
final class AppModel: ObservableObject {
    @Published var selectedDate: LocalDate
    @Published var tasks: [EfficientTimeCore.Task]
    @Published var todayPlan: DayPlan
    @Published var executionLogs: [ExecutionLog]
    @Published var settings: AppSettings
    @Published var selectedBlockID: TimeBlock.ID?
    @Published var isFloatingPanelCompact = false
    @Published var lastErrorMessage: String?
    @Published var now = Date()
    @Published var aiDrafts: [TaskDraft] = []
    @Published var aiQuestions: [String] = []
    @Published var aiStatusMessage = ""
    @Published var isAIPlanning = false
    @Published var reviewAISummary = ""
    @Published var isReviewingWithAI = false
    @Published var pendingConflict: ScheduleConflict?
    @Published var notificationAuthorizationStatus = ""
    @Published var notificationAuthorizationHelp = ""

    private let scheduler = RuleBasedScheduler()
    private let notificationScheduler = NotificationScheduler()
    private let reminderPanelController = ReminderPanelController()
    private let workspaceStore = LocalJSONWorkspaceStore()
    private let secretStore = LocalSecretStore()
    private let delayStepMinutes = 20
    private var dailyWorkspaces: [LocalDate: DailyWorkspace]
    private var floatingPanelController: FloatingPanelController?
    private var clockTask: Swift.Task<Void, Never>?
    private var deliveredRuntimeNotificationIDs: Set<String> = []
    private var openMainWindowAction: (() -> Void)?
    private var didPerformStartupPresentation = false

    init() {
        let date = LocalDate.today()
        let defaultSettings = AppSettings()
        let initial = Self.defaultDailyWorkspace(date: date, withSampleTasks: true, settings: defaultSettings)
        self.selectedDate = date
        self.tasks = initial.tasks
        self.todayPlan = initial.plan
        self.executionLogs = initial.logs
        self.settings = defaultSettings
        self.dailyWorkspaces = [date: initial]
        self.aiStatusMessage = AppLocalization.text("AI 规划待开始。", language: defaultSettings.language)
        self.notificationAuthorizationStatus = AppLocalization.text("未知", language: defaultSettings.language)
        self.notificationAuthorizationHelp = AppLocalization.text("正在读取系统通知权限。", language: defaultSettings.language)

        Swift.Task {
            await loadWorkspaceIfAvailable()
        }
        startClock()
    }

    deinit {
        clockTask?.cancel()
    }

    var selectedDateTitle: String {
        let today = LocalDate.today()
        if selectedDate == today {
            return tr("今天")
        }
        if selectedDate == today.adding(days: 1) {
            return tr("明天")
        }
        return selectedDate.displayString
    }

    var menuBarTitle: String {
        if let currentBlock {
            return currentBlock.title
        }
        if let nextBlock {
            return "\(tr("下一个")) \(nextBlock.start.displayString)"
        }
        return "EfficientTime"
    }

    var currentBlocks: [TimeBlock] {
        guard selectedDate == LocalDate.today() else { return [] }
        let current = Self.clockTime(from: now)
        return visiblePlanBlocks.filter { $0.start <= current && current < $0.end }
    }

    var currentBlock: TimeBlock? {
        currentBlocks.first
    }

    var nextBlock: TimeBlock? {
        let current = selectedDate == LocalDate.today() ? Self.clockTime(from: now) : .startOfDay
        return visiblePlanBlocks.first { $0.start > current }
    }

    var completedCount: Int {
        visiblePlanBlocks.filter { $0.status == .done }.count
    }

    var visiblePlanBlocks: [TimeBlock] {
        todayPlan.blocks.filter { $0.status != .deleted }
    }

    var currentRemainingMinutes: Int? {
        guard let currentBlock else { return nil }
        let current = Self.clockTime(from: now)
        return max(0, currentBlock.end.minutesSinceMidnight - current.minutesSinceMidnight)
    }

    var selectedBlock: TimeBlock? {
        guard let selectedBlockID else { return nil }
        return todayPlan.blocks.first { $0.id == selectedBlockID }
    }

    var timelineActionTargetBlock: TimeBlock? {
        selectedBlock ?? currentBlock
    }

    var availableWindowsText: String {
        todayPlan.availableWindows
            .map { "\($0.start.displayString)-\($0.end.displayString)" }
            .joined(separator: ", ")
    }

    var selectedDateForPicker: Date {
        selectedDate.date()
    }

    var weekSummaries: [DaySummary] {
        let start = selectedDate.startOfWeek()
        return (0..<7).compactMap { offset in
            let date = start.adding(days: offset)
            let workspace = date == selectedDate
                ? DailyWorkspace(tasks: tasks, plan: todayPlan, logs: executionLogs)
                : dailyWorkspaces[date]
            guard let workspace, Self.hasPlanContent(workspace) else { return nil }
            let plan = workspace.plan
            return DaySummary(
                date: date,
                taskCount: plan.blocks.count,
                plannedMinutes: plan.blocks.reduce(0) { $0 + $1.durationMinutes },
                status: plan.status,
                isSelected: date == selectedDate
            )
        }
    }

    var reviewSummary: String {
        let blocks = visiblePlanBlocks
        let done = blocks.filter { $0.status == .done }
        let skipped = blocks.filter { $0.status == .skipped }
        let delayed = blocks.filter { $0.status == .delayed }
        let plannedMinutes = blocks.reduce(0) { $0 + $1.durationMinutes }
        let actualMinutes = blocks.compactMap(actualDurationMinutes(for:)).reduce(0, +)
        return """
        \(trf("%@计划：%d 个时间块，计划 %d 分钟。", selectedDateTitle, blocks.count, plannedMinutes))
        \(trf("已完成：%d 个；已跳过：%d 个；已推迟：%d 个。", done.count, skipped.count, delayed.count))
        \(trf("已记录实际耗时：%d 分钟；执行事件：%d 条。", actualMinutes, executionLogs.count))
        \(trf("状态：%@。", planStatusTitle(todayPlan.status)))
        """
    }

    func showFloatingPanel() {
        if floatingPanelController == nil {
            floatingPanelController = FloatingPanelController()
        }
        floatingPanelController?.show(model: self)
    }

    func registerMainWindowOpener(_ action: @escaping () -> Void) {
        openMainWindowAction = action
    }

    func performStartupPresentation() {
        guard !didPerformStartupPresentation else { return }
        didPerformStartupPresentation = true
        requestNotificationAuthorization()
        showFloatingPanel()
        openMainWindow()
    }

    var notificationRuntimeHelp: String {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "未识别到 Bundle ID"
        let launchHint = Bundle.main.bundleURL.pathExtension == "app"
            ? tr("当前以 .app 方式运行。")
            : tr("当前可能是直接运行可执行文件；建议用 scripts/build_app_bundle.sh 构建后 open dist/EfficientTime.app。")
        return "\(launchHint) \(tr("通知权限对应标识："))\(bundleIdentifier)。"
    }

    func openMainWindow() {
        if bringMainWindowForward() {
            return
        }
        openMainWindowAction?()
        DispatchQueue.main.async { [weak self] in
            _ = self?.bringMainWindowForward()
        }
    }

    func toggleMainWindow() {
        let windows = mainApplicationWindows()
        if windows.contains(where: { $0.isVisible && !$0.isMiniaturized }) {
            windows.forEach { $0.orderOut(nil) }
            return
        }

        if bringMainWindowForward() {
            return
        }
        openMainWindowAction?()
        DispatchQueue.main.async { [weak self] in
            _ = self?.bringMainWindowForward()
        }
    }

    func toggleFloatingPanelSize() {
        isFloatingPanelCompact.toggle()
        floatingPanelController?.setCompact(isFloatingPanelCompact)
    }

    func requestNotificationAuthorization() {
        notificationScheduler.requestAuthorization { [weak self] granted in
            Swift.Task { @MainActor in
                if !granted {
                    self?.refreshNotificationAuthorizationStatus()
                    self?.lastErrorMessage = self?.tr("系统通知权限未开启，请在 macOS 设置里允许 EfficientTime 发送通知。")
                    return
                }
                self?.refreshNotificationAuthorizationStatus()
                self?.scheduleNotifications()
            }
        }
    }

    func refreshNotificationAuthorizationStatus() {
        notificationScheduler.getAuthorizationStatus { [weak self] status in
            Swift.Task { @MainActor in
                self?.updateNotificationAuthorizationStatus(status)
            }
        }
    }

    func scheduleNotifications() {
        notificationScheduler.getAuthorizationStatus { [weak self] status in
            Swift.Task { @MainActor in
                self?.updateNotificationAuthorizationStatus(status)
            }
        }
        var workspaces = dailyWorkspaces
        workspaces[selectedDate] = DailyWorkspace(tasks: tasks, plan: todayPlan, logs: executionLogs)
        let plans = workspaces.values
            .map(\.plan)
            .filter { !$0.blocks.isEmpty }
        notificationScheduler.scheduleNotifications(for: plans, settings: settings)
    }

    func sendTestNotification() {
        reminderPanelController.show(
            title: tr("EfficientTime 测试提醒"),
            body: tr("如果系统通知不可用，这个置顶提醒仍会显示。"),
            kind: .start
        )
        notificationScheduler.deliverNow(
            identifier: "efficienttime-test-\(UUID().uuidString)",
            title: tr("EfficientTime 测试提醒"),
            body: tr("系统通知已触发。")
        ) { [weak self] error in
            Swift.Task { @MainActor in
                self?.refreshNotificationAuthorizationStatus()
                if let error {
                    self?.lastErrorMessage = self?.trf("系统通知发送失败：%@。已显示 EfficientTime 置顶提醒。", error.localizedDescription)
                } else {
                    self?.lastErrorMessage = self?.tr("测试通知已发送；如果没看到横幅，请检查 macOS 通知设置里的 EfficientTime。")
                }
            }
        }
    }

    func selectToday() {
        selectDate(LocalDate.today())
    }

    func selectTomorrow() {
        selectDate(LocalDate.today().adding(days: 1))
    }

    func selectPreviousDay() {
        selectDate(selectedDate.adding(days: -1))
    }

    func selectNextDay() {
        selectDate(selectedDate.adding(days: 1))
    }

    func selectDate(_ date: Date) {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        selectDate(
            LocalDate(
                year: components.year ?? selectedDate.year,
                month: components.month ?? selectedDate.month,
                day: components.day ?? selectedDate.day
            )
        )
    }

    func selectDate(_ date: LocalDate) {
        persistCurrentDailyWorkspace()
        selectedDate = date
        let workspace = dailyWorkspaces[date] ?? Self.defaultDailyWorkspace(date: date, withSampleTasks: false, settings: settings)
        tasks = workspace.tasks
        todayPlan = workspace.plan
        executionLogs = workspace.logs
        selectedBlockID = nil
        reviewAISummary = ""
        saveWorkspace()
    }

    func confirmPlan() {
        todayPlan.status = .ready
        saveWorkspace()
    }

    func startDay() {
        todayPlan.status = .running
        syncActiveBlockStatus()
        scheduleNotifications()
        appendSystemLog(eventType: .started, payload: ["scope": "day"])
        saveWorkspace()
    }

    func finishDay() {
        for index in todayPlan.blocks.indices where todayPlan.blocks[index].status == .active {
            todayPlan.blocks[index].status = .interrupted
            todayPlan.blocks[index].actualEndAt = Date()
            appendSystemLog(eventType: .interrupted, blockId: todayPlan.blocks[index].id)
        }
        todayPlan.status = .finished
        appendSystemLog(eventType: .completed, payload: ["scope": "day"])
        lastErrorMessage = trf("已结束 %@ 的计划。", selectedDateTitle)
        saveWorkspace()
    }

    func clearSelectedDatePlan() {
        clearPlan(on: selectedDate)
    }

    func clearPlan(on date: LocalDate) {
        if date != selectedDate {
            let workspace = dailyWorkspaces[date] ?? Self.defaultDailyWorkspace(date: date, withSampleTasks: false, settings: settings)
            dailyWorkspaces[date] = DailyWorkspace(
                tasks: [],
                plan: DayPlan(
                    date: date,
                    availableWindows: workspace.plan.availableWindows,
                    blocks: [],
                    status: .draft
                ),
                logs: []
            )
            lastErrorMessage = trf("已清空 %@ 的所有任务。", date.displayString)
            saveWorkspace()
            return
        }

        let emptyPlan = DayPlan(
            date: selectedDate,
            availableWindows: todayPlan.availableWindows,
            blocks: [],
            status: .draft
        )
        tasks = []
        todayPlan = emptyPlan
        executionLogs = []
        selectedBlockID = nil
        pendingConflict = nil
        reviewAISummary = ""
        lastErrorMessage = trf("已清空 %@ 的所有任务。", selectedDateTitle)
        saveWorkspace()
    }

    func canClearPlan(on date: LocalDate) -> Bool {
        if date == selectedDate {
            return !tasks.isEmpty || !todayPlan.blocks.isEmpty || !executionLogs.isEmpty
        }
        guard let workspace = dailyWorkspaces[date] else { return false }
        return Self.hasPlanContent(workspace)
    }

    func deletePlan(on date: LocalDate) {
        dailyWorkspaces.removeValue(forKey: date)

        if date == selectedDate {
            if let replacementDate = firstPlannedDateInSelectedWeek(excluding: date),
               let replacementWorkspace = dailyWorkspaces[replacementDate] {
                selectedDate = replacementDate
                tasks = replacementWorkspace.tasks
                todayPlan = replacementWorkspace.plan
                executionLogs = replacementWorkspace.logs
            } else {
                let emptyWorkspace = Self.defaultDailyWorkspace(date: date, withSampleTasks: false, settings: settings)
                tasks = []
                todayPlan = emptyWorkspace.plan
                executionLogs = []
            }
            selectedBlockID = nil
            pendingConflict = nil
            reviewAISummary = ""
        }

        lastErrorMessage = trf("已删除 %@ 的计划。", date.displayString)
        saveWorkspace()
    }

    func canDeletePlan(on date: LocalDate) -> Bool {
        if date == selectedDate {
            return !tasks.isEmpty || !todayPlan.blocks.isEmpty || !executionLogs.isEmpty
        }
        guard let workspace = dailyWorkspaces[date] else { return false }
        return Self.hasPlanContent(workspace)
    }

    func updateAvailableWindows(from text: String) -> Bool {
        do {
            let windows = try parseTimeWindows(text)
            guard !windows.isEmpty else {
                lastErrorMessage = tr("至少需要一个可用时间段。")
                return false
            }
            todayPlan = DayPlan(
                date: selectedDate,
                availableWindows: windows,
                blocks: todayPlan.blocks,
                status: .draft
            )
            rebuildPlanKeepingCompletedBlocks(status: .draft)
            saveWorkspace()
            lastErrorMessage = nil
            return true
        } catch {
            lastErrorMessage = tr("时间段格式需要类似：09:30-21:30。")
            return false
        }
    }

    func addScheduledTask(title: String, startText: String, endText: String) -> Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            lastErrorMessage = tr("任务名称不能为空。")
            return false
        }

        do {
            let defaultStart = settings.aiPlanningDefaults.isValid
                ? settings.aiPlanningDefaults.start
                : AIPlanningDefaults.defaultStart
            let start = try parseClockTimeOrDefault(startText, fallback: defaultStart)
            let end = try parseClockTimeOrDefault(
                endText,
                fallback: start.adding(minutes: 90) ?? (settings.aiPlanningDefaults.isValid ? settings.aiPlanningDefaults.end : AIPlanningDefaults.defaultEnd)
            )
            guard start < end else {
                lastErrorMessage = tr("开始时间必须早于结束时间。")
                return false
            }
            let task = EfficientTimeCore.Task(
                title: trimmedTitle,
                estimatedDurationMinutes: end.minutesSinceMidnight - start.minutesSinceMidnight,
                priority: .medium,
                category: .other,
                fixedStart: start,
                privacyLevel: .anonymized
            )
            let mergedTasks = TaskMerger.mergeSameTitleTasks(tasks + [task])
            let windows = availableWindows(todayPlan.availableWindows, including: mergedTasks)
            tasks = mergedTasks
            rebuildPlanKeepingCompletedBlocks(status: .draft, availableWindows: windows)
            saveWorkspace()
            lastErrorMessage = nil
            pendingConflict = nil
            return true
        } catch {
            lastErrorMessage = tr("时间格式需要是 HH:mm，例如 09:30。")
            return false
        }
    }

    func deleteTasks(at offsets: IndexSet) {
        tasks.remove(atOffsets: offsets)
        rebuildPlanKeepingCompletedBlocks(status: .draft)
        saveWorkspace()
    }

    func selectBlock(_ block: TimeBlock) {
        selectedBlockID = block.id
    }

    func markCurrentDone() {
        guard let currentBlock else { return }
        updateBlock(currentBlock.id, status: .done)
    }

    func markBlockDone(_ id: TimeBlock.ID) {
        selectedBlockID = id
        guard selectedBlock?.status != .deleted else { return }
        updateBlock(id, status: .done)
    }

    func skipBlock(_ id: TimeBlock.ID) {
        guard todayPlan.blocks.first(where: { $0.id == id })?.status != .deleted else { return }
        toggleBlockStatus(id, targetStatus: .skipped)
    }

    func delayBlock(_ id: TimeBlock.ID) {
        guard let block = todayPlan.blocks.first(where: { $0.id == id }) else { return }
        guard block.status != .deleted else { return }
        selectedBlockID = id
        let isCancellingDelay = block.status == .delayed
        let offset = isCancellingDelay ? -delayStepMinutes : delayStepMinutes
        let nextStatus: TimeBlockStatus = isCancellingDelay ? .planned : .delayed
        shiftTimeline(
            from: block.start,
            by: offset,
            targetBlockID: id,
            targetStatus: nextStatus
        )
    }

    func toggleBlockCompletion(_ id: TimeBlock.ID) {
        guard let index = todayPlan.blocks.firstIndex(where: { $0.id == id }) else { return }
        guard todayPlan.blocks[index].status != .deleted else { return }
        let nextStatus: TimeBlockStatus = todayPlan.blocks[index].status == .done ? .planned : .done
        todayPlan.blocks[index].status = nextStatus
        if nextStatus == .done {
            if todayPlan.blocks[index].actualStartAt == nil {
                todayPlan.blocks[index].actualStartAt = Date()
            }
            todayPlan.blocks[index].actualEndAt = Date()
        } else {
            todayPlan.blocks[index].actualStartAt = nil
            todayPlan.blocks[index].actualEndAt = nil
        }
        appendSystemLog(eventType: eventType(for: nextStatus), blockId: id)
        saveWorkspace()
    }

    func skipCurrent() {
        guard let currentBlock else { return }
        skipBlock(currentBlock.id)
    }

    func markTimelineActionTargetDone() {
        guard let target = timelineActionTargetBlock else {
            lastErrorMessage = tr("请先选择一个时间块，或等到当前时间进入某个任务。")
            return
        }
        selectedBlockID = target.id
        updateBlock(target.id, status: .done)
        lastErrorMessage = trf("已完成「%@」。", target.title)
    }

    func skipTimelineActionTarget() {
        guard let target = timelineActionTargetBlock else {
            lastErrorMessage = tr("请先选择一个时间块，或等到当前时间进入某个任务。")
            return
        }
        skipBlock(target.id)
        lastErrorMessage = target.status == .skipped
            ? trf("已取消跳过「%@」。", target.title)
            : trf("已跳过「%@」。", target.title)
    }

    func delayTimelineActionTarget() {
        guard let target = timelineActionTargetBlock else {
            lastErrorMessage = tr("请先选择一个时间块，或等到当前时间进入某个任务。")
            return
        }
        delayBlock(target.id)
    }

    func markSelectedDone() {
        guard let selectedBlockID else { return }
        updateBlock(selectedBlockID, status: .done)
    }

    func skipSelected() {
        guard let selectedBlockID else { return }
        skipBlock(selectedBlockID)
    }

    func delaySelected() {
        guard let selectedBlockID else { return }
        delayBlock(selectedBlockID)
    }

    func deleteSelectedBlock() {
        guard let selectedBlock else { return }
        deleteBlock(selectedBlock.id)
    }

    func deleteBlock(_ id: TimeBlock.ID) {
        guard let index = todayPlan.blocks.firstIndex(where: { $0.id == id }) else { return }
        var block = todayPlan.blocks[index]
        if let taskId = block.taskId {
            tasks.removeAll { $0.id == taskId }
        }
        block.status = .deleted
        block.actualEndAt = Date()
        todayPlan.blocks[index] = block
        selectedBlockID = block.id
        appendSystemLog(eventType: .replanned, blockId: block.id, payload: ["reason": "soft_delete"])
        saveWorkspace()
        lastErrorMessage = trf("已将「%@」移到已删除。", block.title)
    }

    func clearDeletedBlocks() {
        let deletedBlocks = todayPlan.blocks.filter { $0.status == .deleted }
        guard !deletedBlocks.isEmpty else {
            lastErrorMessage = tr("当前没有需要清理的已删除事项。")
            return
        }
        let deletedIDs = Set(deletedBlocks.map(\.id))
        todayPlan.blocks.removeAll { deletedIDs.contains($0.id) }
        if let selectedBlockID, deletedIDs.contains(selectedBlockID) {
            self.selectedBlockID = nil
        }
        appendSystemLog(eventType: .replanned, blockId: deletedBlocks.first?.id, payload: ["reason": "clear_deleted", "count": "\(deletedBlocks.count)"])
        saveWorkspace()
        lastErrorMessage = trf("已彻底清理 %d 个已删除事项。", deletedBlocks.count)
    }

    func updateSelectedBlock(startText: String, endText: String) -> Bool {
        guard let selectedBlockID,
              let blockIndex = todayPlan.blocks.firstIndex(where: { $0.id == selectedBlockID })
        else {
            lastErrorMessage = tr("请先选择一个时间块。")
            return false
        }
        guard todayPlan.blocks[blockIndex].status != .deleted else {
            lastErrorMessage = tr("已删除事项不能更新时间；可以先从已删除中清理。")
            return false
        }

        do {
            let start = try ClockTime(parsing: startText)
            let end = try ClockTime(parsing: endText)
            guard start < end else {
                lastErrorMessage = tr("开始时间必须早于结束时间。")
                return false
            }

            var editedBlock = todayPlan.blocks[blockIndex]
            editedBlock.start = start
            editedBlock.end = end

            guard todayPlan.availableWindows.contains(where: { $0.contains(editedBlock) }) else {
                lastErrorMessage = tr("时间块必须落在可用时间段内。")
                return false
            }
            todayPlan.blocks[blockIndex] = editedBlock
            todayPlan.blocks.sort { $0.start < $1.start }
            if let taskId = editedBlock.taskId,
               let taskIndex = tasks.firstIndex(where: { $0.id == taskId }) {
                tasks[taskIndex].fixedStart = start
                tasks[taskIndex].estimatedDurationMinutes = editedBlock.durationMinutes
                tasks[taskIndex].earliestStart = nil
                tasks[taskIndex].latestEnd = nil
            }
            todayPlan.status = .draft
            appendSystemLog(eventType: .replanned, blockId: editedBlock.id)
            saveWorkspace()
            lastErrorMessage = nil
            pendingConflict = nil
            return true
        } catch {
            lastErrorMessage = tr("时间格式需要是 HH:mm，例如 09:30。")
            return false
        }
    }

    func clearPendingConflict() {
        pendingConflict = nil
        lastErrorMessage = nil
    }

    func selectPendingConflictBlock() {
        guard let conflict = pendingConflict else { return }
        selectedBlockID = conflict.conflictingBlock.id
        pendingConflict = nil
        lastErrorMessage = trf("已选中冲突事项「%@」，可以在右侧修改它的时间。", conflict.conflictingBlock.title)
    }

    func applyPendingConflictSuggestionToSelectedBlock() -> Bool {
        guard let conflict = pendingConflict,
              let editedBlockID = conflict.editedBlockID,
              selectedBlockID == editedBlockID,
              let suggestedStart = conflict.suggestedStart,
              let suggestedEnd = conflict.suggestedEnd
        else {
            lastErrorMessage = tr("当前冲突没有可直接采用的建议时间。")
            return false
        }

        pendingConflict = nil
        return updateSelectedBlock(
            startText: suggestedStart.displayString,
            endText: suggestedEnd.displayString
        )
    }

    func replan() {
        rebuildPlanKeepingCompletedBlocks(status: .draft)
        appendSystemLog(eventType: .replanned, payload: ["reason": "手动重新规划"])
        saveWorkspace()
    }

    func applyTaskDrafts(_ drafts: [TaskDraft]) -> Bool {
        let targetTasks = TaskMerger.mergeSameTitleTasks(drafts.map { $0.makeTask(privacyLevel: .anonymized) })
        let windows = availableWindows(todayPlan.availableWindows, including: drafts)
        let result = scheduler.makePlan(
            request: ScheduleRequest(
                date: selectedDate,
                availableWindows: windows,
                tasks: targetTasks
            )
        )
        guard validateDraftApplication(result: result, expectedTaskCount: targetTasks.count, targetDateTitle: selectedDateTitle) else {
            return false
        }

        tasks = targetTasks
        todayPlan = DayPlan(
            date: selectedDate,
            availableWindows: windows,
            blocks: result.plan.blocks,
            status: .draft
        )
        executionLogs = []
        selectedBlockID = nil
        pendingConflict = nil
        appendSystemLog(eventType: .replanned, payload: ["reason": "应用 AI 草稿"])
        lastErrorMessage = trf("已将 AI 草稿应用到 %@。", selectedDateTitle)
        saveWorkspace()
        return true
    }

    func applyTaskDrafts(_ drafts: [TaskDraft], to date: LocalDate) -> Bool {
        if date == selectedDate {
            return applyTaskDrafts(drafts)
        }

        let workspace = dailyWorkspaces[date] ?? Self.defaultDailyWorkspace(date: date, withSampleTasks: false, settings: settings)
        let targetTasks = TaskMerger.mergeSameTitleTasks(drafts.map { $0.makeTask(privacyLevel: .anonymized) })
        let windows = availableWindows(workspace.plan.availableWindows, including: drafts)
        let result = scheduler.makePlan(
            request: ScheduleRequest(
                date: date,
                availableWindows: windows,
                tasks: targetTasks
            )
        )
        guard validateDraftApplication(result: result, expectedTaskCount: targetTasks.count, targetDateTitle: date.displayString) else {
            return false
        }

        let logs = [
            ExecutionLog(
                blockId: result.plan.blocks.first?.id ?? UUID(),
                eventType: .replanned,
                payload: ["reason": "应用 AI 草稿"]
            )
        ]
        dailyWorkspaces[date] = DailyWorkspace(
            tasks: targetTasks,
            plan: DayPlan(
                date: date,
                availableWindows: windows,
                blocks: result.plan.blocks,
                status: .draft
            ),
            logs: logs
        )
        lastErrorMessage = trf("已将 AI 草稿应用到 %@。", date.displayString)
        saveWorkspace()
        return true
    }

    private func validateDraftApplication(
        result: ScheduleResult,
        expectedTaskCount: Int,
        targetDateTitle: String
    ) -> Bool {
        let scheduledCount = result.plan.blocks.count
        guard result.unscheduledTasks.isEmpty,
              scheduledCount == expectedTaskCount,
              result.issues.isEmpty
        else {
            let firstIssue = result.issues.first?.message.replacingOccurrences(of: "`", with: "")
            let hint = firstIssue.map { trf("主要原因：%@", $0) }
                ?? tr("请调整草稿时间，保证任务都在规划范围内。")
            lastErrorMessage = trf("未应用到%@：%d 个任务中只有 %d 个能排进时间表。%@", targetDateTitle, expectedTaskCount, scheduledCount, hint)
            return false
        }
        return true
    }

    func loadSavedDeepSeekAPIKey() -> String {
        (try? secretStore.read(account: "deepseek-api-key")) ?? ""
    }

    func loadSavedArkAPIKey() -> String {
        (try? secretStore.read(account: "ark-api-key")) ?? ""
    }

    func loadSavedOpenAIAPIKey() -> String {
        (try? secretStore.read(account: "openai-api-key")) ?? ""
    }

    func loadSavedGeminiAPIKey() -> String {
        (try? secretStore.read(account: "gemini-api-key")) ?? ""
    }

    func loadSavedClaudeAPIKey() -> String {
        (try? secretStore.read(account: "claude-api-key")) ?? ""
    }

    func saveDeepSeekAPIKey(_ key: String) -> Bool {
        saveAPIKey(key, account: "deepseek-api-key")
    }

    func saveArkAPIKey(_ key: String) -> Bool {
        saveAPIKey(key, account: "ark-api-key")
    }

    func saveOpenAIAPIKey(_ key: String) -> Bool {
        saveAPIKey(key, account: "openai-api-key")
    }

    func saveGeminiAPIKey(_ key: String) -> Bool {
        saveAPIKey(key, account: "gemini-api-key")
    }

    func saveClaudeAPIKey(_ key: String) -> Bool {
        saveAPIKey(key, account: "claude-api-key")
    }

    private func saveAPIKey(_ key: String, account: String) -> Bool {
        do {
            let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                try secretStore.delete(account: account)
            } else {
                try secretStore.save(trimmed, account: account)
            }
            lastErrorMessage = nil
            return true
        } catch {
            lastErrorMessage = trf("保存 API Key 失败：%@", error.localizedDescription)
            return false
        }
    }

    func saveSettings() {
        settings.aiPlanningDefaults = AppSettings.normalizedPlanningDefaults(settings.aiPlanningDefaults)
        if settings.deepSeekModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            settings.deepSeekModel == AppSettings.legacyDefaultDeepSeekModel {
            settings.deepSeekModel = AppSettings.defaultDeepSeekModel
        }
        settings.arkModel = AppSettings.normalizedModel(settings.arkModel, defaultValue: AppSettings.defaultArkModel)
        settings.openAIModel = AppSettings.normalizedModel(settings.openAIModel, defaultValue: AppSettings.defaultOpenAIModel)
        settings.geminiModel = AppSettings.normalizedModel(settings.geminiModel, defaultValue: AppSettings.defaultGeminiModel)
        settings.claudeModel = AppSettings.normalizedModel(settings.claudeModel, defaultValue: AppSettings.defaultClaudeModel)
        settings.floatingPreviousCount = min(max(settings.floatingPreviousCount, 0), 8)
        settings.floatingNextCount = min(max(settings.floatingNextCount, 0), 8)
        settings.floatingPanelOpacity = min(max(settings.floatingPanelOpacity, 0.0), 1.0)
        settings.advanceReminderMinutes = min(max(settings.advanceReminderMinutes, 0), 60)
        if aiDrafts.isEmpty && !isAIPlanning {
            aiStatusMessage = tr("AI 规划待开始。")
        }
        refreshNotificationAuthorizationStatus()
        saveWorkspace()
        scheduleNotifications()
    }

    func runMockAIPlanning(input: String) {
        isAIPlanning = true
        aiStatusMessage = tr("正在使用本地 mock 拆分任务...")
        Swift.Task {
            await runAIPlanning(input: input, service: MockPlanningService())
        }
    }

    func runDeepSeekAIPlanning(input: String) {
        settings.aiProvider = .deepSeek
        runConfiguredAIPlanning(input: input)
    }

    func runConfiguredAIPlanning(input: String) {
        guard let (service, providerTitle) = configuredAIPlanningService() else { return }
        isAIPlanning = true
        aiStatusMessage = trf("正在调用 %@ 生成规划建议，请求已发送...", providerTitle)
        Swift.Task {
            await runAIPlanning(input: input, service: service, providerTitle: providerTitle, effort: settings.deepSeekEffort)
        }
    }

    func runDeepSeekReview() {
        settings.aiProvider = .deepSeek
        runConfiguredAIReview()
    }

    func runConfiguredAIReview() {
        guard let (service, _) = configuredAIPlanningService() else { return }
        isReviewingWithAI = true
        Swift.Task {
            do {
                let summary = try await service.summarizeDay(
                    plan: todayPlan,
                    logs: executionLogs,
                    outputLanguage: settings.language.aiInstructionName
                )
                reviewAISummary = summary
                isReviewingWithAI = false
            } catch {
                lastErrorMessage = self.trf("AI 复盘失败：%@", error.localizedDescription)
                isReviewingWithAI = false
            }
        }
    }

    private func configuredAIPlanningService() -> ((any AIPlanningService), String)? {
        let providerTitle = settings.aiProvider.localizedTitle(effectiveLanguage)
        let apiKey: String
        let service: any AIPlanningService

        switch settings.aiProvider {
        case .deepSeek:
            apiKey = loadSavedDeepSeekAPIKey()
            service = DeepSeekPlanningService(
                configuration: DeepSeekConfiguration(apiKey: apiKey, model: settings.deepSeekModel)
            )
        case .ark:
            apiKey = loadSavedArkAPIKey()
            service = ArkPlanningService(
                configuration: ArkConfiguration(apiKey: apiKey, model: settings.arkModel)
            )
        case .openAI:
            apiKey = loadSavedOpenAIAPIKey()
            service = OpenAIPlanningService(
                configuration: OpenAIConfiguration(apiKey: apiKey, model: settings.openAIModel)
            )
        case .gemini:
            apiKey = loadSavedGeminiAPIKey()
            service = GeminiPlanningService(
                configuration: GeminiConfiguration(apiKey: apiKey, model: settings.geminiModel)
            )
        case .claude:
            apiKey = loadSavedClaudeAPIKey()
            service = ClaudePlanningService(
                configuration: ClaudeConfiguration(apiKey: apiKey, model: settings.claudeModel)
            )
        }

        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            lastErrorMessage = trf("请先到设置中配置 %@ API Key。", providerTitle)
            return nil
        }

        return (service, providerTitle)
    }

    func resetDemoPlan() {
        let workspace = Self.defaultDailyWorkspace(date: selectedDate, withSampleTasks: true, settings: settings)
        tasks = workspace.tasks
        todayPlan = workspace.plan
        executionLogs = []
        selectedBlockID = nil
        saveWorkspace()
    }

    func copyCurrentPlanToTomorrow() {
        copyCurrentPlan(to: selectedDate.adding(days: 1))
    }

    func copyCurrentPlan(to targetDate: LocalDate) {
        guard targetDate != selectedDate else { return }
        let copiedTasks = tasks.map { task in
            EfficientTimeCore.Task(
                title: task.title,
                notes: task.notes,
                estimatedDurationMinutes: task.estimatedDurationMinutes,
                priority: task.priority,
                category: task.category,
                deadline: task.deadline,
                earliestStart: task.earliestStart,
                latestEnd: task.latestEnd,
                fixedStart: task.fixedStart,
                canSplit: task.canSplit,
                privacyLevel: task.privacyLevel
            )
        }
        let result = scheduler.makePlan(
            request: ScheduleRequest(
                date: targetDate,
                availableWindows: todayPlan.availableWindows,
                tasks: copiedTasks
            )
        )
        dailyWorkspaces[targetDate] = DailyWorkspace(
            tasks: copiedTasks,
            plan: result.plan,
            logs: []
        )
        saveWorkspace()
        lastErrorMessage = trf("已复制到 %@。", targetDate.displayString)
    }

    func nearbyBlocksForFloatingPanel() -> [TimeBlock] {
        let blocks = visiblePlanBlocks.sorted { $0.start < $1.start }
        guard !blocks.isEmpty else { return [] }

        let centerIndex: Int
        if let currentBlock, let index = blocks.firstIndex(where: { $0.id == currentBlock.id }) {
            centerIndex = index
        } else if let nextBlock, let index = blocks.firstIndex(where: { $0.id == nextBlock.id }) {
            centerIndex = index
        } else {
            centerIndex = max(0, blocks.count - 1)
        }

        let start = max(0, centerIndex - settings.floatingPreviousCount)
        let end = min(blocks.count - 1, centerIndex + settings.floatingNextCount)
        return Array(blocks[start...end])
    }

    func actualDurationMinutes(for block: TimeBlock) -> Int? {
        guard let actualStartAt = block.actualStartAt,
              let actualEndAt = block.actualEndAt
        else { return nil }
        return max(0, Int(actualEndAt.timeIntervalSince(actualStartAt) / 60))
    }

    private func runAIPlanning(
        input: String,
        service: any AIPlanningService,
        providerTitle: String = "AI",
        effort: PlanningEffort = .normal
    ) async {
        let startedAt = Date()
        do {
            let context = PlanningContext(
                date: selectedDate,
                availableWindows: todayPlan.availableWindows,
                tasks: [],
                rawUserInput: "",
                effort: effort,
                defaultSchedule: settings.aiPlanningDefaults
            )
            let drafts = try await service.extractTasks(from: input, context: context)
            let elapsed = Date().timeIntervalSince(startedAt)
            aiDrafts = drafts
            aiQuestions = []
            aiStatusMessage = trf("%@ 已生成 %d 个规划建议，用时 %@。", providerTitle, drafts.count, localizedDurationText(elapsed))
            isAIPlanning = false
        } catch {
            let elapsed = Date().timeIntervalSince(startedAt)
            aiStatusMessage = tr("AI 规划失败。")
            lastErrorMessage = trf("AI 规划失败，用时 %@：%@", localizedDurationText(elapsed), error.localizedDescription)
            isAIPlanning = false
        }
    }

    private func updateBlock(_ id: TimeBlock.ID, status: TimeBlockStatus) {
        guard let index = todayPlan.blocks.firstIndex(where: { $0.id == id }) else { return }
        todayPlan.blocks[index].status = status
        if status == .done {
            if todayPlan.blocks[index].actualStartAt == nil {
                todayPlan.blocks[index].actualStartAt = Date()
            }
            todayPlan.blocks[index].actualEndAt = Date()
        } else if status == .active {
            todayPlan.blocks[index].actualStartAt = Date()
        } else if status == .skipped || status == .interrupted {
            todayPlan.blocks[index].actualEndAt = Date()
        } else if status == .planned {
            todayPlan.blocks[index].actualStartAt = nil
            todayPlan.blocks[index].actualEndAt = nil
        }
        appendSystemLog(eventType: eventType(for: status), blockId: id)
        saveWorkspace()
    }

    @discardableResult
    private func bringMainWindowForward() -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        guard let window = mainApplicationWindows().first else { return false }
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.makeKeyAndOrderFront(nil)
        return true
    }

    private func mainApplicationWindows() -> [NSWindow] {
        NSApp.windows.filter { window in
            !(window is NSPanel)
                && window.canBecomeKey
                && window.title == "EfficientTime"
        }
    }

    private func toggleBlockStatus(_ id: TimeBlock.ID, targetStatus: TimeBlockStatus) {
        guard let block = todayPlan.blocks.first(where: { $0.id == id }) else { return }
        selectedBlockID = id
        let nextStatus: TimeBlockStatus = block.status == targetStatus ? .planned : targetStatus
        updateBlock(id, status: nextStatus)
    }

    private func shiftTimeline(
        from anchorStart: ClockTime,
        by offsetMinutes: Int,
        targetBlockID: TimeBlock.ID,
        targetStatus: TimeBlockStatus
    ) {
        let affectedIndices = todayPlan.blocks.indices.filter { index in
            let block = todayPlan.blocks[index]
            return block.id == targetBlockID ||
                (block.start >= anchorStart && block.status != .done && block.status != .skipped && block.status != .deleted)
        }
        guard !affectedIndices.isEmpty else { return }

        var shiftedBlocks: [TimeBlock] = []
        for index in affectedIndices {
            var block = todayPlan.blocks[index]
            guard let shiftedStart = block.start.adding(minutes: offsetMinutes),
                  let shiftedEnd = block.end.adding(minutes: offsetMinutes),
                  shiftedStart < shiftedEnd
            else {
                lastErrorMessage = offsetMinutes > 0
                    ? "推迟后会超过当天 24:00，无法整体顺延。"
                    : "取消推迟后会早于当天 00:00，无法整体回退。"
                return
            }
            block.start = shiftedStart
            block.end = shiftedEnd
            if block.id == targetBlockID {
                block.status = targetStatus
                if targetStatus == .planned {
                    block.actualStartAt = nil
                    block.actualEndAt = nil
                }
            }
            shiftedBlocks.append(block)
        }

        for block in shiftedBlocks {
            guard let index = todayPlan.blocks.firstIndex(where: { $0.id == block.id }) else { continue }
            todayPlan.blocks[index] = block
            syncTaskTime(with: block)
        }
        todayPlan.blocks.sort { lhs, rhs in
            if lhs.start != rhs.start {
                return lhs.start < rhs.start
            }
            return lhs.end < rhs.end
        }
        todayPlan.availableWindows = availableWindows(todayPlan.availableWindows, including: visiblePlanBlocks)
        appendSystemLog(
            eventType: eventType(for: targetStatus),
            blockId: targetBlockID,
            payload: [
                "offsetMinutes": "\(offsetMinutes)",
                "affectedBlocks": "\(shiftedBlocks.count)"
            ]
        )
        saveWorkspace()
        lastErrorMessage = targetStatus == .delayed
            ? "已将「\(shiftedBlocks.first(where: { $0.id == targetBlockID })?.title ?? "任务")」及后续任务整体顺延 \(delayStepMinutes) 分钟。"
            : "已取消推迟，并将「\(shiftedBlocks.first(where: { $0.id == targetBlockID })?.title ?? "任务")」及后续任务整体回退 \(delayStepMinutes) 分钟。"
    }

    private func syncTaskTime(with block: TimeBlock) {
        guard let taskId = block.taskId,
              let taskIndex = tasks.firstIndex(where: { $0.id == taskId })
        else { return }
        tasks[taskIndex].fixedStart = block.start
        tasks[taskIndex].estimatedDurationMinutes = block.durationMinutes
        tasks[taskIndex].earliestStart = nil
        tasks[taskIndex].latestEnd = nil
    }

    private func rebuildPlanKeepingCompletedBlocks(
        status: DayPlanStatus = .ready,
        availableWindows: [TimeWindow]? = nil
    ) {
        let windows = availableWindows ?? todayPlan.availableWindows
        let completedByTaskId = Dictionary(
            uniqueKeysWithValues: todayPlan.blocks.compactMap { block -> (EfficientTimeCore.Task.ID, TimeBlock)? in
                guard block.status == .done || block.status == .skipped,
                      let taskId = block.taskId
                else { return nil }
                return (taskId, block)
            }
        )
        let schedulableTasks = tasks.filter { completedByTaskId[$0.id] == nil }
        let result = scheduler.makePlan(
            request: ScheduleRequest(
                date: selectedDate,
                availableWindows: windows,
                tasks: schedulableTasks
            )
        )
        var blocks = Array(completedByTaskId.values) + result.plan.blocks
        blocks.sort { $0.start < $1.start }
        todayPlan = DayPlan(
            date: selectedDate,
            availableWindows: windows,
            blocks: blocks,
            status: status
        )
    }

    private func saveWorkspace() {
        persistCurrentDailyWorkspace()
        let workspace = AppWorkspace(
            selectedDate: selectedDate,
            dailyWorkspaces: dailyWorkspaces,
            settings: settings
        )
        Swift.Task {
            do {
                try await workspaceStore.save(workspace: workspace)
            } catch {
                await MainActor.run {
                    self.lastErrorMessage = "保存失败：\(error.localizedDescription)"
                }
            }
        }
        scheduleNotifications()
    }

    private func loadWorkspaceIfAvailable() async {
        do {
            guard let workspace = try await workspaceStore.load() else { return }
            dailyWorkspaces = workspace.dailyWorkspaces
            settings = workspace.settings
            selectedDate = workspace.selectedDate
            let current = dailyWorkspaces[selectedDate] ?? Self.defaultDailyWorkspace(date: selectedDate, withSampleTasks: false, settings: settings)
            tasks = current.tasks
            todayPlan = current.plan
            executionLogs = current.logs
            let repairedWindows = availableWindows(todayPlan.availableWindows, including: tasks)
            if repairedWindows != todayPlan.availableWindows {
                rebuildPlanKeepingCompletedBlocks(status: todayPlan.status, availableWindows: repairedWindows)
                lastErrorMessage = "已根据固定时间任务扩展可用时间段，恢复超出旧时间窗的计划。"
                saveWorkspace()
            }
            scheduleNotifications()
        } catch {
            lastErrorMessage = "加载本地计划失败，已使用默认示例。"
        }
    }

    private func persistCurrentDailyWorkspace() {
        dailyWorkspaces[selectedDate] = DailyWorkspace(
            tasks: tasks,
            plan: todayPlan,
            logs: executionLogs
        )
    }

    private func availableWindows(_ existingWindows: [TimeWindow], including drafts: [TaskDraft]) -> [TimeWindow] {
        let draftWindows = drafts.compactMap { draft -> TimeWindow? in
            guard let start = draft.fixedStart,
                  let end = start.adding(minutes: max(5, draft.estimatedDurationMinutes)),
                  start < end
            else { return nil }
            return TimeWindow(start: start, end: end)
        }

        guard let firstStart = draftWindows.map(\.start).min(),
              let lastEnd = draftWindows.map(\.end).max()
        else {
            return existingWindows
        }

        let extraWindow = TimeWindow(start: firstStart, end: lastEnd)
        return Self.mergedWindows(existingWindows + [extraWindow])
    }

    private func availableWindows(_ existingWindows: [TimeWindow], including fixedTasks: [EfficientTimeCore.Task]) -> [TimeWindow] {
        let taskWindows = fixedTasks.compactMap { task -> TimeWindow? in
            guard let start = task.fixedStart,
                  let end = start.adding(minutes: max(5, task.estimatedDurationMinutes)),
                  start < end
            else { return nil }
            return TimeWindow(start: start, end: end)
        }

        guard let firstStart = taskWindows.map(\.start).min(),
              let lastEnd = taskWindows.map(\.end).max()
        else {
            return existingWindows
        }

        let extraWindow = TimeWindow(start: firstStart, end: lastEnd)
        return Self.mergedWindows(existingWindows + [extraWindow])
    }

    private func availableWindows(_ existingWindows: [TimeWindow], including blocks: [TimeBlock]) -> [TimeWindow] {
        let blockWindows = blocks.map { TimeWindow(start: $0.start, end: $0.end) }
        guard let firstStart = blockWindows.map(\.start).min(),
              let lastEnd = blockWindows.map(\.end).max()
        else {
            return existingWindows
        }

        let extraWindow = TimeWindow(start: firstStart, end: lastEnd)
        return Self.mergedWindows(existingWindows + [extraWindow])
    }

    private static func mergedWindows(_ windows: [TimeWindow]) -> [TimeWindow] {
        let sortedWindows = windows.sorted { $0.start < $1.start }
        guard var current = sortedWindows.first else { return [] }

        var merged: [TimeWindow] = []
        for window in sortedWindows.dropFirst() {
            if window.start <= current.end {
                current = TimeWindow(start: current.start, end: max(current.end, window.end))
            } else {
                merged.append(current)
                current = window
            }
        }
        merged.append(current)
        return merged
    }

    private func firstPlannedDateInSelectedWeek(excluding excludedDate: LocalDate) -> LocalDate? {
        let start = selectedDate.startOfWeek()
        return (0..<7)
            .map { start.adding(days: $0) }
            .first { date in
                guard date != excludedDate,
                      let workspace = dailyWorkspaces[date]
                else { return false }
                return Self.hasPlanContent(workspace)
            }
    }

    private func parseTimeWindows(_ value: String) throws -> [TimeWindow] {
        try value
            .split(separator: ",")
            .map { segment in
                let parts = segment.split(separator: "-")
                guard parts.count == 2 else {
                    throw ClockTimeParseError.invalidFormat(String(segment))
                }
                let start = try ClockTime(parsing: String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines))
                let end = try ClockTime(parsing: String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines))
                return TimeWindow(start: start, end: end)
            }
            .sorted { $0.start < $1.start }
    }

    private func parseClockTimeOrDefault(_ value: String, fallback: ClockTime) throws -> ClockTime {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallback }
        return try ClockTime(parsing: trimmed)
    }

    private func firstConflict(for block: TimeBlock, excluding excludedID: TimeBlock.ID? = nil) -> TimeBlock? {
        todayPlan.blocks.first {
            $0.id != excludedID && $0.status != .deleted && $0.overlaps(block)
        }
    }

    private func suggestedAvailableSlot(
        for block: TimeBlock,
        excluding excludedID: TimeBlock.ID? = nil
    ) -> TimeWindow? {
        firstAvailableSlot(
            durationMinutes: block.durationMinutes,
            preferredStart: block.start,
            excluding: excludedID
        ) ?? firstAvailableSlot(
            durationMinutes: block.durationMinutes,
            preferredStart: nil,
            excluding: excludedID
        )
    }

    private func firstAvailableSlot(
        durationMinutes: Int,
        preferredStart: ClockTime?,
        excluding excludedID: TimeBlock.ID?
    ) -> TimeWindow? {
        guard durationMinutes > 0 else { return nil }
        let busyBlocks = todayPlan.blocks
            .filter { $0.id != excludedID && $0.status != .deleted }
            .sorted { $0.start < $1.start }

        for window in todayPlan.availableWindows {
            var cursor = max(window.start, preferredStart ?? window.start)
            guard cursor < window.end else { continue }

            for busy in busyBlocks {
                if busy.end <= cursor { continue }
                if busy.start >= window.end { break }

                let gapEnd = min(busy.start, window.end)
                if let end = cursor.adding(minutes: durationMinutes),
                   end <= gapEnd {
                    return TimeWindow(start: cursor, end: end)
                }

                cursor = max(cursor, busy.end)
                if cursor >= window.end { break }
            }

            if let end = cursor.adding(minutes: durationMinutes),
               end <= window.end {
                return TimeWindow(start: cursor, end: end)
            }
        }

        return nil
    }

    private func conflictMessage(
        start: ClockTime,
        end: ClockTime,
        conflictingTitle: String,
        suggestion: TimeWindow?
    ) -> String {
        let base = "时间冲突：\(start.displayString)-\(end.displayString) 与「\(conflictingTitle)」重叠。"
        guard let suggestion else {
            return base + " 当前可用时间段内没有找到同等时长的连续空档。"
        }
        return base + " 建议改到 \(suggestion.start.displayString)-\(suggestion.end.displayString)。"
    }

    private func updateNotificationAuthorizationStatus(_ status: UNAuthorizationStatus) {
        switch status {
        case .notDetermined:
            notificationAuthorizationStatus = tr("未申请")
            notificationAuthorizationHelp = tr("点击“申请系统通知权限”，macOS 会弹出授权确认。")
        case .denied:
            notificationAuthorizationStatus = tr("已拒绝")
            notificationAuthorizationHelp = tr("请到 macOS 系统设置 > 通知 > EfficientTime，允许通知、横幅和声音。")
        case .authorized:
            notificationAuthorizationStatus = tr("已允许")
            notificationAuthorizationHelp = tr("系统通知已开启；如果看不到横幅，请检查专注模式和通知样式。")
        case .provisional:
            notificationAuthorizationStatus = tr("临时允许")
            notificationAuthorizationHelp = tr("系统允许静默通知；建议在 macOS 通知设置里改为允许横幅。")
        default:
            notificationAuthorizationStatus = tr("未知")
            notificationAuthorizationHelp = tr("macOS 返回了未识别的通知状态，请尝试重新申请权限或从 .app 启动。")
        }
    }

    private func startClock() {
        clockTask = Swift.Task { [weak self] in
            while !Swift.Task.isCancelled {
                await MainActor.run {
                    self?.now = Date()
                    self?.syncActiveBlockStatus()
                    self?.deliverRuntimeTaskNotifications()
                }
                try? await Swift.Task.sleep(for: .seconds(1))
            }
        }
    }

    private func deliverRuntimeTaskNotifications() {
        let today = LocalDate.today()
        let workspace = today == selectedDate
            ? DailyWorkspace(tasks: tasks, plan: todayPlan, logs: executionLogs)
            : dailyWorkspaces[today]
        guard let plan = workspace?.plan,
              plan.status != .finished,
              plan.status != .archived
        else { return }

        for block in plan.blocks {
            guard block.status != .done,
                  block.status != .skipped,
                  block.status != .delayed
            else { continue }

            if settings.startNotificationsEnabled,
               isWithinNotificationGraceWindow(date: plan.date, time: block.start) {
                deliverRuntimeTaskNotification(
                    id: "runtime-start-\(plan.date.displayString)-\(block.id.uuidString)",
                    date: plan.date,
                    blockId: block.id,
                    kind: tr("开始提醒"),
                    panelKind: .start,
                    title: trf("开始：%@", block.title),
                    body: trf("当前任务开始了，%@-%@", block.start.displayString, block.end.displayString)
                )
            }

            if settings.endNotificationsEnabled,
               isWithinNotificationGraceWindow(date: plan.date, time: block.end) {
                deliverRuntimeTaskNotification(
                    id: "runtime-end-\(plan.date.displayString)-\(block.id.uuidString)",
                    date: plan.date,
                    blockId: block.id,
                    kind: tr("结束提醒"),
                    panelKind: .end,
                    title: trf("结束：%@", block.title),
                    body: tr("当前任务到结束时间了，请标记完成或跳过")
                )
            }
        }
    }

    private func deliverRuntimeTaskNotification(
        id: String,
        date: LocalDate,
        blockId: TimeBlock.ID,
        kind: String,
        panelKind: ReminderPanelKind,
        title: String,
        body: String
    ) {
        guard !deliveredRuntimeNotificationIDs.contains(id) else { return }
        deliveredRuntimeNotificationIDs.insert(id)
        reminderPanelController.show(title: title, body: body, kind: panelKind)
        appendNotificationLog(date: date, blockId: blockId, kind: kind)
        notificationScheduler.deliverNow(
            identifier: "efficienttime-\(id)",
            title: title,
            body: body
        ) { [weak self] error in
            guard let error else { return }
            Swift.Task { @MainActor in
                self?.lastErrorMessage = self?.trf("系统通知发送失败：%@。已显示 EfficientTime 置顶提醒。", error.localizedDescription)
            }
        }
        saveWorkspace()
    }

    private func appendNotificationLog(date: LocalDate, blockId: TimeBlock.ID, kind: String) {
        let log = ExecutionLog(
            blockId: blockId,
            eventType: .notified,
            payload: ["kind": kind, "source": "runtime-notification"]
        )
        if date == selectedDate {
            executionLogs.append(log)
        } else if var workspace = dailyWorkspaces[date] {
            workspace.logs.append(log)
            dailyWorkspaces[date] = workspace
        }
    }

    private func isWithinNotificationGraceWindow(date localDate: LocalDate, time: ClockTime) -> Bool {
        guard let targetDate = date(on: localDate, at: time) else { return false }
        let elapsed = now.timeIntervalSince(targetDate)
        return elapsed >= 0 && elapsed <= 180
    }

    private func date(on localDate: LocalDate, at time: ClockTime) -> Date? {
        var components = DateComponents()
        components.year = localDate.year
        components.month = localDate.month
        components.day = localDate.day
        components.hour = time.hour
        components.minute = time.minute
        components.second = 0
        return Calendar.current.date(from: components)
    }

    private func syncActiveBlockStatus() {
        guard selectedDate == LocalDate.today(), todayPlan.status == .running else { return }
        let activeIDs = Set(currentBlocks.map(\.id))
        var didChange = false
        for index in todayPlan.blocks.indices {
            if activeIDs.contains(todayPlan.blocks[index].id),
               todayPlan.blocks[index].status == .planned {
                todayPlan.blocks[index].status = .active
                todayPlan.blocks[index].actualStartAt = Date()
                appendSystemLog(eventType: .started, blockId: todayPlan.blocks[index].id)
                didChange = true
            } else if todayPlan.blocks[index].status == .active,
                      !activeIDs.contains(todayPlan.blocks[index].id) {
                todayPlan.blocks[index].status = .interrupted
                appendSystemLog(eventType: .interrupted, blockId: todayPlan.blocks[index].id)
                didChange = true
            }
        }
        if didChange {
            saveWorkspace()
        }
    }

    private func appendSystemLog(
        eventType: ExecutionEventType,
        blockId: TimeBlock.ID? = nil,
        payload: [String: String] = [:]
    ) {
        let resolvedBlockId = blockId ?? selectedBlockID ?? todayPlan.blocks.first?.id ?? UUID()
        executionLogs.append(
            ExecutionLog(
                blockId: resolvedBlockId,
                eventType: eventType,
                payload: payload
            )
        )
    }

    private func eventType(for status: TimeBlockStatus) -> ExecutionEventType {
        switch status {
        case .planned:
            .replanned
        case .active:
            .started
        case .done:
            .completed
        case .skipped:
            .skipped
        case .delayed:
            .delayed
        case .interrupted:
            .interrupted
        case .deleted:
            .replanned
        }
    }

    private static func defaultDailyWorkspace(
        date: LocalDate,
        withSampleTasks: Bool,
        settings: AppSettings = AppSettings()
    ) -> DailyWorkspace {
        let defaultSchedule = settings.aiPlanningDefaults.isValid ? settings.aiPlanningDefaults : AIPlanningDefaults.standard
        let tasks = withSampleTasks ? sampleTasks(defaultSchedule: defaultSchedule) : []
        let result = RuleBasedScheduler().makePlan(
            request: ScheduleRequest(
                date: date,
                availableWindows: defaultSchedule.windows,
                tasks: tasks
            )
        )
        return DailyWorkspace(tasks: tasks, plan: result.plan, logs: [])
    }

    private static func hasPlanContent(_ workspace: DailyWorkspace) -> Bool {
        !workspace.tasks.isEmpty || !workspace.plan.blocks.isEmpty || !workspace.logs.isEmpty
    }

    private func localizedDurationText(_ interval: TimeInterval) -> String {
        if interval < 10 {
            return String(
                format: tr("%.1f 秒"),
                locale: Locale(identifier: effectiveLanguage.localeIdentifier),
                interval
            )
        }
        return AppLocalization.duration(seconds: Int(interval.rounded()), language: effectiveLanguage)
    }

    private static func sampleTasks(defaultSchedule: AIPlanningDefaultSchedule) -> [EfficientTimeCore.Task] {
        let firstBreakEnd = defaultSchedule.breaks.first?.end ?? ClockTime(hour: 14, minute: 0)
        let focusedWorkStart = firstBreakEnd.adding(minutes: 10) ?? defaultSchedule.start
        let reviewStart = defaultSchedule.end.adding(minutes: -30) ?? ClockTime(hour: 21, minute: 0)
        let restTasks = defaultSchedule.breaks.map { defaultBreak in
            EfficientTimeCore.Task(
                title: defaultBreak.title,
                estimatedDurationMinutes: defaultBreak.durationMinutes,
                priority: .medium,
                category: .rest,
                fixedStart: defaultBreak.start,
                privacyLevel: .anonymized
            )
        }

        return [
            EfficientTimeCore.Task(
                title: "查看股票账户",
                estimatedDurationMinutes: 20,
                priority: .medium,
                category: .finance,
                fixedStart: defaultSchedule.start,
                privacyLevel: .anonymized
            ),
            EfficientTimeCore.Task(
                title: "阅读最新文章综述",
                estimatedDurationMinutes: 60,
                priority: .medium,
                category: .study,
                fixedStart: defaultSchedule.start.adding(minutes: 30) ?? defaultSchedule.start,
                privacyLevel: .anonymized
            ),
            EfficientTimeCore.Task(
                title: "写 EfficientTime 基础代码",
                estimatedDurationMinutes: 120,
                priority: .medium,
                category: .work,
                fixedStart: focusedWorkStart,
                privacyLevel: .anonymized
            ),
            EfficientTimeCore.Task(
                title: "晚间复盘",
                estimatedDurationMinutes: 30,
                priority: .medium,
                category: .review,
                fixedStart: reviewStart,
                privacyLevel: .anonymized
            )
        ] + restTasks
    }

    private static func clockTime(from date: Date) -> ClockTime {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return ClockTime(hour: components.hour ?? 0, minute: components.minute ?? 0)
    }
}

struct ScheduleConflict: Identifiable, Equatable {
    var id: UUID { conflictingBlock.id }
    var proposedTitle: String
    var proposedStart: ClockTime
    var proposedEnd: ClockTime
    var conflictingBlock: TimeBlock
    var suggestedStart: ClockTime?
    var suggestedEnd: ClockTime?
    var editedBlockID: TimeBlock.ID?

    var suggestedWindow: TimeWindow? {
        guard let suggestedStart,
              let suggestedEnd,
              suggestedStart < suggestedEnd
        else { return nil }
        return TimeWindow(start: suggestedStart, end: suggestedEnd)
    }
}

struct DaySummary: Identifiable, Equatable {
    var id: LocalDate { date }
    var date: LocalDate
    var taskCount: Int
    var plannedMinutes: Int
    var status: DayPlanStatus
    var isSelected: Bool
}
