import Cocoa

/// 전역 키 이벤트 처리 로직을 AppDelegate에서 분리한 핸들러.
/// AppDelegate는 설치(install)만 하고, 실제 키 바인딩 판정은 여기서 수행한다.
@MainActor
final class KeyCommandHandler {
    /// 스페이스바로 재생/일시정지할 플레이어 창이 현재 키 윈도우인지.
    let isPlayerKeyWindow: () -> Bool
    /// Cmd+스페이스가 아닌 스페이스바를 플레이어 토글로 소비할지 결정하는 후크.
    let onTogglePlayerPlayPause: () -> Void
    /// ↑/↓ 화살표로 볼륨을 조절한다. delta는 +5.0 또는 -5.0.
    let onVolumeChange: (Double) -> Void
    let onOpenSettings: () -> Void
    let onToggleDebugPanel: (() -> Void)?
    let onToggleDebugAutoScroll: (() -> Void)?

    init(
        isPlayerKeyWindow: @escaping () -> Bool,
        onTogglePlayerPlayPause: @escaping () -> Void,
        onVolumeChange: @escaping (Double) -> Void,
        onOpenSettings: @escaping () -> Void,
        onToggleDebugPanel: (() -> Void)? = nil,
        onToggleDebugAutoScroll: (() -> Void)? = nil
    ) {
        self.isPlayerKeyWindow = isPlayerKeyWindow
        self.onTogglePlayerPlayPause = onTogglePlayerPlayPause
        self.onVolumeChange = onVolumeChange
        self.onOpenSettings = onOpenSettings
        self.onToggleDebugPanel = onToggleDebugPanel
        self.onToggleDebugAutoScroll = onToggleDebugAutoScroll
    }

    func handle(_ event: NSEvent) -> NSEvent? {
        // 텍스트 입력 중에는 스페이스/화살표만 통과시킨다 (입력에 쓰일 수 있는 키).
        // cmd 조합은 텍스트 입력 중에도 항상 처리한다 — 메뉴 키 등가물에 의존하지 않으므로
        // 메뉴바가 재설정되기 전(앱 실행 직후)에도 동작한다.
        let isTextEditing = { () -> Bool in
            guard let responder = NSApp.keyWindow?.firstResponder else { return false }
            return responder is NSText || responder is NSTextView
        }()
        // 영상 플레이어 창이 활성일 때 스페이스바(49) → 재생/일시정지
        if event.keyCode == 49 {
            #if DEBUG
            let cmd = event.modifierFlags.contains(.command)
            Task { @MainActor in
                DebugLogManager.shared?.append("[Key] Space — cmd=\(cmd) playerKey=\(self.isPlayerKeyWindow())")
            }
            #endif
            if isTextEditing { return event }
            if !event.modifierFlags.contains(.command), isPlayerKeyWindow() {
                onTogglePlayerPlayPause()
                return nil
            }
        }
        // 플레이어 창이 활성일 때 ↑(126)/↓(125) → 볼륨 조절
        if event.keyCode == 126 || event.keyCode == 125 {
            if isTextEditing { return event }
            if isPlayerKeyWindow() {
                let delta = event.keyCode == 126 ? 5.0 : -5.0
                #if DEBUG
                Task { @MainActor in
                    DebugLogManager.shared?.append("[Key] Volume — delta=\(delta)")
                }
                #endif
                onVolumeChange(delta)
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
            case 2: // d (debug panel toggle) — local monitor가 항상 처리 (메뉴 키 등가물에 의존하지 않음)
                #if DEBUG
                onToggleDebugPanel?()
                return nil
                #else
                return event
                #endif
            case 6: // w (close window) — 메뉴 키 등가물에 의존하지 않고 keyWindow를 직접 닫는다
                if let win = NSApp.keyWindow {
                    win.performClose(nil)
                    return nil
                }
                return event
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
                    onToggleDebugAutoScroll?()
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
