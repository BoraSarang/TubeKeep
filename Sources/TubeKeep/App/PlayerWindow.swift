import AppKit
#if DEBUG
import Foundation
#endif

final class PlayerWindow: NSWindow {
    #if DEBUG
    deinit {
        DebugLogManager.shared?.append("[App] PlayerWindow 해제 \(ObjectIdentifier(self).hashValue)")
    }
    #endif

    // 닫기 버튼·ESC는 창을 진짜 닫지 않고 숨긴다. 창·PlayerView·MPVClient를
    // 앱 생명주기 동안 1개만 유지해 재사용하면 인스턴스 누수가 원천적으로
    // 발생하지 않는다. (T-1208)
    override func performClose(_ sender: Any?) {
        NotificationCenter.default.post(name: Constants.playerHideNotification, object: self)
        orderOut(sender)
    }

    override func cancelOperation(_ sender: Any?) {
        if styleMask.contains(.fullScreen) {
            toggleFullScreen(sender)
        } else {
            performClose(sender)
        }
    }

    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        if modifiers.contains(.command), modifiers.contains(.shift) {
            switch event.charactersIgnoringModifiers?.lowercased() {
            case "s":
                NotificationCenter.default.post(name: Constants.playerToggleSubtitlePanelNotification, object: self)
                return
            case "q":
                NotificationCenter.default.post(name: Constants.playerToggleQueueNotification, object: self)
                return
            case "p":
                NotificationCenter.default.post(name: Constants.playerToggleSimilarVideosNotification, object: self)
                return
            default:
                break
            }
        }
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
