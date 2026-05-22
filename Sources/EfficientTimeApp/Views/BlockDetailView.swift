import EfficientTimeCore
import SwiftUI

struct BlockDetailView: View {
    @EnvironmentObject private var model: AppModel
    @State private var startText = ""
    @State private var endText = ""
    @State private var showClearDeletedConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                DayStatusRingView(blocks: model.visiblePlanBlocks, accentColor: model.settings.accentColor)
                    .padding(.top)

                Text(model.tr("时间块"))
                    .font(.headline)

                statusOverview

                Divider()

                if let block = model.selectedBlock {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(block.title)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .lineLimit(3)

                        Text("\(block.start.displayString)-\(block.end.displayString)")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)

                        Text(model.minutesText(block.durationMinutes))
                            .foregroundStyle(.secondary)

                        Divider()

                        HStack {
                            Text(model.tr("状态"))
                            Spacer()
                            Text(model.statusTitle(block.status))
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .foregroundStyle(block.status.tint)
                                .background(block.status.softBackground)
                                .clipShape(Capsule())
                        }

                        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 8) {
                            GridRow {
                                Text(model.tr("开始"))
                                TextField("09:00", text: $startText)
                            }
                            GridRow {
                                Text(model.tr("结束"))
                                TextField("10:00", text: $endText)
                            }
                        }
                        .textFieldStyle(.roundedBorder)

                        Button {
                            _ = model.updateSelectedBlock(startText: startText, endText: endText)
                        } label: {
                            Label(model.tr("更新时间"), systemImage: "calendar.badge.clock")
                        }
                        .disabled(block.status == .deleted)

                        if let conflict = model.pendingConflict {
                            conflictPanel(conflict)
                        }

                        Button {
                            if block.status == .done {
                                model.toggleBlockCompletion(block.id)
                            } else {
                                model.markSelectedDone()
                            }
                        } label: {
                            Label(block.status == .done ? model.tr("取消完成") : model.tr("完成"), systemImage: block.status == .done ? "arrow.uturn.backward.circle" : "checkmark.circle")
                        }
                        .disabled(block.status == .deleted)

                        Button {
                            model.skipSelected()
                        } label: {
                            Label(block.status == .skipped ? model.tr("取消跳过") : model.tr("跳过"), systemImage: block.status == .skipped ? "arrow.uturn.backward.circle" : "forward.end")
                        }
                        .disabled(block.status == .done || block.status == .deleted)

                        Button {
                            model.delaySelected()
                        } label: {
                            Label(block.status == .delayed ? model.tr("取消推迟") : model.tr("推迟 20 分钟"), systemImage: block.status == .delayed ? "arrow.uturn.backward.circle" : "clock.badge.exclamationmark")
                        }
                        .disabled(block.status == .done || block.status == .deleted)

                        if block.status != .deleted {
                            Button(role: .destructive) {
                                model.deleteSelectedBlock()
                            } label: {
                                Label(model.tr("删除"), systemImage: "trash")
                            }
                        } else {
                            Text(model.tr("已删除事项可以在上方点击“清理”彻底移除。"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Text(model.tr("选择一个时间块"))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .onAppear(perform: syncFields)
        .onChange(of: model.selectedBlockID) { _, _ in
            syncFields()
        }
        .confirmationDialog(model.tr("清理已删除事项？"), isPresented: $showClearDeletedConfirmation, titleVisibility: .visible) {
            Button(model.tr("确定清理"), role: .destructive) {
                model.clearDeletedBlocks()
            }
            Button(model.tr("取消"), role: .cancel) {}
        } message: {
            Text(model.trf("将永久移除 %d 个已删除事项，此操作不能撤销。", deletedBlocksCount))
        }
    }

    private var statusOverview: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(model.tr("状态归类"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text(model.itemCountText(handledBlocks.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if statusGroups.isEmpty {
                Text(model.tr("暂无完成、跳过、推迟或删除事项。"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(statusGroups, id: \.self) { status in
                    statusGroup(status)
                }
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.42), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
        }
    }

    private var handledBlocks: [TimeBlock] {
        model.todayPlan.blocks.filter { [.done, .skipped, .delayed, .deleted].contains($0.status) }
    }

    private var statusGroups: [TimeBlockStatus] {
        [.done, .skipped, .delayed, .deleted].filter { status in
            model.todayPlan.blocks.contains { $0.status == status }
        }
    }

    private var deletedBlocksCount: Int {
        model.todayPlan.blocks.filter { $0.status == .deleted }.count
    }

    private func statusGroup(_ status: TimeBlockStatus) -> some View {
        let blocks = model.todayPlan.blocks.filter { $0.status == status }
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(status.tint)
                    .frame(width: 7, height: 7)
                Text(model.statusTitle(status))
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(blocks.count)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)

                if status == .deleted {
                    Button(role: .destructive) {
                        showClearDeletedConfirmation = true
                    } label: {
                        Label(model.tr("清理"), systemImage: "trash.slash")
                    }
                    .font(.caption2)
                    .buttonStyle(.borderless)
                }
            }

            ForEach(blocks) { block in
                Button {
                    model.selectBlock(block)
                } label: {
                    HStack(spacing: 6) {
                        Text("\(block.start.displayString)-\(block.end.displayString)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Text(block.title)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(status.softBackground.opacity(0.72), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func syncFields() {
        guard let block = model.selectedBlock else { return }
        startText = block.start.displayString
        endText = block.end.displayString
    }

    private func conflictPanel(_ conflict: ScheduleConflict) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.tr("时间冲突"))
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(model.trf("当前时间 %@-%@ 与「%@」重叠。", conflict.proposedStart.displayString, conflict.proposedEnd.displayString, conflict.conflictingBlock.title))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let suggestion = conflict.suggestedWindow {
                Text(model.trf("建议改到 %@-%@，保持原任务时长并避开已有安排。", suggestion.start.displayString, suggestion.end.displayString))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(model.tr("当前可用时间段内没有找到同等时长的连续空档，可以缩短任务或调整可用时间段。"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                if let suggestion = conflict.suggestedWindow,
                   conflict.editedBlockID == model.selectedBlockID {
                    Button(model.tr("采用建议时间")) {
                        startText = suggestion.start.displayString
                        endText = suggestion.end.displayString
                        _ = model.applyPendingConflictSuggestionToSelectedBlock()
                    }
                }
                Button(model.tr("继续修改当前时间")) {
                    startText = conflict.proposedStart.displayString
                    endText = conflict.proposedEnd.displayString
                    model.clearPendingConflict()
                }
                Button(model.tr("去改冲突事项")) {
                    model.selectPendingConflictBlock()
                }
            }
            .font(.caption)
        }
        .padding(10)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct DayStatusRingView: View {
    @EnvironmentObject private var model: AppModel
    @State private var focusedMinute: Int?

    var blocks: [TimeBlock]
    var accentColor: Color

    private let clockSize: CGFloat = 232
    private let morningRingRadius: CGFloat = 64
    private let afternoonRingRadius: CGFloat = 88
    private let morningRingBaseColor = Color(red: 0.78, green: 0.94, blue: 0.84)
    private let afternoonRingBaseColor = Color(red: 0.78, green: 0.90, blue: 1.00)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.tr("24 小时状态"))
                        .font(.headline)
                    Text(blocks.isEmpty ? model.tr("今天还没有任务") : model.trf("%d 分钟已安排", plannedMinutes))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(blocks.isEmpty ? model.tr("空") : model.itemCountText(blocks.count))
                    .font(.caption.monospacedDigit())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .foregroundStyle(accentColor)
                    .background(accentColor.opacity(0.12), in: Capsule())
            }

            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 6) {
                    clockFace
                        .frame(width: clockSize, height: clockSize)

                    ringRangeLegend
                }

                VStack(alignment: .leading, spacing: 10) {
                    statusLegendPanel
                    focusSummary

                    if blocks.isEmpty {
                        Text(model.tr("添加任务后，这里会按一天 24 小时展示各时间段的执行状态。"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.42), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.34), lineWidth: 1)
        }
    }

    private var clockFace: some View {
        ZStack {
            Circle()
                .stroke(afternoonRingBaseColor, lineWidth: 18)
                .frame(width: afternoonRingRadius * 2, height: afternoonRingRadius * 2)

            Circle()
                .stroke(morningRingBaseColor, lineWidth: 18)
                .frame(width: morningRingRadius * 2, height: morningRingRadius * 2)

            if blocks.isEmpty {
                EmptyDayOrbitView(accentColor: accentColor)
            } else {
                ForEach(blocks) { block in
                    ForEach(segmentPieces(for: block)) { piece in
                        DayClockSegment(
                            startMinute: piece.startMinute,
                            endMinute: piece.endMinute,
                            periodStart: piece.periodStart,
                            radius: piece.radius
                        )
                        .stroke(block.status.tint, style: StrokeStyle(lineWidth: 18, lineCap: .butt))
                        .frame(width: clockSize, height: clockSize)
                        .help("\(block.start.displayString)-\(block.end.displayString) · \(block.title) · \(model.statusTitle(block.status))")
                    }
                }
            }

            ClockTickMarks()
                .stroke(Color.primary.opacity(0.22), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
                .frame(width: clockSize, height: clockSize)

            ForEach(hourLabels, id: \.minute) { item in
                Text(item.title)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 18, height: 12, alignment: .center)
                    .offset(offset(for: item.minute, radius: clockSize / 2 - 13))
            }

            if let focusedMinute {
                Circle()
                    .fill(accentColor)
                    .frame(width: 11, height: 11)
                    .shadow(color: accentColor.opacity(0.28), radius: 6)
                    .offset(offset(for: focusedMinute, radius: focusedMinute < 720 ? morningRingRadius : afternoonRingRadius))
            }

            VStack(spacing: 2) {
                Text(centerTitle)
                    .font(.system(size: focusedMinute == nil && !blocks.isEmpty ? 26 : 22, weight: .black, design: .rounded))
                    .foregroundStyle(blocks.isEmpty ? accentColor : .primary)
                Text(centerSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: clockSize, height: clockSize)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onEnded { value in
                    focusMinute(minute(at: value.location))
                }
        )
        .help(model.tr("点击表盘查看该时间点的任务或空闲状态"))
    }

    private var ringRangeLegend: some View {
        VStack(alignment: .leading, spacing: 4) {
            ringRangeRow(label: model.tr("内圈"), range: "00:00-12:00", color: morningRingBaseColor)
            ringRangeRow(label: model.tr("外圈"), range: "12:00-24:00", color: afternoonRingBaseColor)
        }
        .frame(width: clockSize, alignment: .center)
    }

    private func ringRangeRow(label: String, range: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Capsule()
                .fill(color)
                .frame(width: 24, height: 4)
                .frame(width: 28, alignment: .center)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .trailing)

            Text(range)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 82, alignment: .leading)
        }
        .frame(width: 150, alignment: .leading)
    }

    private var statusLegendPanel: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(model.tr("状态示意"))
                .font(.caption)
                .fontWeight(.semibold)

            ForEach(legendStatuses, id: \.self) { status in
                statusLegend(status)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.30), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var focusSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let focusedMinute {
                let hits = blocks(at: focusedMinute)
                if hits.isEmpty {
                    let idle = idleWindow(containing: focusedMinute)
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(Color.secondary.opacity(0.45))
                            .frame(width: 8, height: 8)
                            .padding(.top, 5)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.trf("%@ 空闲", timeString(focusedMinute)))
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text(model.trf("空闲区间 %@-%@", timeString(idle.start), timeString(idle.end)))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(model.trf("%@ 有 %d 项任务", timeString(focusedMinute), hits.count))
                            .font(.caption)
                            .fontWeight(.semibold)
                        ForEach(hits.prefix(3)) { block in
                            Button {
                                model.selectBlock(block)
                                self.focusedMinute = focusedMinute
                            } label: {
                                HStack(spacing: 7) {
                                    Circle()
                                        .fill(block.status.tint)
                                        .frame(width: 8, height: 8)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(block.title)
                                            .font(.caption)
                                            .lineLimit(1)
                                        Text("\(block.start.displayString)-\(block.end.displayString) · \(model.statusTitle(block.status))")
                                            .font(.caption2.monospacedDigit())
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(block.status.softBackground.opacity(0.68), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }

                        if hits.count > 3 {
                            Text(model.trf("还有 %d 项同时进行", hits.count - 3))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                Text(model.tr("点击表盘查看任务或空闲。"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.32), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var plannedMinutes: Int {
        blocks.reduce(0) { $0 + $1.durationMinutes }
    }

    private var completionPercent: Int {
        guard !blocks.isEmpty else { return 0 }
        let doneMinutes = blocks.filter { $0.status == .done }.reduce(0) { $0 + $1.durationMinutes }
        return Int((Double(doneMinutes) / Double(max(plannedMinutes, 1)) * 100).rounded())
    }

    private var legendStatuses: [TimeBlockStatus] {
        [.planned, .active, .done, .skipped, .delayed, .interrupted]
    }

    private var centerTitle: String {
        if let focusedMinute {
            return timeString(focusedMinute)
        }
        return blocks.isEmpty ? model.tr("待规划") : "\(completionPercent)%"
    }

    private var centerSubtitle: String {
        if let focusedMinute {
            return blocks(at: focusedMinute).isEmpty ? model.tr("空闲") : model.tr("任务")
        }
        return blocks.isEmpty ? model.tr("空闲") : model.tr("完成")
    }

    private var hourLabels: [(minute: Int, title: String)] {
        (0..<12).map { hourIndex in
            let title = hourIndex == 0 ? "12" : "\(hourIndex)"
            return (minute: hourIndex * 60, title: title)
        }
    }

    private func statusLegend(_ status: TimeBlockStatus) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(status.tint)
                .frame(width: 8, height: 8)
            Text(model.statusTitle(status))
                .font(.caption2)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }

    private func focusMinute(_ minute: Int) {
        focusedMinute = minute
        if let block = blocks(at: minute).first {
            model.selectBlock(block)
        }
    }

    private func blocks(at minute: Int) -> [TimeBlock] {
        blocks
            .filter { $0.start.minutesSinceMidnight <= minute && minute < $0.end.minutesSinceMidnight }
            .sorted {
                if $0.start != $1.start {
                    return $0.start < $1.start
                }
                return $0.durationMinutes < $1.durationMinutes
            }
    }

    private func idleWindow(containing minute: Int) -> (start: Int, end: Int) {
        let start = blocks
            .map(\.end.minutesSinceMidnight)
            .filter { $0 <= minute }
            .max() ?? 0
        let end = blocks
            .map(\.start.minutesSinceMidnight)
            .filter { $0 > minute }
            .min() ?? 24 * 60
        return (start, end)
    }

    private func minute(at location: CGPoint) -> Int {
        let center = CGPoint(x: clockSize / 2, y: clockSize / 2)
        let dx = Double(location.x - center.x)
        let dy = Double(location.y - center.y)
        let degrees = atan2(dy, dx) * 180 / Double.pi + 90
        let normalized = degrees < 0 ? degrees + 360 : degrees
        let localMinute = Int((normalized / 360 * 720).rounded()) % 720
        let distance = hypot(location.x - center.x, location.y - center.y)
        let periodStart = abs(distance - afternoonRingRadius) < abs(distance - morningRingRadius) ? 720 : 0
        return periodStart + localMinute
    }

    private func offset(for minute: Int, radius: CGFloat) -> CGSize {
        let localMinute = minute % 720
        let radians = Double(localMinute) / 720 * 2 * Double.pi - Double.pi / 2
        return CGSize(
            width: cos(radians) * radius,
            height: sin(radians) * radius
        )
    }

    private func timeString(_ minute: Int) -> String {
        ClockTime(minutesSinceMidnight: min(max(minute, 0), 24 * 60)).displayString
    }

    private func segmentPieces(for block: TimeBlock) -> [ClockSegmentPiece] {
        var pieces: [ClockSegmentPiece] = []
        let start = block.start.minutesSinceMidnight
        let end = block.end.minutesSinceMidnight

        if start < 720, end > 0 {
            let pieceStart = max(start, 0)
            let pieceEnd = min(end, 720)
            if pieceStart < pieceEnd {
                pieces.append(ClockSegmentPiece(
                    id: "\(block.id.uuidString)-morning",
                    startMinute: pieceStart,
                    endMinute: pieceEnd,
                    periodStart: 0,
                    radius: morningRingRadius
                ))
            }
        }

        if end > 720, start < 1440 {
            let pieceStart = max(start, 720)
            let pieceEnd = min(end, 1440)
            if pieceStart < pieceEnd {
                pieces.append(ClockSegmentPiece(
                    id: "\(block.id.uuidString)-afternoon",
                    startMinute: pieceStart,
                    endMinute: pieceEnd,
                    periodStart: 720,
                    radius: afternoonRingRadius
                ))
            }
        }

        return pieces
    }
}

private struct ClockSegmentPiece: Identifiable {
    var id: String
    var startMinute: Int
    var endMinute: Int
    var periodStart: Int
    var radius: CGFloat
}

private struct DayClockSegment: Shape {
    var startMinute: Int
    var endMinute: Int
    var periodStart: Int
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let start = Angle.degrees(Double(startMinute - periodStart) / 720.0 * 360.0 - 90.0)
        let end = Angle.degrees(Double(endMinute - periodStart) / 720.0 * 360.0 - 90.0)
        path.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
        return path
    }
}

private struct ClockTickMarks: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2 - 23

        for hour in 0..<12 {
            let radians = Double(hour) / 12 * 2 * Double.pi - Double.pi / 2
            let isMajor = hour % 3 == 0
            let innerRadius = outerRadius - (isMajor ? 11 : 5)
            let outer = CGPoint(
                x: center.x + cos(radians) * outerRadius,
                y: center.y + sin(radians) * outerRadius
            )
            let inner = CGPoint(
                x: center.x + cos(radians) * innerRadius,
                y: center.y + sin(radians) * innerRadius
            )
            path.move(to: outer)
            path.addLine(to: inner)
        }

        return path
    }
}

private struct EmptyDayOrbitView: View {
    var accentColor: Color

    var body: some View {
        TimelineView(.animation) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            ZStack {
                Circle()
                    .stroke(accentColor.opacity(0.30), style: StrokeStyle(lineWidth: 3, dash: [5, 8]))
                    .rotationEffect(.degrees(time.truncatingRemainder(dividingBy: 4) / 4 * 360))

                Circle()
                    .stroke(accentColor.opacity(0.12), lineWidth: 28)

                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .fill(accentColor.opacity(0.30 + Double(index) * 0.13))
                        .frame(width: 8 + CGFloat(index), height: 8 + CGFloat(index))
                        .offset(y: -62)
                        .rotationEffect(.degrees(time.truncatingRemainder(dividingBy: 7) / 7 * 360 + Double(index) * 90))
                }
            }
            .frame(width: 146, height: 146)
        }
    }
}

#Preview {
    BlockDetailView()
        .environmentObject(AppModel())
}
