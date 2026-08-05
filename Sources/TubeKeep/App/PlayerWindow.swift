import AppKit

final class PlayerWindow: NSWindow {
    override func cancelOperation(_ sender: Any?) {
        if styleMask.contains(.fullScreen) {
            toggleFullScreen(sender)
        } else {
            close()
        }
    }
}
