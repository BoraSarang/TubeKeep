import SwiftUI
import AppKit

struct MPVVideoView: NSViewRepresentable {
    let client: MPVClient

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = nil
        client.attachView(view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
