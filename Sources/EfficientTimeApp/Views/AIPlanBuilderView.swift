import EfficientTimeCore
import SwiftUI

struct AIPlanBuilderView: View {
    @EnvironmentObject private var model: AppModel
    @StateObject private var speechRecorder = SpeechInputRecorder()
    @State private var input = ""
    @State private var breakMinutesText = "10"
    @State private var planningStartText = ""
    @State private var planningEndText = ""
    @State private var draftItems: [TaskDraft] = []
    @State private var suggestionEdits: [TaskDraft.ID: SuggestionEdit] = [:]
    @State private var applyStatusMessage: String?
    @State private var applyTargetDate = LocalDate.today()
    @State private var applyVisibleMonth = LocalDate.today()
    @State private var isApplyCalendarPresented = false

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 24)
                .padding(.top, 22)
                .padding(.bottom, 14)

            HSplitView {
                inputPanel
                    .frame(minWidth: 430, idealWidth: 480)

                timelinePanel
                    .frame(minWidth: 520)
            }
        }
        .background(model.settings.pageBackground)
        .onAppear {
            speechRecorder.setLanguage(model.settings.language)
            syncPlanningWindowDefaults()
            applyTargetDate = model.selectedDate
            applyVisibleMonth = monthStart(for: model.selectedDate)
            if draftItems.isEmpty, !model.aiDrafts.isEmpty {
                draftItems = model.aiDrafts
                resetSuggestionEdits(for: model.aiDrafts)
            }
        }
        .onChange(of: model.aiDrafts) { _, newValue in
            applyStatusMessage = nil
            draftItems = newValue
            resetSuggestionEdits(for: newValue)
        }
        .onChange(of: model.selectedDateForPicker) { _, _ in
            applyTargetDate = model.selectedDate
            applyVisibleMonth = monthStart(for: model.selectedDate)
        }
        .onChange(of: model.settings.language) { _, newValue in
            speechRecorder.setLanguage(newValue)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.tr("智能规划"))
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("\(model.settings.aiProvider.localizedTitle(model.effectiveLanguage)) · \(model.selectedDateTitle)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if model.isAIPlanning {
                ProgressView()
                    .controlSize(.small)
            }

            Text(model.aiStatusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var inputPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(model.tr("原始计划"))
                    .font(.headline)
                Spacer()
                Button {
                    speechRecorder.toggleRecording { transcript in
                        appendTranscriptToInput(transcript)
                    }
                } label: {
                    Label(speechRecorder.isRecording ? model.tr("停止录入") : model.tr("语音录入"), systemImage: speechRecorder.isRecording ? "stop.circle.fill" : "mic.circle")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(speechRecorder.isRecording ? .red : model.settings.accentColor)
                .help(speechRecorder.isRecording ? model.tr("停止录音并写入文本") : model.tr("使用系统语音识别录入计划"))

                Button {
                    input = ""
                } label: {
                    Label(model.tr("清空"), systemImage: "xmark.circle")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help(model.tr("清空输入"))
            }

            compactPlanningControls

            planEditor

            if speechRecorder.isRecording || speechRecorder.statusText != model.tr("语音输入待开始。") {
                Label(speechRecorder.statusText, systemImage: speechRecorder.isRecording ? "waveform" : "text.bubble")
                    .font(.caption)
                    .foregroundStyle(speechRecorder.isRecording ? model.settings.accentColor : .secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                model.runConfiguredAIPlanning(input: planningInput)
            } label: {
                Label(model.tr("生成分时段日程"), systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(model.settings.accentColor)
            .disabled(model.isAIPlanning || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !planningControlsAreValid)

            if let message = model.lastErrorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.leading, 24)
        .padding(.trailing, 18)
        .padding(.bottom, 22)
    }

    private var planEditor: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $input)
                .font(.system(size: 15))
                .scrollContentBackground(.hidden)
                .padding(8)

            if input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(model.tr("把今天要做的事直接粘进来，例如：\n09:30 看股票账户 20 分钟\n读论文综述，大概 1 小时\n写项目代码\n晚上复盘"))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 16)
                    .allowsHitTesting(false)
            }
        }
        .frame(minHeight: 310)
        .background(Color.white.opacity(0.66), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
        }
    }

    private func appendTranscriptToInput(_ transcript: String) {
        let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTranscript.isEmpty else { return }
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        input = trimmedInput.isEmpty
            ? trimmedTranscript
            : "\(input.trimmingCharacters(in: .newlines))\n\(trimmedTranscript)"
    }

    private var compactPlanningControls: some View {
        HStack(spacing: 8) {
            Label(model.tr("规划"), systemImage: "clock")
                .foregroundStyle(.secondary)

            TextField(model.tr("开始"), text: $planningStartText)
                .frame(width: 58)
                .textFieldStyle(.roundedBorder)
                .monospacedDigit()

            Text(model.tr("到"))
                .foregroundStyle(.secondary)

            TextField(model.tr("结束"), text: $planningEndText)
                .frame(width: 58)
                .textFieldStyle(.roundedBorder)
                .monospacedDigit()

            Divider()
                .frame(height: 16)

            Label(model.tr("间隔"), systemImage: "timer")
                .foregroundStyle(.secondary)

            TextField("10", text: $breakMinutesText)
                .frame(width: 54)
                .textFieldStyle(.roundedBorder)

            Text(model.tr("分钟"))
                .foregroundStyle(.secondary)

            Spacer()

            Text(planningControlStatusText)
                .foregroundStyle(.secondary)
        }
        .font(.caption)
        .foregroundStyle(planningControlsAreValid ? Color.primary : Color.red)
    }

    private var timelinePanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.tr("日程草稿"))
                        .font(.headline)
                    Text(suggestionSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    addDraftRow()
                } label: {
                    Label(model.tr("添加"), systemImage: "plus")
                }
                .disabled(model.isAIPlanning)

                applyTargetPicker

                Button {
                    applyDrafts(to: applyTargetDate, title: title(for: applyTargetDate))
                } label: {
                    Label(model.tr("应用"), systemImage: "calendar.badge.checkmark")
                }
                .buttonStyle(.borderedProminent)
                .tint(model.settings.accentColor)
                .disabled(applyDisabled)
            }

            Divider()

            if let applyStatusMessage {
                Label(applyStatusMessage, systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else if let draftScheduleIssue {
                Label(draftScheduleIssue, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let draftScheduleNotice {
                Label(draftScheduleNotice, systemImage: "wand.and.stars")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if draftItems.isEmpty {
                emptyTimeline
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(draftItems.enumerated()), id: \.element.id) { index, draft in
                            timelineRow(draft: draft, index: index)
                            if index < draftItems.count - 1 {
                                Divider()
                                    .padding(.leading, 96)
                            }
                        }
                    }
                }
            }
        }
        .padding(.leading, 18)
        .padding(.trailing, 24)
        .padding(.bottom, 22)
    }

    private var applyTargetPicker: some View {
        Button {
            applyVisibleMonth = monthStart(for: applyTargetDate)
            isApplyCalendarPresented.toggle()
        } label: {
            Label(model.trf("目标：%@", title(for: applyTargetDate)), systemImage: "calendar")
        }
        .buttonStyle(.bordered)
        .popover(isPresented: $isApplyCalendarPresented, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(model.tr("应用目标日期"))
                        .font(.headline)
                    Spacer()
                    Button(model.tr("今天")) {
                        selectApplyTarget(LocalDate.today())
                    }
                    Button(model.tr("明天")) {
                        selectApplyTarget(LocalDate.today().adding(days: 1))
                    }
                }
                .controlSize(.small)

                PlanMonthCalendarView(
                    selectedDate: applyTargetDate,
                    visibleMonth: $applyVisibleMonth,
                    accentColor: model.settings.accentColor
                ) { date in
                    selectApplyTarget(date)
                }
            }
            .padding(12)
            .frame(width: 300)
        }
    }

    private var emptyTimeline: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 32))
                .foregroundStyle(model.settings.accentColor)
            Text(model.tr("等待生成"))
                .font(.headline)
            Text(model.tr("左侧输入计划后会在这里变成可编辑时间轴。"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func timelineRow(draft: TaskDraft, index: Int) -> some View {
        let edit = suggestionEdits[draft.id] ?? defaultEdit(for: draft, cursor: planningDefaults.start)
        let isInvalid = parsedTimes(for: edit) == nil || trimmedTitle(for: edit).isEmpty

        return HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                labeledTextField(
                    model.tr("Start"),
                    text: startBinding(for: draft.id, fallback: edit.startText),
                    width: 58,
                    alignment: .trailing,
                    monospaced: true
                )
                labeledTextField(
                    model.tr("End"),
                    text: endBinding(for: draft.id, fallback: edit.endText),
                    width: 58,
                    alignment: .trailing,
                    monospaced: true
                )
                labeledTextField(
                    model.tr("时长"),
                    text: durationBinding(for: draft.id, fallback: edit.durationText),
                    width: 58,
                    alignment: .trailing,
                    monospaced: true
                )
            }
            .frame(width: 104)

            VStack(spacing: 0) {
                Circle()
                    .fill(isInvalid ? Color.red : model.settings.accentColor)
                    .frame(width: 10, height: 10)
                Rectangle()
                    .fill(Color(nsColor: .separatorColor).opacity(0.45))
                    .frame(width: 1)
            }
            .frame(width: 14, height: 70)

            VStack(alignment: .leading, spacing: 4) {
                TextField(model.tr("任务名称"), text: titleBinding(for: draft.id, fallback: edit.titleText))
                    .font(.system(size: 14, weight: .semibold))
                    .textFieldStyle(.roundedBorder)

                TextField(model.tr("内容说明"), text: notesBinding(for: draft.id, fallback: edit.notesText), axis: .vertical)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...2)
            }

            Spacer(minLength: 0)

            Button {
                deleteDraftRow(draft.id)
            } label: {
                Image(systemName: "trash")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(model.tr("删除这条草稿"))
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private var planningInput: String {
        """
        \(input.trimmingCharacters(in: .whitespacesAndNewlines))

        规划要求：
        - 默认按照用户输入的任务顺序安排。
        - 所有自然语言输出必须使用 \(model.effectiveLanguage.aiInstructionName)。
        - 默认规划范围是 \(planningDefaults.windowDescription)，不要把未指定时间的任务安排到这个范围之外。
        - 默认固定休息：\(planningDefaults.breakDescription)。这些时段只作为避让约束；除非我明确写了吃饭或休息任务，否则不要额外生成休息任务。
        - 未指定时间的工作任务不要占用默认休息时段。
        - 如果用户写了具体开始、结束、截止或耗时，以用户输入为准。
        - 任务之间预留 \(resolvedBreakMinutes) 分钟间隔休息。
        - 请直接给出可执行的初始规划建议，不要反问用户。
        - 每个任务都需要包含任务名称、内容说明、开始时间、预计耗时和结束时间。
        - 如果我没有写开始时间，请根据任务内容和顺序在 \(planningDefaults.windowDescription) 内评估一个建议开始时间。
        - 如果我没有写大概需要多久，请根据任务类型自己评估一个合理耗时。
        - 信息不足时请合理估算，并把关键估算依据用一句 \(model.effectiveLanguage.aiInstructionName) 写入 assumptions，不要向我反问。
        """
    }

    private var editedDrafts: [TaskDraft] {
        draftApplication()?.drafts ?? []
    }

    private var applyDisabled: Bool {
        draftItems.isEmpty || draftScheduleIssue != nil
    }

    private var draftScheduleIssue: String? {
        if draftItems.contains(where: { draft in
            guard let edit = suggestionEdits[draft.id] else { return true }
            return trimmedTitle(for: edit).isEmpty
        }) {
            return model.tr("草稿里有任务名称为空，请先补全名称。")
        }

        return nil
    }

    private var draftScheduleNotice: String? {
        guard draftScheduleIssue == nil,
              let application = draftApplication()
        else { return nil }
        return application.adjustmentDescription.map { model.trf("点击应用时%@。", $0) }
    }

    private var draftWindows: [(title: String, window: TimeWindow)] {
        draftItems.compactMap { draft in
            guard let edit = suggestionEdits[draft.id],
                  let times = parsedTimes(for: edit)
            else { return nil }
            return (trimmedTitle(for: edit).isEmpty ? draft.title : trimmedTitle(for: edit), TimeWindow(start: times.start, end: times.end))
        }
        .sorted { $0.window.start < $1.window.start }
    }

    private var suggestionSummary: String {
        guard !draftItems.isEmpty else {
            return model.tr("生成后可直接改时间并应用。")
        }
        let total = editedDrafts.reduce(0) { $0 + $1.estimatedDurationMinutes }
        return model.trf("%d 个任务 · 预计 %d 分钟", draftItems.count, total)
    }

    private func applyDrafts(to date: LocalDate, title: String) {
        guard let application = draftApplication() else {
            applyStatusMessage = nil
            model.lastErrorMessage = model.tr("草稿无法应用，请检查任务名称，或确认开始时间没有超过当天结束。")
            return
        }

        suggestionEdits = application.edits
        if model.applyTaskDrafts(application.drafts, to: date) {
            model.lastErrorMessage = nil
            let adjustment = application.adjustmentDescription.map { "\($0)。" } ?? ""
            applyStatusMessage = model.trf("已应用到%@：%d 个任务。%@", title, application.drafts.count, adjustment)
        } else {
            applyStatusMessage = nil
        }
    }

    private func selectApplyTarget(_ date: LocalDate) {
        applyTargetDate = date
        applyVisibleMonth = monthStart(for: date)
        isApplyCalendarPresented = false
    }

    private func title(for date: LocalDate) -> String {
        let today = LocalDate.today()
        if date == today {
            return model.tr("今天")
        }
        if date == today.adding(days: 1) {
            return model.tr("明天")
        }
        if date == model.selectedDate {
            return model.selectedDateTitle
        }
        return date.displayString
    }

    private func monthStart(for date: LocalDate) -> LocalDate {
        LocalDate(year: date.year, month: date.month, day: 1)
    }

    private func addDraftRow() {
        let cursor = draftItems.last.flatMap { draft -> ClockTime? in
            guard let edit = suggestionEdits[draft.id],
                  let end = try? ClockTime(parsing: edit.endText)
            else { return nil }
            return end.adding(minutes: resolvedBreakMinutes)
        } ?? planningDefaults.start

        let draft = TaskDraft(
            title: model.tr("新任务"),
            estimatedDurationMinutes: 30,
            fixedStart: cursor
        )
        draftItems.append(draft)
        suggestionEdits[draft.id] = defaultEdit(for: draft, cursor: cursor)
        applyStatusMessage = nil
    }

    private func deleteDraftRow(_ id: TaskDraft.ID) {
        draftItems.removeAll { $0.id == id }
        suggestionEdits.removeValue(forKey: id)
        applyStatusMessage = nil
    }

    private var parsedDraftRows: [ParsedDraftRow]? {
        var rows: [ParsedDraftRow] = []
        for draft in draftItems {
            guard let edit = suggestionEdits[draft.id],
                  let times = parsedTimes(for: edit)
            else { return nil }

            let duration = max(5, times.end.minutesSinceMidnight - times.start.minutesSinceMidnight)
            var taskDraft = draft
            taskDraft.title = trimmedTitle(for: edit)
            taskDraft.assumptions = editedAssumptions(for: edit)
            taskDraft.fixedStart = times.start
            taskDraft.estimatedDurationMinutes = duration
            taskDraft.earliestStart = nil
            taskDraft.latestEnd = nil
            rows.append(
                ParsedDraftRow(
                    draft: draft,
                    taskDraft: taskDraft,
                    start: times.start,
                    end: times.end,
                    durationMinutes: duration
                )
            )
        }
        return rows
    }

    private func draftApplication() -> DraftApplication? {
        guard !draftItems.isEmpty else { return nil }

        var edits = suggestionEdits
        var drafts: [TaskDraft] = []
        var cursor = planningDefaults.start
        var repairedInvalidTimes = false
        var shiftedPastTimes = false
        var extendedWindow = false

        for draft in draftItems {
            var edit = edits[draft.id] ?? defaultEdit(for: draft, cursor: cursor)
            let title = trimmedTitle(for: edit)
            guard !title.isEmpty else { return nil }

            let fallbackDuration = max(5, parsedDuration(edit.durationText) ?? draft.estimatedDurationMinutes)
            let parsed = parsedTimes(for: edit)
            let shouldKeepParsedTimes = parsed.map { $0.start >= planningDefaults.start } ?? false

            let start: ClockTime
            let end: ClockTime
            if shouldKeepParsedTimes, let parsed {
                start = parsed.start
                end = parsed.end
            } else {
                repairedInvalidTimes = repairedInvalidTimes || parsed == nil
                shiftedPastTimes = shiftedPastTimes || parsed.map { $0.start < planningDefaults.start } == true

                let parsedStart = (try? ClockTime(parsing: edit.startText)).flatMap { candidate -> ClockTime? in
                    candidate >= planningDefaults.start ? candidate : nil
                }
                start = max(parsedStart ?? cursor, planningDefaults.start)
                let proposedEnd = start.adding(minutes: fallbackDuration) ?? .endOfDay
                guard start < proposedEnd else { return nil }
                end = proposedEnd
                edit.startText = start.displayString
                edit.endText = end.displayString
                edit.durationText = "\(end.minutesSinceMidnight - start.minutesSinceMidnight)"
            }

            var taskDraft = draft
            taskDraft.title = title
            taskDraft.assumptions = editedAssumptions(for: edit)
            taskDraft.fixedStart = start
            taskDraft.estimatedDurationMinutes = max(5, end.minutesSinceMidnight - start.minutesSinceMidnight)
            taskDraft.earliestStart = nil
            taskDraft.latestEnd = nil
            drafts.append(taskDraft)

            edits[draft.id] = edit
            if end > planningDefaults.end {
                extendedWindow = true
            }
            cursor = end.adding(minutes: resolvedBreakMinutes) ?? end
        }

        var notes: [String] = []
        if repairedInvalidTimes {
            notes.append(model.tr("自动补全无效或缺失时间"))
        }
        if shiftedPastTimes {
            notes.append(model.trf("早于当前起点的任务已从 %@ 开始安排", planningDefaults.start.displayString))
        }
        if extendedWindow {
            notes.append(model.tr("自动扩展当天时间范围"))
        }

        return DraftApplication(
            drafts: drafts,
            edits: edits,
            adjustmentDescription: notes.isEmpty ? nil : notes.joined(separator: "，")
        )
    }

    private var hasOverlappingDraftWindows: Bool {
        let windows = draftWindows
        return zip(windows, windows.dropFirst()).contains { current, next in
            current.window.end > next.window.start
        }
    }

    private func sequentialApplication(
        rows: [ParsedDraftRow],
        durations: [Int],
        start: ClockTime,
        endLimit: ClockTime
    ) -> DraftApplication? {
        guard rows.count == durations.count,
              let slots = sequentialSlots(durations: durations, start: start, endLimit: endLimit)
        else { return nil }

        var edits = suggestionEdits
        var drafts: [TaskDraft] = []
        for (row, slot) in zip(rows, slots) {
            var draft = row.taskDraft
            draft.fixedStart = slot.start
            draft.estimatedDurationMinutes = slot.end.minutesSinceMidnight - slot.start.minutesSinceMidnight
            draft.earliestStart = nil
            draft.latestEnd = nil
            drafts.append(draft)
            var edit = edits[draft.id] ?? defaultEdit(for: draft, cursor: slot.start)
            edit.startText = slot.start.displayString
            edit.endText = slot.end.displayString
            edit.durationText = "\(draft.estimatedDurationMinutes)"
            edits[draft.id] = edit
        }

        let latestEnd = slots.map(\.end).max() ?? planningDefaults.end
        var notes = [model.tr("按任务顺序自动顺延重叠时间")]
        if latestEnd > planningDefaults.end {
            notes.append(model.trf("扩展到 %@", latestEnd.displayString))
        }
        if durations != rows.map(\.durationMinutes) {
            notes.append(model.tr("压缩部分任务时长"))
        }

        return DraftApplication(
            drafts: drafts,
            edits: edits,
            adjustmentDescription: notes.joined(separator: "，")
        )
    }

    private func sequentialSlots(
        durations: [Int],
        start: ClockTime,
        endLimit: ClockTime
    ) -> [TimeWindow]? {
        let segments = schedulingSegments(from: start, until: endLimit)
        guard !segments.isEmpty else { return nil }

        var cursor = start
        var slots: [TimeWindow] = []
        for duration in durations {
            guard let slot = firstAvailableSlot(duration: duration, cursor: cursor, segments: segments) else {
                return nil
            }
            slots.append(slot)
            cursor = slot.end.adding(minutes: resolvedBreakMinutes) ?? .endOfDay
        }
        return slots
    }

    private func firstAvailableSlot(
        duration: Int,
        cursor: ClockTime,
        segments: [TimeWindow]
    ) -> TimeWindow? {
        for segment in segments {
            let start = max(cursor, segment.start)
            guard start < segment.end,
                  let end = start.adding(minutes: duration),
                  end <= segment.end
            else { continue }
            return TimeWindow(start: start, end: end)
        }
        return nil
    }

    private func schedulingSegments(from start: ClockTime, until end: ClockTime) -> [TimeWindow] {
        guard start < end else { return [] }

        var segments = planningDefaults.workSegments
        if start < planningDefaults.start {
            segments.append(TimeWindow(start: start, end: planningDefaults.start))
        }
        if planningDefaults.end < end {
            segments.append(TimeWindow(start: planningDefaults.end, end: end))
        }

        return mergeSegments(
            segments.compactMap { segment in
                let clippedStart = max(segment.start, start)
                let clippedEnd = min(segment.end, end)
                guard clippedStart < clippedEnd else { return nil }
                return TimeWindow(start: clippedStart, end: clippedEnd)
            }
        )
    }

    private func mergeSegments(_ segments: [TimeWindow]) -> [TimeWindow] {
        let sortedSegments = segments.sorted { $0.start < $1.start }
        guard var current = sortedSegments.first else { return [] }

        var merged: [TimeWindow] = []
        for segment in sortedSegments.dropFirst() {
            if segment.start <= current.end {
                current = TimeWindow(start: current.start, end: max(current.end, segment.end))
            } else {
                merged.append(current)
                current = segment
            }
        }
        merged.append(current)
        return merged
    }

    private func availableTaskMinutes(from start: ClockTime, until end: ClockTime, taskCount: Int) -> Int {
        let segmentMinutes = schedulingSegments(from: start, until: end).reduce(0) { total, segment in
            total + segment.durationMinutes
        }
        let breakMinutes = resolvedBreakMinutes * max(0, taskCount - 1)
        return max(0, segmentMinutes - breakMinutes)
    }

    private func compressedDurations(_ durations: [Int], targetTaskMinutes: Int) -> [Int]? {
        let currentTotal = durations.reduce(0, +)
        guard currentTotal > targetTaskMinutes else { return durations }

        let minimumDurations = durations.map { min($0, 15) }
        guard minimumDurations.reduce(0, +) <= targetTaskMinutes else { return nil }

        var result = durations
        var remainingReduction = currentTotal - targetTaskMinutes
        while remainingReduction > 0 {
            var reducedThisRound = false
            for index in result.indices where result[index] > minimumDurations[index] {
                result[index] -= 1
                remainingReduction -= 1
                reducedThisRound = true
                if remainingReduction == 0 { break }
            }
            if !reducedThisRound { return nil }
        }
        return result
    }

    private func resetSuggestionEdits(for drafts: [TaskDraft]) {
        var edits: [TaskDraft.ID: SuggestionEdit] = [:]
        var cursor = planningDefaults.start

        for draft in drafts {
            let edit = defaultEdit(for: draft, cursor: cursor)
            edits[draft.id] = edit
            if let end = try? ClockTime(parsing: edit.endText) {
                cursor = ClockTime(minutesSinceMidnight: min(planningDefaults.end.minutesSinceMidnight, end.minutesSinceMidnight + resolvedBreakMinutes))
            }
        }

        suggestionEdits = edits
    }

    private func defaultEdit(for draft: TaskDraft, cursor: ClockTime) -> SuggestionEdit {
        let duration = max(5, draft.estimatedDurationMinutes)
        let base = SuggestionEdit(
            titleText: draft.title,
            notesText: taskDescription(for: draft) ?? "",
            startText: "",
            durationText: "\(duration)",
            endText: ""
        )

        if let fixedStart = draft.fixedStart,
           fixedStart >= planningDefaults.start {
            let end = ClockTime(
                minutesSinceMidnight: min(ClockTime.endOfDay.minutesSinceMidnight, fixedStart.minutesSinceMidnight + duration)
            )
            var edit = base
            edit.startText = fixedStart.displayString
            edit.endText = end.displayString
            return edit
        }

        let slot = defaultSlot(startingAt: cursor, durationMinutes: duration)
        var edit = base
        edit.startText = slot.start.displayString
        edit.endText = slot.end.displayString
        return edit
    }

    private func defaultSlot(startingAt cursor: ClockTime, durationMinutes: Int) -> TimeWindow {
        let startCursor = max(cursor, planningDefaults.start)
        for segment in defaultWorkSegments {
            let start = max(segment.start, startCursor)
            guard start < segment.end else { continue }
            if let end = start.adding(minutes: durationMinutes), end <= segment.end {
                return TimeWindow(start: start, end: end)
            }
        }

        let fallbackSegment = defaultWorkSegments.first { max($0.start, startCursor) < $0.end }
            ?? defaultWorkSegments.last
            ?? planningDefaults.window
        let fallbackStart = max(fallbackSegment.start, min(startCursor, fallbackSegment.end))
        if fallbackStart < fallbackSegment.end {
            return TimeWindow(start: fallbackStart, end: fallbackSegment.end)
        }
        return fallbackSegment
    }

    private var defaultWorkSegments: [TimeWindow] {
        planningDefaults.workSegments
    }

    private func labeledTextField(
        _ label: String,
        text: Binding<String>,
        width: CGFloat,
        alignment: TextAlignment = .leading,
        monospaced: Bool = false
    ) -> some View {
        HStack(spacing: 5) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .trailing)

            TextField("", text: text)
                .font(monospaced ? .system(.caption, design: .monospaced) : .caption)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(alignment)
                .frame(width: width)
        }
    }

    private func titleBinding(for id: TaskDraft.ID, fallback: String) -> Binding<String> {
        Binding {
            suggestionEdits[id]?.titleText ?? fallback
        } set: { newValue in
            updateEdit(id) { $0.titleText = newValue }
        }
    }

    private func notesBinding(for id: TaskDraft.ID, fallback: String) -> Binding<String> {
        Binding {
            suggestionEdits[id]?.notesText ?? fallback
        } set: { newValue in
            updateEdit(id) { $0.notesText = newValue }
        }
    }

    private func startBinding(for id: TaskDraft.ID, fallback: String) -> Binding<String> {
        Binding {
            suggestionEdits[id]?.startText ?? fallback
        } set: { newValue in
            updateEdit(id) { edit in
                edit.startText = newValue
                if let duration = parsedDuration(edit.durationText),
                   let start = try? ClockTime(parsing: newValue),
                   let end = start.adding(minutes: duration) {
                    edit.endText = end.displayString
                } else {
                    refreshDurationText(&edit)
                }
            }
        }
    }

    private func endBinding(for id: TaskDraft.ID, fallback: String) -> Binding<String> {
        Binding {
            suggestionEdits[id]?.endText ?? fallback
        } set: { newValue in
            updateEdit(id) { edit in
                edit.endText = newValue
                refreshDurationText(&edit)
            }
        }
    }

    private func durationBinding(for id: TaskDraft.ID, fallback: String) -> Binding<String> {
        Binding {
            suggestionEdits[id]?.durationText ?? fallback
        } set: { newValue in
            updateEdit(id) { edit in
                edit.durationText = newValue
                if let duration = parsedDuration(newValue),
                   let start = try? ClockTime(parsing: edit.startText),
                   let end = start.adding(minutes: duration) {
                    edit.endText = end.displayString
                }
            }
        }
    }

    private func updateEdit(_ id: TaskDraft.ID, mutate: (inout SuggestionEdit) -> Void) {
        var edit = suggestionEdits[id] ?? SuggestionEdit.empty
        mutate(&edit)
        suggestionEdits[id] = edit
        applyStatusMessage = nil
    }

    private func refreshDurationText(_ edit: inout SuggestionEdit) {
        guard let duration = durationMinutes(for: edit) else { return }
        edit.durationText = "\(duration)"
    }

    private func parsedDuration(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmed), (1...24 * 60).contains(value) else { return nil }
        return value
    }

    private func parsedTimes(for edit: SuggestionEdit) -> (start: ClockTime, end: ClockTime)? {
        guard let start = try? ClockTime(parsing: edit.startText),
              let end = try? ClockTime(parsing: edit.endText),
              start < end
        else { return nil }
        return (start, end)
    }

    private func durationMinutes(for edit: SuggestionEdit) -> Int? {
        guard let times = parsedTimes(for: edit) else { return nil }
        return times.end.minutesSinceMidnight - times.start.minutesSinceMidnight
    }

    private func taskDescription(for draft: TaskDraft) -> String? {
        let text = draft.assumptions
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "；")
        return text.isEmpty ? nil : text
    }

    private func trimmedTitle(for edit: SuggestionEdit) -> String {
        edit.titleText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func editedAssumptions(for edit: SuggestionEdit) -> [String] {
        let text = edit.notesText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return [] }
        return text
            .components(separatedBy: CharacterSet.newlines)
            .flatMap { $0.components(separatedBy: "；") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var parsedBreakMinutes: Int? {
        let trimmed = breakMinutesText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmed), (0...120).contains(value) else { return nil }
        return value
    }

    private var resolvedBreakMinutes: Int {
        parsedBreakMinutes ?? 10
    }

    private var planningControlsAreValid: Bool {
        parsedBreakMinutes != nil && parsedPlanningWindow != nil
    }

    private var planningControlStatusText: String {
        guard parsedBreakMinutes != nil else {
            return model.tr("间隔需为 0-120")
        }
        guard parsedPlanningWindow != nil else {
            return model.tr("时间格式 HH:mm")
        }
        return planningDefaults.windowDescription
    }

    private var parsedPlanningWindow: TimeWindow? {
        let startText = planningStartText.trimmingCharacters(in: .whitespacesAndNewlines)
        let endText = planningEndText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let start = try? ClockTime(parsing: startText),
              let end = try? ClockTime(parsing: endText),
              start < end
        else { return nil }
        return TimeWindow(start: start, end: end)
    }

    private var basePlanningDefaults: AIPlanningDefaultSchedule {
        let base = model.settings.aiPlanningDefaults.isValid ? model.settings.aiPlanningDefaults : AIPlanningDefaults.standard
        guard model.selectedDate == LocalDate.today() else {
            return base
        }

        let start = max(base.start, currentClockTime)
        if start < base.end {
            return adjustedPlanningDefaults(from: base, start: start, end: base.end)
        }

        let fallbackStart = start < .endOfDay
            ? start
            : ClockTime(minutesSinceMidnight: ClockTime.endOfDay.minutesSinceMidnight - 30)
        return adjustedPlanningDefaults(from: base, start: fallbackStart, end: .endOfDay)
    }

    private var planningDefaults: AIPlanningDefaultSchedule {
        guard let window = parsedPlanningWindow else {
            return basePlanningDefaults
        }

        let breaks = basePlanningDefaults.breaks.compactMap { defaultBreak -> AIPlanningDefaultBreak? in
            let start = max(defaultBreak.start, window.start)
            let end = min(defaultBreak.end, window.end)
            guard start < end else { return nil }
            return AIPlanningDefaultBreak(title: defaultBreak.title, start: start, end: end)
        }

        let schedule = AIPlanningDefaultSchedule(start: window.start, end: window.end, breaks: breaks)
        return schedule.isValid ? schedule : basePlanningDefaults
    }

    private func syncPlanningWindowDefaults() {
        if planningStartText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            planningStartText = basePlanningDefaults.start.displayString
        }
        if planningEndText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            planningEndText = basePlanningDefaults.end.displayString
        }
    }

    private func adjustedPlanningDefaults(
        from base: AIPlanningDefaultSchedule,
        start: ClockTime,
        end: ClockTime
    ) -> AIPlanningDefaultSchedule {
        let breaks = base.breaks.compactMap { defaultBreak -> AIPlanningDefaultBreak? in
            let breakStart = max(defaultBreak.start, start)
            let breakEnd = min(defaultBreak.end, end)
            guard breakStart < breakEnd else { return nil }
            return AIPlanningDefaultBreak(title: defaultBreak.title, start: breakStart, end: breakEnd)
        }
        let schedule = AIPlanningDefaultSchedule(start: start, end: end, breaks: breaks)
        return schedule.isValid ? schedule : AIPlanningDefaults.standard
    }

    private var currentClockTime: ClockTime {
        let components = Calendar.current.dateComponents([.hour, .minute], from: model.now)
        let hour = min(23, max(0, components.hour ?? 0))
        let minute = min(59, max(0, components.minute ?? 0))
        return ClockTime(hour: hour, minute: minute)
    }
}

private struct SuggestionEdit: Equatable {
    var titleText: String
    var notesText: String
    var startText: String
    var durationText: String
    var endText: String

    static let empty = SuggestionEdit(
        titleText: "",
        notesText: "",
        startText: "",
        durationText: "",
        endText: ""
    )
}

private struct ParsedDraftRow {
    var draft: TaskDraft
    var taskDraft: TaskDraft
    var start: ClockTime
    var end: ClockTime
    var durationMinutes: Int
}

private struct DraftApplication {
    var drafts: [TaskDraft]
    var edits: [TaskDraft.ID: SuggestionEdit]
    var adjustmentDescription: String?
}

#Preview {
    AIPlanBuilderView()
        .environmentObject(AppModel())
}
