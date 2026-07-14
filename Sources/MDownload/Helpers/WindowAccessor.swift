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
                window.level = isOnTop ? .floating : .normal
                window.identifier = NSUserInterfaceItemIdentifier(windowIdentifier)
            }
        )
    }
}

extension View {
    func alwaysOnTop(_ isOnTop: Bool, windowIdentifier: String = "main") -> some View {
        modifier(AlwaysOnTopModifier(isOnTop: isOnTop, windowIdentifier: windowIdentifier))
    }
}


