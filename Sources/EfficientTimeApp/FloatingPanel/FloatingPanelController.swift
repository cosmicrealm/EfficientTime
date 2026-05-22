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
        let currentFrame = panel.frame
        let mouseAnchor = mouseAnchor(in: currentFrame)
        let size: NSSize
        if compact {
            if currentFrame.width > compactSize.width || currentFrame.height > compactSize.height {
                expandedSize = currentFrame.size
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
        let frame = resizedFrame(
            from: currentFrame,
            to: size,
            mouseAnchor: mouseAnchor,
            screen: panel.screen
        )
        panel.setFrame(frame, display: true, animate: true)
    }

    private func mouseAnchor(in frame: NSRect) -> NSPoint? {
        let mouse = NSEvent.mouseLocation
        guard frame.contains(mouse), frame.width > 0, frame.height > 0 else {
            return nil
        }
        return NSPoint(
            x: (mouse.x - frame.minX) / frame.width,
            y: (mouse.y - frame.minY) / frame.height
        )
    }

    private func resizedFrame(
        from frame: NSRect,
        to size: NSSize,
        mouseAnchor: NSPoint?,
        screen: NSScreen?
    ) -> NSRect {
        var nextFrame = frame
        if let mouseAnchor {
            let mouse = NSEvent.mouseLocation
            nextFrame.origin = NSPoint(
                x: mouse.x - size.width * mouseAnchor.x,
                y: mouse.y - size.height * mouseAnchor.y
            )
        } else {
            nextFrame.origin.y += frame.height - size.height
        }
        nextFrame.size = size
        return clamped(nextFrame, to: screen?.visibleFrame)
    }

    private func clamped(_ frame: NSRect, to visibleFrame: NSRect?) -> NSRect {
        guard let visibleFrame else { return frame }
        var clampedFrame = frame
        clampedFrame.origin.x = min(
            max(clampedFrame.origin.x, visibleFrame.minX),
            visibleFrame.maxX - clampedFrame.width
        )
        clampedFrame.origin.y = min(
            max(clampedFrame.origin.y, visibleFrame.minY),
            visibleFrame.maxY - clampedFrame.height
        )
        return clampedFrame
    }

    private var normalizedExpandedSize: NSSize {
        NSSize(
            width: max(expandedSize.width, minimumExpandedSize.width),
            height: max(expandedSize.height, minimumExpandedSize.height)
        )
    }
}
