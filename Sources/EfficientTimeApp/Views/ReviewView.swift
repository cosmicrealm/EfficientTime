import SwiftUI

struct ReviewView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("\(model.selectedDateTitle)复盘")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    model.finishDay()
                } label: {
                    Label("结束", systemImage: "stop.circle")
                }
                Button {
                    model.runConfiguredAIReview()
                } label: {
                    Label("\(model.settings.aiProvider.title) 复盘", systemImage: "sparkles")
                }
                .disabled(model.isReviewingWithAI)
            }

            Text(model.reviewSummary)
                .font(.body)
                .textSelection(.enabled)
                .padding()
                .background(.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            if !model.reviewAISummary.isEmpty {
                Text(model.reviewAISummary)
                    .textSelection(.enabled)
                    .padding()
                    .background(.green.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            List(model.visiblePlanBlocks) { block in
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(block.title)
                        Text("\(block.start.displayString)-\(block.end.displayString)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let actual = model.actualDurationMinutes(for: block) {
                        Text("实际 \(actual)m")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("未记录")
                            .foregroundStyle(.tertiary)
                    }
                    Text(block.status.title)
                        .frame(width: 80, alignment: .trailing)
                        .foregroundStyle(block.status.tint)
                }
            }
        }
        .padding()
    }
}

#Preview {
    ReviewView()
        .environmentObject(AppModel())
}
