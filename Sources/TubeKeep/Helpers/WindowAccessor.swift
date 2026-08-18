import SwiftUI
import AppKit

struct WindowAccessor: NSViewRepresentable {
    var onWindowAvailable: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { [weak view] in
            guard let window = view?.window else { return }
            onWindowAvailable(window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let window = nsView.window else { return }
        onWindowAvailable(window)
    }
}

struct AlwaysOnTopModifier: ViewModifier {
    let isOnTop: Bool
    let windowIdentifier: String

    func body(content: Content) -> some View {
        content.background(
            WindowAccessor { window in
                window.identifier = NSUserInterfaceItemIdentifier(windowIdentifier)
                // fullscreen 전환 중에는 level 변경 금지 — AppKit 전체화면 전환 로직과 충돌해
                // 뷰 계층 해제 경쟁 크래시(_NSExitFullScreenTransitionController)를 유발한다.
                guard !window.styleMask.contains(.fullScreen) else { return }
                window.level = isOnTop ? .floating : .normal
            }
        )
    }
}

extension View {
    func alwaysOnTop(_ isOnTop: Bool, windowIdentifier: String = "main") -> some View {
        modifier(AlwaysOnTopModifier(isOnTop: isOnTop, windowIdentifier: windowIdentifier))
    }
}


