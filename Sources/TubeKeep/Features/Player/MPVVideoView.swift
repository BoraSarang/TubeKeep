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
        updateGLContext()
    }

    override func update() {
        super.update()
        updateGLContext()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        updateGLContext()
    }

    /// fullscreen 진입/종료 전환 중에는 화면이 분리되는 순간(screen == nil)이 있어
    /// GL 컨텍스트 갱신을 건너뛴다 (CGLSetVirtualScreen 크래시 방지).
    /// fullscreen 진입이 완료된 뒤에는 screen이 다시 설정되므로 정상 갱신된다.
    /// 컨텍스트 update(drawable 재구성)는 CGL 잠금으로 렌더 스레드와 직렬화한다. (T-1206)
    private func updateGLContext() {
        guard let window, window.screen != nil else { return }
        guard let ctx = openGLContext else { return }
        ctx.lock()
        ctx.update()
        ctx.unlock()
    }
}
