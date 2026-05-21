import AppKit
import SwiftUI

@MainActor
final class FloatingPanelController {
    private var panel: NSPanel?
    private let compactSize = NSSize(width: 306, height: 76)
    private let minimumExpandedSize = NSSize(width: 520, height: 280)
    private var expandedSize = NSSize(width: 520, height: 340)

    func show(model: AppModel) {
        if panel == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 120, y: 120, width: expandedSize.width, height: expandedSize.height),
                styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView, .resizable],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            panel.isMovableByWindowBackground = true
            panel.standardWindowButton(.zoomButton)?.isHidden = true
            panel.standardWindowButton(.zoomButton)?.isEnabled = false
            panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
            panel.standardWindowButton(.closeButton)?.isHidden = true
            panel.contentView = NSHostingView(
                rootView: FloatingPanelView()
                    .environmentObject(model)
            )
            self.panel = panel
        }

        panel?.orderFrontRegardless()
        setCompact(model.isFloatingPanelCompact)
    }

    func setCompact(_ compact: Bool) {
        guard let panel else { return }
        let size: NSSize
        if compact {
            if panel.frame.width > compactSize.width || panel.frame.height > compactSize.height {
                expandedSize = panel.frame.size
            }
            panel.styleMask.remove(.resizable)
            panel.minSize = compactSize
            panel.maxSize = compactSize
            size = compactSize
        } else {
            panel.styleMask.insert(.resizable)
            panel.minSize = minimumExpandedSize
            panel.maxSize = NSSize(width: 980, height: 520)
            panel.standardWindowButton(.zoomButton)?.isHidden = true
            panel.standardWindowButton(.zoomButton)?.isEnabled = false
            size = normalizedExpandedSize
        }
        var frame = panel.frame
        frame.origin.y += frame.height - size.height
        frame.size = size
        panel.setFrame(frame, display: true, animate: true)
    }

    private var normalizedExpandedSize: NSSize {
        NSSize(
            width: max(expandedSize.width, minimumExpandedSize.width),
            height: max(expandedSize.height, minimumExpandedSize.height)
        )
    }
}
