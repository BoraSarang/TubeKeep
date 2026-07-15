import Cocoa

final class FixedWidthWindowController: NSObject, NSWindowDelegate {
    private let fixedWidth: CGFloat
    private(set) weak var window: NSWindow?
    init(window: NSWindow, width: CGFloat = 840) {
        self.fixedWidth = width
        self.window = window
        super.init()
        window.delegate = self
    }
    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        NSSize(width: fixedWidth, height: frameSize.height)
    }
}
