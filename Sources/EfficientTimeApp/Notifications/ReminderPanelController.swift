import AppKit
import SwiftUI

@MainActor
final class ReminderPanelController {
    private var panel: NSPanel?
    private var dismissWorkItem: DispatchWorkItem?
    private var queue: [ReminderPanelMessage] = []
    private var isShowing = false

    func show(title: String, body: String, kind: ReminderPanelKind) {
        queue.append(ReminderPanelMessage(title: title, message: body, kind: kind))
        showNextIfNeeded()
    }

    private func showNextIfNeeded() {
        guard !isShowing,
              !queue.isEmpty
        else { return }

        isShowing = true
        let message = queue.removeFirst()
        dismissWorkItem?.cancel()

        let panel = panel ?? makePanel()
        panel.contentView = NSHostingView(
            rootView: ReminderPanelView(title: message.title, message: message.message, kind: message.kind)
        )

        if let screenFrame = NSScreen.main?.visibleFrame {
            let size = NSSize(width: 440, height: 128)
            let origin = NSPoint(
                x: screenFrame.midX - size.width / 2,
                y: screenFrame.maxY - size.height - 24
            )
            panel.setFrame(NSRect(origin: origin, size: size), display: true)
        }

        panel.orderFrontRegardless()
        NSApp.requestUserAttention(.informationalRequest)
        self.panel = panel

        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.panel?.orderOut(nil)
                self?.isShowing = false
                self?.showNextIfNeeded()
            }
        }
        dismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + message.kind.displayDuration, execute: workItem)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 128),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        return panel
    }
}

enum ReminderPanelKind {
    case start
    case end

    var accentColor: Color {
        switch self {
        case .start: Color(red: 0.09, green: 0.48, blue: 0.62)
        case .end: Color(red: 0.93, green: 0.12, blue: 0.18)
        }
    }

    var symbolName: String {
        switch self {
        case .start: "play.circle.fill"
        case .end: "bell.badge.fill"
        }
    }

    var displayDuration: Double {
        switch self {
        case .start: 8
        case .end: 14
        }
    }
}

private struct ReminderPanelMessage {
    var title: String
    var message: String
    var kind: ReminderPanelKind
}

private struct ReminderPanelView: View {
    var title: String
    var message: String
    var kind: ReminderPanelKind

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: kind.symbolName)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(kind.accentColor, in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(message)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(width: 440, height: 128)
        .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(kind.accentColor.opacity(0.55), lineWidth: 2)
        }
    }
}
