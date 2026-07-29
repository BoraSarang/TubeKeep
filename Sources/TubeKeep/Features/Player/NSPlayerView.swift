import SwiftUI
import AVKit

struct NSPlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> PlayerViewHost {
        let host = PlayerViewHost()
        host.player = player
        return host
    }

    func updateNSView(_ nsView: PlayerViewHost, context: Context) {
        nsView.player = player
    }
}

class PlayerViewHost: NSView {
    var player: AVPlayer? {
        didSet {
            playerView?.player = player
        }
    }
    private var playerView: AVPlayerView?

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { nil }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor

        let pv = AVPlayerView()
        pv.player = player
        pv.controlsStyle = .none
        pv.autoresizingMask = [.width, .height]
        pv.frame = bounds
        addSubview(pv)
        playerView = pv
    }

    override func layout() {
        super.layout()
        playerView?.frame = bounds
    }
}
