import EfficientTimeCore
import SwiftUI

struct FloatingPanelView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Group {
            if model.isFloatingPanelCompact {
                compactContent
            } else {
                expandedContent
            }
        }
        .background(
            model.settings.floatingPanelBackground.opacity(panelSurfaceOpacity),
            in: RoundedRectangle(cornerRadius: model.isFloatingPanelCompact ? 18 : 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: model.isFloatingPanelCompact ? 18 : 16, style: .continuous)
                .stroke(model.settings.floatingPanelBorderColor.opacity(panelSurfaceOpacity), lineWidth: 1)
        }
        .overlay(alignment: .topLeading) {
            panelBeacon
                .padding(6)
                .allowsHitTesting(false)
        }
        .frame(
            width: model.isFloatingPanelCompact ? 306 : nil,
            height: model.isFloatingPanelCompact ? 76 : nil,
            alignment: .topLeading
        )
        .frame(
            minWidth: model.isFloatingPanelCompact ? 306 : 520,
            idealWidth: model.isFloatingPanelCompact ? 306 : 520,
            maxWidth: model.isFloatingPanelCompact ? 306 : .infinity,
            minHeight: model.isFloatingPanelCompact ? 76 : 280,
            idealHeight: model.isFloatingPanelCompact ? 76 : 340,
            maxHeight: model.isFloatingPanelCompact ? 76 : .infinity,
            alignment: .topLeading
        )
        .contentShape(RoundedRectangle(cornerRadius: model.isFloatingPanelCompact ? 18 : 16, style: .continuous))
        .onTapGesture {
            if model.isFloatingPanelCompact {
                model.toggleFloatingPanelSize()
            }
        }
    }

    private var compactContent: some View {
        HStack(spacing: 9) {
            countdownBadge(size: 48, isCompact: true)

            VStack(alignment: .leading, spacing: 3) {
                statusPill

                Text(floatingTaskTitle)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(floatingTaskSubtitle)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Button {
                model.toggleMainWindow()
            } label: {
                Image(systemName: "macwindow")
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(model.tr("显示或隐藏主窗口"))

            Image(systemName: "chevron.up")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
        }
        .padding(.horizontal, 12)
        .help(model.tr("点击展开"))
    }

    private var panelBeacon: some View {
        Circle()
            .fill(Color(red: 1.0, green: 0.12, blue: 0.18))
            .frame(width: model.isFloatingPanelCompact ? 10 : 11, height: model.isFloatingPanelCompact ? 10 : 11)
            .overlay {
                Circle()
                    .stroke(Color.white.opacity(0.92), lineWidth: 1.4)
            }
            .shadow(color: Color.red.opacity(0.48), radius: 5, y: 1)
            .accessibilityLabel(model.tr("悬浮窗位置标识"))
    }

    private var panelSurfaceOpacity: Double {
        min(max(model.settings.floatingPanelOpacity, 0), 1)
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            panelTopBar
            liveFocusCard

            if model.currentBlocks.count > 1 {
                simultaneousTasksSummary
            }

            nearbyTasksPanel
        }
        .padding(12)
    }

    private var nearbyTasksPanel: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label(model.tr("附近任务"), systemImage: "list.bullet.rectangle")
                    .font(.system(size: 13, weight: .semibold))
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(model.itemCountText(model.nearbyBlocksForFloatingPanel().count))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(model.nearbyBlocksForFloatingPanel()) { block in
                        compactTaskRow(block)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            model.settings.floatingPanelRowBackground.opacity(0.62 * panelSurfaceOpacity),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(model.settings.floatingPanelBorderColor.opacity(0.65 * panelSurfaceOpacity), lineWidth: 1)
        }
    }

    private var panelTopBar: some View {
        HStack(spacing: 8) {
            Button {
                model.toggleFloatingPanelSize()
            } label: {
                HStack(spacing: 7) {
                    Circle()
                        .fill(countdownProgressColor)
                        .frame(width: 8, height: 8)
                    Text(model.tr("实时执行"))
                        .font(.system(size: 13, weight: .bold))
                    Text(currentClockText)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(model.tr("点击顶部空白区域折叠"))

            opacityControl
                .frame(width: 174)

            Button {
                model.toggleMainWindow()
            } label: {
                Image(systemName: "macwindow")
                    .frame(width: 26, height: 24)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(model.tr("显示或隐藏主窗口"))

            Button {
                model.toggleFloatingPanelSize()
            } label: {
                Image(systemName: "chevron.down")
                    .frame(width: 26, height: 24)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(model.tr("折叠悬浮窗"))
        }
        .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
    }

    private var liveFocusCard: some View {
        HStack(alignment: .center, spacing: 14) {
            countdownBadge(size: 92, isCompact: false)

            VStack(alignment: .leading, spacing: 8) {
                statusPill

                Text(floatingTaskTitle)
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(floatingTaskSubtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 7) {
                    progressBar

                    Text(progressPercentText)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .frame(width: 38, alignment: .trailing)
                }

                if let focusedBlock {
                    focusActions(for: focusedBlock)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    countdownCoolColor.opacity(0.36 * panelSurfaceOpacity),
                    countdownMintColor.opacity(0.26 * panelSurfaceOpacity),
                    countdownWarmColor.opacity(0.16 * panelSurfaceOpacity),
                    model.settings.floatingPanelHeaderBackground.opacity(panelSurfaceOpacity)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(countdownProgressColor.opacity((model.currentBlock == nil ? 0.35 : 0.66) * panelSurfaceOpacity), lineWidth: 1.4)
        }
    }

    private func focusActions(for block: TimeBlock) -> some View {
        HStack(spacing: 7) {
            Button {
                if block.status == .done {
                    model.toggleBlockCompletion(block.id)
                } else {
                    model.markBlockDone(block.id)
                }
            } label: {
                Label(block.status == .done ? model.tr("取消完成") : model.tr("完成"), systemImage: block.status == .done ? "arrow.uturn.backward.circle" : "checkmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(model.settings.accentColor)

            Button {
                model.skipBlock(block.id)
            } label: {
                Label(block.status == .skipped ? model.tr("取消跳过") : model.tr("跳过"), systemImage: block.status == .skipped ? "arrow.uturn.backward.circle" : "forward.end")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(block.status == .done)

            Button {
                model.delayBlock(block.id)
            } label: {
                Label(block.status == .delayed ? model.tr("取消推迟") : model.tr("推迟 20 分钟"), systemImage: block.status == .delayed ? "arrow.uturn.backward.circle" : "clock.badge.exclamationmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.orange)
            .disabled(block.status == .done)
        }
        .font(.caption)
        .controlSize(.small)
    }

    private var simultaneousTasksSummary: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(model.trf("同时进行 %d 项", model.currentBlocks.count), systemImage: "rectangle.stack.badge.play")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(model.settings.accentColor)

            ForEach(model.currentBlocks.prefix(3)) { block in
                HStack(spacing: 6) {
                    Circle()
                        .fill(TimeBlockStatus.active.tint)
                        .frame(width: 6, height: 6)
                    Text(block.title)
                        .font(.caption)
                        .lineLimit(1)
                    Spacer()
                    Text("\(block.start.displayString)-\(block.end.displayString)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(TimeBlockStatus.active.softBackground.opacity(panelSurfaceOpacity), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var opacityControl: some View {
        HStack(spacing: 8) {
            Image(systemName: "circle.lefthalf.filled")
                .foregroundStyle(.secondary)
                .frame(width: 18)

            Text(model.tr("透明"))
                .font(.caption2)
                .foregroundStyle(.secondary)

            Slider(
                value: $model.settings.floatingPanelOpacity,
                in: 0.0...1.0,
                step: 0.05,
                onEditingChanged: { isEditing in
                    if !isEditing {
                        model.saveSettings()
                    }
                }
            )

            Text("\(Int(model.settings.floatingPanelOpacity * 100))%")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 38, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.22), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .help(model.tr("调整悬浮窗透明度"))
    }

    private func taskRow(_ block: TimeBlock) -> some View {
        let isCurrent = model.currentBlocks.contains { $0.id == block.id }
        let isSelected = block.id == model.selectedBlockID
        return HStack(spacing: 8) {
            Text(block.start.displayString)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .leading)

            RoundedRectangle(cornerRadius: 2)
                .fill(isCurrent ? TimeBlockStatus.active.tint : block.status.tint)
                .frame(width: 4, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(block.title)
                    .font(.system(size: isCurrent ? 13 : 12, weight: isCurrent ? .semibold : .regular))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(model.statusTitle(block.status))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            HStack(spacing: 4) {
                Button {
                    if block.status == .done {
                        model.toggleBlockCompletion(block.id)
                    } else {
                        model.markBlockDone(block.id)
                    }
                } label: {
                    Image(systemName: block.status == .done ? "arrow.uturn.backward.circle" : "checkmark.circle")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .foregroundStyle(block.status == .done ? .secondary : model.settings.accentColor)
                .help(block.status == .done ? model.tr("改回待开始") : model.tr("标记完成"))

                Button {
                    model.skipBlock(block.id)
                } label: {
                    Image(systemName: block.status == .skipped ? "arrow.uturn.backward.circle" : "forward.end")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .foregroundStyle(block.status == .skipped ? model.settings.accentColor : .secondary)
                .disabled(block.status == .done)
                .help(block.status == .skipped ? model.tr("取消跳过") : model.tr("跳过"))

                Button {
                    model.delayBlock(block.id)
                } label: {
                    Image(systemName: block.status == .delayed ? "arrow.uturn.backward.circle" : "clock.badge.exclamationmark")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .foregroundStyle(block.status == .delayed ? model.settings.accentColor : .orange)
                .disabled(block.status == .done)
                .help(block.status == .delayed ? model.tr("取消推迟并整体回退 20 分钟") : model.tr("整体顺延 20 分钟"))
            }
            .font(.system(size: 15, weight: .semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            rowBackground(for: block, isCurrent: isCurrent).opacity(panelSurfaceOpacity),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke((isSelected ? model.settings.accentColor.opacity(0.62) : rowBorder(for: block, isCurrent: isCurrent)).opacity(panelSurfaceOpacity), lineWidth: isSelected ? 1.5 : 1)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            model.selectBlock(block)
        }
        .help(model.tr("点击选中，或直接完成、跳过、推迟"))
    }

    private func compactTaskRow(_ block: TimeBlock) -> some View {
        let isCurrent = model.currentBlocks.contains { $0.id == block.id }
        let isSelected = block.id == model.selectedBlockID
        return HStack(spacing: 9) {
            RoundedRectangle(cornerRadius: 2)
                .fill(isCurrent ? TimeBlockStatus.active.tint : block.status.tint)
                .frame(width: 5, height: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(block.title)
                    .font(.system(size: isCurrent ? 14 : 13, weight: isCurrent ? .semibold : .regular))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("\(block.start.displayString)-\(block.end.displayString) · \(model.statusTitle(block.status))")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            rowBackground(for: block, isCurrent: isCurrent).opacity(panelSurfaceOpacity),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke((isSelected ? model.settings.accentColor.opacity(0.62) : rowBorder(for: block, isCurrent: isCurrent)).opacity(panelSurfaceOpacity), lineWidth: isSelected ? 1.5 : 1)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            model.selectBlock(block)
        }
        .help(model.tr("点击选中任务"))
    }

    private func rowBackground(for block: TimeBlock, isCurrent: Bool) -> Color {
        if isCurrent {
            return TimeBlockStatus.active.softBackground
        }
        if block.status == .done {
            return TimeBlockStatus.done.softBackground
        }
        return model.settings.floatingPanelRowBackground
    }

    private func rowBorder(for block: TimeBlock, isCurrent: Bool) -> Color {
        if isCurrent {
            return TimeBlockStatus.active.tint.opacity(0.45)
        }
        return block.status.tint.opacity(block.status == .planned ? 0.18 : 0.35)
    }

    private var focusHeader: some View {
        HStack(spacing: 12) {
            countdownBadge(size: 72, isCompact: false)

            VStack(alignment: .leading, spacing: 6) {
                statusPill

                Text(floatingTaskTitle)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(floatingTaskSubtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 7) {
                    progressBar

                    Text(progressPercentText)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .frame(width: 38, alignment: .trailing)
                }
            }

            Spacer(minLength: 4)

            VStack(spacing: 8) {
                Button {
                    model.toggleMainWindow()
                } label: {
                    Image(systemName: "macwindow")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help(model.tr("显示或隐藏主窗口"))

                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
            }
        }
        .padding(10)
        .background(
            LinearGradient(
                colors: [
                    countdownCoolColor.opacity(0.34 * panelSurfaceOpacity),
                    countdownMintColor.opacity(0.24 * panelSurfaceOpacity),
                    countdownWarmColor.opacity(0.18 * panelSurfaceOpacity),
                    model.settings.floatingPanelHeaderBackground.opacity(panelSurfaceOpacity)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(countdownProgressColor.opacity((model.currentBlock == nil ? 0.34 : 0.62) * panelSurfaceOpacity), lineWidth: 1.4)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            model.toggleFloatingPanelSize()
        }
        .help(model.tr("点击顶部折叠"))
    }

    private func countdownBadge(size: CGFloat, isCompact: Bool) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            countdownCoolColor.opacity(model.currentBlock == nil ? 0.18 : 0.34),
                            countdownMintColor.opacity(model.currentBlock == nil ? 0.12 : 0.26)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .stroke(Color.white.opacity(0.7), lineWidth: isCompact ? 4 : 7)

            Circle()
                .trim(from: 0, to: countdownProgress)
                .stroke(
                    AngularGradient(
                        colors: [
                            countdownCoolColor,
                            countdownMintColor,
                            countdownWarmColor,
                            countdownCoralColor,
                            countdownCoolColor
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: isCompact ? 4 : 7, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: -1) {
                Text(countdownPrimaryText)
                    .font(.system(size: isCompact ? 14 : 22, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.58)
                    .lineLimit(1)
                Text(countdownSecondaryText)
                    .font(.system(size: isCompact ? 8 : 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: countdownCoolColor.opacity(model.currentBlock == nil ? 0.12 : 0.34), radius: isCompact ? 5 : 10, y: isCompact ? 1 : 3)
        .shadow(color: countdownCoralColor.opacity(model.currentBlock == nil ? 0.04 : 0.14), radius: isCompact ? 3 : 7, y: 0)
        .help(floatingTaskSubtitle)
    }

    private var statusPill: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(countdownProgressColor)
                .frame(width: 6, height: 6)
            Text(floatingStatusText)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(countdownProgressColor)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(countdownProgressColor.opacity(0.20), in: Capsule())
        .overlay {
            Capsule()
                .stroke(countdownProgressColor.opacity(0.38), lineWidth: 0.8)
        }
    }

    private var progressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.58))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [countdownCoolColor, countdownMintColor, countdownWarmColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(6, proxy.size.width * countdownProgress))
            }
        }
        .frame(height: 6)
    }

    private var floatingTaskTitle: String {
        if model.currentBlocks.count > 1, let first = model.currentBlocks.first {
            return model.trf("%@ 等 %d 项", first.title, model.currentBlocks.count)
        }
        return focusedBlock?.title ?? model.tr("没有事项")
    }

    private var floatingTaskSubtitle: String {
        if let block = model.currentBlock,
           let remainingSeconds = currentRemainingSeconds {
            return "\(block.start.displayString)-\(block.end.displayString) · \(model.tr("剩余")) \(durationText(remainingSeconds))"
        }
        if let next = model.nextBlock,
           let startsInSeconds = nextStartsInSeconds {
            return "\(next.start.displayString)-\(next.end.displayString) · \(durationText(startsInSeconds)) \(model.tr("后开始"))"
        }
        return model.tr("今天已结束")
    }

    private var countdownPrimaryText: String {
        if model.currentBlock != nil,
           let remainingSeconds = currentRemainingSeconds {
            return compactDurationText(remainingSeconds)
        }
        if model.nextBlock != nil,
           let startsInSeconds = nextStartsInSeconds {
            return compactDurationText(startsInSeconds)
        }
        return "✓"
    }

    private var countdownSecondaryText: String {
        if model.currentBlock != nil {
            return model.tr("剩余")
        }
        if model.nextBlock != nil {
            return model.tr("后开始")
        }
        return model.tr("完成")
    }

    private var countdownProgress: Double {
        guard let block = model.currentBlock else { return 0 }
        guard let startDate = todayDate(at: block.start),
              let endDate = todayDate(at: block.end)
        else { return 0 }
        let total = endDate.timeIntervalSince(startDate)
        guard total > 0 else { return 0 }
        let elapsed = model.now.timeIntervalSince(startDate)
        return min(1, max(0, elapsed / total))
    }

    private var countdownProgressColor: Color {
        if model.currentBlock != nil {
            return countdownCoolColor
        }
        if model.nextBlock != nil {
            return countdownWaitingColor
        }
        return countdownDoneColor
    }

    private var countdownCoolColor: Color {
        switch model.settings.countdownStyle {
        case .vivid:
            Color(red: 0.00, green: 0.74, blue: 1.00)
        case .mint:
            Color(red: 0.00, green: 0.86, blue: 0.62)
        case .sunset:
            Color(red: 1.00, green: 0.52, blue: 0.18)
        case .candy:
            Color(red: 0.52, green: 0.68, blue: 1.00)
        }
    }

    private var countdownMintColor: Color {
        switch model.settings.countdownStyle {
        case .vivid:
            Color(red: 0.22, green: 0.96, blue: 0.68)
        case .mint:
            Color(red: 0.56, green: 1.00, blue: 0.52)
        case .sunset:
            Color(red: 1.00, green: 0.82, blue: 0.20)
        case .candy:
            Color(red: 0.95, green: 0.52, blue: 1.00)
        }
    }

    private var countdownWarmColor: Color {
        switch model.settings.countdownStyle {
        case .vivid:
            Color(red: 1.00, green: 0.72, blue: 0.18)
        case .mint:
            Color(red: 0.18, green: 0.74, blue: 1.00)
        case .sunset:
            Color(red: 1.00, green: 0.28, blue: 0.42)
        case .candy:
            Color(red: 1.00, green: 0.80, blue: 0.34)
        }
    }

    private var countdownCoralColor: Color {
        switch model.settings.countdownStyle {
        case .vivid:
            Color(red: 1.00, green: 0.26, blue: 0.42)
        case .mint:
            Color(red: 0.00, green: 0.68, blue: 0.92)
        case .sunset:
            Color(red: 1.00, green: 0.62, blue: 0.12)
        case .candy:
            Color(red: 1.00, green: 0.36, blue: 0.72)
        }
    }

    private var countdownWaitingColor: Color {
        switch model.settings.countdownStyle {
        case .vivid:
            Color(red: 0.43, green: 0.60, blue: 1.00)
        case .mint:
            Color(red: 0.25, green: 0.78, blue: 0.72)
        case .sunset:
            Color(red: 1.00, green: 0.58, blue: 0.22)
        case .candy:
            Color(red: 0.78, green: 0.48, blue: 1.00)
        }
    }

    private var countdownDoneColor: Color {
        switch model.settings.countdownStyle {
        case .vivid:
            Color(red: 0.18, green: 0.86, blue: 0.44)
        case .mint:
            Color(red: 0.12, green: 0.88, blue: 0.48)
        case .sunset:
            Color(red: 1.00, green: 0.74, blue: 0.16)
        case .candy:
            Color(red: 0.34, green: 0.82, blue: 1.00)
        }
    }

    private var floatingStatusText: String {
        if model.currentBlocks.count > 1 {
            return model.trf("进行中 · %d项", model.currentBlocks.count)
        }
        if model.currentBlock != nil {
            return model.tr("进行中")
        }
        if model.nextBlock != nil {
            return model.tr("下一项")
        }
        return model.tr("已完成")
    }

    private var progressPercentText: String {
        guard model.currentBlock != nil else {
            return "--"
        }
        return "\(Int((countdownProgress * 100).rounded()))%"
    }

    private var focusedBlock: TimeBlock? {
        model.currentBlock ?? model.nextBlock
    }

    private var currentClockText: String {
        let components = Calendar.current.dateComponents([.hour, .minute, .second], from: model.now)
        return String(
            format: "%02d:%02d:%02d",
            components.hour ?? 0,
            components.minute ?? 0,
            components.second ?? 0
        )
    }

    private var currentRemainingSeconds: Int? {
        guard let block = model.currentBlock,
              let endDate = todayDate(at: block.end)
        else { return nil }
        return max(0, Int(ceil(endDate.timeIntervalSince(model.now))))
    }

    private var nextStartsInSeconds: Int? {
        guard let next = model.nextBlock,
              let startDate = todayDate(at: next.start)
        else { return nil }
        return max(0, Int(ceil(startDate.timeIntervalSince(model.now))))
    }

    private func todayDate(at time: ClockTime) -> Date? {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: model.now)
        components.hour = time.hour
        components.minute = time.minute
        components.second = 0
        return Calendar.current.date(from: components)
    }

    private func compactDurationText(_ seconds: Int) -> String {
        if seconds >= 3600 {
            let hours = seconds / 3600
            let minutes = (seconds % 3600) / 60
            return "\(hours):\(String(format: "%02d", minutes))"
        }
        if seconds >= 60 {
            let minutes = seconds / 60
            let remainingSeconds = seconds % 60
            return "\(minutes):\(String(format: "%02d", remainingSeconds))"
        }
        return "\(seconds)s"
    }

    private func durationText(_ seconds: Int) -> String {
        return model.durationText(seconds: seconds)
    }

    private var timelineTargetSkipTitle: String {
        model.timelineActionTargetBlock?.status == .skipped ? model.tr("取消跳过") : model.tr("跳过")
    }

    private var timelineTargetSkipIcon: String {
        model.timelineActionTargetBlock?.status == .skipped ? "arrow.uturn.backward.circle" : "forward.end"
    }

    private var timelineTargetDelayTitle: String {
        model.timelineActionTargetBlock?.status == .delayed ? model.tr("取消推迟") : model.tr("推迟 20 分钟")
    }

    private var timelineTargetDelayIcon: String {
        model.timelineActionTargetBlock?.status == .delayed ? "arrow.uturn.backward.circle" : "clock.badge.exclamationmark"
    }
}

#Preview {
    FloatingPanelView()
        .environmentObject(AppModel())
}
