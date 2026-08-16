import Cocoa
import SwiftUI

/// 앱 전역 창 생성 공통 로직을 한 곳에 모은다.
/// AppDelegate의 `open*Window` 메서드들이 중복하던 NSWindow 구성 코드를 대체한다.
@MainActor
enum WindowFactory {
    /// SwiftUI 뷰를 담는 NSWindow를 공통 설정으로 구성한다.
    static func makeWindow<Content: View>(
        identifier: String,
        title: String,
        rootView: Content,
        contentSize: NSSize,
        minSize: NSSize? = nil,
        maxSize: NSSize? = nil,
        styleMask: NSWindow.StyleMask = [.titled, .closable],
        zoomEnabled: Bool = true,
        level: NSWindow.Level? = nil,
        movableByBackground: Bool = false,
        collectionBehavior: NSWindow.CollectionBehavior = [.managed, .ignoresCycle],
        titlebarIcon: NSImage? = nil,
        delegate: NSWindowDelegate? = nil
    ) -> NSWindow {
        let hostingCtrl = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingCtrl)
        window.title = title
        window.styleMask = styleMask
        window.showsResizeIndicator = styleMask.contains(.resizable)
        window.isReleasedWhenClosed = false
        window.collectionBehavior = collectionBehavior
        window.identifier = NSUserInterfaceItemIdentifier(identifier)
        if let minSize { window.contentMinSize = minSize }
        if let maxSize { window.contentMaxSize = maxSize }
        window.setContentSize(contentSize)
        if !zoomEnabled {
            window.standardWindowButton(.zoomButton)?.isEnabled = false
        }
        if let titlebarIcon {
            if let docButton = window.standardWindowButton(.documentIconButton) {
                docButton.isHidden = false
                docButton.image = titlebarIcon
            }
        }
        if let level { window.level = level }
        if movableByBackground { window.isMovableByWindowBackground = true }
        if let delegate { window.delegate = delegate }
        return window
    }

    /// SF Symbol을 타이틀바 창 아이콘으로 사용할 NSImage로 생성한다.
    static func icon(_ symbolName: String) -> NSImage? {
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        image?.isTemplate = true
        return image
    }

    /// 창을 화면 중앙에 띄우고 앱을 전면으로 활성화한다.
    static func present(_ window: NSWindow) {
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
