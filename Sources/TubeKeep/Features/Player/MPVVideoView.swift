import SwiftUI
import AppKit

struct MPVVideoView: NSViewRepresentable {
    let client: MPVClient

    func makeNSView(context: Context) -> NSView {
        let attrs: [NSOpenGLPixelFormatAttribute] = [
            NSOpenGLPixelFormatAttribute(NSOpenGLPFAOpenGLProfile),
            NSOpenGLPixelFormatAttribute(NSOpenGLProfileVersion3_2Core),
            NSOpenGLPixelFormatAttribute(NSOpenGLPFAAccelerated),
            NSOpenGLPixelFormatAttribute(NSOpenGLPFADoubleBuffer),
            NSOpenGLPixelFormatAttribute(NSOpenGLPFAColorSize), NSOpenGLPixelFormatAttribute(24),
            NSOpenGLPixelFormatAttribute(NSOpenGLPFAAllowOfflineRenderers),
            0
        ]
        guard let format = NSOpenGLPixelFormat(attributes: attrs),
              let view = MPVOpenGLView(frame: .zero, pixelFormat: format) else {
            return NSView()
        }
        view.wantsBestResolutionOpenGLSurface = true
        client.attachView(view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

final class MPVOpenGLView: NSOpenGLView {
    override var isOpaque: Bool { true }

    override func reshape() {
        super.reshape()
        openGLContext?.update()
    }

    override func update() {
        super.update()
        openGLContext?.update()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        openGLContext?.update()
    }
}
