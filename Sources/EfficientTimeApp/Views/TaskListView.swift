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
                Label("快速添加", systemImage: "plus.circle.fill")
                    .font(.headline)
                Spacer()
                Text(model.selectedDateTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            TextField("任务名称", text: $title)
                .textFieldStyle(.roundedBorder)

            HStack {
                TextField("开始 默认 \(planningDefaultStartText)", text: $startText)
                    .textFieldStyle(.roundedBorder)
                TextField("结束 默认 +90 分钟", text: $endText)
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
                Label("添加", systemImage: "plus.circle")
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
            Text("时间冲突")
                .font(.subheadline)
                .fontWeight(.semibold)
            Text("新事项「\(conflict.proposedTitle)」\(conflict.proposedStart.displayString)-\(conflict.proposedEnd.displayString) 与「\(conflict.conflictingBlock.title)」\(conflict.conflictingBlock.start.displayString)-\(conflict.conflictingBlock.end.displayString) 重叠。")
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
                   conflict.editedBlockID == nil {
                    Button("按建议时间添加") {
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
                Button("修改新事项时间") {
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

    private var planningDefaultStartText: String {
        let schedule = model.settings.aiPlanningDefaults.isValid ? model.settings.aiPlanningDefaults : AIPlanningDefaults.standard
        return schedule.start.displayString
    }
}

#Preview {
    QuickAddTaskView()
        .environmentObject(AppModel())
}
