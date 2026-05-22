import SwiftUI

struct ReviewView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(model.trf("%@复盘", model.selectedDateTitle))
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    model.finishDay()
                } label: {
                    Label(model.tr("结束"), systemImage: "stop.circle")
                }
                Button {
                    model.runConfiguredAIReview()
                } label: {
                    Label(model.trf("%@ 复盘", model.settings.aiProvider.localizedTitle(model.effectiveLanguage)), systemImage: "sparkles")
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
                        Text(model.trf("实际 %dm", actual))
                            .foregroundStyle(.secondary)
                    } else {
                        Text(model.tr("未记录"))
                            .foregroundStyle(.tertiary)
                    }
                    Text(model.statusTitle(block.status))
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
