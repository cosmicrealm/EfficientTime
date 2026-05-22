import EfficientTimeCore
import SwiftUI

struct QuickAddTaskView: View {
    @EnvironmentObject private var model: AppModel
    @State private var title = ""
    @State private var startText = ""
    @State private var endText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(model.tr("快速添加"), systemImage: "plus.circle.fill")
                    .font(.headline)
                Spacer()
                Text(model.selectedDateTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            TextField(model.tr("任务名称"), text: $title)
                .textFieldStyle(.roundedBorder)

            HStack {
                TextField(model.trf("开始 默认 %@", planningDefaultStartText), text: $startText)
                    .textFieldStyle(.roundedBorder)
                TextField(model.tr("结束 默认 +90 分钟"), text: $endText)
                    .textFieldStyle(.roundedBorder)
            }

            Button {
                let added = model.addScheduledTask(title: title, startText: startText, endText: endText)
                if added {
                    title = ""
                    startText = ""
                    endText = ""
                }
            } label: {
                Label(model.tr("添加"), systemImage: "plus.circle")
            }
            .buttonStyle(.borderedProminent)
            .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if let conflict = model.pendingConflict {
                conflictPanel(conflict)
            }

            if let message = model.lastErrorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                .lineLimit(3)
            }
        }
        .padding()
        .background(Color.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 10)
        .padding(.top, 10)
    }

    private func conflictPanel(_ conflict: ScheduleConflict) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.tr("时间冲突"))
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(model.trf("新事项「%@」%@-%@ 与「%@」%@-%@ 重叠。", conflict.proposedTitle, conflict.proposedStart.displayString, conflict.proposedEnd.displayString, conflict.conflictingBlock.title, conflict.conflictingBlock.start.displayString, conflict.conflictingBlock.end.displayString))
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
                   conflict.editedBlockID == nil {
                    Button(model.tr("按建议时间添加")) {
                        startText = suggestion.start.displayString
                        endText = suggestion.end.displayString
                        let added = model.addScheduledTask(title: title, startText: startText, endText: endText)
                        if added {
                            title = ""
                            startText = ""
                            endText = ""
                        }
                    }
                }
                Button(model.tr("修改新事项时间")) {
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

    private var planningDefaultStartText: String {
        let schedule = model.settings.aiPlanningDefaults.isValid ? model.settings.aiPlanningDefaults : AIPlanningDefaults.standard
        return schedule.start.displayString
    }
}

#Preview {
    QuickAddTaskView()
        .environmentObject(AppModel())
}
