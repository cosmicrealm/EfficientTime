import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let current = model.currentBlock {
                Text(model.trf("当前：%@", current.title))
                Text("\(current.start.displayString)-\(current.end.displayString)")
                    .foregroundStyle(.secondary)
                if let remaining = model.currentRemainingMinutes {
                    Text(model.trf("剩余 %d 分钟", remaining))
                        .foregroundStyle(.secondary)
                }
            } else if let next = model.nextBlock {
                Text(model.trf("下一个：%@", next.title))
                Text(next.start.displayString)
                    .foregroundStyle(.secondary)
            } else {
                Text(model.tr("今天没有更多任务"))
            }

            Divider()

            Button(model.tr("开始今天")) {
                model.startDay()
            }

            Button(model.tr("完成当前")) {
                model.markCurrentDone()
            }

            Button(model.tr("跳过当前")) {
                model.skipCurrent()
            }

            Button(model.tr("显示悬浮窗")) {
                model.showFloatingPanel()
            }

            Button(model.tr("结束今天")) {
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
