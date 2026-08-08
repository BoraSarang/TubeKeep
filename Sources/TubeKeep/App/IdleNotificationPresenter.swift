import Cocoa
import SwiftUI

@MainActor
final class IdleNotificationPresenter {
    static let shared = IdleNotificationPresenter()

    private var panel: NSPanel?
    private weak var statusItem: NSStatusItem?
    private var dismissTask: Task<Void, Never>?

    func configure(statusItem: NSStatusItem?) {
        self.statusItem = statusItem
    }

    func show(title: String, message: String, systemImage: String, tint: Color = .accentColor) {
        dismiss()
        dismissTask?.cancel()

        NSSound(named: "Pop")?.play()

        let iconSize: CGFloat = 18
        let titleSize: CGFloat = 12
        let messageSize: CGFloat = 10
        let padding: CGFloat = 10
        let maxMessageWidth: CGFloat = 260

        let iconW: CGFloat = 28
        let titleW = (title as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: titleSize, weight: .semibold)]).width
        let messageW = (message as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: messageSize)]).width
        let width = min(max(iconW + titleW + messageW + padding * 2 + 6, 200), 340)
        let body = title.isEmpty ? message : "\(title)\n\(message)"
        let textH: CGFloat = title.isEmpty ? messageSize + 4 : (titleSize * 1.35) + (messageSize * 1.3) + 2
        let height = max(textH + padding * 2, 50)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .popUpMenu
        panel.collectionBehavior = [.transient, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true

        let hosting = NSHostingController(
            rootView: IdleNotificationView(
                title: title,
                message: message,
                systemImage: systemImage,
                tint: tint
            )
        )
        panel.contentViewController = hosting
        panel.setContentSize(NSSize(width: width, height: height))

        if let button = statusItem?.button, let buttonWindow = button.window {
            let buttonRect = button.convert(button.bounds, to: nil)
            let screenRect = buttonWindow.convertToScreen(buttonRect)
            let panelX = screenRect.midX - width / 2
            let panelY = screenRect.minY - height - 10
            panel.setFrameOrigin(NSPoint(x: panelX, y: panelY))
        }

        panel.orderFrontRegardless()
        self.panel = panel

        dismissTask = Task { [weak self, weak panel] in
            try? await Task.sleep(nanoseconds: 7_000_000_000)
            guard !Task.isCancelled else { return }
            guard let panel, panel == self?.panel else { return }
            self?.dismiss()
        }
    }

    func dismiss() {
        panel?.close()
        panel = nil
        dismissTask?.cancel()
        dismissTask = nil
    }
}

struct IdleNotificationView: View {
    let title: String
    let message: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 18))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                if !title.isEmpty {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                }
                Text(message)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(radius: 4)
    }
}