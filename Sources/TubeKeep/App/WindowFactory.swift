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
        delegate: NSWindowDelegate? = nil,
        fullSizeTitlebar: Bool = false,
        autosaveName: String? = nil
    ) -> NSWindow {
        let hostingCtrl = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingCtrl)
        window.title = title
        window.styleMask = styleMask
        window.showsResizeIndicator = styleMask.contains(.resizable)
        window.isReleasedWhenClosed = false
        window.collectionBehavior = collectionBehavior
        window.identifier = NSUserInterfaceItemIdentifier(identifier)
        if fullSizeTitlebar {
            window.titlebarAppearsTransparent = true
            window.styleMask.insert(.fullSizeContentView)
            window.titleVisibility = .visible
        }
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
        if let autosaveName {
            window.setFrameAutosaveName(autosaveName)
        }
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

    /// 창 프레임 자동 복원(autosave) — macOS 표준 위치/크기 기억.
    /// nil을 넣으면 autosave를 비활성화한다.
    static func restore(_ window: NSWindow, autosaveName: String?) {
        guard let autosaveName else {
            window.setFrameAutosaveName("")
            return
        }
        window.setFrameAutosaveName(autosaveName)
    }

    /// macOS 26(Tahoe) 이상에서만 적용되는 Liquid Glass 재질 helper.
    /// - Returns: macOS 26 이상이면 true, 이전 버전이면 false (호출부에서 분기).
    static var isLiquidGlassAvailable: Bool {
        if #available(macOS 26.0, *) { return true }
        return false
    }
}
