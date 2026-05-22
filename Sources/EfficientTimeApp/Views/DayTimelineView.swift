import EfficientTimeCore
import SwiftUI

struct DayTimelineView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(model.visiblePlanBlocks) { block in
                        blockRow(block)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .padding(.top)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(model.selectedDateTitle)时间表")
                    .font(.title2)
                    .fontWeight(.semibold)
                HStack(spacing: 8) {
                    Text("完成 \(model.completedCount)/\(model.visiblePlanBlocks.count) · \(model.availableWindowsText)")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text(model.todayPlan.status.title)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .foregroundStyle(model.settings.accentColor)
                        .background(model.settings.accentColor.opacity(0.12), in: Capsule())
                }
            }

            Spacer()

            Button {
                model.startDay()
            } label: {
                Label("开始执行", systemImage: "play.circle")
            }
            .buttonStyle(.borderedProminent)
            .tint(model.settings.accentColor)
            .disabled(model.visiblePlanBlocks.isEmpty || model.todayPlan.status == .running || model.todayPlan.status == .finished)
        }
        .padding(.horizontal)
    }

    private func blockRow(_ block: TimeBlock) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(block.start.displayString)
                Text(block.end.displayString)
                    .foregroundStyle(.secondary)
            }
            .font(.system(.body, design: .monospaced))
            .frame(width: 56, alignment: .trailing)

            Rectangle()
                .fill(block.status.tint)
                .frame(width: 4)
                .clipShape(RoundedRectangle(cornerRadius: 2))

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(block.title)
                        .font(.headline)
                    Spacer()
                    Text(block.status.title)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .foregroundStyle(block.status.tint)
                        .background(block.status.softBackground)
                        .clipShape(Capsule())
                }
                Text("\(block.durationMinutes) 分钟")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(rowBackground(for: block), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(model.selectedBlockID == block.id ? model.settings.accentColor : Color.clear, lineWidth: 2)
        }
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture {
            model.selectBlock(block)
        }
        .contextMenu {
            Button {
                model.markBlockDone(block.id)
            } label: {
                Label("完成", systemImage: "checkmark.circle")
            }

            Button {
                model.skipBlock(block.id)
            } label: {
                Label(block.status == .skipped ? "取消跳过" : "跳过", systemImage: block.status == .skipped ? "arrow.uturn.backward.circle" : "forward.end")
            }
            .disabled(block.status == .done)

            Button {
                model.delayBlock(block.id)
            } label: {
                Label(block.status == .delayed ? "取消推迟" : "推迟 20 分钟", systemImage: block.status == .delayed ? "arrow.uturn.backward.circle" : "clock.badge.exclamationmark")
            }
            .disabled(block.status == .done)

            Divider()

            Button(role: .destructive) {
                model.deleteBlock(block.id)
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }

    private func rowBackground(for block: TimeBlock) -> Color {
        if model.currentBlocks.contains(where: { $0.id == block.id }) {
            return TimeBlockStatus.active.softBackground
        }
        return block.status.softBackground.opacity(block.status == .planned ? 0.45 : 0.9)
    }
}

#Preview {
    DayTimelineView()
        .environmentObject(AppModel())
}
