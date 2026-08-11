import Cocoa

/// 전역 키 이벤트 처리 로직을 AppDelegate에서 분리한 핸들러.
/// AppDelegate는 설치(install)만 하고, 실제 키 바인딩 판정은 여기서 수행한다.
@MainActor
final class KeyCommandHandler {
    /// 스페이스바로 재생/일시정지할 플레이어 창이 현재 키 윈도우인지.
    let isPlayerKeyWindow: () -> Bool
    /// Cmd+스페이스가 아닌 스페이스바를 플레이어 토글로 소비할지 결정하는 후크.
    let onTogglePlayerPlayPause: () -> Void
    let onOpenSettings: () -> Void
    let onToggleDebugPanel: () -> Void
    let onToggleDebugAutoScroll: () -> Void

    init(
        isPlayerKeyWindow: @escaping () -> Bool,
        onTogglePlayerPlayPause: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onToggleDebugPanel: @escaping () -> Void,
        onToggleDebugAutoScroll: @escaping () -> Void
    ) {
        self.isPlayerKeyWindow = isPlayerKeyWindow
        self.onTogglePlayerPlayPause = onTogglePlayerPlayPause
        self.onOpenSettings = onOpenSettings
        self.onToggleDebugPanel = onToggleDebugPanel
        self.onToggleDebugAutoScroll = onToggleDebugAutoScroll
    }

    func handle(_ event: NSEvent) -> NSEvent? {
        // 영상 플레이어 창이 활성일 때 스페이스바(49) → 재생/일시정지
        if event.keyCode == 49 {
            #if DEBUG
            let cmd = event.modifierFlags.contains(.command)
            Task { @MainActor in
                DebugLogManager.shared?.append("[Key] Space — cmd=\(cmd) playerKey=\(self.isPlayerKeyWindow())")
            }
            #endif
            if !event.modifierFlags.contains(.command), isPlayerKeyWindow() {
                onTogglePlayerPlayPause()
                return nil
            }
        }
        if event.modifierFlags.contains(.command) {
            switch event.keyCode {
            case 43: // , (settings)
                onOpenSettings()
                return nil
            case 12: // q (quit)
                NSApp.terminate(nil)
                return nil
            case 7: // x (cut)
                NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil)
                return nil
            case 8: // c (copy)
                #if DEBUG
                if event.modifierFlags.contains(.shift) {
                    DebugLogManager.shared?.copySelection()
                    return nil
                }
                #endif
                NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil)
                return nil
            case 9: // v (paste)
                NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil)
                return nil
            case 0: // a (selectAll)
                #if DEBUG
                if event.modifierFlags.contains(.shift) {
                    DebugLogManager.shared?.copyAll()
                    return nil
                }
                #endif
                NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
                return nil
            case 2: // d (debug panel toggle)
                #if DEBUG
                onToggleDebugPanel()
                return nil
                #else
                return event
                #endif
            case 40: // k (clear logs)
                #if DEBUG
                DebugLogManager.shared?.clear()
                return nil
                #else
                return event
                #endif
            case 1: // s (auto scroll toggle)
                #if DEBUG
                if event.modifierFlags.contains(.shift) {
                    onToggleDebugAutoScroll()
                    return nil
                }
                #endif
                return event
            default:
                return event
            }
        }
        return event
    }
}
