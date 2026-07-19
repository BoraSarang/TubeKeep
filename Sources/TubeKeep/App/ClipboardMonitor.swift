import Cocoa
import SwiftUI

@MainActor
final class ClipboardMonitor {
    private var timer: Timer?
    private var panel: NSPanel?
    private var lastURL: String?
    private weak var statusItem: NSStatusItem?
    var onVideoDetected: ((String) -> Void)?
    var onDismiss: (() -> Void)?

    func start(statusItem: NSStatusItem?) {
        self.statusItem = statusItem
        lastURL = NSPasteboard.general.string(forType: .string)

        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            let current = NSPasteboard.general.string(forType: .string)
            Task { @MainActor in
                guard let url = current, self.isVideoURL(url),
                      url != self.lastURL
                else { return }
                self.lastURL = url
                self.showNotification(url: url)
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func dismiss() {
        panel?.close()
        panel = nil
    }

    private func showNotification(url: String) {
        dismiss()

        NSSound(named: "Pop")?.play()

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 62),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .popUpMenu
        panel.collectionBehavior = [.transient, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true

        let hostingCtrl = NSHostingController(
            rootView: ClipboardNotificationView {
                self.dismiss()
                self.onVideoDetected?(url)
            }
        )
        panel.contentViewController = hostingCtrl
        panel.setContentSize(NSSize(width: 260, height: 62))

        if let button = statusItem?.button, let buttonWindow = button.window {
            let buttonRect = button.convert(button.bounds, to: nil)
            let screenRect = buttonWindow.convertToScreen(buttonRect)
            let panelX = screenRect.midX - 130
            let panelY = screenRect.minY - 72
            panel.setFrameOrigin(NSPoint(x: panelX, y: panelY))
        }

        panel.orderFrontRegardless()
        self.panel = panel

        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.dismiss()
        }
    }

    private func isVideoURL(_ string: String) -> Bool {
        guard let url = URL(string: string.trimmingCharacters(in: .whitespacesAndNewlines)),
              let host = url.host else { return false }
        let hostStr = host.lowercased()

        if hostStr.contains("youtu.be") {
            return true
        }

        if hostStr.contains("youtube.com") {
            let path = url.path.lowercased()
            return path == "/watch" || path.hasPrefix("/watch/")
        }

        return false
    }
}
