import AppKit

final class PlayerWindow: NSWindow {
    override func cancelOperation(_ sender: Any?) {
        if styleMask.contains(.fullScreen) {
            toggleFullScreen(sender)
        } else {
            close()
        }
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 49: // Space (macOS virtual keycode)
            postTogglePlayPause()
        case 123: // ←
            postSeek(direction: -1)
        case 124: // →
            postSeek(direction: 1)
        default:
            super.keyDown(with: event)
        }
    }

    private func postTogglePlayPause() {
        NotificationCenter.default.post(
            name: Constants.playerTogglePlayPauseNotification,
            object: self
        )
    }

    private func postSeek(direction: Double) {
        NotificationCenter.default.post(
            name: Constants.playerSeekNotification,
            object: self,
            userInfo: ["direction": direction]
        )
    }
}
