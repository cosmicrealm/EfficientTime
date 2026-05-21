import SwiftUI

struct BlockDetailView: View {
    @EnvironmentObject private var model: AppModel
    @State private var startText = ""
    @State private var endText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("时间块")
                .font(.headline)
                .padding(.top)

            if let block = model.selectedBlock {
                VStack(alignment: .leading, spacing: 8) {
                    Text(block.title)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .lineLimit(3)

                    Text("\(block.start.displayString)-\(block.end.displayString)")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)

                    Text("\(block.durationMinutes) 分钟")
                        .foregroundStyle(.secondary)

                    Divider()

                    HStack {
                        Text("状态")
                        Spacer()
                        Text(block.status.title)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .foregroundStyle(block.status.tint)
                            .background(block.status.softBackground)
                            .clipShape(Capsule())
                    }

                    Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 8) {
                        GridRow {
                            Text("开始")
                            TextField("09:00", text: $startText)
                        }
                        GridRow {
                            Text("结束")
                            TextField("10:00", text: $endText)
                        }
                    }
                    .textFieldStyle(.roundedBorder)

                    Button {
                        _ = model.updateSelectedBlock(startText: startText, endText: endText)
                    } label: {
                        Label("更新时间", systemImage: "calendar.badge.clock")
                    }

                    if let conflict = model.pendingConflict {
                        conflictPanel(conflict)
                    }

                    Button {
                        model.markSelectedDone()
                    } label: {
                        Label("完成", systemImage: "checkmark.circle")
                    }

                    Button {
                        model.skipSelected()
                    } label: {
                        Label("跳过", systemImage: "forward.end")
                    }

                    Button {
                        model.delaySelected()
                    } label: {
                        Label("推迟", systemImage: "clock.badge.exclamationmark")
                    }

                    Button(role: .destructive) {
                        model.deleteSelectedBlock()
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
            } else {
                Text("选择一个时间块")
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal)
        .onAppear(perform: syncFields)
        .onChange(of: model.selectedBlockID) { _, _ in
            syncFields()
        }
    }

    private func syncFields() {
        guard let block = model.selectedBlock else { return }
        startText = block.start.displayString
        endText = block.end.displayString
    }

    private func conflictPanel(_ conflict: ScheduleConflict) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("时间冲突")
                .font(.subheadline)
                .fontWeight(.semibold)
            Text("当前时间 \(conflict.proposedStart.displayString)-\(conflict.proposedEnd.displayString) 与「\(conflict.conflictingBlock.title)」重叠。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let suggestion = conflict.suggestedWindow {
                Text("建议改到 \(suggestion.start.displayString)-\(suggestion.end.displayString)，保持原任务时长并避开已有安排。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("当前可用时间段内没有找到同等时长的连续空档，可以缩短任务或调整可用时间段。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                if let suggestion = conflict.suggestedWindow,
                   conflict.editedBlockID == model.selectedBlockID {
                    Button("采用建议时间") {
                        startText = suggestion.start.displayString
                        endText = suggestion.end.displayString
                        _ = model.applyPendingConflictSuggestionToSelectedBlock()
                    }
                }
                Button("继续修改当前时间") {
                    startText = conflict.proposedStart.displayString
                    endText = conflict.proposedEnd.displayString
                    model.clearPendingConflict()
                }
                Button("去改冲突事项") {
                    model.selectPendingConflictBlock()
                }
            }
            .font(.caption)
        }
        .padding(10)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    BlockDetailView()
        .environmentObject(AppModel())
}
