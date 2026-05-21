import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let current = model.currentBlock {
                Text("当前：\(current.title)")
                Text("\(current.start.displayString)-\(current.end.displayString)")
                    .foregroundStyle(.secondary)
                if let remaining = model.currentRemainingMinutes {
                    Text("剩余 \(remaining) 分钟")
                        .foregroundStyle(.secondary)
                }
            } else if let next = model.nextBlock {
                Text("下一个：\(next.title)")
                Text(next.start.displayString)
                    .foregroundStyle(.secondary)
            } else {
                Text("今天没有更多任务")
            }

            Divider()

            Button("开始今天") {
                model.startDay()
            }

            Button("完成当前") {
                model.markCurrentDone()
            }

            Button("跳过当前") {
                model.skipCurrent()
            }

            Button("显示悬浮窗") {
                model.showFloatingPanel()
            }

            Button("结束今天") {
                model.finishDay()
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    MenuBarView()
        .environmentObject(AppModel())
}
